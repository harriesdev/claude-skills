# DTOs & Validation

## DTO Patterns

```typescript
import {
  IsEmail, IsString, IsOptional, IsBoolean, IsInt,
  MinLength, MaxLength, Min, Max, IsEnum,
  IsArray, ArrayMinSize, ValidateNested, Matches
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional, PartialType, OmitType, PickType } from '@nestjs/swagger';

export class CreateUserDto {
  @ApiProperty({ description: CreateUserDtoMessages.EmailDescription, example: CreateUserDtoMessages.EmailExample })
  @IsEmail()
  email: string;

  @ApiProperty({ description: CreateUserDtoMessages.PasswordDescription, minLength: CreateUserDtoValues.PasswordMinLength })
  @IsString()
  @MinLength(CreateUserDtoValues.PasswordMinLength)
  @Matches(/^(?=.*[A-Z])(?=.*\d)/, { message: CreateUserDtoMessages.PasswordMatches })
  password: string;

  @ApiProperty({ description: CreateUserDtoMessages.NameDescription, minLength: CreateUserDtoValues.NameMinLength, maxLength: CreateUserDtoValues.NameMaxLength })
  @IsString()
  @MinLength(CreateUserDtoValues.NameMinLength)
  @MaxLength(CreateUserDtoValues.NameMaxLength)
  name: string;

  @ApiPropertyOptional({ description: CreateUserDtoMessages.RoleDescription, enum: UserRole, default: UserRole.USER })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole = UserRole.USER;

  @ApiProperty({ description: CreateUserDtoMessages.PhoneDescription})
  @IsNotEmpty()
  @Matches(phoneNumberPattern)
  phone: string;
}

// create-user-dto-messages.enum.ts
export enum CreateUserDtoMessages {
  EmailDescription = 'User Email',
  EmailExample = 'user@example.com',
  PasswordDescription = 'User Password',
  PasswordMatches = 'Password must contain uppercase and digit',
  NameDescription = 'User Name',
  RoleDescription = 'User Role',
  PhoneDescription = 'Phone Number',
}

// create-user-dto-values.const.ts
export const CreateUserDtoValues = {
  PasswordMinLength: 8,
  NameMinLength: 2,
  NameMaxLength:50,
}

// Partial for updates (all fields optional)
export class UpdateUserDto extends PartialType(
  OmitType(CreateUserDto, ['password'] as const)
) {}

// Pick specific fields
export class LoginDto extends PickType(CreateUserDto, ['email', 'password'] as const) {}
```

## Nested Validation

```typescript
export class CreateOrderDto {
  @ApiProperty({ type: [OrderItemDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items: OrderItemDto[];

  @ApiProperty({ type: AddressDto })
  @ValidateNested()
  @Type(() => AddressDto)
  shippingAddress: AddressDto;
}

export class OrderItemDto {
  @IsInt()
  @Min(1)
  productId: number;

  @IsInt()
  @Min(1)
  @Max(100)
  quantity: number;
}
```

## Custom Validation

```typescript
import { registerDecorator, ValidationOptions, ValidationArguments } from 'class-validator';

// Custom decorator
export function IsStrongPassword(options?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isStrongPassword',
      target: object.constructor,
      propertyName,
      options,
      validator: {
        validate(value: string) {
          return /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$/.test(value);
        },
        defaultMessage(): string {
          return 'Password must contain uppercase, lowercase, digit, and special character';
        },
      },
    });
  };
}

// Usage
@IsStrongPassword()
password: string;
```

## Custom Pattern

```typescript
export const phoneNumberPattern = /^\d{10}(x\d{1,4})?$/;
```

## Transform & Sanitize

```typescript
export class QueryDto {
  @Transform(({ value }) => parseInt(value, 10))
  @IsInt()
  @Min(1)
  page: number = 1;

  @Transform(({ value }) => value?.trim().toLowerCase())
  @IsString()
  @IsOptional()
  search?: string;

  @Transform(({ value }) => value === 'true')
  @IsBoolean()
  isActive: boolean = true;
}
```

## Forms

A form is a request DTO that also builds the domain object. Use a form for every create body that becomes an entity. Use a plain DTO (validated by the global pipe) for bodies that don't become an entity, such as login or change-password.

`FormPipe` validates the form with class-validator, then calls `toDomainObject()`, which hands the form to the domain factory. The controller receives a ready entity.

```
POST /posts  { "title": "Hello" }
  → CreatePostForm (FormPipe): validate → PostFactory.create(form)
  → controller receives Post (entity)
```

```typescript
// src/dto/post/create-post.form.ts
import { Injectable } from '@nestjs/common';
import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { Post } from '../../domain/post/post.entity';
import { PostFactory } from '../../domain/post/post.factory';
import { FormPipe } from '../../shared/pipes/form.pipe';
import { IsNotBlank } from '../../shared/validators/is-not-blank.validator';
import { CreatePostFormMessages } from './create-post-form-messages.enum';
import { CreatePostFormValues } from './create-post-form-values.const';

@Injectable()
export class CreatePostForm extends FormPipe<Post> {
  @ApiProperty({ description: CreatePostFormMessages.TitleDescription })
  @IsNotBlank()
  @MaxLength(CreatePostFormValues.TitleMaxLength)
  title: string;

  @ApiProperty({ description: CreatePostFormMessages.DescriptionDescription, required: false })
  @IsOptional()
  @IsString()
  description?: string;

  protected async toDomainObject(): Promise<Post> {
    return await new PostFactory().create(this);
  }
}
```

```typescript
// controller
@Post('/')
@Version('1')
@ApiOperation({ summary: 'Create post' })
@DtoRequest(CreatePostForm)
@DtoResponse(HttpStatus.CREATED, 'Returns created post', PostDto)
@DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
public async createPost(
  @Body(CreatePostForm) post: Post,
): Promise<Post> {
  return this.postsService.createPost(post);
}
```

### Forms that need services

Forms are `@Injectable()`, so Nest resolves their constructor dependencies when the form class is passed to `@Body()`. Pass the dependencies to `super()` so `FormPipe.create()` can rebuild the form for each request. The form resolves related entities; the factory receives them through the form.

```typescript
// src/dto/subscription/create-subscription.form.ts
@Injectable()
export class CreateSubscriptionForm extends FormPipe<Subscription> {
  @ApiProperty()
  @IsString()
  exchange: string;

  @ApiProperty()
  @IsEnum(TimeInterval)
  time: TimeInterval;

  constructor(
    private readonly exchangesService: ExchangesService,
    private readonly timesService: TimesService,
  ) {
    super(exchangesService, timesService);
  }

  public async getExchange(): Promise<Exchange> {
    return await this.exchangesService.getExchangeByCode(this.exchange);
  }

  public async getTime(): Promise<Time> {
    return await this.timesService.getTimeByInterval(this.time);
  }

  protected async toDomainObject(): Promise<Subscription> {
    return await new SubscriptionFactory().create(this);
  }
}
```

### FormPipe

```typescript
// src/shared/pipes/form.pipe.ts
import { PipeTransform } from '@nestjs/common';
import { validate, ValidationError } from 'class-validator';
import { ValidationException } from '../exceptions/validation.exception';
import { toValidationDetails } from '../functions/validation-details.functions';

export abstract class FormPipe<T extends object> implements PipeTransform {
  private readonly constructorArguments: unknown[];

  constructor(...constructorArguments: unknown[]) {
    this.constructorArguments = constructorArguments;
  }

  public async transform(value: Record<string, unknown>): Promise<T> {
    const form = this.create();

    form.init(value);
    form.handleErrors(await form.validate());

    return form.toDomainObject();
  }

  public init(formData: Record<string, unknown>): this {
    return this.patchValue(formData);
  }

  public patchValue(formData: Record<string, unknown>): this {
    for (const key in formData) {
      if (typeof formData[key] !== 'object') {
        (this as Record<string, unknown>)[key] = formData[key];
      }
    }
    return this;
  }

  public validate(): Promise<ValidationError[]> {
    return validate(this);
  }

  protected create(): FormPipe<T> {
    const FormPipeClass = this.constructor as new (
      ...args: unknown[]
    ) => FormPipe<T>;

    return new FormPipeClass(...this.constructorArguments);
  }

  private handleErrors(errors: ValidationError[]): this {
    if (errors.length > 0) {
      throw new ValidationException(toValidationDetails(errors));
    }
    return this;
  }

  protected abstract toDomainObject(): Promise<T>;
}
```

`toDomainObject()` is not wrapped in a try/catch. Domain validators throw `BadRequestException` for broken business rules, services used by the form throw `NotFoundException` for missing related records, and anything unexpected reaches `HttpExceptionFilter` as a 500 with a generic message (see `references/error-handling.md`).

`patchValue` copies only primitive values. Nested objects are not copied, so forms take ids or codes and resolve related entities themselves.

## Enable Validation Globally

Plain DTOs are validated by a global pipe. `ApiValidationPipe` extends Nest's `ValidationPipe` and skips parameters typed as TypeORM entities. Those parameters are produced by forms (`@Body(CreatePostForm) post: Post`) and by-id pipes (`@Param('exchangeId', ExchangeByIdPipe) exchange: Exchange`), which validate themselves. Without the skip, `whitelist` and `forbidNonWhitelisted` would reject every field, because entities carry no class-validator decorators.

```typescript
// src/shared/pipes/api-validation.pipe.ts
import {
  ArgumentMetadata,
  Injectable,
  ValidationPipe,
  ValidationPipeOptions,
} from '@nestjs/common';
import { getMetadataArgsStorage } from 'typeorm';
import { ValidationException } from '../exceptions/validation.exception';
import { toValidationDetails } from '../functions/validation-details.functions';

@Injectable()
export class ApiValidationPipe extends ValidationPipe {
  constructor(options?: ValidationPipeOptions) {
    super({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
      exceptionFactory: (errors) =>
        new ValidationException(toValidationDetails(errors)),
      ...options,
    });
  }

  protected toValidate(metadata: ArgumentMetadata): boolean {
    if (this.isEntity(metadata.metatype)) {
      return false;
    }
    return super.toValidate(metadata);
  }

  private isEntity(metatype?: ArgumentMetadata['metatype']): boolean {
    return getMetadataArgsStorage().tables.some(
      (table) => table.target === metatype,
    );
  }
}
```

```typescript
// main.ts
app.useGlobalPipes(new ApiValidationPipe());
```

| Body or param | Validated by |
|---------------|--------------|
| `@Body(CreatePostForm) post: Post` | `CreatePostForm` (FormPipe) |
| `@Param('exchangeId', ExchangeByIdPipe) exchange: Exchange` | `ExchangeByIdPipe` |
| `@Body() dto: LoginDto` | `ApiValidationPipe` |
| `@Query() query: QueryDto` | `ApiValidationPipe` |

Validation failures from both paths throw `ValidationException`, which `HttpExceptionFilter` turns into **400** `VALIDATION_ERROR` with field-level `details`.

## Partial Updates (PATCH)

Updates use `PATCH` with a plain DTO whose fields are all optional. The service loads the entity and the domain factory applies only the fields that were sent. Never spread a form entity over a loaded entity (`{ ...post, ...form }`) — an unset `id` on the new instance can overwrite the real one.

```typescript
// src/dto/post/update-post.dto.ts
export class UpdatePostDto {
  @ApiPropertyOptional({ description: UpdatePostDtoMessages.TitleDescription })
  @IsOptional()
  @IsNotBlank()
  @MaxLength(CreatePostFormValues.TitleMaxLength)
  title?: string;

  @ApiPropertyOptional({ description: UpdatePostDtoMessages.DescriptionDescription })
  @IsOptional()
  @IsString()
  description?: string;
}

// src/domain/post/post.factory.ts
public update(post: Post, updatePostDto: UpdatePostDto): Post {
  if (updatePostDto.title !== undefined) {
    post.setTitle(updatePostDto.title);
  }
  if (updatePostDto.description !== undefined) {
    post.setDescription(updatePostDto.description);
  }
  return post;
}
```

## Pagination Query

```typescript
// src/dto/common/pagination-query.dto.ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { PaginationValues } from './pagination-values.const';

export class PaginationQueryDto {
  @ApiPropertyOptional({ default: PaginationValues.DefaultPage, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = PaginationValues.DefaultPage;

  @ApiPropertyOptional({
    default: PaginationValues.DefaultLimit,
    minimum: 1,
    maximum: PaginationValues.MaxLimit,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(PaginationValues.MaxLimit)
  limit: number = PaginationValues.DefaultLimit;
}

// src/dto/common/pagination-values.const.ts
export const PaginationValues = {
  DefaultPage: 1,
  DefaultLimit: 20,
  MaxLimit: 100,
};
```

Extend `PaginationQueryDto` to add filters for a specific list (`class PostsQueryDto extends PaginationQueryDto`). See `references/dto-responses.md` for the paginated response.

## Custom Validator

```typescript
// src/shared/validators/is-not-blank.validator.ts
import { registerDecorator, ValidationOptions } from 'class-validator';

export const IsNotBlank = (validationOptions?: ValidationOptions) => {
  return (object: object, propertyName: string) => {
    registerDecorator({
      name: 'isNotBlank',
      target: object.constructor,
      propertyName,
      options: {
        message: `${propertyName} should not be empty`,
        ...validationOptions,
      },
      validator: {
        validate(value: unknown) {
          return (
            typeof value === 'string' &&
            value.trim().length > 0 &&
            value[0] !== ' '
          );
        },
      },
    });
  };
};
```

## Constraints

### MUST DO
- Use enums for descriptions, errors, messages
- Use constants for numerical variables
- Use a form (`create-{x}.form.ts` extending `FormPipe`) for create bodies that become an entity, and pass it to `@Body(Form)`
- Use an all-optional `update-{x}.dto.ts` with `PATCH` and apply it through the domain factory's `update()`
- Throw `ValidationException` with `toValidationDetails(errors)` for validation failures
- Accept `PaginationQueryDto` (or a subclass) on every list endpoint
- Use a plain DTO for request bodies that don't become an entity; `ApiValidationPipe` validates it
- Register `ApiValidationPipe` globally in `main.ts`

### MUST NOT DO
- Register Nest's plain `ValidationPipe` globally — it rejects entity-typed params produced by forms and by-id pipes
- Build entities from request bodies in controllers or services — forms and domain factories do that
- Wrap `toDomainObject()` in a try/catch that rethrows as `BadRequestException`
- Merge updates with object spread

## Quick Reference

| Decorator | Purpose |
|-----------|---------|
| `@IsString()` | String type |
| `@IsEmail()` | Valid email |
| `@MinLength(n)` | Min string length |
| `@IsInt()`, `@Min(n)` | Integer validation |
| `@IsEnum(Enum)` | Enum value |
| `@IsOptional()` | Optional field |
| `@ValidateNested()` | Validate nested object |
| `@Type(() => Class)` | Transform to class |
| `@Transform()` | Custom transform |
| `@IsNotBlank()` | Non-empty, non-whitespace string |
| `PartialType()` | All fields optional |
| `OmitType()` | Exclude fields |
| `PickType()` | Include only fields |
