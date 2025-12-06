import 'package:chopper/chopper.dart';

part 'status_service.chopper.dart';

/// Status API Service using Chopper
/// Handles all status-related API calls
@ChopperApi(baseUrl: '/statuses')
abstract class StatusService extends ChopperService {
  /// Get all active statuses with optional filters
  /// GET /api/statuses
  @GET(path: '')
  Future<Response> getStatuses({
    @Query('category') String? category,
    @Query('restaurant') String? restaurant,
    @Query('recommended') String? recommended,
    @Query('limit') int? limit,
    @Query('page') int? page,
  });

  /// Get restaurant stories (grouped by restaurant)
  /// GET /api/statuses/stories
  @GET(path: '/stories')
  Future<Response> getStories({
    @Query('limit') int? limit,
    @Query('sortBy') String? sortBy, // 'recent' or 'engagement'
  });

  /// Get all statuses for a specific restaurant
  /// GET /api/statuses/stories/:restaurantId
  @GET(path: '/stories/{restaurantId}')
  Future<Response> getRestaurantStories(@Path('restaurantId') String restaurantId);

  /// Get a single status by ID
  /// GET /api/statuses/:statusId
  @GET(path: '/{statusId}')
  Future<Response> getStatus(@Path('statusId') String statusId);

  /// Get statuses viewed by current user
  /// GET /api/statuses/user/viewed
  @GET(path: '/user/viewed')
  Future<Response> getViewedStatuses();

  /// Record a view on a status
  /// POST /api/statuses/:statusId/view
  @POST(path: '/{statusId}/view')
  Future<Response> recordView(@Path('statusId') String statusId, @Body() Map<String, dynamic> body);

  /// Record multiple views at once (batch)
  /// POST /api/statuses/views/batch
  @POST(path: '/views/batch')
  Future<Response> recordBatchViews(@Body() Map<String, dynamic> body);

  /// Like or unlike a status
  /// POST /api/statuses/:statusId/like
  @POST(path: '/{statusId}/like')
  Future<Response> toggleLike(@Path('statusId') String statusId);

  /// Get comments for a status
  /// GET /api/statuses/:statusId/comments
  @GET(path: '/{statusId}/comments')
  Future<Response> getComments(
    @Path('statusId') String statusId, {
    @Query('page') int? page,
    @Query('limit') int? limit,
  });

  /// Add a comment to a status
  /// POST /api/statuses/:statusId/comments
  @POST(path: '/{statusId}/comments')
  Future<Response> addComment(@Path('statusId') String statusId, @Body() Map<String, dynamic> body);

  /// Delete a comment
  /// DELETE /api/statuses/comments/:commentId
  @DELETE(path: '/comments/{commentId}')
  Future<Response> deleteComment(@Path('commentId') String commentId);

  /// Get replies for a comment
  /// GET /api/statuses/comments/:commentId/replies
  @GET(path: '/comments/{commentId}/replies')
  Future<Response> getReplies(
    @Path('commentId') String commentId, {
    @Query('page') int? page,
    @Query('limit') int? limit,
  });

  /// Add a reply to a comment
  /// POST /api/statuses/comments/:commentId/replies
  @POST(path: '/comments/{commentId}/replies')
  Future<Response> addReply(@Path('commentId') String commentId, @Body() Map<String, dynamic> body);

  /// Toggle reaction on a comment
  /// POST /api/statuses/comments/:commentId/react
  @POST(path: '/comments/{commentId}/react')
  Future<Response> toggleReaction(@Path('commentId') String commentId, @Body() Map<String, dynamic> body);

  /// Get reactions for a comment
  /// GET /api/statuses/comments/:commentId/reactions
  @GET(path: '/comments/{commentId}/reactions')
  Future<Response> getReactions(@Path('commentId') String commentId);

  static StatusService create([ChopperClient? client]) => _$StatusService(client);
}
