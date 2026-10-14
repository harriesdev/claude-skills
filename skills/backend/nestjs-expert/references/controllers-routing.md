# Controllers & Routing

## Constraints

### MUST DO
- Serve every route under `/api/v1/`: set the `api` global prefix in `main.ts` and add `@Version('1')` to every endpoint
- Add `@ApiBearerAuth('JWT-bearer-token')` and `@ApiTags(SwaggerTags.X)` to every controller
- Return entities from endpoints; `@DtoResponse` maps them to the response DTO (see `references/dto-responses.md`)
- Pass path ids to the service with the current user for user-owned records (`@Param('postId', ParseIntPipe) postId: number`, `@CurrentUser() user: User`) so the service checks ownership
- Load path entities with a by-id pipe only for records every authenticated user may read, or on admin-only routes
- Accept `PaginationQueryDto` on every list endpoint and return `Page<T>`
- Use `@HttpCode(HttpStatus.NO_CONTENT)` on endpoints that return nothing, and `@HttpCode(HttpStatus.OK)` on `POST` actions that don't create a resource
- Mark endpoints that need no authentication with `@Public()`; restrict by role with `@Roles(UserRole.Admin)`

### MUST NOT DO
- Put `api` or `v1` in a `@Controller()` or route path — the global prefix and `@Version` add them
- Add `@UseGuards(JwtAuthGuard)` or `@UseGuards(RolesGuard)` — both run globally as `APP_GUARD` (see `references/authentication.md`)
- Read `@Req()` / `req.body` directly
- Return DTO instances built by hand
- Return unbounded arrays from list endpoints
- Document a status in `@DtoResponse` that differs from what the endpoint actually sends

## Controller with Swagger

```typescript
// posts.controller.ts
import {
  Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseIntPipe, Patch, Post, Query, Version,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';

@Controller('posts')
@ApiBearerAuth('JWT-bearer-token')
@ApiTags(SwaggerTags.Posts)
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Get('/')
  @Version('1')
  @ApiOperation({ summary: 'Get my posts' })
  @DtoResponse(HttpStatus.OK, 'Returns a page of posts', PostPageDto)
  public async getPosts(
    @Query() paginationQueryDto: PaginationQueryDto,
    @CurrentUser() user: User,
  ): Promise<Page<Post>> {
    return this.postsService.getPostsByUser(user, paginationQueryDto);
  }

  @Get('/:postId')
  @Version('1')
  @ApiOperation({ summary: 'Get post by id' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.OK, 'Returns post', PostDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async getPostById(
    @Param('postId', ParseIntPipe) postId: number,
    @CurrentUser() user: User,
  ): Promise<Post> {
    return this.postsService.getOwnedPost(postId, user);
  }

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

  @Patch('/:postId')
  @Version('1')
  @ApiOperation({ summary: 'Update post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoRequest(UpdatePostDto)
  @DtoResponse(HttpStatus.OK, 'Returns updated post', PostDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
  public async updatePost(
    @Param('postId', ParseIntPipe) postId: number,
    @Body() updatePostDto: UpdatePostDto,
    @CurrentUser() user: User,
  ): Promise<Post> {
    return this.postsService.updatePost(postId, updatePostDto, user);
  }

  @Post('/:postId/restore')
  @Version('1')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Restore post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.OK, 'Returns the restored post', PostDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async restorePost(
    @Param('postId', ParseIntPipe) postId: number,
    @CurrentUser() user: User,
  ): Promise<Post> {
    return this.postsService.restorePost(postId, user);
  }

  @Delete('/:postId')
  @Version('1')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Soft delete post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.NO_CONTENT, 'Post soft deleted')
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async softDeletePost(
    @Param('postId', ParseIntPipe) postId: number,
    @CurrentUser() user: User,
  ): Promise<void> {
    return this.postsService.softDeletePost(postId, user);
  }

  @Delete('/:postId/permanent')
  @Version('1')
  @Roles(UserRole.Admin)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Hard delete post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.NO_CONTENT, 'Post permanently deleted')
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  @DtoResponseError(HttpStatus.FORBIDDEN, 'Admin role required')
  public async hardDeletePost(
    @Param('postId', ParseIntPipe) postId: number,
    @CurrentUser() user: User,
  ): Promise<void> {
    return this.postsService.hardDeletePost(postId, user);
  }
}
```

### Status Codes and Methods

| Action | Method | Success status |
|--------|--------|----------------|
| List | `GET /posts` | 200 with a page (empty page is still 200) |
| Read | `GET /posts/:id` | 200 |
| Create | `POST /posts` | 201 (Nest's default for POST) |
| Partial update | `PATCH /posts/:id` | 200 |
| Action on a resource (restore, publish) | `POST /posts/:id/restore` | 200 via `@HttpCode` |
| Delete | `DELETE /posts/:id` | 204 via `@HttpCode` |

Use `PUT` only to replace a whole resource with a body that contains every field.

## Public Endpoints

```typescript
@Controller('health')
@ApiTags(SwaggerTags.Health)
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Public()
  @SkipThrottle()
  @Get('/')
  @Version('1')
  @ApiOperation({ summary: 'Liveness check' })
  @DtoResponse(HttpStatus.OK, 'API is healthy', HealthStatusDto)
  @DtoResponseError(HttpStatus.SERVICE_UNAVAILABLE, 'API is not healthy')
  public async getHealth(): Promise<HealthCheckResult> {
    return this.healthService.getHealth();
  }

  @Get('/details')
  @Version('1')
  @Roles(UserRole.Admin)
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'Detailed health of each dependency' })
  @DtoResponse(HttpStatus.OK, 'Health of each dependency', HealthCheckDto)
  @DtoResponseError(HttpStatus.SERVICE_UNAVAILABLE, 'A dependency is not healthy')
  public async getHealthDetails(): Promise<HealthCheckResult> {
    return this.healthService.getHealth();
  }
}
```

`HealthStatusDto` maps only `status`; `HealthCheckDto` maps `status`, `info`, `error` and `details`. Load balancer probes use the public endpoint, so it skips rate limiting.

## Admin Controllers

Admin-only endpoints live in their own controller under an `admin/` route and carry `@Roles(UserRole.Admin)` on the class.

```typescript
@Controller('admin/users')
@Roles(UserRole.Admin)
@ApiBearerAuth('JWT-bearer-token')
@ApiTags(SwaggerTags.AdminUsers)
export class AdminUsersController {}
```

## Nested Routes

```typescript
@Controller('posts/:postId/comments')
@ApiBearerAuth('JWT-bearer-token')
@ApiTags(SwaggerTags.PostComments)
export class CommentsController {
  constructor(private readonly commentsService: CommentsService) {}

  @Get('/')
  @Version('1')
  @ApiOperation({ summary: 'Get comments for post' })
  @DtoResponse(HttpStatus.OK, 'Returns a page of comments', CommentPageDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async getCommentsForPost(
    @Param('postId', ParseIntPipe) postId: number,
    @Query() paginationQueryDto: PaginationQueryDto,
    @CurrentUser() user: User,
  ): Promise<Page<Comment>> {
    return this.commentsService.getCommentsForPost(postId, paginationQueryDto, user);
  }

  @Post('/')
  @Version('1')
  @ApiOperation({ summary: 'Create comment' })
  @DtoRequest(CreateCommentForm)
  @DtoResponse(HttpStatus.CREATED, 'Returns created comment', CommentDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
  public async createComment(
    @Param('postId', ParseIntPipe) postId: number,
    @Body(CreateCommentForm) comment: Comment,
    @CurrentUser() user: User,
  ): Promise<Comment> {
    return this.commentsService.createComment(postId, comment, user);
  }
}
```

## By-Id Pipes

By-id pipes load a record and return 404 when it doesn't exist. They don't know who is asking, so they **don't check ownership**. Use them for records every authenticated user may read (reference data such as exchanges or markets) and on admin-only routes. For user-owned records, pass the id and `@CurrentUser()` to the service instead.

```typescript
// src/shared/pipes/exchange-by-id.pipe.ts
import {
  ArgumentMetadata,
  Injectable,
  NotFoundException,
  ParseIntPipe,
  PipeTransform,
} from '@nestjs/common';
import { Exchange } from '../../domain/exchange/exchange.entity';
import { ExchangeRepository } from '../../modules/database/repositories/exchange/exchange.repository';
import { ExchangeByIdPipeMessages } from './exchange-by-id-pipe-messages.enum';

@Injectable()
export class ExchangeByIdPipe
  implements PipeTransform<string, Promise<Exchange>>
{
  private parseIntPipe = new ParseIntPipe();

  constructor(
    private readonly exchangeRepository: ExchangeRepository,
  ) {}

  async transform(
    value: string,
    metadata: ArgumentMetadata,
  ): Promise<Exchange> {
    const result = await this.exchangeRepository.findById(
      await this.parseIntPipe.transform(value, metadata),
    );

    if (!result) {
      throw new NotFoundException(ExchangeByIdPipeMessages.NotFound);
    }

    return result;
  }
}

// exchange-by-id-pipe-messages.enum.ts
export enum ExchangeByIdPipeMessages {
  NotFound = 'Exchange not found',
}
```

A malformed id returns 400 from `ParseIntPipe`; a missing record returns 404.

## Bootstrap, Versioning & Swagger

```typescript
// main.ts
import { VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import cookieParser from 'cookie-parser';
import basicAuth from 'express-basic-auth';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { SwaggerConfigService } from './docs/swagger-config.service';
import { CorsConfigService } from './modules/config/cors-config.service';
import { ApiRoute } from './shared/enums/api-route.enum';
import { requestIdMiddleware } from './shared/middleware/request-id.middleware';
import { ApiValidationPipe } from './shared/pipes/api-validation.pipe';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const swaggerConfig = SwaggerConfigService.create();
  const corsConfig = CorsConfigService.create();

  app.use(requestIdMiddleware);
  app.use(helmet({ contentSecurityPolicy: swaggerConfig.getContentSecurityPolicy() }));
  app.enableCors(corsConfig.getCorsOptions());
  app.use(cookieParser());
  app.setGlobalPrefix(ApiRoute.Prefix);
  app.enableVersioning({ type: VersioningType.URI });
  app.useGlobalPipes(new ApiValidationPipe());

  app.use(
    [`/${ApiRoute.Docs}`, `/${ApiRoute.Docs}-json`],
    basicAuth({
      challenge: true,
      users: { [swaggerConfig.getUsername()]: swaggerConfig.getPassword() },
    }),
  );
  SwaggerModule.setup(
    ApiRoute.Docs,
    app,
    SwaggerModule.createDocument(app, swaggerConfig.buildDocument()),
  );

  await app.listen(swaggerConfig.getPort(), '0.0.0.0');
}
bootstrap();
```

Middleware order matters: the request id is assigned first so every later log line can use it, and `helmet` and CORS run before any route, including Swagger.

Every route is served under `/api/v1/`: `setGlobalPrefix` adds `/api` and `@Version('1')` adds `/v1`, so `@Controller('posts')` is served at `/api/v1/posts`. Swagger UI is at `/api/docs` behind basic auth. `SwaggerModule.setup` doesn't apply the global prefix, so the docs path includes it.

```typescript
// src/shared/enums/api-route.enum.ts
export enum ApiRoute {
  Prefix = 'api',
  Docs = 'api/docs',
}
```

```typescript
// src/docs/swagger-config.service.ts
import { DocumentBuilder, OpenAPIObject } from '@nestjs/swagger';
import { HelmetOptions } from 'helmet';
import { ApiConfigService } from '../modules/config/api-config.service';
import { API_DOCUMENTATION } from './api-documentation.const';
import { SwaggerDefaults } from './swagger-defaults.enum';

type HelmetContentSecurityPolicy = Exclude<HelmetOptions['contentSecurityPolicy'], boolean | undefined>;

export class SwaggerConfigService extends ApiConfigService {
  public static create(): SwaggerConfigService {
    return new SwaggerConfigService().ensureValues([
      'PORT',
      'SWAGGER_USERNAME',
      'SWAGGER_PASSWORD',
    ]);
  }

  public getUsername(): string {
    return this.getValue('SWAGGER_USERNAME');
  }

  public getPassword(): string {
    return this.getValue('SWAGGER_PASSWORD');
  }

  public getContentSecurityPolicy(): HelmetContentSecurityPolicy {
    return {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'validator.swagger.io'],
      },
    };
  }

  public buildDocument(): Omit<OpenAPIObject, 'paths'> {
    const document = new DocumentBuilder()
      .setTitle(this.getValue('SWAGGER_TITLE', false) || SwaggerDefaults.Title)
      .setDescription(this.getValue('SWAGGER_DESCRIPTION', false) || SwaggerDefaults.Description)
      .setVersion(this.getValue('RELEASE_VERSION', false) || SwaggerDefaults.Version)
      .addBearerAuth(
        {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          name: 'JWT',
          description: 'Enter JWT token',
          in: 'header',
        },
        'JWT-bearer-token',
      );

    API_DOCUMENTATION.forEach((tag) => document.addTag(tag.name, tag.description));
    return document.build();
  }
}
```

```typescript
// src/docs/swagger-tags.enum.ts
export enum SwaggerTags {
  AdminUsers = 'Admin Users',
  Authentication = 'Authentication',
  Health = 'Health',
  PostComments = 'Post Comments',
  Posts = 'Posts',
  Users = 'Users',
}

// src/docs/api-documentation.interface.ts
export interface ApiDocumentation {
  name: SwaggerTags;
  description: string;
}

// src/docs/api-documentation.const.ts
export const API_DOCUMENTATION: ApiDocumentation[] = [
  { name: SwaggerTags.Posts, description: 'Create, read, update and delete posts.' },
];

// src/docs/swagger-defaults.enum.ts
export enum SwaggerDefaults {
  Title = 'API Docs',
  Description = 'API Documentation',
  Version = 'R1.0.0',
}
```

Swagger UI's page uses inline scripts and styles, so the content security policy allows `'unsafe-inline'` for them. The API itself only returns JSON, which a browser never executes, so the looser policy doesn't weaken the endpoints.

### CORS

```typescript
// src/modules/config/cors-config.service.ts
import { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';
import { RequestHeader } from '../../shared/enums/request-header.enum';
import { ApiConfigService } from './api-config.service';
import { CorsValues } from './cors-values.const';

export class CorsConfigService extends ApiConfigService {
  public static create(): CorsConfigService {
    return new CorsConfigService().ensureValues(['CORS_ORIGINS']);
  }

  public getCorsOptions(): CorsOptions {
    return {
      origin: this.getValue('CORS_ORIGINS')
        .split(',')
        .map((origin) => origin.trim()),
      credentials: true,
      methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization', RequestHeader.RequestId, RequestHeader.AuthTransport],
      exposedHeaders: [RequestHeader.RequestId],
      maxAge: CorsValues.PreflightMaxAgeSeconds,
    };
  }
}

// cors-values.const.ts
export const CorsValues = {
  PreflightMaxAgeSeconds: 86400,
};
```

`CORS_ORIGINS` is a comma-separated allow-list of exact origins, e.g. `https://app.example.com,https://admin.example.com`. Never use `*` with `credentials: true`.

Add a `SwaggerTags` entry for every new controller, and an `API_DOCUMENTATION` entry to describe it in Swagger UI.

## Quick Reference

| Decorator | Purpose |
|-----------|---------|
| `@Controller('path')` | Define route prefix |
| `app.setGlobalPrefix(ApiRoute.Prefix)` | `/api` prefix on every route |
| `@Version('1')` | URI version, giving `/api/v1/...` |
| `@Get()`, `@Post()`, `@Put()`, `@Patch()`, `@Delete()` | HTTP method |
| `@Param('name', Pipe)` | Path parameter |
| `@Query('name')` | Query parameter |
| `@Body(Form)` | Request body built into an entity by a form |
| `@HttpCode(201)` | Override status code |
| `@ApiTags(SwaggerTags.X)` | Swagger grouping |
| `@ApiBearerAuth('JWT-bearer-token')` | Swagger auth |
| `@ApiOperation()` | Endpoint description |
| `@DtoResponse()` | Document response and map entity to DTO |
| `@DtoResponseError()` | Document error |
| `@DtoRequest()` | Document request |
| `@CurrentUser()` | Authenticated user entity |
| `@Public()` | Skip authentication |
| `@Roles(UserRole.Admin)` | Require role |
