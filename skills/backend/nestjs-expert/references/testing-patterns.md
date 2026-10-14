# Testing Patterns

## Constraints

### MUST DO
- Run tests with Vitest, using `unplugin-swc` so decorator metadata is emitted
- Name test files `{x}.test.ts` and mirror the `src/` path under `test/`; name E2E tests `test/e2e/{x}.e2e.test.ts`
- Mock custom repositories by class (`{ provide: PostRepository, useValue: ... }`)
- Build entity fixtures with test factories from `test/resources/`
- Register `requestIdMiddleware`, `cookieParser()`, the `api` global prefix, URI versioning and `ApiValidationPipe` in E2E apps, matching `main.ts`
- Test that another user's record returns 404 for every endpoint on a user-owned resource

### MUST NOT DO
- Mock `getRepositoryToken(Entity)` for services that inject a custom repository — the token isn't what they depend on
- Name test files `.spec.ts`
- Use Jest, `ts-jest` or `jest.*` APIs — use Vitest and `vi.*`
- Run Vitest without `unplugin-swc` — esbuild drops the decorator metadata Nest's DI needs

## Vitest Config

Tests run on Vitest. Vitest transforms TypeScript with esbuild, which doesn't emit decorator metadata, so Nest can't resolve constructor dependencies. `unplugin-swc` replaces that transform with SWC, which does.

```typescript
// vitest.config.ts
import swc from 'unplugin-swc';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['test/**/*.test.ts'],
    exclude: ['test/e2e/**'],
    coverage: {
      provider: 'v8',
      include: ['src/**/*.ts'],
      reportsDirectory: './coverage',
    },
  },
  plugins: [swc.vite({ module: { type: 'es6' } })],
});

// vitest.config.e2e.ts
import swc from 'unplugin-swc';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['test/e2e/**/*.e2e.test.ts'],
    fileParallelism: false,
  },
  plugins: [swc.vite({ module: { type: 'es6' } })],
});
```

```json
// package.json
"scripts": {
  "test": "vitest run",
  "test:watch": "vitest",
  "test:cov": "vitest run --coverage",
  "test:e2e": "vitest run --config vitest.config.e2e.ts"
}

// tsconfig.json
"compilerOptions": {
  "types": ["vitest/globals"]
}
```

Install `vitest`, `@vitest/coverage-v8`, `unplugin-swc`, `@swc/core` and `supertest` as dev dependencies. `globals: true` makes `describe`, `it`, `expect` and `vi` available without imports; import types such as `Mocked` from `vitest`.

## Unit Test Setup

Services inject custom repositories (`PostRepository`), so the mock is provided under the repository class.

```typescript
// test/modules/posts/posts.service.test.ts
import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PostRepository } from '../../../src/modules/database/repositories/post/post.repository';
import { PostsService } from '../../../src/modules/posts/posts.service';
import { PostRepositoryTestFactory } from '../../resources/modules/database/repositories/post/post-repository.test-factory';
import { PostTestFactory } from '../../resources/domain/post/post.test-factory';
import { UserTestFactory } from '../../resources/domain/user/user.test-factory';

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

  afterEach(() => vi.clearAllMocks());
});
```

Use `getRepositoryToken(Entity)` only for a class that injects `@InjectRepository(Entity) Repository<Entity>` directly.

## Service Tests

```typescript
describe('createPost', () => {
  it('should assign the owner, save and return the post', async () => {
    const user = UserTestFactory.build();
    const post = PostTestFactory.build();
    postRepository.save.mockImplementation(async (saved) => saved);

    const result = await service.createPost(post, user);

    expect(result.getUser()).toBe(user);
    expect(postRepository.save).toHaveBeenCalledWith(post);
  });
});

describe('getOwnedPost', () => {
  it('should return a post the user owns', async () => {
    const owner = UserTestFactory.build();
    const post = PostTestFactory.build({ id: 1, user: owner });
    postRepository.findById.mockResolvedValue(post);

    expect(await service.getOwnedPost(1, owner)).toBe(post);
  });

  it('should throw NotFoundException when the post does not exist', async () => {
    postRepository.findById.mockResolvedValue(null);
    await expect(service.getOwnedPost(1, UserTestFactory.build())).rejects.toThrow(NotFoundException);
  });

  it('should throw NotFoundException for another user\'s post', async () => {
    const post = PostTestFactory.build({ id: 1, user: UserTestFactory.build() });
    postRepository.findById.mockResolvedValue(post);

    await expect(service.getOwnedPost(1, UserTestFactory.build())).rejects.toThrow(NotFoundException);
  });
});
```

## Controller Tests

```typescript
import type { Mocked } from 'vitest';

describe('UsersController', () => {
  let controller: UsersController;
  let service: Mocked<UsersService>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: {
            create: vi.fn(),
            findOne: vi.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get(UsersController);
    service = module.get(UsersService);
  });

  it('should create user', async () => {
    const dto = { email: 'test@test.com', password: 'pass', name: 'Test' };
    const user = { id: 1, ...dto };
    service.create.mockResolvedValue(user as User);

    const result = await controller.create(dto);
    expect(result).toEqual(user);
  });
});
```

## E2E Tests

```typescript
// test/e2e/users.e2e.test.ts
import { INestApplication, VersioningType } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import cookieParser from 'cookie-parser';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { requestIdMiddleware } from '../../src/shared/middleware/request-id.middleware';
import { ApiValidationPipe } from '../../src/shared/pipes/api-validation.pipe';
import { ApiRoute } from '../../src/shared/enums/api-route.enum';

describe('UsersController (e2e)', () => {
  let app: INestApplication;
  let authToken: string;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.use(requestIdMiddleware);
    app.use(cookieParser());
    app.setGlobalPrefix(ApiRoute.Prefix);
    app.enableVersioning({ type: VersioningType.URI });
    app.useGlobalPipes(new ApiValidationPipe());
    await app.init();

    const response = await request(app.getHttpServer())
      .post('/api/v1/authentication/login')
      .send({ email: 'test@test.com', password: 'password' });
    authToken = response.body.accessToken;
  });

  afterAll(() => app.close());

  it('/api/v1/users (POST)', () => {
    return request(app.getHttpServer())
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ email: 'new@test.com', password: 'Test1234', name: 'New' })
      .expect(201)
      .expect((res) => {
        expect(res.body.email).toBe('new@test.com');
      });
  });

  it('/api/v1/users/:id (GET) - 404', () => {
    return request(app.getHttpServer())
      .get('/api/v1/users/999999')
      .set('Authorization', `Bearer ${authToken}`)
      .expect(404);
  });
});
```

### Refresh Cookie and Sessions

Test both transports and the session rules end to end. `supertest`'s `agent` keeps cookies between requests like a browser.

```typescript
// test/e2e/authentication.e2e.test.ts
it('sets the refresh cookie for the web app and refreshes from it', async () => {
  const agent = request.agent(app.getHttpServer());

  const login = await agent
    .post('/api/v1/authentication/login')
    .set(RequestHeader.AuthTransport, AuthTransport.Cookie)
    .send({ email: 'test@test.com', password: 'password' })
    .expect(200);

  expect(login.body.accessToken).toEqual(expect.any(String));
  expect(login.body.refreshToken).toBeNull();
  expect(login.headers['set-cookie']).toEqual(
    expect.arrayContaining([expect.stringMatching(/^refresh_token=.*HttpOnly.*SameSite=Strict/)]),
  );

  const refreshed = await agent.post('/api/v1/authentication/refresh').send({}).expect(200);
  expect(refreshed.body.refreshToken).toBeNull();

  await request(app.getHttpServer())
    .get('/api/v1/authentication/sessions')
    .set('Authorization', `Bearer ${refreshed.body.accessToken}`)
    .expect(200);
});

it('does not accept the refresh cookie as authentication on other routes', async () => {
  const agent = request.agent(app.getHttpServer());
  await agent
    .post('/api/v1/authentication/login')
    .set(RequestHeader.AuthTransport, AuthTransport.Cookie)
    .send({ email: 'test@test.com', password: 'password' })
    .expect(200);

  await agent.get('/api/v1/authentication/sessions').expect(401);
});

it('keeps the other session when one device logs out', async () => {
  const first = await login();
  const second = await login();

  await request(app.getHttpServer())
    .post('/api/v1/authentication/logout')
    .set('Authorization', `Bearer ${first.accessToken}`)
    .expect(204);

  await request(app.getHttpServer())
    .get('/api/v1/authentication/sessions')
    .set('Authorization', `Bearer ${first.accessToken}`)
    .expect(401);
  await request(app.getHttpServer())
    .get('/api/v1/authentication/sessions')
    .set('Authorization', `Bearer ${second.accessToken}`)
    .expect(200);
});

it('ends only the reused session when an old refresh token is replayed', async () => {
  const session = await login();
  const other = await login();
  const refresh = (refreshToken: string) =>
    request(app.getHttpServer()).post('/api/v1/authentication/refresh').send({ refreshToken });

  const rotated = await refresh(session.refreshToken).expect(200);
  await refresh(session.refreshToken).expect(401);
  await refresh(rotated.body.refreshToken).expect(401);
  await refresh(other.refreshToken).expect(200);
});
```

`login()` is a helper in the test file that posts to `/api/v1/authentication/login` without the transport header and returns the body.

## Entity Tests

```typescript
// test/domain/merchant/merchant.entity.test.ts
describe(Merchant.name, () => {
  let merchant: Merchant;

  beforeAll(async () => {
    merchant = MerchantTestFactory.build({ id: 1 });
    merchant.setUsers(UserTestFactory.buildList(4, {
      merchantId: 1,
      isAssociatedToMerchant: () => true
    }))
  });

  describe('isAssociatedToMerchant', () => {
    it('should associate first user to the merchant', () => {
      expect(merchant.getUsers()[0].isAssociatedToMerchant()).toBe(true);
    });
  });
});
```

## Test Factory

Test factories build entity fixtures for tests. They live in `test/resources/` and are named `{x}.test-factory.ts` / `XTestFactory` so they are never confused with domain factories (`src/domain/{x}/{x}.factory.ts`), which are production code.

`DomainObject` has no setters for `id` or the audit columns, so test factories assign them directly with `Object.assign`.

```typescript
// test/resources/domain/merchant/merchant.test-factory.ts
let merchantIdSequence = 0;

export const MerchantTestFactory = {
  build(overrides: Partial<Merchant> = {}): Merchant {
    const merchant = new Merchant().setName('A Merchant');

    Object.assign(merchant, {
      id: ++merchantIdSequence,
      updatedDate: new Date('2026-06-17T22:15:15.222Z'),
    });

    return Object.assign(merchant, overrides);
  },

  buildList(count: number, overrides: Partial<Merchant> = {}): Merchant[] {
    return Array.from({ length: count }, () =>
      MerchantTestFactory.build(overrides),
    );
  },
};

// test/resources/domain/user/user.test-factory.ts
let userIdSequence = 0;

export const UserTestFactory = {
  build(overrides: Partial<User> = {}): User {
    const user = new User().setName('A User');

    Object.assign(user, {
      id: ++userIdSequence,
      updatedDate: new Date('2026-06-17T22:15:15.222Z'),
    });

    return Object.assign(user, overrides);
  },

  buildList(count: number, overrides: Partial<User> = {}): User[] {
    return Array.from({ length: count }, () =>
      UserTestFactory.build(overrides),
    );
  },
};
```

## Mock Repository Factory

`createMockRepository` mocks the `RepositorySupport` and TypeORM methods every repository has. Each repository's test factory adds its own custom methods.

```typescript
// test/resources/modules/database/repositories/create-mock-repository.ts
export const createMockRepository = () => ({
  create: vi.fn(),
  save: vi.fn(),
  find: vi.fn(),
  findOne: vi.fn(),
  findOneBy: vi.fn(),
  findById: vi.fn(),
  findAndCount: vi.fn(),
  findPage: vi.fn(),
  recover: vi.fn(),
  restore: vi.fn(),
  softRemove: vi.fn(),
  remove: vi.fn(),
  update: vi.fn(),
  delete: vi.fn(),
  createQueryBuilder: vi.fn(() => ({
    where: vi.fn().mockReturnThis(),
    andWhere: vi.fn().mockReturnThis(),
    getOne: vi.fn(),
    getMany: vi.fn(),
  })),
});
```

```typescript
// test/resources/modules/database/repositories/post/post-repository.test-factory.ts
export const PostRepositoryTestFactory = {
  build() {
    return {
      ...createMockRepository(),
      findAll: vi.fn(),
      findPageByUser: vi.fn(),
      findByIdWithRelations: vi.fn(),
    };
  },
};
```

## Quick Reference

| Pattern | Use Case |
|---------|----------|
| `Test.createTestingModule()` | Create test module |
| `vi.fn()` | Mock function |
| `vi.spyOn()` | Spy on an existing method |
| `mockResolvedValue()` | Mock async return |
| `mockReturnValue()` | Mock sync return |
| `supertest` | E2E HTTP testing |
| `vitest run --config vitest.config.e2e.ts` | Run E2E tests |
| `beforeAll` / `afterAll` | Setup/teardown |
