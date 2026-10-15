# Configuration

Two config services exist side by side. They have different names so it is always clear which one is meant.

| Service | Import from | Injectable | Use when |
|---------|-------------|------------|----------|
| `ConfigService` | `@nestjs/config` | Yes | Inside the Nest DI container: services, strategies, guards, `registerAsync` factories |
| `ApiConfigService` | `src/modules/config/api-config.service.ts` | No | Outside the DI container: `main.ts` bootstrap, `forRootAsync()` factories, the TypeORM CLI `DataSource`, Swagger setup |

## Constraints

### MUST DO
- Register Nest's `ConfigModule.forRoot({ envFilePath: '.env', isGlobal: true })` once in `AppModule`
- Inject `ConfigService` from `@nestjs/config` in any class the DI container creates
- Use `getOrThrow()` for required values on `ConfigService`
- Read boolean flags with `getBoolean()`, which accepts only `true` or `false` and throws on anything else
- Read URLs with `getUrl()`, which requires an absolute `http` or `https` URL and throws on anything else
- Read config inside functions: `forRootAsync({ useFactory })`, `bootstrap()` in `main.ts`, or a constructor
- Use `ApiConfigService` (or a subclass) for values needed before or outside DI
- Subclass `ApiConfigService` per concern (e.g. `PostgresTypeormConfigService`) and list required keys in its static `create()` with `ensureValues()`
- Subclass Nest's `ConfigService` for injectable, concern-specific config (e.g. `SocratesHttpConfigService`)

### MUST NOT DO
- Name a custom class `ConfigService` — the name belongs to `@nestjs/config`
- Read `process.env` directly outside `ApiConfigService`
- Instantiate Nest's `ConfigService` with `new`
- Inject `ApiConfigService` — it is a plain class, not a provider
- Decide feature flags such as database SSL from `isProduction()` — give each its own variable (`DB_SSL`)
- Read config at module scope or in decorator arguments, such as `TypeOrmModule.forRoot(new XConfigService().getConfig())` — it runs when the file is imported, before tests can set their environment

## ApiConfigService

```typescript
// src/modules/config/api-config.service.ts
import * as dotenv from 'dotenv';
import { ConfigSource } from './types/config-source.interface';
import { Environment } from './types/environment.enum';

dotenv.config();

export class ApiConfigService {
  constructor(private readonly source: ConfigSource = process.env) {}

  public getEnvironment(): string {
    return this.getValue('ENV');
  }

  public ensureValues(keys: string[]): this {
    keys.forEach((key) => this.getValue(key, true));
    return this;
  }

  public getPort(): string {
    return this.getValue('PORT', true);
  }

  public isProduction(): boolean {
    return this.getEnvironment() === Environment.Production;
  }

  public getBoolean(key: string): boolean {
    const value = this.getValue(key);
    if (value !== 'true' && value !== 'false') {
      throw new Error(`Config Error - Env.${key} must be true or false`);
    }
    return value === 'true';
  }

  public getUrl(key: string): string {
    const value = this.getValue(key);
    const url = URL.canParse(value) ? new URL(value) : null;
    if (!url || !['http:', 'https:'].includes(url.protocol)) {
      throw new Error(`Config Error - Env.${key} must be an http or https URL`);
    }
    return value;
  }

  protected getValue(key: string, throwOnMissing = true): string {
    const value = this.source[key];
    if (!value && throwOnMissing) {
      throw new Error(`Config Error - Missing Env.${key}`);
    }
    return value;
  }
}
```

```typescript
// src/modules/config/types/config-source.interface.ts
export interface ConfigSource {
  [key: string]: string | undefined;
}
```

```typescript
// src/modules/config/types/environment.enum.ts
export enum Environment {
  Production = 'PROD',
}
```

## Subclassing ApiConfigService (outside DI)

```typescript
// src/modules/database/config/postgres-typeorm-config.service.ts
export class PostgresTypeormConfigService extends ApiConfigService {
  public static create(): PostgresTypeormConfigService {
    return new PostgresTypeormConfigService().ensureValues([
      'DB_HOST',
      'DB_PORT',
    ]);
  }

  public getConfig(): TypeOrmModuleOptions {
    return {
      host: this.getValue('DB_HOST'),
      port: parseInt(this.getValue('DB_PORT')),
    };
  }
}

// usage: read when the app boots, not when the module file is imported
TypeOrmModule.forRootAsync({
  useFactory: () => PostgresTypeormConfigService.create().getConfig(),
})
```

## Nest ConfigService (inside DI)

```typescript
// registerAsync factory
import { ConfigModule, ConfigService } from '@nestjs/config';

JwtModule.registerAsync({
  imports: [ConfigModule],
  useFactory: async (configService: ConfigService) => ({
    secret: configService.getOrThrow<string>('JWT_SECRET'),
    signOptions: {
      expiresIn: parseInt(configService.getOrThrow<string>('JWT_EXPIRATION_TIME')),
    },
  }),
  inject: [ConfigService],
});

// constructor injection
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_SECRET'),
    });
  }
}
```

## Subclassing Nest ConfigService (inside DI)

```typescript
// src/modules/http/socrates-http/socrates-http-config.service.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class SocratesHttpConfigService extends ConfigService {
  public getBaseUrl(): string {
    return this.getOrThrow<string>('SOCRATES_URL');
  }
}
```

## Quick Reference

| Need | Use |
|------|-----|
| Port, Swagger credentials in `main.ts` | `new ApiConfigService()` |
| `TypeOrmModule.forRootAsync`, `MailerModule.forRootAsync` factories | `ApiConfigService` subclass |
| TypeORM CLI `DataSource` | `ApiConfigService` subclass |
| CORS allow-list, Swagger credentials | `CorsConfigService`, `SwaggerConfigService` (`ApiConfigService` subclasses) |
| JWT secrets in the auth service | Nest `ConfigService` via constructor |
| `JwtModule.registerAsync` | Nest `ConfigService` via `inject` |
| Service, strategy, guard | Nest `ConfigService` via constructor |
