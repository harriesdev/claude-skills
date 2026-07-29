# Repository service with TypeORM

## Constraints

### MUST DO
- Create relations type for each repository

## Repository Pattern

```typescript
// post.repository.ts
import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';

@Injectable()
export class PostRepository extends RepositorySupport<Post> {
  constructor(
    @InjectRepository(Post)
    repository: Repository<Post>,
  ) {
    super(Post, repository.manager.connection);
  }

  private postRelations: PostRelation[] = [
    'comment',
  ];

  public find(): Promise<Post[]> {
    return super.find({
      relations: this.postRelations,
    });
  }

  public findById(id: number): Promise<Post> {
    return super.findById(id, {
      relations: this.postRelations,
    });
  }

  public async findByIdWithRelations(
    postId: number,
    relations?: PostRelation[],
  ): Promise<Merchant> {
    return super.findById(postId, { relations });
  }

  public async findByUser(user: User): Promise<Post[]> {
    return this.find({ where: { user } });
  }
}
```
## Relation Type

```typescript
// post-relation.type.ts
  export type PostRelation = 
  | 'comment'
```

## Quick Reference

| Pattern | Use When |
|---------|----------|
| `@Inject(token)` | Non-class tokens |