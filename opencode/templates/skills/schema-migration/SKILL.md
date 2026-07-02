---
name: schema-migration
description: Manage database schema migrations safely. Check migration files, verify up/down consistency, detect data loss risks, and test rollback.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: docker-socket
---

## What I do
- Review migration files for correctness
- Check up/down migration consistency
- Detect risky operations (DROP TABLE, column removal)
- Verify foreign key and index changes
- Test migration rollback
- Check for data loss in schema changes
- Validate against schema conventions

## Migration review checklist
1. **Up migration** — Does it create/modify the expected structure?
2. **Down migration** — Does it correctly reverse the change?
3. **Data safety** — Any DROP, TRUNCATE, or column removal?
4. **Indexes** — Are new indexes needed for changed columns?
5. **Foreign keys** — Are constraints properly updated?
6. **Default values** — For new NOT NULL columns?
7. **Backfill** — Data migration for existing rows?
8. **Locking** — Will this lock the table in production?

## Commands by ORM
```bash
# Prisma
npx prisma migrate status
npx prisma migrate diff --from-migrations ./prisma/migrations --to-schema-datamodel ./prisma/schema.prisma
npx prisma migrate dev --name <name>
npx prisma migrate deploy

# TypeORM
npx typeorm migration:show
npx typeorm migration:run
npx typeorm migration:revert

# Knex
npx knex migrate:list
npx knex migrate:up
npx knex migrate:down
npx knex migrate:rollback

# Alembic (Python/SQLAlchemy)
alembic current
alembic heads
alembic history
alembic upgrade head
alembic downgrade -1

# Django
python manage.py showmigrations
python manage.py makemigrations
python manage.py migrate
python manage.py migrate <app> <migration>
```

## Safety checks
```bash
# Check migration files for destructive operations
grep -rniE 'DROP (TABLE|COLUMN|INDEX|DATABASE|SCHEMA)' <migrations-dir>/
grep -rniE 'TRUNCATE|DELETE FROM' <migrations-dir>/
grep -rniE 'ALTER TABLE.*DROP' <migrations-dir>/
grep -rniE 'RENAME (TABLE|COLUMN)' <migrations-dir>/

# Check for missing down migrations
ls <migrations-dir>/down/  # or check migration files
```

## Output format
```
## Migration Review

### Migration: <name>
- **Up**: Creates users table with id, name, email, timestamps
- **Down**: Drops users table
- **Risk**: LOW (new table creation)
- **Indexes**: email (UNIQUE), created_at (BTREE)
- **Status**: APPROVED

### Migration: <name>
- **Up**: Drops legacy_orders column from users
- **Down**: Adds legacy_orders column back (data LOST)
- **Risk**: HIGH — data loss on drop
- **Warning**: Ensure data is backed up before running
- **Status**: NEEDS REVIEW
```
