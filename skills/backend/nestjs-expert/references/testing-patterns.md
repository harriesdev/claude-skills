# Testing Patterns

## Constraints

### MUST DO
- Name test files `{x}.test.ts` and mirror the `src/` path under `test/` (Jest only matches `.*\.test\.ts$`)
- Mock custom repositories by class (`{ provide: PostRepository, useValue: ... }`)
- Build entity fixtures with test factories from `test/resources/`
- Register `requestIdMiddleware`, `ApiValidationPipe` and URI versioning in E2E apps, matching `main.ts`
- Test that another user's record returns 404 for every endpoint on a user-owned resource

### MUST NOT DO
- Mock `getRepositoryToken(Entity)` for services that inject a custom repository — the token isn't what they depend on
- Name test files `.spec.ts`

## Jest Config

```json
// package.json
"jest": {
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": "test",
  "testRegex": ".*\\.test\\.ts$",
  "transform": { "^.+\\.(t|j)s$": "ts-jest" },
  "collectCoverageFrom": ["**/*.(t|j)s"],
  "coverageDirectory": "../coverage",
  "testEnvironment": "node"
}
```

E2E tests use `test/jest-e2e.json` and run with `npm run test:e2e`.

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

  afterEach(() => jest.clearAllMocks());
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
describe('UsersController', () => {
  let controller: UsersController;
  let service: jest.Mocked<UsersService>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: {
            create: jest.fn(),
            findOne: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get(UsersController);
    service = module.get(UsersService);
  });

  it('should create user', async () => {
    const dto = { email: 'test@test.com', password: 'pass', name: 'Test' };
    const user = { id: '1', ...dto };
    service.create.mockResolvedValue(user as User);

    const result = await controller.create(dto);
    expect(result).toEqual(user);
  });
});
```

## E2E Tests

```typescript
import { INestApplication, VersioningType } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { requestIdMiddleware } from '../src/shared/middleware/request-id.middleware';
import { ApiValidationPipe } from '../src/shared/pipes/api-validation.pipe';

describe('UsersController (e2e)', () => {
  let app: INestApplication;
  let authToken: string;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.use(requestIdMiddleware);
    app.enableVersioning({ type: VersioningType.URI });
    app.useGlobalPipes(new ApiValidationPipe());
    await app.init();

    const response = await request(app.getHttpServer())
      .post('/v1/authentication/login')
      .send({ email: 'test@test.com', password: 'password' });
    authToken = response.body.accessToken;
  });

  afterAll(() => app.close());

  it('/users (POST)', () => {
    return request(app.getHttpServer())
      .post('/v1/users')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ email: 'new@test.com', password: 'Test1234', name: 'New' })
      .expect(201)
      .expect((res) => {
        expect(res.body.email).toBe('new@test.com');
      });
  });

  it('/users/:id (GET) - 404', () => {
    return request(app.getHttpServer())
      .get('/v1/users/999999')
      .set('Authorization', `Bearer ${authToken}`)
      .expect(404);
  });
});
```

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
  create: jest.fn(),
  save: jest.fn(),
  find: jest.fn(),
  findOne: jest.fn(),
  findOneBy: jest.fn(),
  findById: jest.fn(),
  findAndCount: jest.fn(),
  findPage: jest.fn(),
  recover: jest.fn(),
  restore: jest.fn(),
  softRemove: jest.fn(),
  remove: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getOne: jest.fn(),
    getMany: jest.fn(),
  })),
});
```

```typescript
// test/resources/modules/database/repositories/post/post-repository.test-factory.ts
export const PostRepositoryTestFactory = {
  build() {
    return {
      ...createMockRepository(),
      findAll: jest.fn(),
      findPageByUser: jest.fn(),
      findByIdWithRelations: jest.fn(),
    };
  },
};
```

## Quick Reference

| Pattern | Use Case |
|---------|----------|
| `Test.createTestingModule()` | Create test module |
| `jest.fn()` | Mock function |
| `mockResolvedValue()` | Mock async return |
| `mockReturnValue()` | Mock sync return |
| `supertest` | E2E HTTP testing |
| `beforeAll` / `afterAll` | Setup/teardown |
