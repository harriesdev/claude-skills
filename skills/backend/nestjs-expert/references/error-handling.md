# Error Handling

Every error response has the same shape. A global `HttpExceptionFilter` builds it from whatever was thrown, and a request id ties the response to the server logs.

```json
{ "error": "VALIDATION_ERROR", "message": "Validation failed", "details": { "title": ["title should not be empty"] }, "requestId": "4f1c…" }
{ "error": "NOT_FOUND", "message": "Post not found", "requestId": "4f1c…" }
{ "error": "INTERNAL_ERROR", "message": "An unexpected error occurred", "requestId": "4f1c…" }
```

## Constraints

### MUST DO
- Register `HttpExceptionFilter` as `APP_FILTER` in `AppModule`
- Register `requestIdMiddleware` first in `main.ts`
- Throw Nest `HttpException` subclasses with enum messages for every expected error
- Throw `ValidationException` (never a plain `BadRequestException`) for class-validator failures

### MUST NOT DO
- Send stack traces, SQL, or messages from non-HTTP errors to the client — the filter replaces them with a generic message and logs the original
- Build error bodies by hand in controllers or services

## Files

```
src/shared/
├── enums/
│   ├── error-code.enum.ts
│   ├── error-messages.enum.ts
│   └── request-header.enum.ts
├── exceptions/
│   └── validation.exception.ts
├── filter/
│   └── http-exception.filter.ts
├── functions/
│   └── validation-details.functions.ts
├── interfaces/
│   └── api-error.interface.ts
└── middleware/
    └── request-id.middleware.ts
```

## ApiError

```typescript
// src/shared/interfaces/api-error.interface.ts
export interface ApiError {
  error: ErrorCode;
  message: string;
  details?: Record<string, string[]>;
  requestId?: string;
}

// src/shared/enums/error-code.enum.ts
export enum ErrorCode {
  BadRequest = 'BAD_REQUEST',
  ValidationError = 'VALIDATION_ERROR',
  Unauthorized = 'UNAUTHORIZED',
  Forbidden = 'FORBIDDEN',
  NotFound = 'NOT_FOUND',
  Conflict = 'CONFLICT',
  UnprocessableEntity = 'UNPROCESSABLE_ENTITY',
  TooManyRequests = 'TOO_MANY_REQUESTS',
  InternalError = 'INTERNAL_ERROR',
  BadGateway = 'BAD_GATEWAY',
  ServiceUnavailable = 'SERVICE_UNAVAILABLE',
}

// src/shared/enums/error-messages.enum.ts
export enum ErrorMessages {
  ValidationFailed = 'Validation failed',
  Unexpected = 'An unexpected error occurred',
}

// src/shared/enums/request-header.enum.ts
export enum RequestHeader {
  RequestId = 'x-request-id',
}
```

## ValidationException

Validation failures carry field-level details. Both `ApiValidationPipe` and `FormPipe` throw it (see `references/dtos-validation.md`).

```typescript
// src/shared/exceptions/validation.exception.ts
import { BadRequestException } from '@nestjs/common';
import { ErrorMessages } from '../enums/error-messages.enum';

export class ValidationException extends BadRequestException {
  constructor(private readonly details: Record<string, string[]>) {
    super(ErrorMessages.ValidationFailed);
  }

  public getDetails(): Record<string, string[]> {
    return this.details;
  }
}
```

```typescript
// src/shared/functions/validation-details.functions.ts
import { ValidationError } from 'class-validator';

export function toValidationDetails(
  errors: ValidationError[],
  parentPath = '',
): Record<string, string[]> {
  return errors.reduce<Record<string, string[]>>((details, error) => {
    const path = parentPath ? `${parentPath}.${error.property}` : error.property;
    if (error.constraints) {
      details[path] = Object.values(error.constraints);
    }
    if (error.children?.length) {
      Object.assign(details, toValidationDetails(error.children, path));
    }
    return details;
  }, {});
}
```

Nested errors use dotted paths: `items.0.quantity`.

## HttpExceptionFilter

```typescript
// src/shared/filter/http-exception.filter.ts
import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { ErrorCode } from '../enums/error-code.enum';
import { ErrorMessages } from '../enums/error-messages.enum';
import { RequestHeader } from '../enums/request-header.enum';
import { ValidationException } from '../exceptions/validation.exception';
import { ApiError } from '../interfaces/api-error.interface';

const ERROR_CODES: Partial<Record<HttpStatus, ErrorCode>> = {
  [HttpStatus.BAD_REQUEST]: ErrorCode.BadRequest,
  [HttpStatus.UNAUTHORIZED]: ErrorCode.Unauthorized,
  [HttpStatus.FORBIDDEN]: ErrorCode.Forbidden,
  [HttpStatus.NOT_FOUND]: ErrorCode.NotFound,
  [HttpStatus.CONFLICT]: ErrorCode.Conflict,
  [HttpStatus.UNPROCESSABLE_ENTITY]: ErrorCode.UnprocessableEntity,
  [HttpStatus.TOO_MANY_REQUESTS]: ErrorCode.TooManyRequests,
  [HttpStatus.BAD_GATEWAY]: ErrorCode.BadGateway,
  [HttpStatus.SERVICE_UNAVAILABLE]: ErrorCode.ServiceUnavailable,
};

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  public catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToHttp();
    const request = context.getRequest<Request>();
    const response = context.getResponse<Response>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const requestId = request.header(RequestHeader.RequestId);

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(
        `${request.method} ${request.url} failed [${requestId}]`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    response.status(status).json(this.toApiError(exception, status, requestId));
  }

  private toApiError(
    exception: unknown,
    status: number,
    requestId?: string,
  ): ApiError {
    if (exception instanceof ValidationException) {
      return {
        error: ErrorCode.ValidationError,
        message: ErrorMessages.ValidationFailed,
        details: exception.getDetails(),
        requestId,
      };
    }

    if (
      !(exception instanceof HttpException) ||
      status === HttpStatus.INTERNAL_SERVER_ERROR
    ) {
      return {
        error: ErrorCode.InternalError,
        message: ErrorMessages.Unexpected,
        requestId,
      };
    }

    return {
      error: ERROR_CODES[status] ?? ErrorCode.InternalError,
      message: this.getMessage(exception),
      requestId,
    };
  }

  private getMessage(exception: HttpException): string {
    const body = exception.getResponse();
    if (typeof body === 'string') {
      return body;
    }
    const message = (body as { message?: string | string[] }).message;
    return Array.isArray(message) ? message.join(', ') : message ?? exception.message;
  }
}
```

| Thrown | Status | `error` | `message` sent |
|--------|--------|---------|----------------|
| `ValidationException` | 400 | `VALIDATION_ERROR` | `Validation failed` + `details` |
| Other `HttpException` (4xx, 502, 503) | its status | from `ERROR_CODES` | the exception's message |
| `HttpException` with 500 (e.g. `IllegalArgumentException`) | 500 | `INTERNAL_ERROR` | generic, original logged |
| Anything else (TypeORM, TypeError…) | 500 | `INTERNAL_ERROR` | generic, original logged |

## Request Id

```typescript
// src/shared/middleware/request-id.middleware.ts
import { randomUUID } from 'crypto';
import { NextFunction, Request, Response } from 'express';
import { RequestHeader } from '../enums/request-header.enum';

const REQUEST_ID_PATTERN = /^[A-Za-z0-9-]{1,64}$/;

export function requestIdMiddleware(
  request: Request,
  response: Response,
  next: NextFunction,
): void {
  const incoming = request.header(RequestHeader.RequestId);
  const requestId =
    incoming && REQUEST_ID_PATTERN.test(incoming) ? incoming : randomUUID();

  request.headers[RequestHeader.RequestId] = requestId;
  response.setHeader(RequestHeader.RequestId, requestId);
  next();
}
```

An incoming `x-request-id` is reused only when it matches the pattern, so callers can't inject arbitrary text into logs. Include the request id in log lines that relate to a request.

## Registration

```typescript
// app.module.ts
providers: [
  { provide: APP_FILTER, useClass: HttpExceptionFilter },
]

// main.ts
app.use(requestIdMiddleware);
```
