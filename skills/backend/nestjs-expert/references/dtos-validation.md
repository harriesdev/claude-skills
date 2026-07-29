# DTOs & Validation

## DTO Patterns

```typescript
import {
  IsEmail, IsString, IsOptional, IsBoolean, IsInt,
  MinLength, MaxLength, Min, Max, IsUUID, IsEnum,
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
  @IsUUID()
  productId: string;

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

## Enable Validation Globally

```typescript
// main.ts
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,           // Strip unknown properties
  forbidNonWhitelisted: true, // Throw on unknown properties
  transform: true,            // Auto-transform types
  transformOptions: {
    enableImplicitConversion: true,
  },
}));
```

## Constraints

### MUST DO
- Use enums for descriptions, errors, messages
- Use constants for numerical variables

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
| `PartialType()` | All fields optional |
| `OmitType()` | Exclude fields |
| `PickType()` | Include only fields |
