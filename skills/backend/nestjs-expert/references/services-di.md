# Services & Dependency Injection

## Service Pattern

```typescript
import { Injectable, Logger, NotFoundException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PostRepository } from '../database/repositories/post/post.repository';

@Injectable()
export class PostsService {
  private readonly logger = new Logger(PostsService.name);

  constructor(
    private readonly postRepository: PostRepository,
  ) {}

  public async getPostByUser(user: User): Promise<Post[]> {
    return await this.postRepository.findByUser(user);
  }

  public async getPostById(id: number): Promise<Post> {
    const post = await this.postRepository.findOneBy({ id });
    if (!post) {
      throw new HttpException('Post not found', HttpStatus.NOT_FOUND);
    }
    return post;
  }

  public async createPost(post: Post): Promise<Post> {
    return await this.postRepository.save(post);
  }

  public async updatePost(post: Post, postUpdateForm: Post): Promise<Post> {
    return await this.postRepository.save({ ...post, ...postUpdateForm });
  }

  public async restorePost(id: number): Promise<Post> {
    await this.postRepository.restore({id});
    return await this.postRepository.findOneBy({id});
  }

  public async softDeletePost(post: Post): Promise<void> {
    await this.postRepository.softRemove(post);
  }

  public async hardDeletePost(post: Post): Promise<void> {
    await this.postRepository.remove(post);
  }
}
```

## Module with Providers

```typescript
@Module({
  controllers: [PostsController],
  providers: [PostsService],
  exports: [PostsService],  // Make available to other modules
})
export class PostsModule {}
```

## Custom Providers

```typescript
// Value provider
{ provide: 'API_KEY', useValue: process.env.API_KEY }

// Factory provider
{
  provide: 'CONFIG',
  useFactory: (configService: ConfigService) => ({
    apiUrl: configService.get('API_URL'),
  }),
  inject: [ConfigService],
}

// Class provider
{ provide: LoggerService, useClass: CustomLoggerService }

// Async factory
{
  provide: 'DATABASE_CONNECTION',
  useFactory: async () => {
    const connection = await createConnection();
    return connection;
  },
}
```

## Injection Patterns

```typescript
// Constructor injection (preferred)
constructor(private readonly postsService: PostsService) {}

// Token injection
constructor(@Inject('API_KEY') private apiKey: string) {}

// Optional injection
constructor(@Optional() private readonly cache?: CacheService) {}

// Property injection (use sparingly)
@Inject() private readonly logger: Logger;
```

## Scope

```typescript
// Default: Singleton (shared across app)
@Injectable()
export class SharedService {}

// Request-scoped: New instance per request
@Injectable({ scope: Scope.REQUEST })
export class RequestService {
  constructor(@Inject(REQUEST) private request: Request) {}
}

// Transient: New instance every injection
@Injectable({ scope: Scope.TRANSIENT })
export class HelperService {}
```

## Quick Reference

| Pattern | Use When |
|---------|----------|
| Constructor DI | Most cases (recommended) |
| `@Inject(token)` | Non-class tokens |
| `@Optional()` | Optional dependency |
| Factory provider | Dynamic configuration |
| Scope.REQUEST | Per-request state |
