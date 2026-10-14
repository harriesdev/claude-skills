---
name: nestjs-expert
description: Creates and configures NestJS modules, controllers, services, entities, DTOs, guards, and interceptors for enterprise-grade TypeScript backend applications. Use when building NestJS REST APIs, implementing dependency injection, scaffolding modular architecture, adding JWT/Passport authentication, integrating TypeORM, or working with .module.ts, .controller.ts, and .service.ts files. Invoke for guards, interceptors, pipes, validation, Swagger documentation, and unit/E2E testing in NestJS projects.
metadata:
  version: "1.2.0"
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
3. **Create** — Create entities, domain factories, validators, relationships and database migrations; register entities in `Entities` and repositories in `RepositoryServices`
4. **Implement** — Create modules, services, forms, response DTOs and controllers with proper DI wiring
5. **Secure** — Mark public endpoints with `@Public()`, restrict roles with `@Roles()`, validate input with forms and `ApiValidationPipe`
6. **Verify** — Run `npm run lint`, `npm run build`, and confirm DI graph with `nest info`
7. **Test** — Write unit tests for services and E2E tests for controllers. Write tests for entities. Run `npm run test`

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
|-------|-----------|-----------|
| API Design | `references/api-design-standards.md` | REST/GraphQL APIs, versioning, CORS, validation |
| Controllers | `references/controllers-routing.md` | Creating controllers, routing, Swagger docs, validation pipes |
| Services | `references/services-di.md` | Services, dependency injection, providers, exceptions, external HTTP, email, health checks |
| Repositories | `references/repository-typeorm.md` | Repository, query, typeorm |
| Entities | `references/entities-domain.md` | Entity, domain, relationships, audit, domain factories |
| Migrations | `references/migrations-database.md` | Migration, database, postgres |
| DTOs & Forms | `references/dtos-validation.md` | Validation, class-validator, request DTOs, forms, `ApiValidationPipe` |
| Response DTOs | `references/dto-responses.md` | `@DtoResponse`, `@DtoProperty`, mapping entities to responses |
| Configuration | `references/configuration.md` | ConfigService, ApiConfigService, env variables |
| Error Handling | `references/error-handling.md` | Error responses, `HttpExceptionFilter`, `ValidationException`, request ids |
| Authentication | `references/authentication.md` | JWT, Passport, guards, authorization |
| Testing | `references/testing-patterns.md` | Unit tests, E2E tests, mocking |


## NestJS Application Structure

```
api/
├── src/
│   ├── docs/
│   │   ├── api-documentation.const.ts
│   │   ├── swagger-config.service.ts
│   │   └── swagger-tags.enum.ts
│   ├── domain/
│   │   ├── database-table.enum.ts
│   │   ├── domain-object.ts
│   │   ├── index.ts
│   │   ├── user/
│   │   │   ├── user.entity.ts
│   │   │   ├── user.factory.ts
│   │   │   └── user.validator.ts
│   │   └── post/
│   │       ├── post.entity.ts
│   │       ├── post.factory.ts
│   │       └── post.validator.ts
│   ├── dto/
│   │   ├── common/
│   │   │   ├── page-meta.dto.ts
│   │   │   ├── pagination-query.dto.ts
│   │   │   └── pagination-values.const.ts
│   │   ├── user/
│   │   │   ├── create-user.dto.ts
│   │   │   ├── update-user.dto.ts
│   │   │   └── user.dto.ts
│   │   └── post/
│   │       ├── create-post.form.ts
│   │       ├── update-post.dto.ts
│   │       ├── post.dto.ts
│   │       └── post-page.dto.ts
│   ├── modules/
│   │   ├── config/
│   │   │   ├── api-config.service.ts
│   │   │   ├── cors-config.service.ts
│   │   │   └── types/
│   │   │       ├── config-source.interface.ts
│   │   │       └── environment.enum.ts
│   │   ├── database/
│   │   │   ├── audit/
│   │   │   │   ├── audit-context.ts
│   │   │   │   ├── audit-user.interceptor.ts
│   │   │   │   └── domain-audit.subscriber.ts
│   │   │   ├── config/
│   │   │   │   ├── column-types.functions.ts
│   │   │   │   ├── postgres-typeorm-config.service.ts
│   │   │   │   └── snake-naming-strategy.ts
│   │   │   ├── database.module.ts
│   │   │   ├── migrations/
│   │   │   │   ├── 1761848303789-create-user-table.ts
│   │   │   │   └── 1761848303790-create-post-table.ts
│   │   │   └── repositories
│   │   │       ├── repository-services.const.ts
│   │   │       ├── repository.support.ts
│   │   │       ├── user/
│   │   │       │   ├── user-relation.type.ts
│   │   │       │   └── user.repository.ts
│   │   │       └── post/
│   │   │           ├── post-relation.type.ts
│   │   │           └── post.repository.ts
│   │   ├── authentication/
│   │   │   ├── authentication.controller.ts
│   │   │   ├── authentication.module.ts
│   │   │   ├── authentication.service.ts
│   │   │   └── strategies/
│   │   │       └── jwt.strategy.ts
│   │   ├── users/
│   │   │   ├── users.controller.ts
│   │   │   ├── users.service.ts
│   │   │   └── users.module.ts
│   │   └── posts/
│   │       ├── posts.controller.ts
│   │       ├── posts.service.ts
│   │       └── posts.module.ts
│   ├── shared/
│   │   ├── const/
│   │   │   ├── dto-properties-array-symbol.const.ts
│   │   │   └── throttle-values.const.ts
│   │   ├── decorators/
│   │   │   ├── current-user.decorator.ts
│   │   │   ├── dto.decorator.ts
│   │   │   ├── dto-property.decorator.ts
│   │   │   ├── dto-type.decorator.ts
│   │   │   ├── locale.decorator.ts
│   │   │   ├── public.decorator.ts
│   │   │   └── roles.decorator.ts
│   │   ├── enums/
│   │   │   ├── error-code.enum.ts
│   │   │   ├── error-messages.enum.ts
│   │   │   └── request-header.enum.ts
│   │   ├── exceptions/
│   │   │   ├── illegal-argument.exception.ts
│   │   │   ├── illegal-state.exception.ts
│   │   │   └── validation.exception.ts
│   │   ├── filter/
│   │   │   └── http-exception.filter.ts
│   │   ├── functions/
│   │   │   └── validation-details.functions.ts
│   │   ├── guards/
│   │   │   ├── admin.guard.ts
│   │   │   ├── jwt-auth.guard.ts
│   │   │   └── roles.guard.ts
│   │   ├── interceptors/
│   │   │   ├── dto-response.interceptor.ts
│   │   │   ├── dto-response-mapper.interceptor.ts
│   │   │   ├── dto-response-mapper.service.ts
│   │   │   └── sentry.interceptor.ts
│   │   ├── interfaces/
│   │   │   ├── api-error.interface.ts
│   │   │   ├── dto-property-type.interface.ts
│   │   │   └── jwt-payload.interface.ts
│   │   ├── middleware/
│   │   │   ├── localization.middleware.ts
│   │   │   └── request-id.middleware.ts
│   │   ├── pipes/
│   │   │   ├── api-validation.pipe.ts
│   │   │   ├── form.pipe.ts
│   │   │   └── exchange-by-id.pipe.ts
│   │   ├── types/
│   │   │   ├── constructor.type.ts
│   │   │   └── page.ts
│   │   └── validators/
│   │       ├── is-not-blank.validator.ts
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
    │   │   │   └── user.test-factory.ts
    │   │   └── post/
    │   │       └── post.test-factory.ts
    │   ├── modules/
    │   │   ├── database/
    │   │   │   └── repositories
    │   │   │       ├── user/
    │   │   │       │   └── user-repository.test-factory.ts
    │   │   │       └── post/
    │   │   │           └── post-repository.test-factory.ts
    │   │   ├── users/
    │   │   │   ├── users-controller.test-factory.ts
    │   │   │   └── users-service.test-factory.ts
    │   │   └── posts/
    │   │       ├── posts-controller.test-factory.ts
    │   │       └── posts-service.test-factory.ts
    │   └── shared/
    │     ├── decorators/
    │     │   └── locale-decorator.test-factory.ts
    │     ├── filter/
    │     │   └── http-exception-filter.test-factory.ts
    │     ├── guards/
    │     │   └── admin-guard.test-factory.ts
    │     ├── interceptors/
    │     │   └── sentry-interceptor.test-factory.ts
    │     ├── middleware/
    │     │   └── localization-middleware.test-factory.ts
    │     ├── pipes/
    │     │   └── exchange-by-id-pipe.test-factory.ts
    │     └── validators/
    │         └── security-position-validator.test-factory.ts
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
        │   └── exchange-by-id-pipe.test.ts
        └── validators/
            └── security-position-validator.test.ts
```

## Code Examples

### Controller with Form, Response DTO and Swagger

Request bodies that become entities use a form (`FormPipe`), which validates and calls the domain factory. Controllers return entities; `@DtoResponse` maps them to the response DTO. See `references/dtos-validation.md` and `references/dto-responses.md`.

```typescript
// create-post.form.ts
@Injectable()
export class CreatePostForm extends FormPipe<Post> {
  @ApiProperty({ description: CreatePostFormMessages.TitleDescription })
  @IsNotBlank()
  @MaxLength(CreatePostFormValues.TitleMaxLength)
  title: string;

  @ApiProperty({ description: CreatePostFormMessages.DescriptionDescription })
  @IsString()
  @MinLength(CreatePostFormValues.DescriptionMinLength)
  description: string;

  protected async toDomainObject(): Promise<Post> {
    return await new PostFactory().create(this);
  }
}

// post.dto.ts
@DtoType('Post')
export class PostDto extends DtoResponseInterceptor {
  @DtoProperty((post: Post) => post.getId(), PostDtoMessages.Id)
  readonly id: number;

  @DtoProperty((post: Post) => post.getTitle(), PostDtoMessages.Title)
  readonly title: string;

  public create(): DtoResponseInterceptor {
    return new PostDto();
  }
}

// posts.controller.ts
import { Body, Controller, HttpStatus, Post, Version } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

@Controller('posts')
@ApiBearerAuth('JWT-bearer-token')
@ApiTags(SwaggerTags.Posts)
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Post('/')
  @Version('1')
  @ApiOperation({ summary: 'Create post' })
  @DtoRequest(CreatePostForm)
  @DtoResponse(HttpStatus.CREATED, 'Returns created post', PostDto)
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
  public async createPost(
    @Body(CreatePostForm) post: Post,
    @CurrentUser() user: User,
  ): Promise<Post> {
    return this.postsService.createPost(post, user);
  }
}
```

### Service with Dependency Injection and Error Handling

```typescript
// posts.service.ts
import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PostRepository } from '../database/repositories/post/post.repository';
import { PostsServiceMessages } from './posts-service-messages.enum';

@Injectable()
export class PostsService {
  private readonly logger = new Logger(PostsService.name);

  constructor(
    private readonly postRepository: PostRepository,
  ) {}

  public async getOwnedPost(id: number, user: User): Promise<Post> {
    const post = await this.postRepository.findById(id);
    if (!post || !post.canBeAccessedBy(user)) {
      throw new NotFoundException(PostsServiceMessages.NotFound);
    }
    return post;
  }

  public async createPost(post: Post, user: User): Promise<Post> {
    return await this.postRepository.save(post.setUser(user));
  }
}
```

Records a user may not access return 404, the same as missing records. See `references/services-di.md` for update, restore and delete.

## Entities with getters and setters

Entities extend `DomainObject`, which provides `id` and the audit columns (`createdDate`, `createdBy`, `updatedDate`, `updatedBy`, `deletedDate`, `deletedBy`). `DomainAuditSubscriber` fills the `*By` columns from the authenticated user. Entities that don't need auditing declare their own `@PrimaryGeneratedColumn` instead. See `references/entities-domain.md`.

```typescript
// post.entity.ts
import {
  Column,
  Entity,
} from 'typeorm';
import { DatabaseTable } from '../database-table.enum';
import { DomainObject } from '../domain-object';

@Entity(DatabaseTable.Post)
export class Post extends DomainObject {
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
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Post } from '../../../../domain/post/post.entity';
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
}
```
### Repository Registration

Every new repository must be added to `RepositoryServices` in `src/modules/database/repositories/repository-services.const.ts`. The global `DatabaseModule` (`src/modules/database/database.module.ts`) provides and exports that list, so repositories are injectable in any module without importing `DatabaseModule` or `TypeOrmModule.forFeature`. See `references/repository-typeorm.md`.

```typescript
// repository-services.const.ts
export const RepositoryServices = [
  PostRepository,
  UserRepository,
];
```

## Domain Factory

```typescript
// post.factory.ts
export class PostFactory {
  public async create(form: CreatePostForm): Promise<Post> {
    return new Post()
      .setTitle(form.title)
      .setDescription(form.description);
  }
}
```

Domain factories (`src/domain/{x}/{x}.factory.ts`) are production code that build entities from forms. Test fixtures are **test factories** (`test/resources/**/{x}.test-factory.ts`).

## Migration for Database

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
        created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER NULL,
        updated_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
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

### Module Definition

```typescript
// posts.module.ts
import { Module } from '@nestjs/common';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';

@Module({
  controllers: [PostsController],
  providers: [PostsService],
  exports: [PostsService],
})
export class PostsModule {}
```

### Unit Test for Service

```typescript
// test/modules/posts/posts.service.test.ts
import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PostRepository } from '../../../src/modules/database/repositories/post/post.repository';
import { PostsService } from '../../../src/modules/posts/posts.service';
import { PostTestFactory } from '../../resources/domain/post/post.test-factory';
import { UserTestFactory } from '../../resources/domain/user/user.test-factory';
import { PostRepositoryTestFactory } from '../../resources/modules/database/repositories/post/post-repository.test-factory';

describe(PostsService.name, () => {
  let service: PostsService;
  let postRepository: ReturnType<typeof PostRepositoryTestFactory.build>;

  beforeEach(async () => {
    postRepository = PostRepositoryTestFactory.build();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PostsService,
        { provide: PostRepository, useValue: postRepository },
      ],
    }).compile();
    service = module.get(PostsService);
  });

  afterEach(() => jest.clearAllMocks());

  it('returns a post the user owns', async () => {
    const owner = UserTestFactory.build();
    const post = PostTestFactory.build({ id: 1, user: owner });
    postRepository.findById.mockResolvedValue(post);
    expect(await service.getOwnedPost(1, owner)).toBe(post);
  });

  it('throws NotFoundException for another user\'s post', async () => {
    const post = PostTestFactory.build({ id: 1, user: UserTestFactory.build() });
    postRepository.findById.mockResolvedValue(post);
    await expect(service.getOwnedPost(1, UserTestFactory.build())).rejects.toThrow(NotFoundException);
  });
});
```

## Constraints

### MUST DO
- Use `@Injectable()` and constructor injection for all services — never instantiate services with `new`
- Validate all inputs with `class-validator` decorators; use a form (`FormPipe`) for bodies that become entities and a plain DTO for the rest, and register `ApiValidationPipe` globally (see `references/dtos-validation.md`)
- Use DTOs for all request/response bodies; never pass raw `req.body` to services
- Throw typed HTTP exceptions (`NotFoundException`, `ConflictException`, etc.) in services with messages from an enum
- Return entities from controllers and map them with `@DtoResponse(status, description, Dto)`; response DTOs extend `DtoResponseInterceptor` (see `references/dto-responses.md`)
- Check ownership in the service for user-owned records (`canBeAccessedBy`); not-owned and missing both return 404. Use by-id pipes only for shared reference data or admin-only routes
- Return `Page<T>` from every list endpoint, taking `PaginationQueryDto`; never return unbounded arrays
- Use `201` for creates, `204` with `@HttpCode` for empty responses, `PATCH` for partial updates and `POST /:id/{action}` for actions
- Let `HttpExceptionFilter` (registered as `APP_FILTER`) shape every error as `{ error, message, details?, requestId }` (see `references/error-handling.md`)
- Sign access and refresh tokens with separate secrets and a `type` claim, rotate refresh tokens, and rate-limit auth endpoints with `@Throttle`
- Allow only the origins in `CORS_ORIGINS`
- Add `@Version('1')` to every endpoint and `@ApiBearerAuth('JWT-bearer-token')` to every authenticated controller
- Mark unauthenticated endpoints with `@Public()` and restrict roles with `@Roles(UserRole.X)`; `JwtAuthGuard` and `RolesGuard` run globally as `APP_GUARD` (see `references/authentication.md`)
- Extend `RepositorySupport<T>` for every repository
- Document controllers with `@ApiTags(SwaggerTags.X)` and document all endpoints with `@ApiOperation`, `@DtoRequest`, `@DtoResponse` and `@DtoResponseError` decorators
- Write unit tests for every service method using `Test.createTestingModule`, mocking custom repositories by class
- Name test files `.test.ts`
- Write unit tests for every entity, dto and validator
- Read config through Nest's `ConfigService` (from `@nestjs/config`) inside DI, and through `ApiConfigService` (`src/modules/config/api-config.service.ts`) outside DI; never hardcode values (see `references/configuration.md`)
- Use enum's for string values
- Extend `DomainObject` and name tables with `@Entity(DatabaseTable.X)`; entities that skip `DomainObject` declare their own `@PrimaryGeneratedColumn`
- Include the six audit columns in migrations for `DomainObject` entities
- Create a domain factory and an entity validator for each entity
- Call fixtures in `test/resources/` test factories (`{x}.test-factory.ts`, `XTestFactory`)
- Add every new repository to `RepositoryServices` in `src/modules/database/repositories/repository-services.const.ts`
- Use kebab-case for all file naming, snake_case for database table and column names, PascalCase on all class, enum, and interface names.

### MUST NOT DO
- Expose passwords, secrets, or internal stack traces in responses
- Accept unvalidated user input — every body goes through a form or `ApiValidationPipe`
- Register Nest's plain `ValidationPipe` globally — it rejects entity params produced by forms and by-id pipes
- Add `@UseGuards(JwtAuthGuard)` or `@UseGuards(RolesGuard)` — they already run globally
- Pass a DTO type to more than one `@DtoResponse` on the same endpoint
- Wrap errors in `BadRequestException` just to change the status — let typed exceptions through
- Return an upstream API's status or message to the client — `HttpService` maps failures to 502/503
- Call `app.enableCors()` without an origin allow-list
- Use `any` type unless absolutely necessary and documented
- Provide a repository in a feature module's `providers` — register it in `RepositoryServices` instead
- Create circular dependencies between modules — use `forwardRef()` only as a last resort
- Hardcode hostnames, ports, or credentials in source files
- Name a custom class `ConfigService` or read `process.env` directly outside `ApiConfigService`
- Skip error handling in service methods
- Comment Code
- Create an unauthenticated endpoint without an explicit `@Public()` — everything else is protected by the global guards (see `references/authentication.md`)

## Output Templates

When implementing a NestJS feature, provide in this order:
1. Module definition (`.module.ts`)
2. Controller with Swagger decorators returning entities (`.controller.ts`), plus `SwaggerTags` entry
3. Service with typed error handling (`.service.ts`)
4. Entities extending `DomainObject` with getters and setters (`.entity.ts`), plus the `DatabaseTable` enum entry
5. Domain factories (`.factory.ts`) and entity validators (`.validator.ts`)
6. Migrations including audit columns for `DomainObject` entities
7. Forms (`.form.ts`), request DTOs with `class-validator` decorators and response DTOs (`.dto.ts`)
8. Repositories extending `RepositorySupport` (`.repository.ts`), relation types, and the `RepositoryServices` entry
9. Unit tests (`.test.ts`) and test factories (`.test-factory.ts`)
10. Enums for strings (`.enum.ts`)
11. Interface typing (`.interface.ts`)
12. Constants for numerical variables (`.const.ts`)

## Knowledge Reference

NestJS, TypeScript, TypeORM, Passport, JWT, bcrypt, class-validator, class-transformer, Swagger/OpenAPI, Jest, Supertest, Guards, Interceptors, Pipes, Filters, @nestjs/terminus, @nestjs/axios, @nestjs-modules/mailer, helmet
