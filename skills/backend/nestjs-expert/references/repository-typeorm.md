# Repository service with TypeORM

## Constraints

### MUST DO
- Extend `RepositorySupport<T>` and decorate the repository with `@Injectable()`
- Create relations type for each repository
- Return `Page<T>` from list queries via `findPage()`, always with an `order`
- Add every new repository to `RepositoryServices` in `src/modules/database/repositories/repository-services.const.ts`
- Add every new entity to `Entities` in `src/domain/index.ts` so `DatabaseModule` registers it with `TypeOrmModule.forFeature`

### MUST NOT DO
- Provide repositories in feature module `providers` — the global `DatabaseModule` already provides and exports them

## Repository Pattern

```typescript
// post.repository.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Post } from '../../../../domain/post/post.entity';
import { User } from '../../../../domain/user/user.entity';
import { PaginationQueryDto } from '../../../../dto/common/pagination-query.dto';
import { Page } from '../../../../shared/types/page';
import { RepositorySupport } from '../repository.support';
import { PostRelation } from './post-relation.type';

@Injectable()
export class PostRepository extends RepositorySupport<Post> {
  constructor(
    @InjectRepository(Post)
    repository: Repository<Post>,
  ) {
    super(Post, repository.manager.connection);
  }

  private postRelations: PostRelation[] = [
    'comments',
  ];

  public findAll(): Promise<Post[]> {
    return super.find({
      relations: this.postRelations,
    });
  }

  public findById(id: number): Promise<Post | null> {
    return super.findById(id, {
      relations: this.postRelations,
    });
  }

  public async findByIdWithRelations(
    postId: number,
    relations?: PostRelation[],
  ): Promise<Post | null> {
    return super.findById(postId, { relations });
  }

  public async findPageByUser(
    user: User,
    paginationQueryDto: PaginationQueryDto,
  ): Promise<Page<Post>> {
    return this.findPage(paginationQueryDto, {
      where: { user: { id: user.getId() } },
      order: { createdDate: 'DESC', id: 'DESC' },
    });
  }
}
```

Name list methods `findAll()` rather than overriding TypeORM's `find(options)`, so `this.find({ where })` keeps working inside the repository.

## RepositorySupport

Every repository extends `RepositorySupport`, which extends TypeORM's `Repository` and adds `findById` and `rawQuery`.

```typescript
// src/modules/database/repositories/repository.support.ts
import {
  DataSource,
  EntityTarget,
  FindManyOptions,
  FindOneOptions,
  FindOptionsWhere,
  ObjectLiteral,
  Repository,
} from 'typeorm';
import { PaginationQueryDto } from '../../../dto/common/pagination-query.dto';
import { IllegalArgumentException } from '../../../shared/exceptions/illegal-argument.exception';
import { Page } from '../../../shared/types/page';
import { RepositorySupportMessages } from './repository-support-messages.enum';

export abstract class RepositorySupport<T extends ObjectLiteral> extends Repository<T> {
  constructor(target: EntityTarget<T>, dataSource: DataSource) {
    super(target, dataSource.createEntityManager());
  }

  public async findById(
    id: number | string,
    findOptions?: Omit<FindOneOptions<T>, 'where'>,
  ): Promise<T | null> {
    if (id === null || id === undefined) {
      throw new IllegalArgumentException(RepositorySupportMessages.IdRequired);
    }
    return super.findOne({
      ...findOptions,
      where: { id } as unknown as FindOptionsWhere<T>,
    });
  }

  public async findPage(
    paginationQueryDto: PaginationQueryDto,
    findOptions: Omit<FindManyOptions<T>, 'skip' | 'take'> &
      Required<Pick<FindManyOptions<T>, 'order'>>,
  ): Promise<Page<T>> {
    const { page, limit } = paginationQueryDto;
    const [items, total] = await this.findAndCount({
      ...findOptions,
      skip: (page - 1) * limit,
      take: limit,
    });
    return new Page(items, total, page, limit);
  }

  protected rawQuery<R>(sql: string, parameters?: unknown[]): Promise<R> {
    return this.manager.query(sql, parameters);
  }
}

// repository-support-messages.enum.ts
export enum RepositorySupportMessages {
  IdRequired = 'id must be defined',
}
```

`findById` passes `findOptions` (relations, select, withDeleted) through to `findOne`. `findPage` requires an `order` so pages are stable between requests. Use `rawQuery` only for SQL that the query builder can't express, and always pass values as `parameters`, never by string interpolation.

## Repository Registration

Repositories are registered once, centrally. Add the new repository to the `RepositoryServices` array:

```typescript
// src/modules/database/repositories/repository-services.const.ts
import { CommentRepository } from './comment/comment.repository';
import { PostRepository } from './post/post.repository';
import { UserRepository } from './user/user.repository';

export const RepositoryServices = [
  CommentRepository,
  PostRepository,
  UserRepository,
];
```

The global `DatabaseModule` provides and exports that list, so every repository is injectable in any feature module's services, pipes and forms without further imports:

```typescript
// src/modules/database/database.module.ts
import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Entities } from '../../domain';
import { PostgresTypeormConfigService } from './config/postgres-typeorm-config.service';
import { RepositoryServices } from './repositories/repository-services.const';

@Global()
@Module({
  imports: [
    TypeOrmModule.forRoot(PostgresTypeormConfigService.create().getConfig()),
    TypeOrmModule.forFeature([...Entities]),
  ],
  providers: [...RepositoryServices],
  exports: [...RepositoryServices],
})
export class DatabaseModule {}
```

`DatabaseModule` is imported once, in `AppModule`:

```typescript
// app.module.ts
@Module({
  imports: [
    ConfigModule.forRoot({ envFilePath: '.env', isGlobal: true }),
    DatabaseModule,
    PostsModule,
    UsersModule,
  ],
  providers: [
    { provide: APP_INTERCEPTOR, useClass: AuditUserInterceptor },
  ],
})
export class AppModule {}
```

## Database Config

`DatabaseModule` reads its connection settings from `src/modules/database/config/postgres-typeorm-config.service.ts`, which extends `ApiConfigService` (see `references/configuration.md`) because `TypeOrmModule.forRoot` and the CLI run outside DI. The same file exports `AppDataSource` for the TypeORM CLI (`migration:run`, `migration:revert`, `migration:show`).

```typescript
// src/modules/database/config/postgres-typeorm-config.service.ts
import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { DataSource, DataSourceOptions, LoggerOptions } from 'typeorm';
import { ApiConfigService } from '../../config/api-config.service';
import { DomainAuditSubscriber } from '../audit/domain-audit.subscriber';
import { SnakeNamingStrategy } from './snake-naming-strategy';

export class PostgresTypeormConfigService extends ApiConfigService {
  public static create(): PostgresTypeormConfigService {
    return new PostgresTypeormConfigService().ensureValues([
      'DB_HOST',
      'DB_PORT',
      'DB_USERNAME',
      'DB_PASSWORD',
      'DB_DATABASE',
    ]);
  }

  public getConfig(): TypeOrmModuleOptions {
    return {
      type: 'postgres',
      host: this.getValue('DB_HOST'),
      port: parseInt(this.getValue('DB_PORT')),
      username: this.getValue('DB_USERNAME'),
      password: this.getValue('DB_PASSWORD'),
      database: this.getValue('DB_DATABASE'),
      entities: ['dist/**/*.entity{.ts,.js}'],
      migrations: ['dist/modules/database/migrations/*{.ts,.js}'],
      namingStrategy: new SnakeNamingStrategy(),
      subscribers: [DomainAuditSubscriber],
      synchronize: false,
      logging: this.getLoggingOptions(),
      ssl: this.isProduction() ? { rejectUnauthorized: false } : false,
    };
  }

  private getLoggingOptions(): LoggerOptions {
    if (this.isProduction()) {
      return ['error', 'warn'];
    }
    return ['error', 'warn', 'info', 'log', 'migration'];
  }
}

export const AppDataSource = new DataSource(
  PostgresTypeormConfigService.create().getConfig() as DataSourceOptions,
);
```

### Rules
- `synchronize` is always `false` — schema changes go through migrations only
- Missing `DB_*` environment variables fail fast at startup
- `SnakeNamingStrategy` maps camelCase properties to snake_case columns; table names come from `@Entity(DatabaseTable.X)`
- `DomainAuditSubscriber` is registered here so audit columns are filled on every `DomainObject` (see `references/entities-domain.md`)

### Snake Naming Strategy

```typescript
// src/modules/database/config/snake-naming-strategy.ts
import { DefaultNamingStrategy, NamingStrategyInterface } from 'typeorm';
import { snakeCase } from 'typeorm/util/StringUtils';

export class SnakeNamingStrategy
  extends DefaultNamingStrategy
  implements NamingStrategyInterface
{
  public tableName(className: string, customName: string): string {
    return customName ? customName : snakeCase(className);
  }

  public columnName(
    propertyName: string,
    customName: string,
    embeddedPrefixes: string[],
  ): string {
    return (
      snakeCase(embeddedPrefixes.join('_')) +
      (customName ? customName : snakeCase(propertyName))
    );
  }

  public relationName(propertyName: string): string {
    return snakeCase(propertyName);
  }

  public joinColumnName(
    relationName: string,
    referencedColumnName: string,
  ): string {
    return snakeCase(relationName + '_' + referencedColumnName);
  }

  public joinTableName(
    firstTableName: string,
    secondTableName: string,
    firstPropertyName: string,
  ): string {
    return snakeCase(
      firstTableName +
        '_' +
        firstPropertyName.replace(/\./gi, '_') +
        '_' +
        secondTableName,
    );
  }

  public joinTableColumnName(
    tableName: string,
    propertyName: string,
    columnName?: string,
  ): string {
    return snakeCase(tableName + '_' + (columnName ? columnName : propertyName));
  }
}
```

### package.json scripts

```json
{
  "migration:create": "npm run build && npm run typeorm migration:create src/modules/database/migrations/migration",
  "migration:run": "npm run build && npm run typeorm -- migration:run -d src/modules/database/config/postgres-typeorm-config.service.ts",
  "migration:revert": "npm run build && npm run typeorm -- migration:revert -d src/modules/database/config/postgres-typeorm-config.service.ts",
  "migration:show": "npm run build && npm run typeorm -- migration:show -d src/modules/database/config/postgres-typeorm-config.service.ts"
}
```

## Relation Type

```typescript
// post-relation.type.ts
export type PostRelation =
  | 'comments'
```

## Quick Reference

| Pattern | Use When |
|---------|----------|
| `@Inject(token)` | Non-class tokens |
| `RepositoryServices` | Registering a new repository |
| `DatabaseModule` | Global provider/exporter of all repositories |