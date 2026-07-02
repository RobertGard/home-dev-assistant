---
name: database-tools
description: Explore database schemas, generate seed data, optimize queries, and manage database operations across SQL and NoSQL databases.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: docker-socket
---

## What I do
- Inspect database schemas: tables, columns, types, constraints
- Generate seed data for testing and development
- Analyze slow queries with EXPLAIN plans
- Generate ERD descriptions from live databases
- Check index coverage and suggest missing indexes
- Backup and restore databases
- Cross-reference ORM models with actual schema

## When to use me
Use this skill when:
- You need to understand a database's structure
- Setting up a test database with realistic seed data
- Debugging slow queries in production
- Reviewing a migration's impact before applying
- Comparing ORM definitions with actual database state
- Generating documentation from a live database

## Commands reference

### Universal (usql — works with all databases)
```bash
# Connect to any database
usql postgres://user:pass@host/db
usql mysql://user:pass@host/db
usql sqlite:/workspace/data.db

# List all tables across all databases
usql -c "\dt"

# Run a query
usql -c "SELECT * FROM users LIMIT 5" postgres://...

# Describe a table
usql -c "\d users" sqlite:/workspace/data.db
```

### PostgreSQL
```bash
# List all tables with sizes
psql "$DATABASE_URL" -c "
SELECT schemaname, tablename, 
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC"

# Table details
psql "$DATABASE_URL" -c "\d+ <table>"

# List indexes
psql "$DATABASE_URL" -c "
SELECT tablename, indexname, indexdef 
FROM pg_indexes WHERE schemaname = 'public'
ORDER BY tablename, indexname"

# Explain a query
psql "$DATABASE_URL" -c "EXPLAIN (ANALYZE, BUFFERS) <query>"

# Find missing indexes
psql "$DATABASE_URL" -c "
SELECT schemaname, relname as table, seq_scan, idx_scan,
  CASE WHEN seq_scan > 0 AND idx_scan = 0 THEN 'NO INDEX'
       WHEN seq_scan > idx_scan * 2 THEN 'CONSIDER INDEX'
  END as recommendation
FROM pg_stat_user_tables
WHERE seq_scan > 100 ORDER BY seq_scan DESC"

# Backup
pg_dump "$DATABASE_URL" > backup.sql

# List connections
psql "$DATABASE_URL" -c "SELECT pid, usename, application_name, state, query_start FROM pg_stat_activity"
```

### MySQL/MariaDB
```bash
mysql -e "SHOW TABLES"
mysql -e "DESCRIBE <table>"
mysql -e "SHOW INDEX FROM <table>"
mysql -e "EXPLAIN <query>"
mysqldump > backup.sql
```

### SQLite
```bash
sqlite3 data.db ".tables"
sqlite3 data.db ".schema <table>"
sqlite3 data.db ".indexes <table>"
sqlite3 data.db "EXPLAIN QUERY PLAN <query>"
sqlite3 data.db ".dump" > backup.sql
```

### MongoDB
```bash
mongosh --eval "db.getCollectionNames()"
mongosh --eval "db.<collection>.stats()"
mongosh --eval "db.<collection>.getIndexes()"
mongosh --eval "db.<collection>.find().explain('executionStats')"
mongodump --out backup/
```

## Seed data generation
```bash
# Generate realistic seed data with faker
npx @faker-js/faker  # or via MCP

# Pattern: read schema → identify required fields → generate matching data
# Support: users, orders, products, posts, comments, events, etc.

# For Prisma projects
npx prisma db seed

# For TypeORM
npx typeorm migration:run && npx ts-node src/seed.ts
```

## Schema comparison (ORM vs DB)
```bash
# Prisma: compare schema with database
npx prisma migrate diff --from-schema-datamodel prisma/schema.prisma \
  --to-schema-datasource prisma/schema.prisma --shadow-database-url "$SHADOW_DB"

# General approach: extract ORM model definitions → extract actual DB schema → diff
```

## Output format
```
## Database Report: <database>

### Overview
- Type: <PostgreSQL/MySQL/SQLite/MongoDB>
- Tables/Collections: <count>
- Total Size: <size>
- Connections: <active>/<max>

### Schema
**users** (1.2 MB, 4,523 rows)
| Column | Type | Nullable | Default | Index |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | PK |
| email | varchar(255) | NO | - | UNIQUE |
| name | varchar(100) | YES | - | - |
| created_at | timestamptz | NO | now() | BTREE |

### Performance
- Slow queries (>100ms): 23 in last hour
- Missing indexes: users.role, orders.user_id
- Table scans (no index): audit_logs (sequential scan overhead)

### Recommendations
1. Add index on `users.role` (used in WHERE clause, table has 4.5K rows)
2. Add composite index on `orders(user_id, status)` — covers most queries
3. Consider partitioning `audit_logs` by month (850K rows, growing 50K/day)
```
