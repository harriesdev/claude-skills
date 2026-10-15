# Migrations for Database

## Constraints

### MUST DO
- Create migration for database changes in `server/src/modules/database/migrations/`
- Use current unix timestamp in filename and class title, and set `name` to the class name
- Use down method to revert changes to original state in up method.
- Include the six audit columns in every table for an entity that extends `DomainObject`
- Use the `DatabaseTable` enum value as the table name
- Use `TIMESTAMP WITH TIME ZONE` for every date and time column — a plain `TIMESTAMP` is read back in the server's local time zone, so dates shift on any machine not set to UTC
- If dropping column, use two migration. The first changes the column name to `deprecated_column_name`. The second migration drops the deprecated column.

- Create migration files with `npm run migration:create` (see `references/repository-typeorm.md`)
- Add every new migration class to `Migrations` in `src/modules/database/migrations/index.ts` — the data source loads that list, not a file glob

### MUST NOT DO
- Run migration
- Enable `synchronize`
- Use `TIMESTAMP` without a time zone
- Use N+1 Queries


## Migration Pattern for DomainObject Entities

Every table for an entity that extends `DomainObject` must include the six audit columns. `DomainAuditSubscriber` writes to them on every save, so a missing column breaks inserts.

```typescript
// 1761848303790-create-post-table.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePostTable1761848303790
  implements MigrationInterface
{
  name = 'CreatePostTable1761848303790';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "post" (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description VARCHAR(255),
        cost NUMERIC DEFAULT NULL,
        user_id INTEGER NOT NULL,
        created_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER NULL,
        updated_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_by INTEGER NULL,
        deleted_date TIMESTAMP WITH TIME ZONE NULL,
        deleted_by INTEGER NULL,
        FOREIGN KEY (user_id) REFERENCES "user" (id)
      );
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
        DROP TABLE IF EXISTS "post";
    `);
  }
}
```

### Audit Columns

| Column | Type | Maps to |
|--------|------|---------|
| `created_date` | `TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP` | `DomainObject.createdDate` |
| `created_by` | `INTEGER NULL` | `DomainObject.createdBy` |
| `updated_date` | `TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP` | `DomainObject.updatedDate` |
| `updated_by` | `INTEGER NULL` | `DomainObject.updatedBy` |
| `deleted_date` | `TIMESTAMP WITH TIME ZONE NULL` | `DomainObject.deletedDate` |
| `deleted_by` | `INTEGER NULL` | `DomainObject.deletedBy` |

## Migration Pattern for Entities without DomainObject

Entities that declare their own `@PrimaryGeneratedColumn` get only the columns they define — no audit columns.

```typescript
// 1761848303791-create-price-table.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePriceTable1761848303791
  implements MigrationInterface
{
  name = 'CreatePriceTable1761848303791';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "price" (
        id SERIAL PRIMARY KEY,
        epoch TIMESTAMP WITH TIME ZONE NOT NULL,
        close NUMERIC NOT NULL,
        market_id INTEGER NOT NULL,
        FOREIGN KEY (market_id) REFERENCES "market" (id)
      );
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
        DROP TABLE IF EXISTS "price";
    `);
  }
}
```
