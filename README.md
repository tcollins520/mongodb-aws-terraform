# MongoDB on AWS with Terraform

## Overview

This project provisions and configures a MongoDB environment on Amazon Web Services (AWS) using Terraform and Red Hat Enterprise Linux (RHEL) 8.10. It focuses on infrastructure as code, database security, high availability, replication, backup and recovery, and distributed database architecture.

The initial deployment consists of three MongoDB nodes distributed across three AWS Availability Zones. The nodes will form a three-member replica set named `rs0`, providing data replication, automatic primary elections, and resilience to individual node failures.

Security is a core part of the implementation. MongoDB authentication, role-based access control (RBAC), TLS encryption, and internal member authentication will be configured immediately after MongoDB installation and before replica-set initialization.

Backup and recovery procedures will be implemented and tested before sharding is introduced.

## Project Objectives

- Provision AWS infrastructure using Terraform.
- Deploy MongoDB on RHEL 8.10 x86-64 EC2 instances.
- Configure a three-member MongoDB replica set across three Availability Zones.
- Implement authentication, RBAC, TLS encryption, and secure internal member communication.
- Validate replication, primary elections, failover, and node recovery.
- Implement database backup and recovery procedures and demonstrate successful restoration.
- Validate security controls and operational readiness.
- Implement MongoDB sharding as the final project phase.

## Architecture

### AWS Infrastructure

| Component | Configuration |
|---|---|
| Cloud provider | Amazon Web Services |
| Region | `us-east-1` |
| Infrastructure as code | Terraform |
| Operating system | RHEL 8.10, x86-64 |
| VPC CIDR | `10.20.0.0/16` |
| Public subnets | 3 |
| Private subnets | 3 |
| Internet connectivity | Internet Gateway and NAT Gateway |
| Routing | Separate public and private route tables |
| Administrative access | SSH through a bastion host |
| Database deployment | Three private EC2 instances |
| Database replication | MongoDB replica set `rs0` |

### MongoDB Nodes

| Node | Private IP | Availability Zone | Intended role |
|---|---|---|---|
| `mongo-cs1` | `10.20.11.249` | `us-east-1a` | Replica-set member |
| `mongo-cs2` | `10.20.21.49` | `us-east-1b` | Replica-set member |
| `mongo-cs3` | `10.20.31.199` | `us-east-1c` | Replica-set member |

All three MongoDB nodes reside in private subnets and have no public IP addresses. SSH administration is routed through the bastion host.

The replica-set members will use MongoDB's internal authentication mechanism and TLS to secure communication between nodes.

**Note:** The node roles shown above describe the intended architecture. The elected primary and secondary roles will be determined by replica-set initialization and elections.

## Repository Structure

```text
mongodb-aws-terraform/
├── terraform/
│   ├── .terraform/
│   ├── .gitignore
│   ├── bastion.tf
│   ├── iam.tf
│   ├── instances.tf
│   ├── networking.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── security-groups.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
├── scripts/
│   ├── install/
│   ├── security/
│   ├── replication/
│   ├── backup-recovery/
│   └── validation/
├── docs/
│   ├── architecture.md
│   ├── installation.md
│   ├── security.md
│   ├── replica-set.md
│   ├── backup-recovery.md
│   └── sharding.md
└── README.md
```

The structure is a target organization for the project. Files and directories will be added as the implementation progresses.

## Implementation Roadmap

### Phase 1 — AWS Infrastructure

- [x] Create a dedicated VPC.
- [x] Configure three public and three private subnets.
- [x] Configure Internet Gateway, NAT Gateway, and route tables.
- [x] Provision a bastion host.
- [x] Provision three private MongoDB EC2 instances across three Availability Zones.
- [x] Configure infrastructure using Terraform.
- [ ] Complete end-to-end SSH verification for all three MongoDB nodes.
- [ ] Review and document infrastructure outputs and security-group rules.

### Phase 2 — MongoDB Installation

- [ ] Configure the official MongoDB repository compatible with RHEL 8.
- [ ] Select and pin a consistent MongoDB Community Server version.
- [ ] Install MongoDB on all three nodes.
- [ ] Configure service startup and verify installation.
- [ ] Document installation commands and configuration files.

### Phase 3 — Authentication, RBAC, and TLS

Security will be implemented immediately after installation, before replica-set initialization.

- [ ] Configure MongoDB authentication.
- [ ] Create an administrative user with appropriately scoped privileges.
- [ ] Implement least-privilege application and operational roles.
- [ ] Configure TLS certificates and certificate validation.
- [ ] Enforce encrypted MongoDB connections.
- [ ] Configure secure inter-node communication.
- [ ] Configure and securely distribute the replica-set keyfile where required.
- [ ] Restrict network access to authorized clients and database members.
- [ ] Test authenticated access, authorization boundaries, and TLS enforcement.

### Phase 4 — Three-Member Replica Set

- [ ] Configure the replica-set name `rs0`.
- [ ] Configure secure member communication and replica-set addresses.
- [ ] Initialize the replica set with authentication and TLS enabled.
- [ ] Validate primary and secondary states.
- [ ] Create test data and verify replication.
- [ ] Confirm that writes on the primary replicate to secondary members.
- [ ] Document replica-set status and health checks.

### Phase 5 — Failover and Recovery Testing

- [ ] Verify automatic primary elections.
- [ ] Perform controlled primary failover tests.
- [ ] Test recovery of a stopped or unavailable member.
- [ ] Verify replication catches up after recovery.
- [ ] Test service and instance restart behavior.
- [ ] Confirm data consistency following failover.
- [ ] Document test procedures, expected outcomes, and observed results.

### Phase 6 — Backup and Recovery

Replication alone is not a substitute for backups. This phase will establish independent recovery capabilities and demonstrate that data can be restored.

- [ ] Define backup scope, frequency, retention, and recovery objectives.
- [ ] Implement a consistent MongoDB backup procedure appropriate for the deployment.
- [ ] Store backups separately from the database nodes.
- [ ] Protect backup storage with encryption and restrictive access controls.
- [ ] Document backup verification and retention procedures.
- [ ] Restore a backup into an isolated test environment.
- [ ] Verify restored databases, collections, indexes, and test data.
- [ ] Document recovery procedures and measured recovery results.
- [ ] Evaluate point-in-time recovery requirements and supporting mechanisms.

### Phase 7 — Final Security and Operational Validation

- [ ] Verify authentication is required.
- [ ] Confirm least-privilege RBAC behavior.
- [ ] Verify TLS certificate validation and encrypted connections.
- [ ] Confirm unauthorized network access is restricted.
- [ ] Review replica-set health and member synchronization.
- [ ] Verify backup integrity and successful restoration.
- [ ] Document operational commands and troubleshooting procedures.

### Phase 8 — MongoDB Sharding

Sharding will be implemented only after the replica set, security controls, failover tests, and backup and recovery procedures are complete.

- [ ] Design the sharded architecture.
- [ ] Plan config servers and shard replica sets.
- [ ] Configure the required routing and internal connectivity.
- [ ] Deploy and secure the sharding components.
- [ ] Configure `mongos` routers.
- [ ] Enable sharding for the selected database and collections.
- [ ] Select and document appropriate shard keys.
- [ ] Validate chunk distribution and query routing.
- [ ] Test sharded-cluster availability and recovery.
- [ ] Document the final architecture and operational procedures.

## Security Principles

The deployment follows these principles:

- **Private database nodes:** MongoDB instances do not receive public IP addresses.
- **Bastion-based administration:** Administrative SSH access passes through the bastion host.
- **Authentication:** Database access requires authenticated identities.
- **Least privilege:** Users receive only the roles and privileges necessary for their responsibilities.
- **Encryption in transit:** TLS protects supported client and inter-node connections.
- **Internal authentication:** Replica-set members authenticate to one another.
- **Network restrictions:** Security-group rules limit access to required sources and ports.
- **Protected credentials:** Private keys, passwords, certificates, and internal authentication secrets must not be committed to Git.
- **Independent backups:** Recovery copies are stored separately from the database instances.

## Technology Stack

- Amazon Web Services (AWS)
- Terraform
- Amazon EC2
- Red Hat Enterprise Linux 8.10
- MongoDB Community Server
- MongoDB replica sets
- MongoDB authentication and RBAC
- TLS certificates
- SSH and bastion-based administration
- MongoDB backup and recovery tooling
- MongoDB sharding

## Validation and Evidence

Implementation claims will be marked complete only after the corresponding steps have been executed and verified.

Evidence will include:

- Terraform plans and relevant infrastructure outputs.
- MongoDB version and service status.
- Replica-set status and replication results.
- Authentication, RBAC, and TLS verification.
- Failover and member-recovery test results.
- Backup and restoration results.
- Sharded-cluster validation results.

Sensitive values, private keys, passwords, tokens, and unredacted secrets must be excluded from committed evidence.

## Project Status

**Infrastructure:** Provisioned; SSH access and node connectivity are being verified.

**MongoDB installation:** Pending.

**Security and replica-set configuration:** Planned.

**Failover testing and backup/recovery:** Planned.

**Sharding:** Deferred until all prerequisite phases are complete.

## Future Enhancements

Potential future improvements include scheduled and monitored backups, automated recovery validation, enhanced database monitoring and alerting, and documented operational runbooks.

