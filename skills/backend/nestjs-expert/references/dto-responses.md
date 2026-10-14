# Response DTOs & Mapping

Controllers return **entities**. The `@DtoResponse` decorator documents the response in Swagger and attaches an interceptor that maps the returned entity (or array of entities) to the response DTO. Services and controllers never build response DTOs by hand.

```
GET /posts/1
  → controller returns Post (entity)
  → DtoResponseMapperInterceptor reads @DtoProperty metadata on PostDto
  → client receives PostDto JSON
```

## Constraints

### MUST DO
- Return the entity (`Promise<Post>`, `Promise<Post[]>`) from controllers; the DTO type goes on `@DtoResponse`
- Extend `DtoResponseInterceptor` for every response DTO and implement `create()`
- Decorate every response DTO with `@DtoType('SchemaName')`
- Map every field with `@DtoProperty`, `@DtoArray` or `@DtoEnum`
- Use exactly one `@DtoResponse` with a DTO type per endpoint
- Return `Page<T>` from list endpoints and map it with a `{X}PageDto` of `data` and `meta`
- Use `HttpStatus.CREATED` for endpoints that create a resource and `HttpStatus.NO_CONTENT` (with `@HttpCode`) for endpoints that return nothing
- Document error responses with `@DtoResponseError`

### MUST NOT DO
- Pass a DTO type to more than one `@DtoResponse` on the same endpoint — each attaches an interceptor and only one mapping can apply
- Expose fields by returning the raw entity without a `@DtoResponse` type
- Map passwords, secrets or invite codes into a response DTO

## Files

```
src/shared/
├── const/
│   └── dto-properties-array-symbol.const.ts
├── decorators/
│   ├── dto.decorator.ts
│   ├── dto-property.decorator.ts
│   └── dto-type.decorator.ts
├── interceptors/
│   ├── dto-response.interceptor.ts
│   ├── dto-response-mapper.interceptor.ts
│   └── dto-response-mapper.service.ts
├── interfaces/
│   └── dto-property-type.interface.ts
└── types/
    └── constructor.type.ts
```

## Response DTO

```typescript
// src/dto/post/post.dto.ts
import { Post } from '../../domain/post/post.entity';
import { DtoProperty } from '../../shared/decorators/dto-property.decorator';
import { DtoType } from '../../shared/decorators/dto-type.decorator';
import { DtoResponseInterceptor } from '../../shared/interceptors/dto-response.interceptor';
import { UserDto } from '../user/user.dto';
import { PostDtoMessages } from './post-dto-messages.enum';

@DtoType('Post')
export class PostDto extends DtoResponseInterceptor {
  @DtoProperty((post: Post) => post.getId(), PostDtoMessages.Id)
  readonly id: number;

  @DtoProperty((post: Post) => post.getTitle(), PostDtoMessages.Title)
  readonly title: string;

  @DtoProperty((post: Post) => post.getDescription(), PostDtoMessages.Description)
  readonly description: string;

  @DtoProperty(UserDto, (post: Post) => post.getUser(), PostDtoMessages.User)
  readonly user: UserDto;

  public create(): DtoResponseInterceptor {
    return new PostDto();
  }
}
```

### Paginated List

List endpoints return a `Page<T>` and map it with a page DTO. The response is `{ data, meta }`.

```json
{
  "data": [{ "id": 1, "title": "Hello" }],
  "meta": { "page": 1, "limit": 20, "total": 42, "totalPages": 3 }
}
```

```typescript
// src/shared/types/page.ts
export class Page<T> {
  constructor(
    private readonly items: T[],
    private readonly total: number,
    private readonly page: number,
    private readonly limit: number,
  ) {}

  public getItems(): T[] {
    return this.items;
  }

  public getTotal(): number {
    return this.total;
  }

  public getPage(): number {
    return this.page;
  }

  public getLimit(): number {
    return this.limit;
  }

  public getTotalPages(): number {
    return Math.ceil(this.total / this.limit);
  }
}
```

```typescript
// src/dto/common/page-meta.dto.ts
@DtoType('PageMeta')
export class PageMetaDto extends DtoResponseInterceptor {
  @DtoProperty((page: Page<unknown>) => page.getPage(), PageMetaDtoMessages.Page)
  readonly page: number;

  @DtoProperty((page: Page<unknown>) => page.getLimit(), PageMetaDtoMessages.Limit)
  readonly limit: number;

  @DtoProperty((page: Page<unknown>) => page.getTotal(), PageMetaDtoMessages.Total)
  readonly total: number;

  @DtoProperty((page: Page<unknown>) => page.getTotalPages(), PageMetaDtoMessages.TotalPages)
  readonly totalPages: number;

  public create(): DtoResponseInterceptor {
    return new PageMetaDto();
  }
}

// src/dto/post/post-page.dto.ts
@DtoType('PostPage')
export class PostPageDto extends DtoResponseInterceptor {
  @DtoArray(PostDto, (page: Page<Post>) => page.getItems(), PostDtoMessages.Posts)
  readonly data: PostDto[];

  @DtoProperty(PageMetaDto, (page: Page<Post>) => page, PostDtoMessages.PageMeta)
  readonly meta: PageMetaDto;

  public create(): DtoResponseInterceptor {
    return new PostPageDto();
  }
}
```

```typescript
// controller
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
```

An empty list is a `200` with `data: []`, never a `404`. `RepositorySupport.findPage()` builds the `Page` (see `references/repository-typeorm.md`).

Use a plain array (`@DtoResponse(HttpStatus.OK, '...', PostDto, true)`) only for small, bounded lists such as enum-like reference data.

### Enum field

```typescript
@DtoEnum((user: User) => user.getRoles(), UserRole, 'UserRole')
readonly roles: UserRole[];
```

## Controller Usage

```typescript
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
```

## Decorators

```typescript
// src/shared/decorators/dto.decorator.ts
import { applyDecorators, HttpStatus, UseInterceptors } from '@nestjs/common';
import { ApiBody, ApiResponse } from '@nestjs/swagger';
import { DtoResponseInterceptor } from '../interceptors/dto-response.interceptor';
import { DtoResponseMapperInterceptor } from '../interceptors/dto-response-mapper.interceptor';
import { Constructor } from '../types/constructor.type';

export const DtoRequest = (type: Constructor<object>) => {
  return applyDecorators(ApiBody({ type }));
};

export function DtoResponse(
  status: HttpStatus,
  description: string,
  type?: Constructor<DtoResponseInterceptor>,
  isArray?: boolean,
) {
  if (type) {
    return applyDecorators(
      ApiResponse({ type, description, status, isArray }),
      UseInterceptors(type, DtoResponseMapperInterceptor),
    );
  }
  return applyDecorators(ApiResponse({ description, status }));
}

export function DtoResponseError(status: HttpStatus, description: string) {
  return applyDecorators(ApiResponse({ description, status }));
}
```

```typescript
// src/shared/decorators/dto-property.decorator.ts
import { ApiProperty } from '@nestjs/swagger';
import { DtoPropertiesArraySymbol } from '../const/dto-properties-array-symbol.const';
import {
  DtoPropertyAccessor,
  DtoPropertyType,
} from '../interfaces/dto-property-type.interface';
import { DtoResponseInterceptor } from '../interceptors/dto-response.interceptor';
import { Constructor } from '../types/constructor.type';

type DtoAssociation = Constructor<DtoResponseInterceptor>;

export function DtoProperty(
  accessor: DtoPropertyAccessor,
  description?: string,
): PropertyDecorator;
export function DtoProperty(
  dtoType: DtoAssociation,
  accessor: DtoPropertyAccessor,
  description?: string,
): PropertyDecorator;
export function DtoProperty(...args: unknown[]): PropertyDecorator {
  return (target: object, propertyName: string | symbol) => {
    const property = createDtoPropertyType(String(propertyName), args);
    ApiProperty({
      description: property.description,
      type: property.dtoAssociationType,
    })(target, propertyName);
    addDtoProperty(target, property);
  };
}

export function DtoArray(
  dtoType: DtoAssociation,
  accessor: DtoPropertyAccessor,
  description?: string,
): PropertyDecorator {
  return (target: object, propertyName: string | symbol) => {
    ApiProperty({ type: [dtoType], description })(target, propertyName);
    addDtoProperty(target, {
      propertyName: String(propertyName),
      accessor,
      dtoAssociationType: dtoType,
      description,
    });
  };
}

export function DtoEnum(
  accessor: DtoPropertyAccessor,
  enumType: object,
  enumName: string,
): PropertyDecorator {
  return (target: object, propertyName: string | symbol) => {
    ApiProperty({ name: String(propertyName), enum: enumType, enumName })(
      target,
      propertyName,
    );
    addDtoProperty(target, { propertyName: String(propertyName), accessor });
  };
}

function createDtoPropertyType(
  propertyName: string,
  args: unknown[],
): DtoPropertyType {
  if (typeof args[1] === 'function') {
    return {
      propertyName,
      dtoAssociationType: args[0] as DtoAssociation,
      accessor: args[1] as DtoPropertyAccessor,
      description: args[2] as string | undefined,
    };
  }
  return {
    propertyName,
    accessor: args[0] as DtoPropertyAccessor,
    description: args[1] as string | undefined,
  };
}

function addDtoProperty(target: object, property: DtoPropertyType): void {
  const dtoProperties: DtoPropertyType[] =
    Reflect.getMetadata(DtoPropertiesArraySymbol, target) || [];
  Reflect.defineMetadata(
    DtoPropertiesArraySymbol,
    dtoProperties.concat([property]),
    target,
  );
}
```

```typescript
// src/shared/decorators/dto-type.decorator.ts
export function DtoType(schemaName: string) {
  return function classDecorator<T extends new (...args: unknown[]) => object>(
    constructor: T,
  ) {
    return {
      [schemaName]: class extends constructor {
        public create() {
          return new constructor();
        }
      },
    }[schemaName];
  };
}
```

Every DTO field is always present in the response. Missing values are sent as `null`, so clients get a stable schema.

`@DtoType` renames the class so the Swagger schema is `Post` rather than `PostDto`.

## Interceptors

```typescript
// src/shared/interceptors/dto-response.interceptor.ts
import { CallHandler, ExecutionContext, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';

export abstract class DtoResponseInterceptor implements NestInterceptor {
  public intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    const response = context.switchToHttp().getResponse();
    response.createResponseDto = this.create;
    return next.handle();
  }

  public abstract create(): DtoResponseInterceptor;
}
```

```typescript
// src/shared/interceptors/dto-response-mapper.interceptor.ts
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { mergeMap, Observable } from 'rxjs';
import { DtoResponseMapperService } from './dto-response-mapper.service';

@Injectable()
export class DtoResponseMapperInterceptor implements NestInterceptor {
  public intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    const response = context.switchToHttp().getResponse();
    return next
      .handle()
      .pipe(
        mergeMap((responseBody) =>
          new DtoResponseMapperService(response.createResponseDto).mapResponseToDto(
            responseBody,
          ),
        ),
      );
  }
}
```

```typescript
// src/shared/interceptors/dto-response-mapper.service.ts
import { DtoPropertiesArraySymbol } from '../const/dto-properties-array-symbol.const';
import { DtoPropertyType } from '../interfaces/dto-property-type.interface';

export class DtoResponseMapperService {
  constructor(private readonly target: () => object) {}

  public async mapResponseToDto(
    responseOutput: unknown,
  ): Promise<object | object[]> {
    if (Array.isArray(responseOutput)) {
      return Promise.all(responseOutput.map((entity) => this.mapEntity(entity)));
    }
    return this.mapEntity(responseOutput);
  }

  private async mapEntity(
    entity: unknown,
    createTarget: () => object = this.target,
  ): Promise<object> {
    const target = createTarget() as Record<string, unknown>;
    const properties: DtoPropertyType[] =
      Reflect.getMetadata(DtoPropertiesArraySymbol, target) || [];

    for (const property of properties) {
      target[property.propertyName] =
        (await this.getValue(property, entity)) ?? null;
    }
    return target;
  }

  private async getValue(
    property: DtoPropertyType,
    entity: unknown,
  ): Promise<unknown> {
    const read = property.accessor as (entity: unknown) => unknown;
    const value = await read(entity);
    if (!property.dtoAssociationType || !value) {
      return value;
    }

    const createAssociation = () => new property.dtoAssociationType();
    if (Array.isArray(value)) {
      return Promise.all(
        value.map((item) => this.mapEntity(item, createAssociation)),
      );
    }
    return this.mapEntity(value, createAssociation);
  }
}
```

## Supporting Types

```typescript
// src/shared/interfaces/dto-property-type.interface.ts
import { DtoResponseInterceptor } from '../interceptors/dto-response.interceptor';
import { Constructor } from '../types/constructor.type';

export type DtoPropertyAccessor = (entity: never) => unknown;

export interface DtoPropertyType {
  propertyName: string;
  accessor: DtoPropertyAccessor;
  dtoAssociationType?: Constructor<DtoResponseInterceptor>;
  description?: string;
}
```

```typescript
// src/shared/const/dto-properties-array-symbol.const.ts
export const DtoPropertiesArraySymbol = Symbol('dtoPropertiesArray');
```

```typescript
// src/shared/types/constructor.type.ts
export type Constructor<T> = new (...args: unknown[]) => T;
```

## Quick Reference

| Decorator | Purpose |
|-----------|---------|
| `@DtoRequest(Type)` | Document the request body |
| `@DtoResponse(status, description, Type?, isArray?)` | Document the success response and map the returned entity to `Type` |
| `@DtoResponseError(status, description)` | Document an error response |
| `@DtoType('Name')` | Swagger schema name for the DTO |
| `@DtoProperty(accessor, description?)` | Map a scalar field |
| `@DtoProperty(Dto, accessor, description?)` | Map a nested entity to a nested DTO |
| `@DtoArray(Dto, accessor, description?)` | Map an array of entities to an array of DTOs |
| `@DtoEnum(accessor, Enum, 'EnumName')` | Map an enum field |
