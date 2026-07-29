# Controllers & Routing

## Controller with Swagger

```typescript
// posts.controller.ts
import {
  Controller, Get, Post, Patch, Delete,
  Body, Param, Query, HttpCode, HttpStatus, UseGuards
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery } from '@nestjs/swagger';
import { ParseUUIDPipe, ParseIntPipe } from '@nestjs/common';

@Controller('posts')
@UseGuards(JwtAuthGuard)
@ApiTags(SwaggerTags.Posts)
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Get('/')
  @ApiOperation({ summary: 'Get all posts' })
  @DtoResponse(HttpStatus.OK, 'Returns array of posts', PostsDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Posts not found')
  public async getPostsByUser(
    @CurrentUser() user: User,
  ): Promise<PostsDto> {
    return this.postsService.getPostsByUser(user)
  }

  @Get('/:postId')
  @ApiOperation({ summary: 'Get post by id' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.OK, 'Returns post', PostDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async getPostById(
    @Param('postId', PostByIdPipe) post: Post
  ): Promise<PostDto> {
    return post;
  }

  @Post('/')
  @ApiOperation({ summary: 'Create post' })
  @DtoRequest(CreatePostForm)
  @DtoResponse(HttpStatus.OK, 'Returns created post', PostDto)
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
  public async createPost(
    @Body(CreatePostForm) post: Post
  ): Promise<PostDto> {
    return this.postsService.createPost(post);
  }

  @Put('/:postId')
  @ApiOperation({ summary: 'Update post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoRequest(UpdatePostForm)
  @DtoResponse(HttpStatus.OK, 'Returns updated post', PostDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
  public async updatePost(    
    @Param('postId', PostByIdPipe) post: Post,
    @Body(UpdatePostForm) updatePostForm: Post
  ): Promise<PostDto> {
    return this.postsService.updatePost(post, updatePostForm);
  }

  @Put('/:postId/restore')
  @ApiOperation({ summary: 'Restore post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.OK, 'Returns the restored post', PostResponseDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async restorePost(
    @Param('postId') postId: number,
  ): Promise<Post> {
    return this.postsService.restorePost(postId);
  }

  @Delete('/:postId')
  @ApiOperation({ summary: 'Soft delete post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.OK, 'Post soft deleted')
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async softDeletePost(
    @Param('id', PostByIdPipe) post: Post,
  ): Promise<void> {
    return this.postsService.softDeletePost(post);
  }

  @Delete('/:postId/permanent')
  @ApiOperation({ summary: 'Hard delete post' })
  @ApiParam({ name: 'postId', type: Number, required: true })
  @DtoResponse(HttpStatus.OK, 'Post permanently deleted')
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async hardDeletePost(
    @Param('postId', PostByIdPipe) post: Post,
  ): Promise<void> {
    return this.postsService.hardDeletePost(post);
  }
}
```

## Nested Routes

```typescript
@Controller('post/:postId/comment')
@UseGuards(JwtAuthGuard)
@ApiTags(SwaggerTags.PostComment)
export class CommentsController {
  @Get('/')
  @ApiOperation({ summary: 'Get all comments for post' })
  @DtoResponse(HttpStatus.OK, 'Returns array of comments', CommentsDto)
  @DtoResponseError(HttpStatus.NOT_FOUND, 'Post not found')
  public async getAllCommentsForPost(
    @Param('postId', ParseUUIDPipe)
  ): Promise<CommentsDto> {
    return this.commentsService.getAllCommentsForPost(postId)
  }

  @Post('/')
  @ApiOperation({ summary: 'Create comment' })
  @DtoRequest(CreateCommentDto)
  @DtoResponse(HttpStatus.OK, 'Returns created comment', CommentDto)
  @DtoResponseError(HttpStatus.BAD_REQUEST, 'Validation failed')
  public async createPost(
    @Body(CreateCommentDto) comment: Comment
  ): Promise<CommentDto> {
    return this.commentsService.createComment(comment);
  }
}
```

## Pipes

```typescript
// post-by-id.pipe.ts
import {
  ArgumentMetadata,
  BadRequestException,
  Injectable,
  ParseIntPipe,
  PipeTransform,
} from '@nestjs/common';
import { Post } from '../../domain/post/post.entity';
import { PostRepository } from '../../modules/database/repositories/post/post.entity';

@Injectable()
export class PostByIdPipe
  implements PipeTransform<string, Promise<Post>>
{
  private parseIntPipe = new ParseIntPipe();
  constructor(
    private readonly postRepository: PostRepository,
  ) {}

  async transform(
    value: string,
    metadata: ArgumentMetadata,
  ): Promise<Post> {
    const result = await this.postRepository.findById(
      await this.parseIntPipe.transform(value, metadata),
    );

    if (!Boolean(result)) {
      throw new BadRequestException('Invalid post id');
    }

    return result;
  }
}
```

## Global Prefix & Versioning

```typescript
// main.ts
const app = await NestFactory.create(AppModule);
```

## Quick Reference

| Decorator | Purpose |
|-----------|---------|
| `@Controller('path')` | Define route prefix |
| `@Get()`, `@Post()`, @Put(), @Patch(), @Delete() | HTTP method |
| `@Param('name')` | Path parameter |
| `@Query('name')` | Query parameter |
| `@Body()` | Request body |
| `@HttpCode(201)` | Override status code |
| `@ApiTags()` | Swagger grouping |
| `@ApiOperation()` | Endpoint description |
| `@DtoResponse()` | Document response |
| `@DtoResponseError` | Document error |
| `@DtoRequest()` | Document request |
| `@CurrentUser()` | Authenticated user |
