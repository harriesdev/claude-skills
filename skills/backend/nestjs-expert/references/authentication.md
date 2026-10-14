# Authentication & Guards

Every endpoint is authenticated by default. `JwtAuthGuard` and `RolesGuard` are registered globally as `APP_GUARD`. Endpoints opt out with `@Public()` and restrict access with `@Roles()`.

| Caller | Decorators | Guards that apply |
|--------|-----------|-------------------|
| Anyone (login, register, health) | `@Public()` | None |
| Any authenticated user | none | `JwtAuthGuard` |
| Admin | `@Roles(UserRole.Admin)` | `JwtAuthGuard`, then `RolesGuard` |

A user can be signed in on several devices at once. Each login starts a **session**: a row in the `refresh_token` table that holds the hash of that device's current refresh token. Both tokens carry the session id (`sid`), so a session can be listed, revoked on its own, or kept while every other one is signed out.

Every client sends the access token as an `Authorization: Bearer` header. The web app keeps it in memory, never in storage, and gets a new one from refresh after a page reload. Its refresh token lives in an httpOnly cookie that only the authentication routes receive, so script on the page can never read it. Mobile and desktop clients get the refresh token in the response body and store it in the platform's secure storage.

## Constraints

### MUST DO
- Register `JwtAuthGuard` and `RolesGuard` as `APP_GUARD` in `AppModule`
- Mark every unauthenticated endpoint with `@Public()`
- Use `@Roles(UserRole.X)` with the `UserRole` enum for role checks
- Load the full user entity in `JwtAuthGuard` and attach it to `request.user`, and reject the request when its session is revoked or expired
- Get the authenticated user with `@CurrentUser()` and its session id with `@CurrentSessionId()`
- Hash passwords with bcrypt
- Exclude the password and the refresh token hash from every serialized entity (`@Exclude()`)
- Sign access and refresh tokens with different secrets and a `type` claim (`TokenType`); put the session id in both (`sid`) and a random `jti` in the refresh token
- Accept only access tokens in `JwtStrategy`; accept refresh tokens only in `POST /authentication/refresh`
- Create one `RefreshToken` row per login; store a SHA-256 hash of that session's current refresh token, replace it on every refresh, and revoke the session on logout or when a replaced token is presented
- Revoke every other session of the user on password change, and offer `POST /authentication/sessions/revoke-others`
- Read the access token only from the `Authorization: Bearer` header
- Set the refresh cookie only through `AuthCookieService`: `httpOnly`, `SameSite=Strict`, `Secure` from `AUTH_COOKIE_SECURE`, scoped to `/api/v1/authentication`
- Leave the refresh token out of the response body when it is delivered as a cookie
- Rate-limit login, register and refresh with `@Throttle`

### MUST NOT DO
- Add `@UseGuards(JwtAuthGuard)` to controllers — the global guard already runs, so it would run twice
- Put roles or permissions in the JWT — roles are read from the loaded user so changes apply immediately
- Store the refresh token hash on the user — that allows only one session per user
- Hash refresh tokens with bcrypt — bcrypt only uses the first 72 bytes, and JWTs for the same user share that prefix
- Revoke all of a user's sessions when one session's refresh token is reused — revoke that session only
- Put the access token in a cookie or read it from one — cookie auth on every route would need CSRF protection on every route
- Set cookies with `@Res()` without `passthrough: true`, or call `response.cookie()` outside `AuthCookieService`
- Use `SameSite=None` on the refresh cookie — `Strict` is what stops cross-site requests from carrying it
- Reveal whether an email is registered in login responses
- Return a user entity without a response DTO

## Files

```
src/
├── domain/
│   ├── authentication/
│   │   ├── authentication.entity.ts
│   │   ├── auth-transport.enum.ts
│   │   └── token-type.enum.ts
│   ├── refresh-token/
│   │   ├── refresh-token.entity.ts
│   │   └── refresh-token-values.const.ts
│   └── user/
│       └── user-role.enum.ts
├── dto/
│   └── authentication/
│       ├── access-token.dto.ts
│       ├── refresh-token.dto.ts
│       ├── session.dto.ts
│       └── session-page.dto.ts
├── modules/
│   ├── authentication/
│   │   ├── authentication.controller.ts
│   │   ├── authentication.module.ts
│   │   ├── authentication.service.ts
│   │   ├── cookies/
│   │   │   ├── auth-cookie.enum.ts
│   │   │   └── auth-cookie.service.ts
│   │   └── strategies/
│   │       └── jwt.strategy.ts
│   └── database/
│       ├── migrations/
│       │   └── 1761848303791-create-refresh-token-table.ts
│       └── repositories/
│           └── refresh-token/
│               ├── refresh-token-relation.type.ts
│               └── refresh-token.repository.ts
└── shared/
    ├── decorators/
    │   ├── auth-transport.decorator.ts
    │   ├── cookies.decorator.ts
    │   ├── current-session-id.decorator.ts
    │   ├── current-user.decorator.ts
    │   ├── public.decorator.ts
    │   └── roles.decorator.ts
    ├── guards/
    │   ├── jwt-auth.guard.ts
    │   └── roles.guard.ts
    └── interfaces/
        ├── authenticated-request.interface.ts
        └── jwt-payload.interface.ts
```

## JWT Strategy

```typescript
// jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { TokenType } from '../../../domain/authentication/token-type.enum';
import { AuthenticationMessages } from '../../../shared/guards/authentication-messages.enum';
import { JwtPayload } from '../../../shared/interfaces/jwt-payload.interface';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<JwtPayload> {
    if (payload.type !== TokenType.Access || !payload.sid) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidToken);
    }
    return payload;
  }
}

// jwt-payload.interface.ts
export interface JwtPayload {
  sub: number;
  sid: number;
  email: string;
  type: TokenType;
  jti?: string;
  iat?: number;
  exp?: number;
}

// token-type.enum.ts
export enum TokenType {
  Access = 'access',
  Refresh = 'refresh',
}
```

The strategy never reads cookies. The only cookie the API uses is the refresh cookie, read by `POST /authentication/refresh`. `cookieParser()` must be registered in `main.ts` (see `references/controllers-routing.md`) or `request.cookies` is undefined there.

## JWT Auth Guard

Validates the token, checks that its session is still active, then loads the user so `RolesGuard`, `@CurrentUser()` and the audit interceptor all work with the real entity. Checking the session on every request means a revoked session stops working at once, not when its access token expires.

```typescript
// jwt-auth.guard.ts
import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { RefreshTokenRepository } from '../../modules/database/repositories/refresh-token/refresh-token.repository';
import { UsersService } from '../../modules/users/users.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { AuthenticatedRequest } from '../interfaces/authenticated-request.interface';
import { JwtPayload } from '../interfaces/jwt-payload.interface';
import { AuthenticationMessages } from './authentication-messages.enum';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(
    private readonly reflector: Reflector,
    private readonly usersService: UsersService,
    private readonly refreshTokenRepository: RefreshTokenRepository,
  ) {
    super();
  }

  public async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      return true;
    }

    await super.canActivate(context);

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const payload = request.user as unknown as JwtPayload;

    const session = await this.refreshTokenRepository.findActiveById(payload.sid, payload.sub);
    if (!session) {
      throw new UnauthorizedException(AuthenticationMessages.SessionEnded);
    }

    const user = await this.usersService
      .getSanitizedUserById(payload.sub)
      .catch(() => null);
    if (!user) {
      throw new UnauthorizedException(AuthenticationMessages.UserNotFound);
    }

    request.user = user;
    request.sessionId = session.getId();
    return true;
  }

  public handleRequest<TUser = JwtPayload>(
    error: Error | null,
    payload: TUser | false,
  ): TUser {
    if (error || !payload) {
      throw error || new UnauthorizedException(AuthenticationMessages.InvalidToken);
    }
    return payload;
  }
}

// authenticated-request.interface.ts
import { Request } from 'express';
import { User } from '../../domain/user/user.entity';

export interface AuthenticatedRequest extends Request {
  user: User;
  sessionId: number;
}

// authentication-messages.enum.ts
export enum AuthenticationMessages {
  InvalidToken = 'Invalid token or no token provided',
  InvalidRefreshToken = 'Invalid or expired refresh token',
  SessionEnded = 'Session has ended',
  SessionNotFound = 'Session not found',
  UserNotFound = 'User not found',
  EmailExists = 'Email already exists',
  InvalidCredentials = 'Email or password is incorrect',
  OldPasswordIncorrect = 'Old password is incorrect',
}
```

## Public Decorator

```typescript
// public.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
```

## Roles Guard

```typescript
// roles.decorator.ts
import { SetMetadata } from '@nestjs/common';
import { UserRole } from '../../domain/user/user-role.enum';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);

// roles.guard.ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '../../domain/user/user-role.enum';
import { User } from '../../domain/user/user.entity';
import { ROLES_KEY } from '../decorators/roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles) {
      return true;
    }
    const user = context.switchToHttp().getRequest().user as User;
    return Boolean(user) && user.hasRole(requiredRoles);
  }
}

// user-role.enum.ts
export enum UserRole {
  Admin = 'Admin',
  User = 'User',
}
```

## Request Decorators

```typescript
// current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { User } from '../../domain/user/user.entity';
import { AuthenticatedRequest } from '../interfaces/authenticated-request.interface';

export const CurrentUser = createParamDecorator(
  (data: unknown, context: ExecutionContext): User => {
    return context.switchToHttp().getRequest<AuthenticatedRequest>().user;
  },
);

// current-session-id.decorator.ts
export const CurrentSessionId = createParamDecorator(
  (data: unknown, context: ExecutionContext): number => {
    return context.switchToHttp().getRequest<AuthenticatedRequest>().sessionId;
  },
);

// cookies.decorator.ts
import { Request } from 'express';
import { AuthCookie } from '../../modules/authentication/cookies/auth-cookie.enum';

export const Cookies = createParamDecorator(
  (name: AuthCookie, context: ExecutionContext): string | undefined => {
    return context.switchToHttp().getRequest<Request>().cookies?.[name];
  },
);

// auth-transport.decorator.ts
import { AuthTransport } from '../../domain/authentication/auth-transport.enum';
import { RequestHeader } from '../enums/request-header.enum';

export const AuthTransportHeader = createParamDecorator(
  (data: unknown, context: ExecutionContext): AuthTransport => {
    const value = context.switchToHttp().getRequest<Request>().header(RequestHeader.AuthTransport);
    return value === AuthTransport.Cookie ? AuthTransport.Cookie : AuthTransport.Bearer;
  },
);

// auth-transport.enum.ts
export enum AuthTransport {
  Bearer = 'bearer',
  Cookie = 'cookie',
}

// request-header.enum.ts
export enum RequestHeader {
  RequestId = 'x-request-id',
  AuthTransport = 'x-auth-transport',
  UserAgent = 'user-agent',
}
```

Add `RequestHeader.AuthTransport` to `allowedHeaders` in `CorsConfigService` so the web app can send it.

## Sessions

### RefreshToken Entity

```typescript
// src/domain/refresh-token/refresh-token.entity.ts
import { Exclude } from 'class-transformer';
import { Column, Entity, JoinColumn, ManyToOne } from 'typeorm';
import { DatabaseTable } from '../database-table.enum';
import { DomainObject } from '../domain-object';
import { User } from '../user/user.entity';
import { RefreshTokenValues } from './refresh-token-values.const';

@Entity(DatabaseTable.RefreshToken)
export class RefreshToken extends DomainObject {
  @ManyToOne(() => User, { eager: true, nullable: false, onDelete: 'CASCADE' })
  @JoinColumn()
  user: User;

  @Column()
  userId: number;

  @Column({ type: 'varchar', length: 64, nullable: true })
  @Exclude()
  private tokenHash: string | null;

  @Column({ type: 'varchar', length: RefreshTokenValues.UserAgentMaxLength, nullable: true })
  private userAgent: string | null;

  @Column({ type: 'timestamptz' })
  expiresDate: Date;

  @Column({ type: 'timestamptz', nullable: true })
  private lastUsedDate: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  revokedDate: Date | null;

  private current = false;

  public static create(user: User, userAgent: string | undefined, expiresDate: Date): RefreshToken {
    return new RefreshToken()
      .setUser(user)
      .setUserAgent(userAgent)
      .setExpiresDate(expiresDate);
  }

  public getUser(): User {
    return this.user;
  }

  public setUser(user: User): this {
    this.user = user;
    this.userId = user.getId();
    return this;
  }

  public getTokenHash(): string | null {
    return this.tokenHash;
  }

  public getUserAgent(): string | null {
    return this.userAgent;
  }

  public setUserAgent(userAgent: string | undefined): this {
    this.userAgent = userAgent ? userAgent.slice(0, RefreshTokenValues.UserAgentMaxLength) : null;
    return this;
  }

  public getExpiresDate(): Date {
    return this.expiresDate;
  }

  public setExpiresDate(expiresDate: Date): this {
    this.expiresDate = expiresDate;
    return this;
  }

  public getLastUsedDate(): Date | null {
    return this.lastUsedDate;
  }

  public isCurrent(): boolean {
    return this.current;
  }

  public markCurrent(sessionId: number): this {
    this.current = this.getId() === sessionId;
    return this;
  }

  public isActive(now: Date = new Date()): boolean {
    return this.revokedDate === null && this.expiresDate > now;
  }

  public rotate(tokenHash: string, expiresDate: Date): this {
    this.tokenHash = tokenHash;
    this.expiresDate = expiresDate;
    this.lastUsedDate = new Date();
    return this;
  }

  public revoke(): this {
    this.revokedDate = new Date();
    return this;
  }
}

// refresh-token-values.const.ts
export const RefreshTokenValues = {
  UserAgentMaxLength: 255,
};

// database-table.enum.ts
RefreshToken = 'refresh_token',
```

`userId`, `expiresDate` and `revokedDate` have no access modifier so repository `where` clauses can use them. The service builds sessions from a login, never from a form, so `RefreshToken` has no domain factory. `current` is not a column: the service sets it when listing sessions so the client can tell which one it is.

### Migration

```typescript
// 1761848303791-create-refresh-token-table.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateRefreshTokenTable1761848303791 implements MigrationInterface {
  name = 'CreateRefreshTokenTable1761848303791';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "refresh_token" (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        token_hash VARCHAR(64) NULL,
        user_agent VARCHAR(255) NULL,
        expires_date TIMESTAMP WITH TIME ZONE NOT NULL,
        last_used_date TIMESTAMP WITH TIME ZONE NULL,
        revoked_date TIMESTAMP WITH TIME ZONE NULL,
        created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER NULL,
        updated_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_by INTEGER NULL,
        deleted_date TIMESTAMP WITH TIME ZONE NULL,
        deleted_by INTEGER NULL,
        FOREIGN KEY (user_id) REFERENCES "user" (id) ON DELETE CASCADE
      );
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS refresh_token_user_id_idx ON "refresh_token" (user_id);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP TABLE IF EXISTS "refresh_token";
    `);
  }
}
```

`token_hash` is nullable because the row is saved first to get the id that goes into the token's `sid` claim, then the hash of that token is stored. A row without a hash can't be refreshed. Delete expired and revoked rows with a scheduled job; nothing reads them.

### Repository

```typescript
// refresh-token-relation.type.ts
export type RefreshTokenRelation = 'user';

// refresh-token.repository.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, MoreThan, Not, Repository } from 'typeorm';
import { RefreshToken } from '../../../../domain/refresh-token/refresh-token.entity';
import { User } from '../../../../domain/user/user.entity';
import { PaginationQueryDto } from '../../../../dto/common/pagination-query.dto';
import { Page } from '../../../../shared/types/page';
import { RepositorySupport } from '../repository.support';

@Injectable()
export class RefreshTokenRepository extends RepositorySupport<RefreshToken> {
  constructor(
    @InjectRepository(RefreshToken)
    repository: Repository<RefreshToken>,
  ) {
    super(RefreshToken, repository.manager.connection);
  }

  public findActiveById(id: number, userId: number): Promise<RefreshToken | null> {
    return this.findOne({
      where: { id, userId, revokedDate: IsNull(), expiresDate: MoreThan(new Date()) },
    });
  }

  public findActivePageByUser(
    user: User,
    paginationQueryDto: PaginationQueryDto,
  ): Promise<Page<RefreshToken>> {
    return this.findPage(paginationQueryDto, {
      where: { userId: user.getId(), revokedDate: IsNull(), expiresDate: MoreThan(new Date()) },
      order: { createdDate: 'DESC', id: 'DESC' },
    });
  }

  public async revokeAllForUser(userId: number, exceptSessionId?: number): Promise<void> {
    await this.update(
      {
        userId,
        revokedDate: IsNull(),
        ...(exceptSessionId ? { id: Not(exceptSessionId) } : {}),
      },
      { revokedDate: new Date() },
    );
  }
}
```

Add `RefreshTokenRepository` to `RepositoryServices` and `RefreshToken` to `Entities`.

## Authentication Domain Object

Login, register and refresh return an `Authentication` domain object; `AccessTokenDto` maps it to the response. When the refresh token is delivered as a cookie, `AuthCookieService` returns a copy without it, so the body's `refreshToken` is `null`. The access token is always in the body.

```typescript
// authentication.entity.ts
export class Authentication {
  private accessToken: string;
  private refreshToken: string | null;

  public static create(accessToken: string, refreshToken: string): Authentication {
    return new Authentication()
      .setAccessToken(accessToken)
      .setRefreshToken(refreshToken);
  }

  public getAccessToken(): string {
    return this.accessToken;
  }

  public setAccessToken(accessToken: string): Authentication {
    this.accessToken = accessToken;
    return this;
  }

  public getRefreshToken(): string | null {
    return this.refreshToken;
  }

  public setRefreshToken(refreshToken: string | null): Authentication {
    this.refreshToken = refreshToken;
    return this;
  }

  public withoutRefreshToken(): Authentication {
    return new Authentication().setAccessToken(this.accessToken).setRefreshToken(null);
  }
}

// access-token.dto.ts
@DtoType('AccessToken')
export class AccessTokenDto extends DtoResponseInterceptor {
  @DtoProperty((authentication: Authentication) => authentication.getAccessToken(), 'Access token')
  readonly accessToken: string;

  @DtoProperty((authentication: Authentication) => authentication.getRefreshToken(), 'Refresh token, or null when sent as a cookie')
  readonly refreshToken: string | null;

  public create(): DtoResponseInterceptor {
    return new AccessTokenDto();
  }
}

// session.dto.ts
@DtoType('Session')
export class SessionDto extends DtoResponseInterceptor {
  @DtoProperty((session: RefreshToken) => session.getId(), SessionDtoMessages.Id)
  readonly id: number;

  @DtoProperty((session: RefreshToken) => session.getUserAgent(), SessionDtoMessages.UserAgent)
  readonly userAgent: string | null;

  @DtoProperty((session: RefreshToken) => session.getCreatedDate(), SessionDtoMessages.CreatedDate)
  readonly createdDate: Date;

  @DtoProperty((session: RefreshToken) => session.getLastUsedDate(), SessionDtoMessages.LastUsedDate)
  readonly lastUsedDate: Date | null;

  @DtoProperty((session: RefreshToken) => session.isCurrent(), SessionDtoMessages.Current)
  readonly current: boolean;

  public create(): DtoResponseInterceptor {
    return new SessionDto();
  }
}

// session-page.dto.ts
@DtoType('SessionPage')
export class SessionPageDto extends DtoResponseInterceptor {
  @DtoArray(SessionDto, (page: Page<RefreshToken>) => page.getItems(), SessionDtoMessages.Sessions)
  readonly data: SessionDto[];

  @DtoProperty(PageMetaDto, (page: Page<RefreshToken>) => page, SessionDtoMessages.PageMeta)
  readonly meta: PageMetaDto;

  public create(): DtoResponseInterceptor {
    return new SessionPageDto();
  }
}
```

## Auth Service

```typescript
import { createHash, randomBytes, timingSafeEqual } from 'crypto';

@Injectable()
export class AuthenticationService {
  constructor(
    private readonly usersService: UsersService,
    private readonly refreshTokenRepository: RefreshTokenRepository,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  public async register(registerDto: RegisterDto, userAgent?: string): Promise<Authentication> {
    if (await this.usersService.findUserByEmail(registerDto.email)) {
      throw new ConflictException(AuthenticationMessages.EmailExists);
    }
    const user = User.create(
      registerDto.email,
      await this.hashPassword(registerDto.password),
      registerDto.name,
    );
    return this.startSession(await this.usersService.saveUser(user), userAgent);
  }

  public async login(loginDto: LoginDto, userAgent?: string): Promise<Authentication> {
    const user = await this.validateUser(loginDto.email, loginDto.password);
    return this.startSession(user, userAgent);
  }

  public async refresh(refreshToken: string | undefined): Promise<Authentication> {
    if (!refreshToken) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidRefreshToken);
    }
    const payload = await this.verifyRefreshToken(refreshToken);
    const session = await this.refreshTokenRepository.findActiveById(payload.sid, payload.sub);
    if (!session) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidRefreshToken);
    }
    if (!this.matchesTokenHash(session, refreshToken)) {
      await this.refreshTokenRepository.save(session.revoke());
      throw new UnauthorizedException(AuthenticationMessages.InvalidRefreshToken);
    }
    return this.issueTokens(session.getUser(), session);
  }

  public async logout(sessionId: number, user: User): Promise<void> {
    const session = await this.refreshTokenRepository.findActiveById(sessionId, user.getId());
    if (session) {
      await this.refreshTokenRepository.save(session.revoke());
    }
  }

  public async getSessions(
    user: User,
    sessionId: number,
    paginationQueryDto: PaginationQueryDto,
  ): Promise<Page<RefreshToken>> {
    const page = await this.refreshTokenRepository.findActivePageByUser(user, paginationQueryDto);
    page.getItems().forEach((session) => session.markCurrent(sessionId));
    return page;
  }

  public async revokeSession(id: number, user: User): Promise<void> {
    const session = await this.refreshTokenRepository.findActiveById(id, user.getId());
    if (!session) {
      throw new NotFoundException(AuthenticationMessages.SessionNotFound);
    }
    await this.refreshTokenRepository.save(session.revoke());
  }

  public async revokeOtherSessions(sessionId: number, user: User): Promise<void> {
    await this.refreshTokenRepository.revokeAllForUser(user.getId(), sessionId);
  }

  public async changePassword(
    changePasswordDto: ChangePasswordDto,
    currentUser: User,
    sessionId: number,
  ): Promise<void> {
    const user = await this.usersService.getUserById(currentUser.getId());
    if (!(await bcrypt.compare(changePasswordDto.oldPassword, user.getPassword()))) {
      throw new BadRequestException(AuthenticationMessages.OldPasswordIncorrect);
    }
    await this.usersService.saveUser(
      user.setPassword(await this.hashPassword(changePasswordDto.newPassword)),
    );
    await this.revokeOtherSessions(sessionId, user);
  }

  private async validateUser(email: string, password: string): Promise<User> {
    const user = await this.usersService.findUserByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.getPassword()))) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidCredentials);
    }
    return user;
  }

  private async startSession(user: User, userAgent?: string): Promise<Authentication> {
    const session = await this.refreshTokenRepository.save(
      RefreshToken.create(user, userAgent, this.getRefreshExpiresDate()),
    );
    return this.issueTokens(user, session);
  }

  private async issueTokens(user: User, session: RefreshToken): Promise<Authentication> {
    const claims = { sub: user.getId(), sid: session.getId(), email: user.getEmail() };
    const accessToken = await this.jwtService.signAsync({
      ...claims,
      type: TokenType.Access,
    } satisfies JwtPayload);
    const refreshToken = await this.jwtService.signAsync(
      {
        ...claims,
        type: TokenType.Refresh,
        jti: randomBytes(AuthenticationValues.TokenIdBytes).toString('hex'),
      } satisfies JwtPayload,
      {
        secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
        expiresIn: this.getRefreshLifetimeSeconds(),
      },
    );

    await this.refreshTokenRepository.save(
      session.rotate(this.hashToken(refreshToken), this.getRefreshExpiresDate()),
    );
    return Authentication.create(accessToken, refreshToken);
  }

  private async verifyRefreshToken(refreshToken: string): Promise<JwtPayload> {
    const payload = await this.jwtService
      .verifyAsync<JwtPayload>(refreshToken, {
        secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
      })
      .catch(() => null);

    if (!payload || payload.type !== TokenType.Refresh || !payload.sid) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidRefreshToken);
    }
    return payload;
  }

  private matchesTokenHash(session: RefreshToken, refreshToken: string): boolean {
    const storedHash = session.getTokenHash();
    if (!storedHash) {
      return false;
    }
    const presented = Buffer.from(this.hashToken(refreshToken), 'hex');
    const stored = Buffer.from(storedHash, 'hex');
    return presented.length === stored.length && timingSafeEqual(presented, stored);
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private getRefreshLifetimeSeconds(): number {
    return parseInt(this.configService.getOrThrow<string>('JWT_REFRESH_EXPIRATION_TIME'));
  }

  private getRefreshExpiresDate(): Date {
    return new Date(Date.now() + this.getRefreshLifetimeSeconds() * 1000);
  }

  private async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, AuthenticationValues.SaltRounds);
  }
}

// authentication-values.const.ts
export const AuthenticationValues = {
  SaltRounds: 10,
  TokenIdBytes: 16,
};
```

| Token | Secret | Lifetime | Claims | Accepted by |
|-------|--------|----------|--------|-------------|
| Access (`type: access`) | `JWT_SECRET` | `JWT_EXPIRATION_TIME` in seconds (short, e.g. 900) | `sub`, `sid`, `email` | `JwtStrategy` on every protected endpoint |
| Refresh (`type: refresh`) | `JWT_REFRESH_SECRET` | `JWT_REFRESH_EXPIRATION_TIME` in seconds (e.g. 604800) | `sub`, `sid`, `email`, `jti` | `POST /authentication/refresh` only |

Each refresh issues a new pair and replaces that session's stored hash, so a refresh token works once. The random `jti` keeps two tokens issued in the same second from being identical. Presenting a replaced refresh token revokes its session: a stolen token that is replayed after the real client refreshed ends that session, and the user's other devices stay signed in. Each refresh also moves the session's expiry forward, so a device that keeps being used stays signed in.

Two refreshes of the same session at once (for example two browser tabs) look like reuse, and the second ends the session. Web clients must send one refresh at a time and share the result across tabs.

Login failures return the same message for an unknown email and a wrong password, so the API doesn't reveal which emails are registered.

## Refresh Cookie

The web app sends `x-auth-transport: cookie` on register and login. The refresh token is then set as an httpOnly cookie and left out of the response body, so script on the page can never read it. The access token is returned in the body either way. Other clients send nothing and get both tokens in the body.

```typescript
// auth-cookie.enum.ts
export enum AuthCookie {
  RefreshToken = 'refresh_token',
}

export enum AuthCookiePath {
  Authentication = '/api/v1/authentication',
}

// auth-cookie.service.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CookieOptions, Response } from 'express';
import { AuthTransport } from '../../../domain/authentication/auth-transport.enum';
import { Authentication } from '../../../domain/authentication/authentication.entity';
import { AuthCookie, AuthCookiePath } from './auth-cookie.enum';

@Injectable()
export class AuthCookieService {
  constructor(private readonly configService: ConfigService) {}

  public deliver(
    authentication: Authentication,
    transport: AuthTransport,
    response: Response,
  ): Authentication {
    if (transport === AuthTransport.Bearer) {
      return authentication;
    }
    response.cookie(AuthCookie.RefreshToken, authentication.getRefreshToken(), {
      ...this.getBaseOptions(),
      maxAge: parseInt(this.configService.getOrThrow<string>('JWT_REFRESH_EXPIRATION_TIME')) * 1000,
    });
    return authentication.withoutRefreshToken();
  }

  public clear(response: Response): void {
    response.clearCookie(AuthCookie.RefreshToken, this.getBaseOptions());
  }

  private getBaseOptions(): CookieOptions {
    return {
      httpOnly: true,
      secure: this.configService.getOrThrow<string>('AUTH_COOKIE_SECURE') === 'true',
      sameSite: 'strict',
      path: AuthCookiePath.Authentication,
    };
  }
}
```

The cookie's path limits it to `/api/v1/authentication/*`, so no other route ever receives it, and no other route accepts cookie authentication. `SameSite=Strict` stops other sites from sending it, and the CORS allow-list stops them from reading the response. A forged refresh request could only rotate the user's own tokens, so the API needs no CSRF token. Strict counts every subdomain of the same registrable domain as the same site, so host the web app and API under a domain you control fully. Set `AUTH_COOKIE_SECURE=true` everywhere except local HTTP development.

The web app's flow:

| Moment | Request | Result |
|--------|---------|--------|
| Login | `POST /authentication/login` with `x-auth-transport: cookie` and `credentials: 'include'` | Access token in the body, refresh cookie set |
| Every API call | `Authorization: Bearer <access token from memory>` | Normal request |
| Page load, or a `401` from an expired access token | `POST /authentication/refresh` with an empty body and `credentials: 'include'` | New access token in the body, refresh cookie replaced |
| Logout | `POST /authentication/logout` with the Bearer header and `credentials: 'include'` | Session revoked, refresh cookie cleared |

Refresh decides the delivery from where the token came from: a token in the body gets the new refresh token in the body, and a token from the cookie gets a new cookie. Logout always clears the cookie.

## Auth Controller

```typescript
@Controller('authentication')
@ApiTags(SwaggerTags.Authentication)
export class AuthenticationController {
  constructor(
    private readonly authenticationService: AuthenticationService,
    private readonly authCookieService: AuthCookieService,
  ) {}

  @Public()
  @Throttle({ default: ThrottleValues.Authentication })
  @Post('/register')
  @Version('1')
  @ApiOperation({ summary: 'Register a user' })
  @ApiHeader({ name: RequestHeader.AuthTransport, required: false, enum: AuthTransport })
  @DtoRequest(RegisterDto)
  @DtoResponse(HttpStatus.CREATED, 'User registered and logged in', AccessTokenDto)
  @DtoResponseError(HttpStatus.CONFLICT, 'Email already exists')
  @DtoResponseError(HttpStatus.TOO_MANY_REQUESTS, 'Too many attempts')
  public async register(
    @Body() registerDto: RegisterDto,
    @Headers(RequestHeader.UserAgent) userAgent: string | undefined,
    @AuthTransportHeader() transport: AuthTransport,
    @Res({ passthrough: true }) response: Response,
  ): Promise<Authentication> {
    const authentication = await this.authenticationService.register(registerDto, userAgent);
    return this.authCookieService.deliver(authentication, transport, response);
  }

  @Public()
  @Throttle({ default: ThrottleValues.Authentication })
  @Post('/login')
  @Version('1')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'User authentication login' })
  @ApiHeader({ name: RequestHeader.AuthTransport, required: false, enum: AuthTransport })
  @DtoRequest(LoginDto)
  @DtoResponse(HttpStatus.OK, 'User logged in', AccessTokenDto)
  @DtoResponseError(HttpStatus.UNAUTHORIZED, 'Email or password is incorrect')
  @DtoResponseError(HttpStatus.TOO_MANY_REQUESTS, 'Too many attempts')
  public async login(
    @Body() loginDto: LoginDto,
    @Headers(RequestHeader.UserAgent) userAgent: string | undefined,
    @AuthTransportHeader() transport: AuthTransport,
    @Res({ passthrough: true }) response: Response,
  ): Promise<Authentication> {
    const authentication = await this.authenticationService.login(loginDto, userAgent);
    return this.authCookieService.deliver(authentication, transport, response);
  }

  @Public()
  @Throttle({ default: ThrottleValues.Authentication })
  @Post('/refresh')
  @Version('1')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Exchange a refresh token from the body or cookie for a new token pair' })
  @DtoRequest(RefreshTokenDto)
  @DtoResponse(HttpStatus.OK, 'Tokens refreshed', AccessTokenDto)
  @DtoResponseError(HttpStatus.UNAUTHORIZED, 'Invalid or expired refresh token')
  public async refresh(
    @Body() refreshTokenDto: RefreshTokenDto,
    @Cookies(AuthCookie.RefreshToken) cookieRefreshToken: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ): Promise<Authentication> {
    const transport = refreshTokenDto.refreshToken ? AuthTransport.Bearer : AuthTransport.Cookie;
    const authentication = await this.authenticationService.refresh(
      refreshTokenDto.refreshToken ?? cookieRefreshToken,
    );
    return this.authCookieService.deliver(authentication, transport, response);
  }

  @Post('/logout')
  @Version('1')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'End the current session' })
  @DtoResponse(HttpStatus.NO_CONTENT, 'Logged out')
  public async logout(
    @CurrentUser() user: User,
    @CurrentSessionId() sessionId: number,
    @Res({ passthrough: true }) response: Response,
  ): Promise<void> {
    await this.authenticationService.logout(sessionId, user);
    this.authCookieService.clear(response);
  }

  @Get('/sessions')
  @Version('1')
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'List my active sessions' })
  @DtoResponse(HttpStatus.OK, 'Returns a page of active sessions', SessionPageDto)
  public async getSessions(
    @Query() paginationQueryDto: PaginationQueryDto,
    @CurrentUser() user: User,
    @CurrentSessionId() sessionId: number,
  ): Promise<Page<RefreshToken>> {
    return this.authenticationService.getSessions(user, sessionId, paginationQueryDto);
  }

  @Delete('/sessions/:sessionId')
  @Version('1')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'End one of my sessions' })
  @DtoResponse(HttpStatus.NO_CONTENT, 'Session ended')
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Session not found')
  public async revokeSession(
    @Param('sessionId', ParseIntPipe) sessionId: number,
    @CurrentUser() user: User,
  ): Promise<void> {
    return this.authenticationService.revokeSession(sessionId, user);
  }

  @Post('/sessions/revoke-others')
  @Version('1')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'Sign out of all other sessions' })
  @DtoResponse(HttpStatus.NO_CONTENT, 'Other sessions ended')
  public async revokeOtherSessions(
    @CurrentUser() user: User,
    @CurrentSessionId() sessionId: number,
  ): Promise<void> {
    return this.authenticationService.revokeOtherSessions(sessionId, user);
  }

  @Post('/change-password')
  @Version('1')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'Change password and end all other sessions' })
  @DtoRequest(ChangePasswordDto)
  @DtoResponse(HttpStatus.NO_CONTENT, 'Password changed')
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Old password is incorrect')
  public async changePassword(
    @Body() changePasswordDto: ChangePasswordDto,
    @CurrentUser() user: User,
    @CurrentSessionId() sessionId: number,
  ): Promise<void> {
    return this.authenticationService.changePassword(changePasswordDto, user, sessionId);
  }
}

// refresh-token.dto.ts
export class RefreshTokenDto {
  @ApiPropertyOptional({ description: RefreshTokenDtoMessages.RefreshToken })
  @IsOptional()
  @IsJWT()
  refreshToken?: string;
}
```

Login and refresh are `POST` because they send credentials in the body, but they don't create a resource, so they return `200` via `@HttpCode`. Register creates a user and returns `201`. A session that belongs to another user returns 404 from `DELETE /sessions/:sessionId`, the same as a missing one, because `findActiveById` filters by the user.

## Auth Module Setup

```typescript
@Module({
  imports: [
    UsersModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.getOrThrow<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: parseInt(configService.getOrThrow<string>('JWT_EXPIRATION_TIME')),
        },
      }),
    }),
  ],
  controllers: [AuthenticationController],
  providers: [AuthenticationService, AuthCookieService, JwtStrategy],
  exports: [AuthenticationService, JwtModule],
})
export class AuthenticationModule {}
```

| Variable | Example | Purpose |
|----------|---------|---------|
| `JWT_SECRET` | 64 random bytes | Signs access tokens |
| `JWT_EXPIRATION_TIME` | `900` | Access token lifetime in seconds |
| `JWT_REFRESH_SECRET` | 64 random bytes, different from `JWT_SECRET` | Signs refresh tokens |
| `JWT_REFRESH_EXPIRATION_TIME` | `604800` | Refresh token, session and cookie lifetime in seconds |
| `AUTH_COOKIE_SECURE` | `true` | Adds `Secure` to the refresh cookie; `false` only for local HTTP |

## Rate Limiting

`@nestjs/throttler` limits every endpoint by client IP, with a stricter limit on the authentication endpoints. Exceeding a limit returns **429** `TOO_MANY_REQUESTS`.

```typescript
// src/shared/const/throttle-values.const.ts
export const ThrottleValues = {
  Default: { ttl: 60000, limit: 100 },
  Authentication: { ttl: 60000, limit: 5 },
};

// app.module.ts
ThrottlerModule.forRoot([{ name: 'default', ...ThrottleValues.Default }])
```

Behind a load balancer or reverse proxy, every request arrives from the proxy's IP. Set Express's `trust proxy` (`app.set('trust proxy', 1)` on a `NestExpressApplication`) so limits apply per real client. With several API instances, use a shared store such as `@nest-lab/throttler-storage-redis`, or each instance counts separately.

## Apply Guards Globally

```typescript
// app.module.ts
@Module({
  imports: [
    ThrottlerModule.forRoot([{ name: 'default', ...ThrottleValues.Default }]),
    UsersModule,
    AuthenticationModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_INTERCEPTOR, useClass: AuditUserInterceptor },
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
  ],
})
export class AppModule {}
```

Guards run in registration order: `ThrottlerGuard` rejects floods before any database work, then `JwtAuthGuard` attaches the user before `RolesGuard` checks roles. `UsersModule` must export `UsersService` because `JwtAuthGuard` injects it; `RefreshTokenRepository` comes from the global `DatabaseModule`.

## Sanitizing the User Entity

The password is excluded from every serialized user. Admin-only fields are exposed only in the `Admin` group.

```typescript
@Entity(DatabaseTable.User)
export class User extends DomainObject {
  @Column()
  @Expose()
  public email: string;

  @Column({ nullable: true })
  @Exclude()
  private password: string;

  @Column({ type: 'enum', enum: UserRole, array: true })
  @Expose({ groups: [UserRole.Admin] })
  roles: UserRole[];

  public static create(email: string, password: string, name: string, roles: UserRole[] = [UserRole.User]): User {
    return new User().setEmail(email).setPassword(password).setName(name).setRoles(roles);
  }

  public hasRole(roles: UserRole[]): boolean {
    return roles.some((role) => this.roles.includes(role));
  }
}

// users.service.ts
public async getSanitizedUserById(id: number): Promise<User> {
  return this.sanitizeUser(await this.getUserById(id));
}

private sanitizeUser(user: User): User {
  return plainToInstance(User, user, {
    excludeExtraneousValues: true,
    enableImplicitConversion: true,
  });
}
```

## Quick Reference

| Component | Purpose |
|-----------|---------|
| `JwtStrategy` | Validate access tokens from the Bearer header |
| `JwtAuthGuard` | Global: authenticate, check the session is active, load the user |
| `RolesGuard` | Global: role-based access |
| `@Public()` | Skip authentication |
| `@Roles(UserRole.Admin)` | Require role |
| `@CurrentUser()` | Authenticated user entity |
| `@CurrentSessionId()` | Id of the session the request belongs to |
| `RefreshToken` | One session per login: current refresh token hash, expiry, revocation |
| `Authentication` | Login/register/refresh result mapped by `AccessTokenDto` |
| `AuthCookieService` | Sets and clears the refresh cookie when `x-auth-transport: cookie` |
| `TokenType` | `access` / `refresh` claim that keeps the two tokens apart |
| `@Throttle({ default: ThrottleValues.Authentication })` | Stricter rate limit on auth endpoints |
