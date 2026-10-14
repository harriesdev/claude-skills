# Entities & Domain

## Constraints

### MUST DO
- Extend `DomainObject` for every entity that needs an id and audit columns
- Name every table with `@Entity(DatabaseTable.X)` and add the table to the `DatabaseTable` enum
- Eager load OneToOne & ManyToOne relationships
- Use relationships in repository queries or lazy load OneToMany relationships
- Import entity into `api/src/domain/index.ts` and add it to the exported const Entities
- Create a domain factory (`{x}.factory.ts`) that builds the entity from its form
- Create an entity validator (`{x}.validator.ts`) for business rules and call it from `validateAndSet...` methods
- Give user-owned entities `isOwnedBy(user)` and `canBeAccessedBy(user)` (owner or admin)

### MUST NOT DO
- Eager load OneToMany & ManyToMany relationships
- Set audit columns (`createdBy`, `updatedBy`, `deletedBy`) by hand — `DomainAuditSubscriber` fills them in
- Declare `id` or audit columns on an entity that extends `DomainObject`

## Domain Files

```
src/domain/
├── domain-object.ts
├── database-table.enum.ts
├── index.ts
└── post/
    ├── post.entity.ts
    ├── post.factory.ts
    └── post.validator.ts
```

## DomainObject

Base class for entities. Provides the primary key and the audit columns.

```typescript
// src/domain/domain-object.ts
import {
  Column,
  CreateDateColumn,
  DeleteDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity()
export abstract class DomainObject {
  @PrimaryGeneratedColumn()
  public id: number;

  @CreateDateColumn()
  public createdDate: Date;

  @Column({ type: 'int', nullable: true })
  public createdBy: number;

  @UpdateDateColumn()
  public updatedDate: Date;

  @Column({ type: 'int', nullable: true })
  public updatedBy: number;

  @DeleteDateColumn()
  public deletedDate: Date;

  @Column({ type: 'int', nullable: true })
  public deletedBy: number;

  public getId(): number {
    return this.id;
  }

  public getCreatedDate(): Date {
    return this.createdDate;
  }

  public getCreatedBy(): number {
    return this.createdBy;
  }

  public getUpdatedDate(): Date {
    return this.updatedDate;
  }

  public getUpdatedBy(): number {
    return this.updatedBy;
  }

  public getDeletedDate(): Date {
    return this.deletedDate;
  }

  public getDeletedBy(): number {
    return this.deletedBy;
  }
}
```

| Property | Column | Set by |
|----------|--------|--------|
| `id` | `id SERIAL PRIMARY KEY` | Database |
| `createdDate` | `created_date` | TypeORM `@CreateDateColumn` |
| `createdBy` | `created_by` | `DomainAuditSubscriber` on insert |
| `updatedDate` | `updated_date` | TypeORM `@UpdateDateColumn` |
| `updatedBy` | `updated_by` | `DomainAuditSubscriber` on insert, update and soft remove |
| `deletedDate` | `deleted_date` | TypeORM `softRemove` / `softDelete` |
| `deletedBy` | `deleted_by` | `DomainAuditSubscriber` on soft remove |

## Audit

`DomainAuditSubscriber` fills `createdBy`, `updatedBy` and `deletedBy` with the id of the authenticated user. `AuditUserInterceptor` puts that id into an `AsyncLocalStorage` for the duration of each request, and the subscriber reads it before every insert, update and soft remove. Requests without a user (public endpoints, jobs) leave the columns `null`.

```
src/modules/database/audit/
├── audit-context.ts
├── audit-user.interceptor.ts
└── domain-audit.subscriber.ts
```

```typescript
// src/modules/database/audit/audit-context.ts
import { AsyncLocalStorage } from 'async_hooks';
import { User } from '../../../domain/user/user.entity';

export const auditContext = new AsyncLocalStorage<number>();

export function getAuditActor(user: User | undefined): number | undefined {
  return user?.getId();
}
```

```typescript
// src/modules/database/audit/audit-user.interceptor.ts
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { User } from '../../../domain/user/user.entity';
import { auditContext, getAuditActor } from './audit-context';

@Injectable()
export class AuditUserInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const actor = getAuditActor(
      context.switchToHttp().getRequest<{ user?: User }>().user,
    );

    if (!actor) {
      return next.handle();
    }

    return new Observable((subscriber) => {
      auditContext.run(actor, () => {
        const subscription = next.handle().subscribe({
          next: (value) => subscriber.next(value),
          error: (err) => subscriber.error(err),
          complete: () => subscriber.complete(),
        });
        return () => subscription.unsubscribe();
      });
    });
  }
}
```

```typescript
// src/modules/database/audit/domain-audit.subscriber.ts
import {
  EntitySubscriberInterface,
  EventSubscriber,
  InsertEvent,
  SoftRemoveEvent,
  UpdateEvent,
} from 'typeorm';
import { DomainObject } from '../../../domain/domain-object';
import { auditContext } from './audit-context';

@EventSubscriber()
export class DomainAuditSubscriber
  implements EntitySubscriberInterface<DomainObject>
{
  listenTo() {
    return DomainObject;
  }

  beforeInsert(event: InsertEvent<DomainObject>): void {
    const actor = auditContext.getStore();
    if (!actor) {
      return;
    }

    event.entity.createdBy ??= actor;
    event.entity.updatedBy = actor;
  }

  beforeUpdate(event: UpdateEvent<DomainObject>): void {
    const actor = auditContext.getStore();
    if (!actor || !event.entity) {
      return;
    }

    event.entity.updatedBy = actor;
  }

  beforeSoftRemove(event: SoftRemoveEvent<DomainObject>): void {
    const actor = auditContext.getStore();
    if (!actor || !event.entity) {
      return;
    }

    event.entity.deletedBy = actor;
    event.entity.updatedBy = actor;
  }
}
```

Wiring:
- `subscribers: [DomainAuditSubscriber]` in `PostgresTypeormConfigService.getConfig()` (see `references/repository-typeorm.md`)
- `{ provide: APP_INTERCEPTOR, useClass: AuditUserInterceptor }` in `AppModule` providers

Subscribers only fire for entity-based operations (`save`, `softRemove`). `update()`, `softDelete()` and raw queries bypass them, so prefer `save` and `softRemove` on `DomainObject` entities.

## DatabaseTable Enum

```typescript
// src/domain/database-table.enum.ts
export enum DatabaseTable {
  Comment = 'comment',
  Market = 'market',
  Post = 'post',
  Price = 'price',
  Reply = 'reply',
  User = 'user',
}
```

## Entity Pattern extending DomainObject

```typescript
import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
} from 'typeorm';
import { DatabaseTable } from '../database-table.enum';
import { DomainObject } from '../domain-object';

@Entity(DatabaseTable.Post)
export class Post extends DomainObject {
  private validator = new PostValidator();

  @Column()
  title: string;

  @Column({ nullable: true })
  description: string;

  @Column({
    nullable: true,
    type: 'numeric',
    transformer: new ColumnNumericTransformer(),
  })
  cost: number;

  @ManyToOne(() => User, { eager: true })
  @JoinColumn()
  user: User;

  @OneToMany(
    () => Comment,
    (comment) => comment.post,
    { cascade: true },
  )
  comments: Comment[];

  public getTitle(): string {
    return this.title;
  }

  public setTitle(title: string): Post {
    this.title = title;
    return this;
  }

  public getDescription(): string | null {
    return this.description;
  }

  public setDescription(description: string | null): Post {
    this.description = description;
    return this;
  }

  public hasDescription(): boolean {
    return Boolean(this.getDescription());
  }

  public setCost(cost: number | null): Post {
    this.cost = cost;
    return this;
  }

  public getCost(): number | null {
    return this.cost;
  }

  public hasCost(): boolean {
    return Boolean(this.cost) || this.cost === 0;
  }

  public getUser(): User {
    return this.user;
  }

  public setUser(user: User): Post {
    this.user = user;
    return this;
  }

  public isOwnedBy(user: User): boolean {
    return this.getUser()?.getId() === user.getId();
  }

  public canBeAccessedBy(user: User): boolean {
    return this.isOwnedBy(user) || user.hasRole([UserRole.Admin]);
  }

  public getComments(): Comment[] {
    return this.comments;
  }

  public addComment(comment: Comment): this {
    if (!this.comments) {
      this.comments = [comment];
      return this;
    }
    this.comments = this.comments.concat([comment]);
    return this;
  }

  public setComments(comments: Comment[]): this {
    this.comments = comments;
    return this;
  }

  public validateAndSetCost(
    cost: number | null
  ): Post {
    this.validator.validateCost(
      cost
    );
    this.setCost(cost);
    return this;
  }
}
```

## Entity Pattern without DomainObject

Some entities don't extend `DomainObject` — for example high-volume or append-only data such as price ticks, where audit columns add no value. They declare their own `@PrimaryGeneratedColumn` and getters. `DomainAuditSubscriber` only listens to `DomainObject`, so these entities are never audited.

```typescript
import {
  Column,
  Entity,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { DatabaseTable } from '../database-table.enum';

@Entity(DatabaseTable.Price)
export class Price {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'timestamptz', nullable: false })
  epoch: Date;

  @Column({
    nullable: false,
    type: 'numeric',
    transformer: new ColumnNumericTransformer(),
  })
  close: number;

  @ManyToOne(() => Market, { eager: true })
  market: Market;

  public getId(): number {
    return this.id;
  }

  public getEpoch(): Date {
    return this.epoch;
  }

  public setEpoch(epoch: Date): Price {
    this.epoch = epoch;
    return this;
  }

  public getClose(): number {
    return this.close;
  }

  public setClose(close: number): Price {
    this.close = close;
    return this;
  }
}
```

## Lazy Load Entity Relationship

```typescript
@Entity(DatabaseTable.Comment)
export class Comment extends DomainObject {

  @OneToOne(
    () => Reply,
    (reply) => reply.comment,
    { cascade: true, lazy: true },
  )
  reply: Promise<Reply>;

  public async hasReply(): Promise<boolean> {
    return Boolean(await this.getReply());
  }

  public async getReply(): Promise<Reply> {
    return (await this.reply);
  }

  public setReply(reply: Reply): this {
    this.reply = Promise.resolve(reply);
    return this;
  }  
}
```

## Entity Pattern with UUID

```typescript
import {
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { DatabaseTable } from '../database-table.enum';

@Entity(DatabaseTable.User)
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;
}
```

## Domain Factory

A domain factory builds a new entity from a validated form. It lives next to the entity and is the only place that turns request input into a domain object. Forms call it from `toDomainObject()`.

```typescript
// src/domain/post/post.factory.ts
import { CreatePostForm } from '../../modules/posts/types/create-post.form';
import { Post } from './post.entity';

export class PostFactory {
  public async create(form: CreatePostForm): Promise<Post> {
    return new Post()
      .setTitle(form.title)
      .setDescription(form.description)
      .validateAndSetCost(form.cost);
  }

  public update(post: Post, updatePostDto: UpdatePostDto): Post {
    if (updatePostDto.title !== undefined) {
      post.setTitle(updatePostDto.title);
    }
    if (updatePostDto.description !== undefined) {
      post.setDescription(updatePostDto.description);
    }
    if (updatePostDto.cost !== undefined) {
      post.validateAndSetCost(updatePostDto.cost);
    }
    return post;
  }
}
```

`create()` builds a new entity from a form. `update()` applies only the fields present in a PATCH DTO to an entity that was loaded from the database, so the entity keeps its `id` and audit columns.

When building the entity needs other entities, the form resolves them and the factory receives them through the form:

```typescript
// src/domain/subscription/subscription.factory.ts
export class SubscriptionFactory {
  public async create(form: SubscriptionCreateForm): Promise<Subscription> {
    return new Subscription()
      .setName(form.name)
      .setExchange(await form.getExchange())
      .setMarket(await form.getMarket());
  }
}
```

Domain factories are production code. Fixtures for tests are **test factories** — see `references/testing-patterns.md`.

## Custom Transformer

```typescript
export class ColumnNumericTransformer {
  to(data: number): number {
    return data;
  }
  from(data: string | null): number {
    if (data === null) {
      return null;
    }
    return parseFloat(data);
  }
}

// Usage
  @Column({
    nullable: true,
    type: 'numeric',
    transformer: new ColumnNumericTransformer(),
  })
  cost: number;
```

## Column Type Helpers

Postgres-specific column types (`enum`, `json`, `jsonb`, `bytea`) fall back to `String` when `NODE_ENV=testing`, so entities also load in test databases that don't support them.

```typescript
// src/modules/database/config/column-types.functions.ts
import { Column, ColumnOptions } from 'typeorm';

export function EnumColumn(
  enumReference: object,
  options?: ColumnOptions,
): PropertyDecorator {
  return Column(stringOr({ ...options, type: 'enum', enum: enumReference }));
}

export function JsonColumn(options?: ColumnOptions): PropertyDecorator {
  return Column(stringOr({ ...options, type: 'json' }));
}

export function JsonBColumn(options?: ColumnOptions): PropertyDecorator {
  return Column(stringOr({ ...options, type: 'jsonb' }));
}

export function ByteaColumn(options?: ColumnOptions): PropertyDecorator {
  return Column(stringOr({ ...options, type: 'bytea' }));
}

function stringOr<T extends ColumnOptions>(options: T): T {
  return isTestingEnv() ? { ...options, type: String } : options;
}

function isTestingEnv(): boolean {
  return new ApiConfigService().isTesting();
}

// usage
@EnumColumn(UserRole, { array: true })
roles: UserRole[];
```

Add `Testing = 'testing'` to the `Environment` enum and set `ENV=testing` in the test environment.

## Entity Validator

```typescript
// src/domain/post/post.validator.ts
export class PostValidator {
  public validateCost(
    cost: number | null
  ): void {
    if (cost !== null && cost <= 0) {
      throw new BadRequestException(PostValidatorMessages.CostMustBePositive);
    }
  }
}

// post-validator-messages.enum.ts
export enum PostValidatorMessages {
  CostMustBePositive = 'Cost must be more than zero',
}
```

## Quick Reference

| Decorator / File | Purpose |
|------------------|---------|
| `@Entity(DatabaseTable.X)` | Class decorator with the table name |
| `@Column, @ManyToOne, @OneToMany, @ManyToMany, @OneToOne, @PrimaryGeneratedColumn` | Property decorators |
| `DomainObject` | Base class: id + audit columns |
| `{x}.factory.ts` | Domain factory: form → entity |
| `{x}.validator.ts` | Business rule checks used by the entity |
