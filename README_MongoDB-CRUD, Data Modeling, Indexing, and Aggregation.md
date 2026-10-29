# MongoDB Learning Project: CRUD, Data Modeling, Indexing, and Aggregation

A hands-on MongoDB Enterprise learning project built by running commands
in `mongosh`, inspecting real results, and comparing MongoDB operations
with familiar SQL patterns. This README is intended to grow with the
exercises; it separates commands and outputs observed in the current
airline-database work from additional reference examples that still need
hands-on validation.

> **Recorded environment for the airline exercises:** MongoDB Enterprise
> 8.0.34, host `mongo-cs1`, port `27017`, replica set `rs0`; shell
> prompt `Enterprise rs0 [direct: primary] airline>`. The active
> database for these exercises is `airline`.

## Table of contents

1.  [Learning objectives and evidence
    labels](#learning-objectives-and-evidence-labels)
2.  [Environment and data model](#environment-and-data-model)
3.  [MongoDB fundamentals](#mongodb-fundamentals)
4.  [CRUD reference](#crud-reference)
5.  [Queries, projections, operators, and
    sorting](#queries-projections-operators-and-sorting)
6.  [Documents, arrays, and
    relationships](#documents-arrays-and-relationships)
7.  [Indexing and query performance](#indexing-and-query-performance)
8.  [Aggregation pipelines](#aggregation-pipelines)
9.  [MongoDB and SQL comparison](#mongodb-and-sql-comparison)
10. [Independent practice exercises](#independent-practice-exercises)
11. [Troubleshooting and DBA notes](#troubleshooting-and-dba-notes)
12. [Quick-reference command guide](#quick-reference-command-guide)
13. [Progress and remaining work](#progress-and-remaining-work)

## Learning objectives and evidence labels

This project practices:

-   MongoDB databases, collections, BSON documents, and `_id`.
-   Insert, read, update, replace, upsert, and delete patterns.
-   Query filters, projections, logical/comparison operators, sorting,
    and limits.
-   Embedded documents, arrays, and collection relationships.
-   Index creation and interpretation of `COLLSCAN`, `IXSCAN`, `FETCH`,
    and covered-query plans.
-   Aggregation stages including `$match`, `$group`, `$sum`, `$avg`,
    `$min`, `$max`, `$project`, `$sort`, `$unwind`, and `$lookup`.
-   SQL equivalents and differences in behavior.
-   Safe operational habits for changes and destructive operations.

To keep the README honest:

-   **Observed** means the command or output was present in the current
    airline-database practice records.
-   **Reference** means a reusable command pattern included for
    learning, but not claimed as executed in this specific airline
    session.
-   Additional operators should be changed to **Observed** only after
    running them and recording their actual result.

## Environment and data model

### Recorded environment

  Item                                              Recorded value
  ------------------------------------------------- ------------------------------
  Database                                          `airline`
  MongoDB                                           Enterprise 8.0.34
  Host                                              `mongo-cs1`
  Port                                              `27017`
  Replica set                                       `rs0`
  Shell context                                     Direct connection to PRIMARY
  Main collections used                             `customers`, `bookings`
  Additional collection used in an insert example   `flightData`

The shell prompt was:

``` text
Enterprise rs0 [direct: primary] airline>
```

### Database and collection commands

**Observed command pattern:**

``` javascript
use airline
show collections
db.getName()
```

-   `use airline` switches the shell's current database context.
-   `show collections` lists collections in the current database.
-   `db.getName()` returns the current database name.

### Customer data observed during practice

  Customer          Age Home airport   Loyalty tier
  --------------- ----- -------------- --------------
  Michael Chen       45 SFO            `Platinum`
  Sarah Johnson      33 LAX            `Platium`
  David Wilson       40 DFW            `Platium`
  Maria Garcia       29 MIA            `Silver`

The data contains the exact string `Platium` for Sarah and David. This
is a data-quality typo, not a MongoDB behavior. Exact equality matching
treats `"Platium"` and `"Platinum"` as different strings.

Maria's document included a `preferredAirports` array with `MIA`, `MCO`,
and `JFK`, and an embedded address in the practice data. Her booking
results included flights `AA101` and `UA205`.

### Inspecting documents

**Reference commands:**

``` javascript
db.customers.find()
db.customers.findOne()
db.bookings.find()
db.customers.findOne({ firstName: "Maria", lastName: "Garcia" })
```

`find()` returns a cursor of matching documents. `findOne()` returns one
matching document or `null` if none matches.

## MongoDB fundamentals

MongoDB stores records as BSON documents inside collections. Documents
use field-value pairs and can contain nested documents and arrays.
Unlike a conventional relational table, documents in a collection can
have different fields, although consistent schema design remains
important.

  -----------------------------------------------------------------------
  MongoDB                             Relational database analogy
  ----------------------------------- -----------------------------------
  Database                            Database

  Collection                          Table-like grouping of records

  Document                            Row-like record

  Field                               Column-like attribute

  Array                               Often modeled with a child table or
                                      collection

  Embedded document                   Often modeled with a related table
                                      or structured type

  `_id`                               Unique document identifier; can
                                      serve a role similar to a primary
                                      key

  Index                               Index
  -----------------------------------------------------------------------

These are useful analogies, not exact equivalences. MongoDB's document
model and relational normalization have different trade-offs.

## CRUD reference

CRUD means **Create, Read, Update, Delete**. The insert command below
was observed in the current practice record. The other examples in this
section are reference patterns and should be adapted to the actual
document shape before execution.

### Create: insert one document

**Observed command:**

``` javascript
db.flightData.insertOne({
  departureAirport: "MUC",
  arrivalAirport: "SFO",
  aircraft: "Airbus A380",
  distance: 12000,
  intercontinental: true
})
```

**Observed result shape:**

``` javascript
{
  acknowledged: true,
  insertedId: ObjectId("...")
}
```

The actual output returned a generated ObjectId. MongoDB creates `_id`
automatically when it is not supplied.

### Create: insert multiple documents

**Reference pattern:**

``` javascript
db.collectionName.insertMany([
  { name: "Example One", active: true },
  { name: "Example Two", active: false }
])
```

SQL analogy:

``` sql
INSERT INTO collection_name (name, active)
VALUES ('Example One', TRUE), ('Example Two', FALSE);
```

The SQL is conceptual: a real SQL database requires a table and
compatible column definitions.

### Read: find documents

**Observed query patterns:**

``` javascript
db.customers.find()

db.customers.find({ homeAirport: "MIA" })

db.customers.find({
  loyaltyTier: "Silver",
  active: true
})
```

SQL equivalents:

``` sql
SELECT * FROM customers;

SELECT *
FROM customers
WHERE homeAirport = 'MIA';

SELECT *
FROM customers
WHERE loyaltyTier = 'Silver'
  AND active = TRUE;
```

The SQL examples are conceptual equivalents. Field and table names,
Boolean syntax, and case rules vary by SQL platform.

### Update selected fields with `$set`

**Reference pattern:**

``` javascript
db.customers.updateOne(
  { firstName: "Maria", lastName: "Garcia" },
  { $set: { loyaltyTier: "Silver" } }
)
```

`$set` changes the specified field and preserves other fields in the
document.

SQL equivalent:

``` sql
UPDATE customers
SET loyaltyTier = 'Silver'
WHERE firstName = 'Maria'
  AND lastName = 'Garcia';
```

### Increment a numeric field with `$inc`

**Reference pattern:**

``` javascript
db.customers.updateOne(
  { firstName: "David", lastName: "Wilson" },
  { $inc: { milesFlown: 500 } }
)
```

SQL equivalent:

``` sql
UPDATE customers
SET milesFlown = milesFlown + 500
WHERE firstName = 'David'
  AND lastName = 'Wilson';
```

### Replace a document with `replaceOne()`

**Reference pattern:**

``` javascript
db.customers.replaceOne(
  { firstName: "Example", lastName: "Customer" },
  {
    firstName: "Example",
    lastName: "Customer",
    age: 35,
    homeAirport: "SFO",
    active: true
  }
)
```

`replaceOne()` replaces the matched document's non-`_id` content with
the replacement document. Fields not included in the replacement are not
retained. Review the filter and current document first.

SQL databases generally use `UPDATE` to change selected columns; a full
document replacement has no single universal SQL equivalent.

### Upsert

**Reference pattern:**

``` javascript
db.customers.updateOne(
  { email: "new.customer@example.com" },
  {
    $set: {
      firstName: "New",
      lastName: "Customer",
      email: "new.customer@example.com",
      active: true
    }
  },
  { upsert: true }
)
```

If a document matches the filter, it is updated. If none matches,
MongoDB inserts a document based on the filter and update expression. A
unique index on the key is often important when upsert logic must avoid
duplicates under concurrent writes.

SQL equivalents include platform-specific `MERGE` or
`INSERT ... ON CONFLICT` / `ON DUPLICATE KEY UPDATE` patterns. Syntax
and concurrency behavior vary by database.

### Delete

**Reference pattern:**

``` javascript
db.customers.deleteOne({
  firstName: "Example",
  lastName: "Customer"
})
```

SQL equivalent:

``` sql
DELETE FROM customers
WHERE firstName = 'Example'
  AND lastName = 'Customer';
```

**Safety:** Always inspect the filter first. `deleteMany({})` can delete
every document in the collection. Never run a destructive command with a
broad filter unless deleting all matching records is intentional.

## Queries, projections, operators, and sorting

### Projection

**Observed covered-query projection:**

``` javascript
db.customers.find(
  { loyaltyTier: "Silver", active: true },
  { _id: 0, loyaltyTier: 1, active: 1 }
)
```

In an inclusion projection, fields marked `1` are returned. `_id` is
returned by default unless explicitly excluded. Do not mix inclusion and
exclusion projections except for the special `_id` behavior.

SQL equivalent:

``` sql
SELECT loyaltyTier, active
FROM customers
WHERE loyaltyTier = 'Silver'
  AND active = TRUE;
```

### Logical and comparison operators

**Reference patterns:**

``` javascript
// Greater than
db.customers.find({ age: { $gt: 35 } })

// Greater than or equal to
db.customers.find({ age: { $gte: 35 } })

// Less than
db.customers.find({ age: { $lt: 40 } })

// One of several values
db.customers.find({ homeAirport: { $in: ["SFO", "MIA"] } })

// AND is implicit when fields are combined
db.customers.find({ active: true, age: { $gte: 30 } })

// Explicit OR
db.customers.find({
  $or: [
    { homeAirport: "SFO" },
    { homeAirport: "MIA" }
  ]
})
```

SQL equivalents use `>`, `>=`, `<`, `IN (...)`, `AND`, and `OR`.

### Sorting, limiting, and counting

**Reference patterns:**

``` javascript
db.customers.find().sort({ age: -1 })
db.customers.find().sort({ age: 1 }).limit(3)
db.customers.countDocuments({ active: true })
```

-   Sort direction `1` is ascending.
-   Sort direction `-1` is descending.
-   `limit(3)` returns at most three documents.
-   `countDocuments()` counts documents matching the filter.

SQL equivalents:

``` sql
SELECT * FROM customers ORDER BY age DESC;
SELECT * FROM customers ORDER BY age ASC LIMIT 3;
SELECT COUNT(*) FROM customers WHERE active = TRUE;
```

Some SQL platforms use `TOP` or `FETCH FIRST` rather than `LIMIT`.

## Documents, arrays, and relationships

### Embedded documents

An embedded document stores related fields inside a parent document. The
airline practice data included an embedded address for Maria.

**Reference query pattern** (adjust the nested field path to match the
stored document):

``` javascript
db.customers.find({ "address.city": "Miami" })
```

MongoDB uses dot notation to query nested fields.

SQL usually models this with separate columns or a related address
table, depending on the schema and access patterns.

### Arrays

Maria's `preferredAirports` array contained `MIA`, `MCO`, and `JFK`.

**Observed array aggregation:**

``` javascript
db.customers.aggregate([
  { $unwind: "$preferredAirports" },
  {
    $group: {
      _id: "$preferredAirports",
      customerCount: { $sum: 1 }
    }
  },
  {
    $project: {
      _id: 0,
      airport: "$_id",
      customerCount: 1
    }
  },
  { $sort: { airport: 1 } }
])
```

**Observed output:**

``` javascript
[
  { customerCount: 1, airport: "JFK" },
  { customerCount: 1, airport: "MCO" },
  { customerCount: 1, airport: "MIA" }
]
```

Other common array-update operators (reference patterns):

``` javascript
// Add an item only if it is not already present
db.customers.updateOne(
  { firstName: "Maria", lastName: "Garcia" },
  { $addToSet: { preferredAirports: "LAX" } }
)

// Append an item even if a duplicate exists
db.customers.updateOne(
  { firstName: "Maria", lastName: "Garcia" },
  { $push: { preferredAirports: "LAX" } }
)

// Remove a field
db.customers.updateOne(
  { firstName: "Maria", lastName: "Garcia" },
  { $unset: { temporaryField: "" } }
)
```

`$addToSet` prevents adding a new duplicate value but does not remove
duplicates already in the array. `$push` appends and may create
duplicates.

### `$lookup`: join bookings to customers

**Observed pipeline:**

``` javascript
db.bookings.aggregate([
  {
    $lookup: {
      from: "customers",
      localField: "customerId",
      foreignField: "_id",
      as: "customer"
    }
  },
  { $unwind: "$customer" },
  {
    $project: {
      _id: 0,
      flight: 1,
      seat: 1,
      status: 1,
      firstName: "$customer.firstName",
      lastName: "$customer.lastName",
      email: "$customer.email"
    }
  },
  { $sort: { flight: 1 } }
])
```

**Observed output:**

``` javascript
[
  {
    flight: "AA101",
    seat: "12A",
    status: "confirmed",
    firstName: "Maria",
    lastName: "Garcia",
    email: "maria.garcia@example.com"
  },
  {
    flight: "UA205",
    seat: "8C",
    status: "confirmed",
    firstName: "Maria",
    lastName: "Garcia",
    email: "maria.garcia@example.com"
  }
]
```

`$lookup` joins `bookings.customerId` to `customers._id` and stores
matches in an array called `customer`. `$unwind` expands the matched
customer. By default, `$unwind` drops bookings whose joined array is
empty. To preserve unmatched bookings, use:

``` javascript
{
  $unwind: {
    path: "$customer",
    preserveNullAndEmptyArrays: true
  }
}
```

### SQL join equivalent

A conceptual SQL equivalent for the observed join is:

``` sql
SELECT
    b.flight,
    b.seat,
    b.status,
    c.firstName,
    c.lastName,
    c.email
FROM bookings AS b
JOIN customers AS c
    ON b.customerId = c.id
ORDER BY b.flight ASC;
```

In MongoDB, the example joins `customerId` to the customer's `_id`. In a
SQL schema, the equivalent customer key might be named `id` or
`customer_id`; adapt it to the actual relational schema.

A regular SQL `JOIN` behaves like an inner join. MongoDB `$lookup`
creates an array of matching documents, conceptually closer to a left
outer join; adding `$unwind` without `preserveNullAndEmptyArrays`
removes rows without a match.

## Indexing and query performance

Indexes can reduce the amount of data MongoDB must examine, but they
also consume disk and memory and add write overhead. Design indexes
around real filter, sort, and projection patterns.

### Compound index

**Observed index name:** `loyaltyTier_1_active_1`.

``` javascript
db.customers.createIndex({ loyaltyTier: 1, active: 1 })
db.customers.getIndexes()
```

The index supports the query pattern filtering on both `loyaltyTier` and
`active`. Compound index field order matters, especially when queries
use only a prefix of the index.

### Explain with execution statistics

**Observed non-covered query:**

``` javascript
db.customers.find({
  loyaltyTier: "Silver",
  active: true
}).explain("executionStats")
```

**Observed covered-query variant:**

``` javascript
db.customers.find(
  { loyaltyTier: "Silver", active: true },
  { _id: 0, loyaltyTier: 1, active: 1 }
).explain("executionStats")
```

Recorded output for the covered query:

-   Winning plan: `PROJECTION_COVERED` over `IXSCAN`.
-   Index: `loyaltyTier_1_active_1`.
-   `nReturned: 1`.
-   `totalKeysExamined: 1`.
-   `totalDocsExamined: 0`.

Recorded output for the non-covered query:

-   Winning plan: `FETCH` over `IXSCAN`.
-   One index key examined.
-   One document examined.

### Reading common plan stages

  -----------------------------------------------------------------------
  Stage                               Meaning
  ----------------------------------- -----------------------------------
  `COLLSCAN`                          Scans collection documents

  `IXSCAN`                            Scans index entries

  `FETCH`                             Fetches full documents after
                                      identifying candidate index entries

  `PROJECTION_COVERED`                Returns required fields from the
                                      index without fetching collection
                                      documents
  -----------------------------------------------------------------------

An index being used does not automatically prove a query is optimal.
Review `nReturned`, `totalKeysExamined`, `totalDocsExamined`, sort
behavior, selectivity, write overhead, and representative workload.

### Covered queries

A covered query can satisfy the filter and projection entirely from an
index. In the observed example, the projection returned only
`loyaltyTier` and `active`, both present in the compound index, and
explicitly excluded `_id`. The recorded explain output showed zero
documents examined.

### Unique indexes

**Reference pattern:**

``` javascript
db.customers.createIndex({ email: 1 }, { unique: true })
```

A unique index prevents duplicate indexed values, subject to MongoDB's
handling of missing and null values and any partial/sparse index
options. Before creating it on existing data, check for duplicates;
otherwise index creation can fail.

### Index trade-offs

-   Faster reads for matching query patterns.
-   Additional storage and memory use.
-   More work on inserts, updates, and deletes.
-   Compound field order affects which query patterns can use an index
    efficiently.
-   Multikey indexes can support array queries but have their own
    constraints.
-   A collection scan may be reasonable for a small collection or a
    query that returns a large fraction of the data.

## Aggregation pipelines

An aggregation pipeline passes documents through ordered stages. A stage
transforms or filters the documents before passing them to the next
stage.

### Pipeline 1: average age by home airport

**Observed command:**

``` javascript
db.customers.aggregate([
  {
    $group: {
      _id: "$homeAirport",
      averageAge: { $avg: "$age" }
    }
  },
  {
    $project: {
      _id: 0,
      homeAirport: "$_id",
      averageAge: 1
    }
  },
  {
    $sort: {
      averageAge: -1
    }
  }
])
```

**Observed output:**

``` javascript
[
  { averageAge: 45, homeAirport: "SFO" },
  { averageAge: 40, homeAirport: "DFW" },
  { averageAge: 33, homeAirport: "LAX" },
  { averageAge: 29, homeAirport: "MIA" }
]
```

Explanation:

-   `$group` groups customers by `homeAirport`.
-   `$avg` calculates the average `age` in each group.
-   `$project` hides the generated `_id` and exposes it as
    `homeAirport`.
-   `$sort` sorts the average ages descending.

### Pipeline 2: match Platinum customers and group by airport

**Observed command:**

``` javascript
db.customers.aggregate([
  {
    $match: {
      loyaltyTier: "Platinum"
    }
  },
  {
    $group: {
      _id: "$homeAirport",
      averageAge: { $avg: "$age" },
      customerCount: { $sum: 1 }
    }
  },
  {
    $project: {
      _id: 0,
      homeAirport: "$_id",
      averageAge: 1,
      customerCount: 1
    }
  },
  {
    $sort: {
      averageAge: -1
    }
  }
])
```

**Observed output:**

``` javascript
[
  { averageAge: 45, customerCount: 1, homeAirport: "SFO" }
]
```

Only Michael Chen matched the exact `"Platinum"` string. The records
containing `"Platium"` were excluded. This illustrates that `$match`
filters documents before grouping and that spelling consistency affects
query results.

### Pipeline 3: expand and count preferred airports

**Observed command:**

``` javascript
db.customers.aggregate([
  {
    $unwind: "$preferredAirports"
  },
  {
    $group: {
      _id: "$preferredAirports",
      customerCount: { $sum: 1 }
    }
  },
  {
    $project: {
      _id: 0,
      airport: "$_id",
      customerCount: 1
    }
  },
  {
    $sort: {
      airport: 1
    }
  }
])
```

**Observed output:**

``` javascript
[
  { customerCount: 1, airport: "JFK" },
  { customerCount: 1, airport: "MCO" },
  { customerCount: 1, airport: "MIA" }
]
```

`$unwind` expands array entries into separate pipeline documents;
`$group` counts each airport; `$project` renames the output field;
`$sort` orders the codes alphabetically.

### Pipeline 4: join bookings to customers

**Observed command:**

``` javascript
db.bookings.aggregate([
  {
    $lookup: {
      from: "customers",
      localField: "customerId",
      foreignField: "_id",
      as: "customer"
    }
  },
  {
    $unwind: "$customer"
  },
  {
    $project: {
      _id: 0,
      flight: 1,
      seat: 1,
      status: 1,
      firstName: "$customer.firstName",
      lastName: "$customer.lastName",
      email: "$customer.email"
    }
  },
  {
    $sort: {
      flight: 1
    }
  }
])
```

**Observed output:**

``` javascript
[
  {
    flight: "AA101",
    seat: "12A",
    status: "confirmed",
    firstName: "Maria",
    lastName: "Garcia",
    email: "maria.garcia@example.com"
  },
  {
    flight: "UA205",
    seat: "8C",
    status: "confirmed",
    firstName: "Maria",
    lastName: "Garcia",
    email: "maria.garcia@example.com"
  }
]
```

This demonstrates a join, array expansion, output shaping, and sorting
in a single pipeline.

### Additional accumulator reference: `$sum`, `$min`, `$max`, `$avg`

The first two accumulators below (`$sum` and `$avg`) were used in the
observed pipelines. `$min` and `$max` are included here as **reference
patterns** for a future hands-on exercise.

``` javascript
db.customers.aggregate([
  {
    $group: {
      _id: "$homeAirport",
      customerCount: { $sum: 1 },
      averageAge: { $avg: "$age" },
      youngestAge: { $min: "$age" },
      oldestAge: { $max: "$age" }
    }
  },
  { $sort: { _id: 1 } }
])
```

Interpretation:

-   `$sum: 1` counts documents in each group.
-   `$avg` calculates a numeric average.
-   `$min` returns the smallest value in each group.
-   `$max` returns the largest value in each group.

This combined pipeline is a reference exercise and its output has not
been recorded in the current session.

## MongoDB and SQL comparison

  -----------------------------------------------------------------------------------
  Task                    MongoDB pattern                SQL pattern
  ----------------------- ------------------------------ ----------------------------
  Read all records        `db.customers.find()`          `SELECT * FROM customers;`

  Filter                  `find({ age: { $gt: 35 } })`   `WHERE age > 35`

  Projection              `find(filter, projection)`     `SELECT column_list`

  Sort                    `.sort({ age: -1 })`           `ORDER BY age DESC`

  Limit                   `.limit(3)`                    `LIMIT 3` or platform
                                                         equivalent

  Count                   `countDocuments(filter)`       `COUNT(*)`

  Update field            `$set` with `updateOne()`      `UPDATE ... SET ...`

  Increment field         `$inc`                         `SET x = x + n`

  Join                    `$lookup`                      `JOIN`

  Group                   `$group`                       `GROUP BY`

  Average                 `$avg`                         `AVG()`

  Minimum / maximum       `$min` / `$max` accumulators   `MIN()` / `MAX()`

  Expand array            `$unwind`                      Often modeled using a
                                                         normalized child table and
                                                         join
  -----------------------------------------------------------------------------------

SQL examples are conceptual. MongoDB arrays and embedded documents do
not map one-to-one to a relational schema; an SQL implementation may
require separate tables and foreign keys.

## Independent practice exercises

These are practice prompts. They are not marked complete until the
commands are run and the results are reviewed.

### Exercise 1 --- Filter and project

Return only the first name, last name, and home airport of customers
whose age is at least 35. Exclude `_id`.

**Hint:** `find(filter, projection)` and `$gte`.

### Exercise 2 --- Update safely

Increase David Wilson's `milesFlown` by 500. Inspect his document before
and after.

**Hint:** `$inc`.

### Exercise 3 --- Prevent duplicate email addresses

Before creating a unique index on `email`, determine whether duplicate
or missing email values exist. Explain why the pre-check matters.

**Hint:** `aggregate()` with `$group`, `$sum`, and a filter on counts
greater than one.

### Exercise 4 --- Aggregation with four metrics

Group customers by home airport and calculate count, average age,
minimum age, and maximum age. Sort by airport.

**Hint:** `$group`, `$sum`, `$avg`, `$min`, `$max`, `$sort`.

### Exercise 5 --- SQL join comparison

Write a SQL `JOIN` that returns each booking with the customer's name
and email. Identify which fields correspond to `localField` and
`foreignField` in the MongoDB `$lookup`.

### Exercise 6 --- Explain a query

Run `explain("executionStats")` for a filter that uses an existing index
and a filter that does not. Compare the winning plan, keys examined,
documents examined, and number returned.

## Troubleshooting and DBA notes

### Exact strings do not match

`"Platinum"` does not match `"Platium"`. Before assuming the query is
broken, inspect actual stored values and check for spelling,
capitalization, whitespace, data type, and missing fields.

### `IXSCAN` does not automatically mean "fast"

Check how many keys and documents are examined relative to the number
returned. An index can be used while MongoDB still fetches many
documents or performs a sort. Evaluate against representative workload,
not only a tiny sample.

### Covered-query requirements

A covered query needs the fields required by the filter and projection
to be available from the index, and the projection must avoid requiring
unavailable fields. In the observed example, `_id` was excluded and the
two returned fields were in the compound index.

### `$lookup` returns an array

The joined matches appear in the field named by `as`. Use `$unwind` when
subsequent stages should operate on each matched document individually.
Decide explicitly whether unmatched source documents should be retained.

### Destructive operations

Before updates or deletes:

1.  Run a `find()` with the exact intended filter.
2.  Confirm the matching document(s).
3.  Use the narrowest appropriate operation (`updateOne()` or
    `deleteOne()` when only one record is intended).
4.  Check the operation result and re-read the affected record.

### Small datasets

Execution times on a tiny practice dataset do not predict production
latency. Use execution statistics, representative data volume, query
frequency, concurrency, and write overhead when evaluating index
choices.

## Quick-reference command guide

``` javascript
// Database context
use airline
db.getName()
show collections

// Read
db.customers.find()
db.customers.findOne()
db.customers.find({ homeAirport: "MIA" })
db.customers.countDocuments({})

// Insert
db.flightData.insertOne({
  departureAirport: "MUC",
  arrivalAirport: "SFO",
  aircraft: "Airbus A380",
  distance: 12000,
  intercontinental: true
})

// Indexes
db.customers.getIndexes()
db.customers.createIndex({ loyaltyTier: 1, active: 1 })

// Explain
db.customers.find({
  loyaltyTier: "Silver",
  active: true
}).explain("executionStats")

// Aggregation
db.customers.aggregate([
  { $group: { _id: "$homeAirport", averageAge: { $avg: "$age" } } },
  { $sort: { averageAge: -1 } }
])

// Join
db.bookings.aggregate([
  {
    $lookup: {
      from: "customers",
      localField: "customerId",
      foreignField: "_id",
      as: "customer"
    }
  }
])
```

## Progress and remaining work

### Completed and observed in the current airline exercises

-   [x] Insert a document into `flightData`.
-   [x] Query customer documents and use a filter/projection.
-   [x] Create/use the compound index `loyaltyTier_1_active_1`.
-   [x] Inspect `explain("executionStats")` for covered and non-covered
    query variants.
-   [x] Aggregate average age by home airport.
-   [x] Filter `"Platinum"` customers and group by airport.
-   [x] Use `$unwind` to count `preferredAirports`.
-   [x] Use `$lookup` to join bookings to customers and format the
    results.

### Reference topics to validate in future exercises

-   [ ] Run and record actual `insertMany()` output.
-   [ ] Run and record `$set`, `$inc`, `$addToSet`, `$push`, and
    `$unset` updates in the airline database.
-   [ ] Run and record `replaceOne()`, upsert, and a safe delete
    example.
-   [ ] Exercise logical/comparison operators, sorting, limits, and
    counts.
-   [ ] Check for duplicate email values before testing a unique index.
-   [ ] Run an aggregation using `$min` and `$max` and save the real
    output.
-   [ ] Complete the independent exercises and add the verified
    commands/results here.

The README should continue to be expanded as each exercise is completed.
The distinction between observed work and reference material is
intentional: it keeps the project technically accurate while still
providing a useful learning roadmap.
