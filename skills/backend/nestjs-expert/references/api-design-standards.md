# API Design Standards

## RESTful API Conventions

### URL Structure
```
# Collection vs Resource
GET    /api/users          # List all users
POST   /api/users          # Create user
GET    /api/users/:id      # Get single user
PUT    /api/users/:id      # Full update
PATCH  /api/users/:id      # Partial update
DELETE /api/users/:id      # Delete user

# Nested resources
GET    /api/users/:id/posts        # User's posts
POST   /api/users/:id/posts        # Create post for user
GET    /api/posts/:id/comments     # Comments on post
```

### HTTP Status Codes
```typescript
// Success codes
200 OK              // GET, PUT, PATCH successful
201 Created         // POST successful, resource created
204 No Content      // DELETE successful, no body
202 Accepted        // Async operation queued

// Client error codes
400 Bad Request     // Malformed request or validation failed
401 Unauthorized    // Authentication required
403 Forbidden       // Authenticated but not authorized
404 Not Found       // Resource doesn't exist
409 Conflict        // Resource conflict (e.g., duplicate)
422 Unprocessable   // Well-formed but semantically invalid
429 Too Many Requests // Rate limit exceeded

// Server error codes
500 Internal Server Error  // Unhandled exception
502 Bad Gateway           // Upstream service failed
503 Service Unavailable   // Temporary downtime
```

### Backend Error Handling

```typescript
// NestJS
@Patch(':id')
public async updateUser(
  @Param('id') id: string,
  @Body() dto: UpdateUserDto,
  @CurrentUser() user: User,
) {
  if (user.id !== id && !user.isAdmin) {
    throw new ForbiddenException('Not authorized');
  }

  try {
    return await this.userService.update(id, dto);
  } catch (error) {
    if (error instanceof UserNotFoundError) {
      throw new NotFoundException('User not found');
    }
    if (error instanceof EmailTakenError) {
      throw new UnprocessableEntityException('Email already in use');
    }
    throw error;
  }
}
```

### Error Response Format

Every error uses this shape. `HttpExceptionFilter` produces it; see `references/error-handling.md`.

```typescript
// Consistent error shape
interface ApiError {
  error: ErrorCode;
  message: string;
  details?: Record<string, string[]>;
  requestId?: string;
}

// Example responses
{ "error": "VALIDATION_ERROR", "message": "Invalid input", "details": { "email": ["Invalid format"] } }
{ "error": "NOT_FOUND", "message": "User not found" }
{ "error": "FORBIDDEN", "message": "Not authorized to perform this action" }
```

### Pagination

In this codebase, list endpoints take `PaginationQueryDto` and return `Page<T>` mapped by a `{X}PageDto` (`references/dto-responses.md`). The generic example below also shows `sort`, `filter` and `links`; add them to a list's query DTO and page DTO when that list needs them.

```typescript
// Query parameters
GET /api/users?page=1&limit=20&sort=-createdAt&filter[role]=admin

// Response format
interface PaginatedResponse<T> {
  data: T[];
  meta: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  links?: {
    first: string;
    prev?: string;
    next?: string;
    last: string;
  };
}

// Implementation
@Get()
public async findAll(
  @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
  @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
) {
  const [data, total] = await this.service.findAndCount({ page, limit });
  return {
    data,
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
    links: {
      first: `/api/users?page=1&limit=${limit}`,
      next: page < totalPages ? `/api/users?page=${page + 1}&limit=${limit}` : undefined,
      last: `/api/users?page=${totalPages}&limit=${limit}`,
    },
  };
}
```

## API Versioning

### URL Path Versioning (Recommended)
```typescript
// Version in URL path
GET /api/v1/users
GET /api/v2/users

// Express routing
app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);

// NestJS versioning
@Controller({ version: '1', path: 'users' })
export class UsersV1Controller {}

@Controller({ version: '2', path: 'users' })
export class UsersV2Controller {}
```

### Header Versioning (Alternative)
```typescript
// Request header
GET /api/users
Accept-Version: v2

// Middleware
app.use((req, res, next) => {
  const version = req.headers['accept-version'] || 'v1';
  req.apiVersion = version;
  next();
});
```

## Rate Limiting

In NestJS use `@nestjs/throttler` (see the Rate Limiting section of `references/authentication.md`). The Express examples below show the same limits for non-Nest services.

### Per-Endpoint Configuration
```typescript
// Express with express-rate-limit
import rateLimit from 'express-rate-limit';

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                 // 100 requests per window
  message: 'Too many requests from this IP',
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,                   // Stricter for auth endpoints
  skipSuccessfulRequests: true,
});

app.use('/api/', generalLimiter);
app.use('/api/auth/', authLimiter);
```

### Redis-backed Rate Limiting
```typescript
import { RateLimiterRedis } from 'rate-limiter-flexible';

const rateLimiter = new RateLimiterRedis({
  storeClient: redisClient,
  keyPrefix: 'rate-limit',
  points: 100,              // Number of requests
  duration: 60,             // Per 60 seconds
});

app.use(async (req, res, next) => {
  try {
    await rateLimiter.consume(req.ip);
    next();
  } catch (error) {
    res.status(429).json({ error: 'Too Many Requests' });
  }
});
```

## CORS Configuration

In NestJS, `CorsConfigService` builds these options from `CORS_ORIGINS` (see `references/controllers-routing.md`).

### Production-ready CORS
```typescript
import cors from 'cors';

const corsOptions = {
  origin: (origin, callback) => {
    const allowedOrigins = [
      'https://app.example.com',
      'https://admin.example.com',
    ];

    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,                    // Allow cookies
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['X-Total-Count'],
  maxAge: 86400,                        // 24 hours preflight cache
};

app.use(cors(corsOptions));
```

## Request/Response Validation

### Input Validation with Zod
```typescript
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(18).max(120).optional(),
  role: z.enum(['user', 'admin']).default('user'),
});

// Middleware
const validate = (schema: z.ZodSchema) => (req, res, next) => {
  try {
    req.validatedBody = schema.parse(req.body);
    next();
  } catch (error) {
    res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request data',
        details: error.errors,
      },
    });
  }
};

app.post('/api/users', validate(createUserSchema), createUserHandler);
```

## API Documentation

### OpenAPI/Swagger Setup
```typescript
// NestJS with Swagger
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

const config = new DocumentBuilder()
  .setTitle('API Documentation')
  .setDescription('The API description')
  .setVersion('1.0')
  .addBearerAuth()
  .build();

const document = SwaggerModule.createDocument(app, config);
SwaggerModule.setup('api/docs', app, document);

// Decorate endpoints
@ApiOperation({ summary: 'Create a new user' })
@ApiResponse({ status: 201, description: 'User created successfully' })
@ApiResponse({ status: 422, description: 'Validation failed' })
@Post()
async create(@Body() dto: CreateUserDto) {
  return this.service.create(dto);
}
```

## Quick Reference

| Aspect | Standard | Example |
|--------|----------|---------|
| URL naming | Plural nouns | `/api/users` not `/api/user` |
| HTTP methods | RESTful semantics | GET (read), POST (create), PUT/PATCH (update), DELETE |
| Status codes | Semantic usage | 200 (success), 201 (created), 400 (validation) |
| Errors | Consistent format | `{ error, message, details?, requestId }` |
| Pagination | Data + meta | `{ data, meta: { page, limit, total, totalPages } }` |
| Versioning | URL path | `/api/v1/users` |
| Rate limiting | `@nestjs/throttler` | Auth: 5/min, General: 100/min |
| CORS | Whitelist origins | Production domains only |
| Validation | class-validator | Forms and `ApiValidationPipe`, field-level `details` |
| Documentation | OpenAPI | Auto-generated from decorators |
