---
name: nestjs-expert
description: Creates and configures NestJS modules, controllers, services, entities, DTOs, guards, and interceptors for enterprise-grade TypeScript backend applications. Use when building NestJS REST APIs, implementing dependency injection, scaffolding modular architecture, adding JWT/Passport authentication, integrating TypeORM, or working with .module.ts, .controller.ts, and .service.ts files. Invoke for guards, interceptors, pipes, validation, Swagger documentation, and unit/E2E testing in NestJS projects.
metadata:
  version: "1.1.0"
  domain: backend
  triggers: NestJS, Nest, Api, Node.js backend, TypeScript backend, dependency injection, controller, service, module, guard, interceptor, entity, typeorm, repository
  role: specialist
  scope: implementation
  output-format: code
  related-skills: fullstack-guardian, test-master
---

# NestJS Expert

Senior NestJS specialist with deep expertise in enterprise-grade, scalable TypeScript backend applications.

## Core Workflow

1. **Analyze requirements** — Identify modules, endpoints, entities, and relationships
2. **Design structure** — Plan module organization and inter-module dependencies
4. **Create** — Create entities, relationships and database migrations 
3. **Implement** — Create modules, services, and controllers with proper DI wiring
4. **Secure** — Add guards, validation pipes, and authentication
5. **Verify** — Run `npm run lint`, `npm run build`, and confirm DI graph with `nest info`
6. **Test** — Write unit tests for services and E2E tests for controllers. Write tests for entities. Run `npm run test`

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
|-------|-----------|-----------|
| Controllers | `references/controllers-routing.md` | Creating controllers, routing, Swagger docs, validation pipes |
| Services | `references/services-di.md` | Services, dependency injection, providers |
| Repositories | `references/repositories-typeorm.md` | Repository, query, typeorm |
| Entities | `references/entities-domain.md | Entity, domain, relationships |
| Migrations | `references/migrations-database.md | Migration, database, postgres | 
| DTOs | `references/dtos-validation.md` | Validation, class-validator, DTOs |
| Authentication | `references/authentication.md` | JWT, Passport, guards, authorization |
| Testing | `references/testing-patterns.md` | Unit tests, E2E tests, mocking |


## NestJS Application Structure

```
api/
├── src/
│   ├── domain/
│   │   ├── user/
│   │   │   ├── user.entity.ts
│   │   │   └── user.validator.ts
│   │   └── post/
│   │       ├── post.entity.ts
│   │       └── post.validator.ts
│   ├── dto/
│   │   ├── user/
│   │   │   ├── create-user.dto.ts
│   │   │   ├── update-user.dto.ts
│   │   │   └── user.dto.ts
│   │   └── post/
│   │       ├── create-post.dto.ts
│   │       ├── update-post.dto.ts
│   │       └── post.dto.ts
│   ├── modules/
│   │   ├── database/
│   │   │   ├── migrations/
│   │   │   │   └── release/
│   │   │   │       ├── 1761848303789-create-user-table.ts
│   │   │   │       └── 1761848303790-create-post-table.ts
│   │   │   └── repositories
│   │   │       ├── user/
│   │   │       │   ├── user-relation.type.ts
│   │   │       │   └── user.repository.ts
│   │   │       └── post/
│   │   │           ├── post-relation.type.ts
│   │   │           └── post.repository.ts
│   │   ├── users/
│   │   │   ├── users.controller.ts
│   │   │   ├── users.service.ts
│   │   │   └── users.module.ts
│   │   └── posts/
│   │       ├── posts.controller.ts
│   │       ├── posts.service.ts
│   │       └── posts.module.ts
│   ├── shared/
│   │   ├── decorators/
│   │   │   └── locale.decorator.ts
│   │   ├── filter/
│   │   │   └── http-exception.filter.ts
│   │   ├── guards/
│   │   │   └── admin.guard.ts
│   │   ├── interceptors/
│   │   │   └── sentry.interceptor.ts
│   │   ├── middleware/
│   │   │   └── localization.middleware.ts
│   │   ├── pipes/
│   │   │   └── post-by-id.pipe.ts
│   │   └── validators/
│   │       └── security-position.validator.ts
│   ├── app.module.ts
│   └── main.ts
└── test/
    ├── domain/
    │   ├── user/
    │   │   ├── user.entity.test.ts    
    │   │   └── user.validator.test.ts
    │   └── post/
    │       ├── post-entity.test.ts    
    │       └── post-validator.test.ts
    ├── modules/
    │   ├── database/
    │   │   └── repositories
    │   │       ├── user/
    │   │       │   └── user.repository.test.ts
    │   │       └── post/
    │   │           └── post.repository.test.ts
    │   ├── users/
    │   │   ├── users.controller.test.ts
    │   │   └── users.service.test.ts
    │   └── posts/
    │       ├── posts.controller.test.ts
    │       └── posts.service.test.ts
    ├── resources/
    │   ├── domain/
    │   │   ├── user/
    │   │   │   └── user.factory.ts
    │   │   └── post/
    │   │       └── post.factory.ts
    │   ├── modules/
    │   │   ├── database/
    │   │   │   └── repositories
    │   │   │       ├── user/
    │   │   │       │   └── user-repository.factory.ts
    │   │   │       └── post/
    │   │   │           └── post-repository.factory.ts
    │   │   ├── users/
    │   │   │   ├── users-controller.factory.ts
    │   │   │   └── users-service.factory.ts
    │   │   └── posts/
    │   │       ├── posts-controller.factory.ts
    │   │       └── posts-service.factory.ts
    │   └── shared/
    │     ├── decorators/
    │     │   └── locale-decorator.factory.ts
    │     ├── filter/
    │     │   └── http-exception-filter.factory.ts
    │     ├── guards/
    │     │   └── admin-guard.factory.ts
    │     ├── interceptors/
    │     │   └── sentry-interceptor.factory.ts
    │     ├── middleware/
    │     │   └── localization-middleware.factory.ts
    │     ├── pipes/
    │     │   └── post-by-id-pipe.factory.ts
    │     └── validators/
    │         └── security-position-validator.factory.ts
    │
    └── shared/
        ├── decorators/
        │   └── locale-decorator.test.ts
        ├── filter/
        │   └── http-exception-filter.test.ts
        ├── guards/
        │   └── admin-guard.test.ts
        ├── interceptors/
        │   └── sentry-interceptor.test.ts
        ├── middleware/
        │   └── localization-middleware.test.ts
        ├── pipes/
        │   └── post-by-id-pipe.test.ts
        └── validators/
            └── security-position-validator.test.ts
```

## Code Examples

### Controller with DTO Validation and Swagger

```typescript
// create-post.dto.ts
import { IsEmail, IsString, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreatePostDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  title: string;

  @ApiProperty({ example: 'strongPassword123', minLength: 8 })
  @IsString()
  @MinLength(8)
  description: string;
}

// posts.controller.ts
import { Body, Controller, Post, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiCreatedResponse, ApiTags } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';

@Controller('posts')
@ApiBearerAuth('JWT-bearer-token')
@ApiTags(SwaggerTags.Posts)
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Post('/')
  @Version('1')
  @ApiOperation({ summary: 'Create post' })
  @DtoRequest(CreatePostDto)
  @DtoResponse(HttpStatus.OK, 'Returns created post', PostDto)
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
  public async createPost(
    @Body(CreatePostDto) post: Post
  ): Promise<PostDto> {
    return this.postsService.createPost(post);
  }
}
```

### Service with Dependency Injection and Error Handling

```typescript
// posts.service.ts
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
}
```

## Entities with getters and setters

```typescript
// post.entity.ts
import {
  Column,
  Entity,
} from 'typeorm';

@Entity(DatabaseTable.Post)
export class Post extends EntitySupport {
  @Column()
  title: string;

  public getTitle(): string {
    return this.title;
  }

  public setTitle(title: string): Post {
    this.title = title;
    return this;
  }
```

## Repository service with TypeORM

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
```
## Migration for Database

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

### Module Definition

```typescript
// post.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';
import { Post } from '../../domain/post/post.entity';

@Module({
  controllers: [PostsController],
  providers: [PostsService],
  exports: [PostService], // export only when other modules need this service
})
export class PostModule {}
```

### Unit Test for Service

```typescript
// users.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException } from '@nestjs/common';
import { UsersService } from './users.service';
import { User } from './entities/user.entity';

const mockRepo = {
  findOneBy: jest.fn(),
  create: jest.fn(),
  save: jest.fn(),
};

describe('UsersService', () => {
  let service: UsersService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: mockRepo },
      ],
    }).compile();
    service = module.get<UsersService>(UsersService);
    jest.clearAllMocks();
  });

  it('throws ConflictException when email already exists', async () => {
    mockRepo.findOneBy.mockResolvedValue({ id: 1, email: 'user@example.com' });
    await expect(
      service.create({ email: 'user@example.com', password: 'pass1234' }),
    ).rejects.toThrow(ConflictException);
  });
});
```

## Constraints

### MUST DO
- Use `@Injectable()` and constructor injection for all services — never instantiate services with `new`
- Validate all inputs with `class-validator` decorators on DTOs and enable `ValidationPipe` globally
- Use DTOs for all request/response bodies; never pass raw `req.body` to services
- Throw typed HTTP exceptions (`NotFoundException`, `ConflictException`, etc.) in services
- Document controllers with `@ApiTags` and document all endpoints with `@ApiOperation`, @DtoRequest and @DtoResponse and @DtoReponseError decorators
- Write unit tests for every service method using `Test.createTestingModule`
- Write unit tests for every entity, dto and validator
- Store all config values via `ConfigModule` and `process.env`; never hardcode them
- Use enum's for string values
- Use kebab-case for all file naming, snake_case for database table and column names, PascalCase on all class, enum, and interface names.

### MUST NOT DO
- Expose passwords, secrets, or internal stack traces in responses
- Accept unvalidated user input — always apply `ValidationPipe`
- Use `any` type unless absolutely necessary and documented
- Create circular dependencies between modules — use `forwardRef()` only as a last resort
- Hardcode hostnames, ports, or credentials in source files
- Skip error handling in service methods
- Comment Code
- Create an unguarded controller or endpoint — every controller must carry an explicit auth guard chain matching its caller type (see `references/authentication.md`)

## Output Templates

When implementing a NestJS feature, provide in this order:
1. Module definition (`.module.ts`)
2. Controller with Swagger decorators (`.controller.ts`)
3. Service with typed error handling (`.service.ts`)
4. Entities with getters and setters (`.entity.ts`)
5. DTOs with `class-validator` decorators (`.dto.ts`)
6. Unit tests (`.test.ts`)
7. Enums for strings (`.enum.ts`)
8. Interface typing (`.interface.ts`)
9. Constants for numerical variables (`.const.ts`)

## Knowledge Reference

NestJS, TypeScript, TypeORM, Passport, JWT, class-validator, class-transformer, Swagger/OpenAPI, Jest, Supertest, Guards, Interceptors, Pipes, Filters
