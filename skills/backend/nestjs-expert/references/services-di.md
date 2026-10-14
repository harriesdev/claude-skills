# Services & Dependency Injection

## Service Pattern

Services that work on user-owned records take the current user and check ownership before returning or changing a record. A record the user may not access is reported as **404**, the same as a missing record, so ids of other users' records can't be discovered.

```typescript
import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PaginationQueryDto } from '../../dto/common/pagination-query.dto';
import { UpdatePostDto } from '../../dto/post/update-post.dto';
import { PostFactory } from '../../domain/post/post.factory';
import { Page } from '../../shared/types/page';
import { PostRepository } from '../database/repositories/post/post.repository';
import { PostsServiceMessages } from './posts-service-messages.enum';

@Injectable()
export class PostsService {
  private readonly logger = new Logger(PostsService.name);

  constructor(
    private readonly postRepository: PostRepository,
  ) {}

  public async getPostsByUser(
    user: User,
    paginationQueryDto: PaginationQueryDto,
  ): Promise<Page<Post>> {
    return this.postRepository.findPageByUser(user, paginationQueryDto);
  }

  public async getOwnedPost(id: number, user: User): Promise<Post> {
    const post = await this.postRepository.findById(id);
    return this.assertAccessible(post, user);
  }

  public async createPost(post: Post, user: User): Promise<Post> {
    return await this.postRepository.save(post.setUser(user));
  }

  public async updatePost(
    id: number,
    updatePostDto: UpdatePostDto,
    user: User,
  ): Promise<Post> {
    const post = await this.getOwnedPost(id, user);
    return await this.postRepository.save(
      new PostFactory().update(post, updatePostDto),
    );
  }

  public async restorePost(id: number, user: User): Promise<Post> {
    const post = this.assertAccessible(
      await this.postRepository.findById(id, { withDeleted: true }),
      user,
    );
    return await this.postRepository.recover(post);
  }

  public async softDeletePost(id: number, user: User): Promise<void> {
    await this.postRepository.softRemove(await this.getOwnedPost(id, user));
  }

  public async hardDeletePost(id: number, user: User): Promise<void> {
    const post = this.assertAccessible(
      await this.postRepository.findById(id, { withDeleted: true }),
      user,
    );
    await this.postRepository.remove(post);
  }

  private assertAccessible(post: Post | null, user: User): Post {
    if (!post || !post.canBeAccessedBy(user)) {
      throw new NotFoundException(PostsServiceMessages.NotFound);
    }
    return post;
  }
}
```

Entities that belong to a user expose the ownership rule (see `references/entities-domain.md`):

```typescript
// post.entity.ts
public isOwnedBy(user: User): boolean {
  return this.getUser()?.getId() === user.getId();
}

public canBeAccessedBy(user: User): boolean {
  return this.isOwnedBy(user) || user.hasRole([UserRole.Admin]);
}
```

```typescript
// posts-service-messages.enum.ts
export enum PostsServiceMessages {
  NotFound = 'Post not found',
}
```

### Ownership Rules
- Every query for user-owned records is scoped to the user (`findPageByUser`) or followed by `assertAccessible`
- Not-owned and missing records both throw `NotFoundException`
- Admins pass `canBeAccessedBy`; other roles never bypass ownership
- By-id pipes only check existence, so use them only for records every authenticated user may read (reference data) or on admin-only routes

## Exceptions

Services throw typed Nest exceptions with messages from an enum. Two extra exceptions in `src/shared/exceptions/` describe programming and state errors:

| Exception | Extends | Throw when |
|-----------|---------|------------|
| `NotFoundException` | Nest | A requested record doesn't exist |
| `ConflictException` | Nest | A unique value already exists |
| `BadRequestException` | Nest | Input breaks a business rule |
| `ForbiddenException` | Nest | The user may not act on this record |
| `IllegalArgumentException` | `InternalServerErrorException` | Code passed an invalid argument (a bug, e.g. `findById(undefined)`) |
| `IllegalStateException` | `ConflictException` | The record is in a state that forbids the action |

```typescript
// src/shared/exceptions/illegal-argument.exception.ts
import { InternalServerErrorException } from '@nestjs/common';

export class IllegalArgumentException extends InternalServerErrorException {}

// src/shared/exceptions/illegal-state.exception.ts
import { ConflictException } from '@nestjs/common';

export class IllegalStateException extends ConflictException {}
```

### Unique Violations

Catch Postgres unique violations and rethrow them as `ConflictException`:

```typescript
// src/shared/enums/postgres-error-code.enum.ts
export enum PostgresErrorCode {
  UniqueViolation = '23505',
}

// service
public async createUser(user: User): Promise<User> {
  try {
    return await this.userRepository.save(user);
  } catch (error) {
    if ((error as { code?: string }).code === PostgresErrorCode.UniqueViolation) {
      throw new ConflictException(UsersServiceMessages.EmailExists);
    }
    throw error;
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
{
  provide: 'API_KEY',
  useFactory: (configService: ConfigService) => configService.getOrThrow<string>('API_KEY'),
  inject: [ConfigService],
}

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

## External HTTP Services

Outbound HTTP calls go through a shared `HttpService` wrapper around `@nestjs/axios`. The wrapper never passes the remote API's status or message to our client: a failed upstream call becomes **502** (`BadGatewayException`), and an unreachable or timed-out upstream becomes **503** (`ServiceUnavailableException`). The upstream details are logged. Each external API gets a config service (subclass of Nest's `ConfigService`, see `references/configuration.md`), an endpoints enum, and a base service that feature services extend.

```
src/modules/http/
├── http.module.ts
├── http.service.ts
├── http-request-config.interface.ts
└── socrates-http/
    ├── socrates-http-config.service.ts
    ├── socrates-http-endpoints.enum.ts
    ├── socrates-http.service.ts
    └── price-socrates-http.service.ts
```

```typescript
// http.service.ts
import { HttpService as NestHttpService } from '@nestjs/axios';
import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { AxiosError } from 'axios';
import { lastValueFrom, map } from 'rxjs';
import { HttpRequestConfig } from './http-request-config.interface';
import { HttpServiceMessages } from './http-service-messages.enum';
import { HttpServiceValues } from './http-service-values.const';
import { UpstreamException } from './upstream.exception';

@Injectable()
export class HttpService {
  private readonly logger = new Logger(HttpService.name);

  constructor(private readonly httpService: NestHttpService) {}

  public async get<T>(config: HttpRequestConfig): Promise<T> {
    return this.request<T>({ ...config, method: 'get' });
  }

  public async post<T>(config: HttpRequestConfig): Promise<T> {
    return this.request<T>({ ...config, method: 'post' });
  }

  public async put<T>(config: HttpRequestConfig): Promise<T> {
    return this.request<T>({ ...config, method: 'put' });
  }

  public async patch<T>(config: HttpRequestConfig): Promise<T> {
    return this.request<T>({ ...config, method: 'patch' });
  }

  private async request<T>(config: HttpRequestConfig): Promise<T> {
    return lastValueFrom(
      this.httpService
        .request<T>({ timeout: HttpServiceValues.TimeoutMs, ...config })
        .pipe(map((response) => response.data)),
    ).catch((error: AxiosError) => {
      this.logger.error(
        `${config.method?.toUpperCase()} ${config.url} failed: ${error.response?.status ?? error.code}`,
        JSON.stringify(error.response?.data),
      );
      if (!error.response) {
        throw new ServiceUnavailableException(HttpServiceMessages.Unavailable);
      }
      throw new UpstreamException(error.response.status);
    });
  }
}

// upstream.exception.ts
import { BadGatewayException } from '@nestjs/common';
import { HttpServiceMessages } from './http-service-messages.enum';

export class UpstreamException extends BadGatewayException {
  constructor(private readonly upstreamStatus: number) {
    super(HttpServiceMessages.UpstreamError);
  }

  public getUpstreamStatus(): number {
    return this.upstreamStatus;
  }
}

// http-service-messages.enum.ts
export enum HttpServiceMessages {
  UpstreamError = 'An upstream service returned an error',
  Unavailable = 'An upstream service is unavailable',
}

// http-service-values.const.ts
export const HttpServiceValues = {
  TimeoutMs: 10000,
};

// http-request-config.interface.ts
import { AxiosRequestConfig } from 'axios';

export interface HttpRequestConfig extends AxiosRequestConfig {}
```

```typescript
// socrates-http-config.service.ts
@Injectable()
export class SocratesHttpConfigService extends ConfigService {
  public getHttpRequestConfig<T>(
    path: SocratesHttpEndPoint,
    body?: T,
    headers?: Record<string, string>,
  ): HttpRequestConfig {
    return {
      url: `${this.getOrThrow<string>('SOCRATES_API_URL')}/${path}`,
      data: body,
      headers,
    };
  }
}

// socrates-http-endpoints.enum.ts
export enum SocratesHttpEndPoint {
  Ping = 'ping',
}

// socrates-http.service.ts
@Injectable()
export class SocratesHttpService {
  constructor(
    protected readonly httpService: HttpService,
    protected readonly socratesHttpConfigService: SocratesHttpConfigService,
  ) {}
}

// price-socrates-http.service.ts
@Injectable()
export class PriceSocratesHttpService extends SocratesHttpService {
  public async getPing(): Promise<string> {
    return this.httpService.get<string>(
      this.socratesHttpConfigService.getHttpRequestConfig(SocratesHttpEndPoint.Ping),
    );
  }
}
```

```typescript
// http.module.ts
@Module({
  imports: [NestHttpModule],
  providers: [HttpService, SocratesHttpConfigService, SocratesHttpService, PriceSocratesHttpService],
  exports: [HttpService, PriceSocratesHttpService],
})
export class HttpModule {}
```

When a feature needs to react to a specific upstream status, catch `UpstreamException` in the feature service and translate it into our own meaning:

```typescript
public async getMerchant(id: string): Promise<Merchant> {
  try {
    return await this.httpService.get<Merchant>(/* ... */);
  } catch (error) {
    if (error instanceof UpstreamException && error.getUpstreamStatus() === HttpStatus.NOT_FOUND) {
      throw new NotFoundException(MerchantsServiceMessages.NotFound);
    }
    throw error;
  }
}
```

## Email

Email is sent through `@nestjs-modules/mailer`. `MailerModule.forRoot` is configured in `AppModule` with an `ApiConfigService` subclass; a `MessagesService` owns every outgoing message.

```typescript
// mail-config.service.ts
export class MailConfigService extends ApiConfigService {
  public static create(): MailConfigService {
    return new MailConfigService().ensureValues([
      'EMAIL_HOST',
      'EMAIL_USERNAME',
      'EMAIL_PASSWORD',
      'EMAIL_ADDRESS',
    ]);
  }

  public getMailerOptions(): MailerOptions {
    return {
      transport: {
        host: this.getValue('EMAIL_HOST'),
        auth: {
          user: this.getValue('EMAIL_USERNAME'),
          pass: this.getValue('EMAIL_PASSWORD'),
        },
      },
      defaults: { from: this.getValue('EMAIL_ADDRESS') },
    };
  }
}

// app.module.ts
MailerModule.forRoot(MailConfigService.create().getMailerOptions())

// messages.service.ts
@Injectable()
export class MessagesService {
  constructor(private readonly mailerService: MailerService) {}

  public async sendInviteCode(user: User): Promise<void> {
    await this.mailerService.sendMail({
      to: user.getEmail(),
      subject: MessagesSubjects.InviteCode,
      text: `Your invite code is ${user.getInviteCode()}`,
    });
  }
}
```

## Health Checks

Health checks use `@nestjs/terminus`. The public liveness endpoint returns only an overall status; the detailed result is admin-only, so infrastructure details aren't exposed. Check only dependencies this API actually uses.

```typescript
// health.module.ts
@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
  providers: [HealthService],
})
export class HealthModule {}

// health.service.ts
@Injectable()
export class HealthService {
  constructor(
    private readonly health: HealthCheckService,
    private readonly database: TypeOrmHealthIndicator,
  ) {}

  public async getHealth(): Promise<HealthCheckResult> {
    return this.health.check([
      () => this.database.pingCheck(HealthCheck.Database),
    ]);
  }
}

// health-check.enum.ts
export enum HealthCheck {
  Database = 'database',
}
```

`health.check()` throws `ServiceUnavailableException` (503) when a check fails. Add an indicator (for example `HttpHealthIndicator` against an upstream the API depends on) only when that dependency is required for the API to work.

## Quick Reference

| Pattern | Use When |
|---------|----------|
| Constructor DI | Most cases (recommended) |
| Typed exception + messages enum | Every error a service raises |
| `HttpService` wrapper | Calling external APIs |
| `@Inject(token)` | Non-class tokens |
| `@Optional()` | Optional dependency |
| Factory provider | Dynamic configuration |
| Scope.REQUEST | Per-request state |
