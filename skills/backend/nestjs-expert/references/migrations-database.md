# Migrations for Database

## Constraints

### MUST DO
- Create migration for database changes in `api/src/modules/database/release/`
- Use current unit time stamp in filename and class title
- Use down method to revert changes to original state in up method.
- If dropping column, use two migration. The first changes the column name to `deprecated_column_name`. The second migration drops the deprecated column.

### MUST NOT DO
- Run migration
- Use N+1 Queries


## Migration Pattern

```typescript
// 1761848303790-create-post-table.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePostTable1761848303790
  implements MigrationInterface
{
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS post (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255),
        description VARCHAR(255),
        cost NUMERIC DEFAULT NULL
        user_id INTEGER NOT NULL
        FOREIGN KEY (user_id) REFERENCES "user" (id)
      );
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
        DROP TABLE IF EXISTS post;
    `);
  }
}
```