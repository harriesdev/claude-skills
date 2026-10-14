# Authentication & Guards

Every endpoint is authenticated by default. `JwtAuthGuard` and `RolesGuard` are registered globally as `APP_GUARD`. Endpoints opt out with `@Public()` and restrict access with `@Roles()`.

| Caller | Decorators | Guards that apply |
|--------|-----------|-------------------|
| Anyone (login, register, health) | `@Public()` | None |
| Any authenticated user | none | `JwtAuthGuard` |
| Admin | `@Roles(UserRole.Admin)` | `JwtAuthGuard`, then `RolesGuard` |

## Constraints

### MUST DO
- Register `JwtAuthGuard` and `RolesGuard` as `APP_GUARD` in `AppModule`
- Mark every unauthenticated endpoint with `@Public()`
- Use `@Roles(UserRole.X)` with the `UserRole` enum for role checks
- Load the full user entity in `JwtAuthGuard` and attach it to `request.user`
- Get the authenticated user with `@CurrentUser()`
- Hash passwords with bcrypt
- Exclude the password and refresh token hash from every serialized user (`@Exclude()`)
- Sign access and refresh tokens with different secrets and a `type` claim (`TokenType`)
- Accept only access tokens in `JwtStrategy`; accept refresh tokens only in `POST /authentication/refresh`
- Store a SHA-256 hash of the current refresh token on the user, rotate it on every refresh, and clear it on logout and password change
- Rate-limit login, register and refresh with `@Throttle`

### MUST NOT DO
- Add `@UseGuards(JwtAuthGuard)` to controllers — the global guard already runs, so it would run twice
- Put roles or permissions in the JWT — roles are read from the loaded user so changes apply immediately
- Hash refresh tokens with bcrypt — bcrypt only uses the first 72 bytes, and JWTs for the same user share that prefix
- Reveal whether an email is registered in login responses
- Return a user entity without a response DTO

## Files

```
src/
├── domain/
│   ├── authentication/
│   │   ├── authentication.entity.ts
│   │   └── token-type.enum.ts
│   └── user/
│       └── user-role.enum.ts
├── modules/authentication/
│   ├── authentication.controller.ts
│   ├── authentication.module.ts
│   ├── authentication.service.ts
│   └── strategies/
│       └── jwt.strategy.ts
└── shared/
    ├── decorators/
    │   ├── current-user.decorator.ts
    │   ├── public.decorator.ts
    │   └── roles.decorator.ts
    ├── guards/
    │   ├── jwt-auth.guard.ts
    │   └── roles.guard.ts
    └── interfaces/
        └── jwt-payload.interface.ts
```

## JWT Strategy

```typescript
// jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtPayload } from '../../../shared/interfaces/jwt-payload.interface';
import { TokenType } from '../../../domain/authentication/token-type.enum';
import { AuthenticationMessages } from '../../../shared/guards/authentication-messages.enum';

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
    if (payload.type !== TokenType.Access) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidToken);
    }
    return payload;
  }
}

// jwt-payload.interface.ts
export interface JwtPayload {
  sub: number;
  email: string;
  type: TokenType;
  iat?: number;
  exp?: number;
}

// token-type.enum.ts
export enum TokenType {
  Access = 'access',
  Refresh = 'refresh',
}
```

## JWT Auth Guard

Validates the token, then loads the user so `RolesGuard`, `@CurrentUser()` and the audit interceptor all work with the real entity.

```typescript
// jwt-auth.guard.ts
import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { UsersService } from '../../modules/users/users.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { JwtPayload } from '../interfaces/jwt-payload.interface';
import { AuthenticationMessages } from './authentication-messages.enum';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(
    private readonly reflector: Reflector,
    private readonly usersService: UsersService,
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

    const request = context.switchToHttp().getRequest();
    const payload = request.user as JwtPayload;
    const user = await this.usersService
      .getSanitizedUserById(payload.sub)
      .catch(() => null);

    if (!user) {
      throw new UnauthorizedException(AuthenticationMessages.UserNotFound);
    }
    request.user = user;
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

// authentication-messages.enum.ts
export enum AuthenticationMessages {
  InvalidToken = 'Invalid token or no token provided',
  InvalidRefreshToken = 'Invalid or expired refresh token',
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

## Current User Decorator

```typescript
// current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { User } from '../../domain/user/user.entity';

export const CurrentUser = createParamDecorator(
  (data: unknown, context: ExecutionContext): User => {
    return context.switchToHttp().getRequest().user;
  },
);
```

## Authentication Domain Object

Login and register return an `Authentication` domain object; `AccessTokenDto` maps it to the response.

```typescript
// authentication.entity.ts
export class Authentication {
  private accessToken: string;
  private refreshToken: string;

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

  public getRefreshToken(): string {
    return this.refreshToken;
  }

  public setRefreshToken(refreshToken: string): Authentication {
    this.refreshToken = refreshToken;
    return this;
  }
}

// access-token.dto.ts
@DtoType('AccessToken')
export class AccessTokenDto extends DtoResponseInterceptor {
  @DtoProperty((authentication: Authentication) => authentication.getAccessToken(), 'Access token')
  readonly accessToken: string;

  @DtoProperty((authentication: Authentication) => authentication.getRefreshToken(), 'Refresh token')
  readonly refreshToken: string;

  public create(): DtoResponseInterceptor {
    return new AccessTokenDto();
  }
}
```

## Auth Service

```typescript
import { createHash, timingSafeEqual } from 'crypto';

@Injectable()
export class AuthenticationService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  public async register(registerDto: RegisterDto): Promise<Authentication> {
    if (await this.usersService.findUserByEmail(registerDto.email)) {
      throw new ConflictException(AuthenticationMessages.EmailExists);
    }
    const user = User.create(
      registerDto.email,
      await this.hashPassword(registerDto.password),
      registerDto.name,
    );
    return this.authenticateUser(await this.usersService.saveUser(user));
  }

  public async login(loginDto: LoginDto): Promise<Authentication> {
    const user = await this.validateUser(loginDto.email, loginDto.password);
    return this.authenticateUser(user);
  }

  public async refresh(refreshTokenDto: RefreshTokenDto): Promise<Authentication> {
    const payload = await this.verifyRefreshToken(refreshTokenDto.refreshToken);
    const user = await this.usersService.getUserById(payload.sub).catch(() => null);

    if (!user || !this.matchesStoredRefreshToken(user, refreshTokenDto.refreshToken)) {
      if (user) {
        await this.usersService.saveUser(user.clearRefreshTokenHash());
      }
      throw new UnauthorizedException(AuthenticationMessages.InvalidRefreshToken);
    }
    return this.authenticateUser(user);
  }

  public async logout(currentUser: User): Promise<void> {
    const user = await this.usersService.getUserById(currentUser.getId());
    await this.usersService.saveUser(user.clearRefreshTokenHash());
  }

  public async changePassword(
    changePasswordDto: ChangePasswordDto,
    currentUser: User,
  ): Promise<void> {
    const user = await this.usersService.getUserById(currentUser.getId());
    if (!(await bcrypt.compare(changePasswordDto.oldPassword, user.getPassword()))) {
      throw new BadRequestException(AuthenticationMessages.OldPasswordIncorrect);
    }
    user
      .setPassword(await this.hashPassword(changePasswordDto.newPassword))
      .clearRefreshTokenHash();
    await this.usersService.saveUser(user);
  }

  private async validateUser(email: string, password: string): Promise<User> {
    const user = await this.usersService.findUserByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.getPassword()))) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidCredentials);
    }
    return user;
  }

  private async authenticateUser(user: User): Promise<Authentication> {
    const accessToken = await this.jwtService.signAsync({
      sub: user.getId(),
      email: user.getEmail(),
      type: TokenType.Access,
    } satisfies JwtPayload);
    const refreshToken = await this.jwtService.signAsync(
      { sub: user.getId(), email: user.getEmail(), type: TokenType.Refresh } satisfies JwtPayload,
      {
        secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
        expiresIn: parseInt(this.configService.getOrThrow<string>('JWT_REFRESH_EXPIRATION_TIME')),
      },
    );

    await this.usersService.saveUser(
      user.setRefreshTokenHash(this.hashToken(refreshToken)),
    );
    return Authentication.create(accessToken, refreshToken);
  }

  private async verifyRefreshToken(refreshToken: string): Promise<JwtPayload> {
    const payload = await this.jwtService
      .verifyAsync<JwtPayload>(refreshToken, {
        secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
      })
      .catch(() => null);

    if (!payload || payload.type !== TokenType.Refresh) {
      throw new UnauthorizedException(AuthenticationMessages.InvalidRefreshToken);
    }
    return payload;
  }

  private matchesStoredRefreshToken(user: User, refreshToken: string): boolean {
    const storedHash = user.getRefreshTokenHash();
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

  private async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, AuthenticationValues.SaltRounds);
  }
}

// authentication-values.const.ts
export const AuthenticationValues = {
  SaltRounds: 10,
};
```

The user table needs the hash column, added in a migration:

```sql
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS refresh_token_hash VARCHAR(64) NULL;
```

| Token | Secret | Lifetime | Accepted by |
|-------|--------|----------|-------------|
| Access (`type: access`) | `JWT_SECRET` | `JWT_EXPIRATION_TIME` (short, e.g. 900s) | `JwtStrategy` on every protected endpoint |
| Refresh (`type: refresh`) | `JWT_REFRESH_SECRET` | `JWT_REFRESH_EXPIRATION_TIME` (e.g. 7 days) | `POST /authentication/refresh` only |

Each refresh issues a new pair and replaces the stored hash, so a refresh token works once. Presenting an old refresh token clears the stored hash, which logs out every session for that user — a stolen token that is replayed after the real client refreshed revokes itself. Login failures return the same message for an unknown email and a wrong password, so the API doesn't reveal which emails are registered.

## Auth Controller

```typescript
@Controller('authentication')
@ApiTags(SwaggerTags.Authentication)
export class AuthenticationController {
  constructor(private readonly authenticationService: AuthenticationService) {}

  @Public()
  @Throttle({ default: ThrottleValues.Authentication })
  @Post('/register')
  @Version('1')
  @ApiOperation({ summary: 'Register a user' })
  @DtoRequest(RegisterDto)
  @DtoResponse(HttpStatus.CREATED, 'User registered and logged in', AccessTokenDto)
  @DtoResponseError(HttpStatus.CONFLICT, 'Email already exists')
  @DtoResponseError(HttpStatus.TOO_MANY_REQUESTS, 'Too many attempts')
  public async register(@Body() registerDto: RegisterDto): Promise<Authentication> {
    return this.authenticationService.register(registerDto);
  }

  @Public()
  @Throttle({ default: ThrottleValues.Authentication })
  @Post('/login')
  @Version('1')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'User authentication login' })
  @DtoRequest(LoginDto)
  @DtoResponse(HttpStatus.OK, 'User logged in', AccessTokenDto)
  @DtoResponseError(HttpStatus.UNAUTHORIZED, 'Email or password is incorrect')
  @DtoResponseError(HttpStatus.TOO_MANY_REQUESTS, 'Too many attempts')
  public async login(@Body() loginDto: LoginDto): Promise<Authentication> {
    return this.authenticationService.login(loginDto);
  }

  @Public()
  @Throttle({ default: ThrottleValues.Authentication })
  @Post('/refresh')
  @Version('1')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Exchange a refresh token for a new token pair' })
  @DtoRequest(RefreshTokenDto)
  @DtoResponse(HttpStatus.OK, 'Tokens refreshed', AccessTokenDto)
  @DtoResponseError(HttpStatus.UNAUTHORIZED, 'Invalid or expired refresh token')
  public async refresh(@Body() refreshTokenDto: RefreshTokenDto): Promise<Authentication> {
    return this.authenticationService.refresh(refreshTokenDto);
  }

  @Post('/logout')
  @Version('1')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'Revoke the refresh token' })
  @DtoResponse(HttpStatus.NO_CONTENT, 'Logged out')
  public async logout(@CurrentUser() user: User): Promise<void> {
    return this.authenticationService.logout(user);
  }

  @Post('/change-password')
  @Version('1')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth('JWT-bearer-token')
  @ApiOperation({ summary: 'User change password' })
  @DtoRequest(ChangePasswordDto)
  @DtoResponse(HttpStatus.NO_CONTENT, 'Password changed')
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Old password is incorrect')
  public async changePassword(
    @Body() changePasswordDto: ChangePasswordDto,
    @CurrentUser() user: User,
  ): Promise<void> {
    return this.authenticationService.changePassword(changePasswordDto, user);
  }
}

// refresh-token.dto.ts
export class RefreshTokenDto {
  @ApiProperty({ description: RefreshTokenDtoMessages.RefreshToken })
  @IsJWT()
  refreshToken: string;
}
```

Login and refresh are `POST` because they send credentials in the body, but they don't create a resource, so they return `200` via `@HttpCode`. Register creates a user and returns `201`.

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
  providers: [AuthenticationService, JwtStrategy],
  exports: [AuthenticationService, JwtModule],
})
export class AuthenticationModule {}
```

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

Guards run in registration order: `ThrottlerGuard` rejects floods before any database work, then `JwtAuthGuard` attaches the user before `RolesGuard` checks roles. `UsersModule` must export `UsersService` because `JwtAuthGuard` injects it.

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

  @Column({ type: 'varchar', length: 64, nullable: true })
  @Exclude()
  private refreshTokenHash: string | null;

  public static create(email: string, password: string, name: string, roles: UserRole[] = [UserRole.User]): User {
    return new User().setEmail(email).setPassword(password).setName(name).setRoles(roles);
  }

  public hasRole(roles: UserRole[]): boolean {
    return roles.some((role) => this.roles.includes(role));
  }

  public getRefreshTokenHash(): string | null {
    return this.refreshTokenHash;
  }

  public setRefreshTokenHash(refreshTokenHash: string): this {
    this.refreshTokenHash = refreshTokenHash;
    return this;
  }

  public clearRefreshTokenHash(): this {
    this.refreshTokenHash = null;
    return this;
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
| `JwtStrategy` | Validate JWT tokens |
| `JwtAuthGuard` | Global: authenticate and load the user |
| `RolesGuard` | Global: role-based access |
| `@Public()` | Skip authentication |
| `@Roles(UserRole.Admin)` | Require role |
| `@CurrentUser()` | Authenticated user entity |
| `Authentication` | Login/register/refresh result mapped by `AccessTokenDto` |
| `TokenType` | `access` / `refresh` claim that keeps the two tokens apart |
| `@Throttle({ default: ThrottleValues.Authentication })` | Stricter rate limit on auth endpoints |
