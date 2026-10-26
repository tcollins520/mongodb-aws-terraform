# MongoDB Enterprise on AWS --- Installation, Replication & Failover Runbook

This README documents the hands-on MongoDB Enterprise deployment on
three AWS EC2 nodes, including installation, TLS, authorization,
replica-set initialization, replication validation, and controlled
primary failover.

> **Accuracy note:** The node addresses, installed versions,
> configuration values, successful command outputs, and test results
> below reflect the project state recorded during implementation. Some
> original one-off installation/PKI commands were not retained verbatim
> in the conversation; commands below provide a reproducible runbook for
> those steps. Check the version/repository availability before
> re-running installation commands.

## 1. Architecture and current state

-   AWS Region: `us-east-1`
-   VPC: `vpc-08179611eb7730eeb` (`10.20.0.0/16`)
-   OS: Red Hat Enterprise Linux 8.10, x86-64
-   MongoDB Enterprise: `8.0.34`
-   `mongosh`: `2.14.0`
-   Replica set: `rs0`
-   Database port: TCP `27017`
-   SSH is through the bastion; MongoDB should not be exposed publicly.

  ---------------------------------------------------------------------------------------
  Node           Private IP         Availability   EC2 instance ID         Role at last
                                    Zone                                   validation
  -------------- ------------------ -------------- ----------------------- --------------
  `mongo-cs1`    `10.20.11.249`     `us-east-1a`   `i-0dbb8ea57a6abd9ac`   `SECONDARY`

  `mongo-cs2`    `10.20.21.49`      `us-east-1b`   `i-0f544e36d0f592e90`   `PRIMARY`

  `mongo-cs3`    `10.20.31.199`     `us-east-1c`   `i-0af0c0650f448715b`   `SECONDARY`

  Bastion        `10.20.10.157`     ---            `i-0f225ad2eb5549aae`   SSH jump host
                 private;                                                  
                 `32.196.121.156`                                          
                 public                                                    
  ---------------------------------------------------------------------------------------

### SSH aliases

The Mac has SSH aliases `mongo-bastion`, `mongo-cs1`, `mongo-cs2`, and
`mongo-cs3` in `~/.ssh/config`, using `ec2-user`, key
`~/.ssh/mongodb-aws-key`, and `ProxyJump mongo-bastion`.

Example from the Mac:

``` bash
ssh mongo-cs1
ssh mongo-cs2
ssh mongo-cs3
```

The original Terraform project is `~/mongodb-aws-terraform`, with
Terraform files in `~/mongodb-aws-terraform/terraform`. GitHub
repository: <https://github.com/tcollins520/mongodb-aws-terraform>.

## 2. Security group and network prerequisites

Before installing MongoDB, confirm these network rules in AWS:

-   Allow SSH from your trusted management source to the bastion.
-   Allow SSH from the bastion security group to the three database
    nodes.
-   Allow TCP `27017` between the three database nodes (preferably
    source-restricted to the database-node security group).
-   Allow TCP `27017` from the bastion or approved management sources
    only if interactive administration through the bastion is needed.
-   Do **not** allow TCP `27017` from `0.0.0.0/0`.
-   Ensure each node can reach the MongoDB package repository and
    required OS repositories for installation.

Use AWS CLI from the Mac to inspect instances if needed:

``` bash
aws ec2 describe-instances \
  --instance-ids i-0dbb8ea57a6abd9ac i-0f544e36d0f592e90 i-0af0c0650f448715b \
  --region us-east-1 \
  --query 'Reservations[].Instances[].{Instance:InstanceId,State:State.Name,PrivateIP:PrivateIpAddress,AZ:Placement.AvailabilityZone}' \
  --output table
```

## 3. Install MongoDB Enterprise 8.0 on all three nodes

Run the following on **each database node** (`mongo-cs1`, `mongo-cs2`,
and `mongo-cs3`) as `ec2-user` with sudo access.

### 3.1 Add the MongoDB Enterprise 8.0 repository

``` bash
sudo tee /etc/yum.repos.d/mongodb-enterprise-8.0.repo > /dev/null <<'EOF'
[mongodb-enterprise-8.0]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/8/mongodb-enterprise/8.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF
```

Refresh package metadata and inspect available versions:

``` bash
sudo dnf makecache
sudo dnf --showduplicates list mongodb-enterprise
```

### 3.2 Install the version used in this project

The project nodes reported MongoDB Enterprise `8.0.34`. If the exact
version remains available from the configured repository, install it
with:

``` bash
sudo dnf install -y mongodb-enterprise
```

If DNF reports that one of these exact package versions is unavailable,
inspect `dnf --showduplicates list` and use the package names/versions
available in the approved repository. Do not silently mix MongoDB minor
versions across the three nodes.

Verify on each node:

``` bash
mongod --version
mongosh --version
rpm -qa | grep -E '^mongodb-enterprise'
```

Expected project versions: MongoDB `8.0.34`; `mongosh` `2.14.0`.

### 3.3 Keep MongoDB stopped until TLS and config are ready

``` bash
sudo systemctl enable mongod
sudo systemctl stop mongod
```

## 4. TLS certificates and keyfile

TLS and internal replica-set authentication were configured before
initializing `rs0`.

### 4.1 Certificate layout

The CA was created on the Mac under:

-   `~/mongodb-aws-terraform/pki/mongodb-ca.key`
-   `~/mongodb-aws-terraform/pki/mongodb-ca.crt`

CA subject CN: `MongoDB-Project-CA`.

**Never copy `mongodb-ca.key` to an EC2 node or commit it to Git.** Only
the CA certificate is copied to nodes.

Each node has a certificate PEM bundle (certificate followed by its
private key) and the CA certificate:

  ----------------------------------------------------------------------------------------
  Node              DNS SAN           IP SAN            Certificate bundle on node
  ----------------- ----------------- ----------------- ----------------------------------
  `mongo-cs1`       `mongo-cs1`       `10.20.11.249`    `/etc/mongodb/pki/mongo-cs1.pem`

  `mongo-cs2`       `mongo-cs2`       `10.20.21.49`     `/etc/mongodb/pki/mongo-cs2.pem`

  `mongo-cs3`       `mongo-cs3`       `10.20.31.199`    `/etc/mongodb/pki/mongo-cs3.pem`
  ----------------------------------------------------------------------------------------

The certificates were validated successfully (`openssl verify` returned
`OK` for all three). They were created with `serverAuth,clientAuth`
extended key usage and `digitalSignature,keyEncipherment` key usage.

### 4.2 Create directories and set permissions on each node

Run on each node, substituting its certificate name as needed:

``` bash
sudo install -d -o root -g mongod -m 750 /etc/mongodb/pki
sudo install -d -o root -g mongod -m 750 /etc/mongodb/secrets
```

Copy the node-specific PEM bundle and `mongodb-ca.crt` into
`/etc/mongodb/pki/` using the secure transfer method already configured
for this project. Then set permissions on each node:

``` bash
sudo chown root:mongod /etc/mongodb/pki/mongo-cs1.pem /etc/mongodb/pki/mongodb-ca.crt
sudo chmod 640 /etc/mongodb/pki/mongo-cs1.pem /etc/mongodb/pki/mongodb-ca.crt
```

For `mongo-cs2`, use `mongo-cs2.pem`; for `mongo-cs3`, use
`mongo-cs3.pem`. Do not run the `mongo-cs1.pem` ownership command
unchanged on other nodes.

### 4.3 Validate certificate files

Run on each node, from a location containing the CA and issued
certificate files as appropriate:

``` bash
openssl verify -CAfile /etc/mongodb/pki/mongodb-ca.crt /path/to/mongo-cs1.crt
```

Use the matching certificate filename for each node. Expected output
ends in `OK`.

### 4.4 Generate and distribute the shared replica-set keyfile

A single random keyfile was generated on `mongo-cs1` and securely copied
to the other nodes. Generate it only once for a new deployment; **do not
generate a different keyfile per node**.

On `mongo-cs1`:

``` bash
sudo install -d -o root -g mongod -m 750 /etc/mongodb/secrets
sudo sh -c 'openssl rand -base64 756 > /etc/mongodb/secrets/rs0-keyfile'
sudo chown mongod:mongod /etc/mongodb/secrets/rs0-keyfile
sudo chmod 400 /etc/mongodb/secrets/rs0-keyfile
```

Securely copy that same file to `mongo-cs2` and `mongo-cs3`, then on
**each** node run:

``` bash
sudo chown mongod:mongod /etc/mongodb/secrets/rs0-keyfile
sudo chmod 400 /etc/mongodb/secrets/rs0-keyfile
sudo stat -c '%U:%G %a %n' /etc/mongodb/secrets/rs0-keyfile
```

Expected owner/mode: `mongod:mongod 400`.

> The original transfer process used a temporary copy to move the
> keyfile. The transcript did not confirm cleanup of
> `/home/ec2-user/rs0-keyfile` on `mongo-cs1` or `./rs0-keyfile` on the
> Mac. Check and remove any temporary copies after confirming the
> installed copies are correct.

## 5. Configure `/etc/mongod.conf` on all nodes

The final effective configuration has the same structure on each node.
Only `bindIp` and `certificateKeyFile` differ.

### 5.1 `mongo-cs1`

``` yaml
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

storage:
  dbPath: /var/lib/mongo

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

net:
  port: 27017
  bindIp: 127.0.0.1,10.20.11.249
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/mongodb/pki/mongo-cs1.pem
    CAFile: /etc/mongodb/pki/mongodb-ca.crt
    allowConnectionsWithoutCertificates: true

security:
  authorization: enabled
  keyFile: /etc/mongodb/secrets/rs0-keyfile

replication:
  replSetName: rs0
```

### 5.2 `mongo-cs2`

Use the same configuration with these node-specific values:

``` yaml
  bindIp: 127.0.0.1,10.20.21.49
  tls:
    certificateKeyFile: /etc/mongodb/pki/mongo-cs2.pem
```

All other TLS, security, storage, logging, process-management, and
replication settings remain the same as the `mongo-cs1` configuration.

### 5.3 `mongo-cs3`

Use the same configuration with these node-specific values:

``` yaml
  bindIp: 127.0.0.1,10.20.31.199
  tls:
    certificateKeyFile: /etc/mongodb/pki/mongo-cs3.pem
```

All other settings remain the same.

Edit on each node:

``` bash
sudo vi /etc/mongod.conf
```

Validate the config on each node:

``` bash
sudo mongod --config /etc/mongod.conf --outputConfig
```

Review the rendered output for the correct node IP/certificate,
`allowConnectionsWithoutCertificates: true`, `authorization: enabled`,
the keyfile path, and `replication.replSetName: rs0`.

Start/restart and check each node:

``` bash
sudo systemctl enable mongod
sudo systemctl restart mongod
sudo systemctl is-active mongod
```

Expected service status: `active` on all three nodes.

## 6. Bootstrap the first administrator

The first user was created while `mongo-cs1` was temporarily running in
standalone mode, because the initial attempt to create a user while
connected to the private hostname was rejected with `Unauthorized`. The
local bootstrap connection used `--tlsAllowInvalidHostnames` because the
server certificate SAN did not include `127.0.0.1`; CA validation
remained enabled via `--tlsCAFile`.

### 6.1 Temporary standalone bootstrap (historical step)

To reproduce this bootstrap pattern on a fresh deployment only,
temporarily comment out the replication section on **all three nodes**,
validate the config, and restart all three services. Do not repeat this
on the existing live replica set unless you intentionally plan a
maintenance window and have a recovery plan.

Temporary configuration:

``` yaml
# replication:
#   replSetName: rs0
```

The existing deployment has already restored the replication section and
initialized `rs0`; **do not comment it out again for the current
cluster**.

On `mongo-cs1`, connect locally:

``` bash
mongosh "mongodb://127.0.0.1:27017/?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --tlsAllowInvalidHostnames
```

At the `mongosh` prompt:

``` javascript
use admin
db.createUser({
  user: "siteAdmin",
  pwd: passwordPrompt(),
  roles: [{ role: "root", db: "admin" }]
})
```

Expected successful result:

``` javascript
{ ok: 1 }
```

`siteAdmin` is an administrative bootstrap account with broad
privileges. Do not use it as an application account. The next planned
phase is to create least-privilege application and read-only users.

### 6.2 Verify authenticated access

Connect to `mongo-cs1`:

``` bash
mongosh "mongodb://mongo-cs1:27017/admin?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --username siteAdmin \
  --authenticationDatabase admin \
  --password
```

At the prompt:

``` javascript
db.runCommand({ connectionStatus: 1 })
```

The successful result showed `siteAdmin` authenticated against `admin`
and its role as `root`.

## 7. Initialize the replica set `rs0`

Run this **once only**, authenticated as `siteAdmin`, connected directly
to `mongo-cs1` after restoring the replication section and restarting
all nodes.

Connect:

``` bash
mongosh "mongodb://mongo-cs1:27017/admin?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --username siteAdmin \
  --authenticationDatabase admin \
  --password
```

Initialize:

``` javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "10.20.11.249:27017" },
    { _id: 1, host: "10.20.21.49:27017" },
    { _id: 2, host: "10.20.31.199:27017" }
  ]
})
```

Observed result:

``` javascript
{ ok: 1 }
```

Validate:

``` javascript
rs.status()
```

Then summarize the members:

``` javascript
rs.status().members.map(m => ({
  name: m.name,
  state: m.stateStr,
  health: m.health
}))
```

The initial state was:

-   `10.20.11.249:27017` --- `PRIMARY`, health `1`
-   `10.20.21.49:27017` --- `SECONDARY`, health `1`
-   `10.20.31.199:27017` --- `SECONDARY`, health `1`

Use `db.hello()` or `db.adminCommand({ hello: 1 })` to check the node
role and primary address.

## 8. Validate initial replication

### 8.1 Connect to the original primary

``` bash
mongosh "mongodb://10.20.11.249:27017/admin?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --username siteAdmin \
  --authenticationDatabase admin \
  --password
```

### 8.2 Insert a test document on `mongo-cs1`

Run each statement separately in `mongosh`:

``` javascript
use replicationTest
```

``` javascript
db.replicationCheck.insertOne({
  test: "replication-validation",
  createdAt: new Date(),
  source: "mongo-cs1"
})
```

Successful result recorded:

``` javascript
{
  acknowledged: true,
  insertedId: ObjectId("6adf128236884b9fc565ead2")
}
```

### 8.3 Verify on `mongo-cs2`

Connect to `mongo-cs2`:

``` bash
mongosh "mongodb://10.20.21.49:27017/admin?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --username siteAdmin \
  --authenticationDatabase admin \
  --password
```

Run each line separately:

``` javascript
use replicationTest
```

``` javascript
db.getMongo().setReadPref("secondary")
```

``` javascript
db.replicationCheck.find().pretty()
```

The document with `_id` `6adf128236884b9fc565ead2` was found on
`mongo-cs2`.

### 8.4 Verify on `mongo-cs3`

Connect:

``` bash
mongosh "mongodb://10.20.31.199:27017/admin?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --username siteAdmin \
  --authenticationDatabase admin \
  --password
```

Run separately:

``` javascript
use replicationTest
```

``` javascript
db.getMongo().setReadPref("secondary")
```

``` javascript
db.replicationCheck.find().pretty()
```

The same document and ObjectId were found on `mongo-cs3`. This confirmed
replication to both secondaries.

## 9. Controlled failover: step down `mongo-cs1`

At the time of the test, `mongo-cs1` was primary and both other nodes
were healthy secondaries.

### 9.1 Connect directly to `mongo-cs1`

``` bash
mongosh "mongodb://10.20.11.249:27017/admin?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --username siteAdmin \
  --authenticationDatabase admin \
  --password
```

Confirm the current role:

``` javascript
db.hello()
```

Before the stepdown, `isWritablePrimary` was `true` on `mongo-cs1`.

### 9.2 Step down the primary

Run on the primary only:

``` javascript
rs.stepDown(60)
```

Observed result:

``` javascript
{ ok: 1 }
```

The shell then showed `mongo-cs1` as `SECONDARY`, as expected.

### 9.3 Confirm the new primary

``` javascript
rs.status().members.map(m => ({
  name: m.name,
  state: m.stateStr,
  health: m.health
}))
```

Observed result:

``` javascript
[
  { name: "10.20.11.249:27017", state: "SECONDARY", health: 1 },
  { name: "10.20.21.49:27017", state: "PRIMARY", health: 1 },
  { name: "10.20.31.199:27017", state: "SECONDARY", health: 1 }
]
```

`mongo-cs2` (`10.20.21.49`) became primary.

## 10. Verify writes after failover

### 10.1 Connect to the new primary (`mongo-cs2`)

``` bash
mongosh "mongodb://10.20.21.49:27017/admin?directConnection=true&tls=true" \
  --tlsCAFile /etc/mongodb/pki/mongodb-ca.crt \
  --username siteAdmin \
  --authenticationDatabase admin \
  --password
```

Confirm it is writable:

``` javascript
db.hello()
```

The observed output included:

``` javascript
{
  isWritablePrimary: true,
  primary: "10.20.21.49:27017",
  me: "10.20.21.49:27017"
}
```

### 10.2 Insert a new document on `mongo-cs2`

Run separately:

``` javascript
use replicationTest
```

``` javascript
db.replicationCheck.insertOne({
  test: "failover-write-validation",
  createdAt: new Date(),
  source: "mongo-cs2",
  primaryAfterFailover: true
})
```

Successful result recorded:

``` javascript
{
  acknowledged: true,
  insertedId: ObjectId("6adf15e1ad1613d1a4a86c43")
}
```

### 10.3 Verify the post-failover write on `mongo-cs1`

Connect to `mongo-cs1` with the authenticated connection command in
section 8.1, then run these one at a time:

``` javascript
use replicationTest
```

``` javascript
db.getMongo().setReadPref("secondary")
```

``` javascript
db.replicationCheck.find({ test: "failover-write-validation" }).pretty()
```

The expected document was returned with `_id`
`6adf15e1ad1613d1a4a86c43`, source `mongo-cs2`, and
`primaryAfterFailover: true`.

### 10.4 Verify the post-failover write on `mongo-cs3`

Connect to `mongo-cs3` with the authenticated connection command in
section 8.4, then run:

``` javascript
use replicationTest
```

``` javascript
db.getMongo().setReadPref("secondary")
```

``` javascript
db.replicationCheck.find({ test: "failover-write-validation" }).pretty()
```

The same document was returned on `mongo-cs3`. This confirmed that the
write made on the new primary replicated to both secondaries after
failover.

## 11. Final health check after failover

Run on any authenticated replica-set member:

``` javascript
rs.status().members.map(m => ({
  name: m.name,
  state: m.stateStr,
  health: m.health
}))
```

Final observed state:

  Node                                   State         Health
  -------------------------------------- ------------- --------
  `mongo-cs1` --- `10.20.11.249:27017`   `SECONDARY`   `1`
  `mongo-cs2` --- `10.20.21.49:27017`    `PRIMARY`     `1`
  `mongo-cs3` --- `10.20.31.199:27017`   `SECONDARY`   `1`

### What was proven

-   The three-member replica set initialized successfully.
-   All three members were healthy at the last check.
-   The initial test write on `mongo-cs1` was replicated to both
    secondaries.
-   `rs.stepDown(60)` caused the primary to step down successfully.
-   `mongo-cs2` was elected primary.
-   The new primary accepted a write.
-   That post-failover write was replicated to both `mongo-cs1` and
    `mongo-cs3`.

## 12. Troubleshooting notes from the implementation

### `Unauthorized` while creating the first user

The first attempt to create `siteAdmin` through the private hostname was
rejected. The localhost exception applies only to a localhost connection
when no users/roles exist. The bootstrap was performed through
`127.0.0.1` after temporarily disabling replica-set mode on all three
nodes. After the first user was created and authentication verified,
replica-set mode was restored.

### TLS hostname verification on loopback

The server certificate did not include `127.0.0.1` as a SAN. The local
bootstrap command therefore used `--tlsAllowInvalidHostnames` while
still providing `--tlsCAFile`. For a hardened follow-up, consider
issuing a certificate with `localhost` and `127.0.0.1` SANs for the
relevant local use case rather than routinely bypassing hostname
verification.

### `getaddrinfo ENOTFOUND mongo-cs1`

A connection from `mongo-cs2` using the hostname `mongo-cs1` failed to
resolve. The working commands used private IPs. Validate private
DNS/host mappings before using DNS names for connections.

### Deprecated `rs.secondaryOk()`

That method returned a deprecation warning. The later verification used:

``` javascript
db.getMongo().setReadPref("secondary")
```

### Configuration validation

Use this on each node after editing `mongod.conf`:

``` bash
sudo mongod --config /etc/mongod.conf --outputConfig
```

Then restart and verify:

``` bash
sudo systemctl restart mongod
sudo systemctl is-active mongod
```

## 13. Security and cleanup checklist

-   [ ] Verify and remove any temporary `/home/ec2-user/rs0-keyfile`
    copy on `mongo-cs1` if it still exists.
-   [ ] Verify and remove any temporary `./rs0-keyfile` copy on the Mac
    if it still exists.
-   [ ] Never commit the CA private key, node private keys, keyfile,
    passwords, Terraform state, `.terraform/`, or real secret-bearing
    `.tfvars` files.
-   [ ] Create dedicated least-privilege application and read-only users
    in the next RBAC phase.
-   [ ] Verify private DNS/host resolution if hostnames will be used in
    the replica-set configuration.
-   [ ] Consider reissuing certificates with loopback SANs if local TLS
    connections should not require hostname-check exceptions.
-   [ ] Complete backup/recovery and test an actual restore.
-   [ ] Complete final security/operational validation.
-   [ ] Implement sharding only after replica-set, RBAC,
    backup/recovery, and security validation.

## 14. Next phases

1.  **RBAC:** create a least-privilege application user and a separate
    read-only user; test allowed and denied operations.
2.  **Backup and recovery:** run a backup, validate its contents,
    restore into a controlled target, and verify the restored data.
3.  **Final security/operations:** review TLS, access control, key
    handling, network rules, and operational checks.
4.  **Sharding:** implement at the end of the project, after the
    replica-set and security milestones.

## Appendix: Quick verification commands

On any node:

``` bash
mongod --version
mongosh --version
sudo systemctl is-active mongod
sudo mongod --config /etc/mongod.conf --outputConfig
```

In an authenticated `mongosh` session:

``` javascript
db.runCommand({ connectionStatus: 1 })
db.hello()
rs.status()
rs.status().members.map(m => ({ name: m.name, state: m.stateStr, health: m.health }))
```

On a secondary, read the test data:

``` javascript
use replicationTest
db.getMongo().setReadPref("secondary")
db.replicationCheck.find().pretty()
```

**Current project state at last verification:** `mongo-cs2` was primary;
`mongo-cs1` and `mongo-cs3` were healthy secondaries. The next
phase is RBAC implementation.
