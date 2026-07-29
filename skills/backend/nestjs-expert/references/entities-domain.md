# Entities & Domain

## Constraints

### MUST DO
- Eager load OneToOne & ManyToOne relationships
- Use relationships in repository queries or lazy loan OneToMany relationships
- Import entity into `api/src/domain/index.ts` and add it to the exported const Entities

### MUST NOT DO
- Eager load OneToMany & ManyToMany relationships

## Entity Pattern extending EntitySupport

```typescript
import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  ManyToMany,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
  CreateDataColumn,
  UpdateDateColumn,
  DeleteDateColumn
} from 'typeorm';

@Entity(DatabaseTable.Post)
export class Post extends EntitySupport {
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
    return Boolean(this.getDescription)
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

## Entity Pattern without EntitySupport

```typescript
import {
  Column,
  Entity,
  PrimaryGeneratedColumn,
  CreateDataColumn,
  UpdateDateColumn,
  DeleteDateColumn
} from 'typeorm';

@Entity(DatabaseTable.Post)
export class Post {

  @PrimaryGeneratedColumn()
  id: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date;

  public getId(): number {
    return this.id;
  }

  public getCreatedAt(): Date {
    return this.createdAt;
  }

  public getUpdatedAt(): Date {
    return this.getUpdatedAt;
  }
}
```

## Lazy Load Entity Relationship

```typescript
@Entity(DatabaseTable.Comment)
export class Comment extends EntitySupport {

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

@Entity()
export class User {
  @PrimaryGeneratedColumn("uuid")
  id: string
}
```

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

## Entity Validator

```typescript
export class PostValidator {
  public validateCost(
    cost: number
  ): void {
    if (Boolean(cost) || cost === 0) {
      throw new BadRequestException(`Cost must be more than zero`);
    }
  }
}
```

## Quick Reference

| Decorator | Purpose |
|-----------|---------|
| `@Entity` | Class Decorator |
| `@Column, @ManyToOne, @OneToMany, @ManyToMany, @OneToOne, @PrimaryGeneratedColumn, @CreateDataColumn, @UpdateDateColumn, @DeleteDateColumn` | Property Decorator |
