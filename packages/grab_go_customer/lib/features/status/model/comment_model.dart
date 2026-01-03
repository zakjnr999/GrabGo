/// User information embedded in comment
class CommentUser {
  final String id;
  final String name;
  final String? email;
  final String? profileImage;

  CommentUser({required this.id, required this.name, this.email, this.profileImage});

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final email = json['email'] as String?;

    return CommentUser(
      id: json['_id']?.toString() ?? '',
      name: name ?? email?.split('@').first ?? 'User',
      email: email,
      profileImage: json['profileImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'email': email, 'profileImage': profileImage};
  }
}

/// Reaction types for comments
enum ReactionType {
  like,
  love,
  haha,
  wow,
  sad,
  angry;

  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.haha:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😠';
    }
  }
}

/// Reaction summary for a comment
class ReactionSummary {
  final int like;
  final int love;
  final int haha;
  final int wow;
  final int sad;
  final int angry;
  final int total;
  final ReactionType? userReaction;

  ReactionSummary({
    required this.like,
    required this.love,
    required this.haha,
    required this.wow,
    required this.sad,
    required this.angry,
    required this.total,
    this.userReaction,
  });

  factory ReactionSummary.empty() {
    return ReactionSummary(like: 0, love: 0, haha: 0, wow: 0, sad: 0, angry: 0, total: 0, userReaction: null);
  }

  factory ReactionSummary.fromJson(Map<String, dynamic> json) {
    return ReactionSummary(
      like: json['like'] as int? ?? 0,
      love: json['love'] as int? ?? 0,
      haha: json['haha'] as int? ?? 0,
      wow: json['wow'] as int? ?? 0,
      sad: json['sad'] as int? ?? 0,
      angry: json['angry'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      userReaction: json['userReaction'] != null ? ReactionType.values.byName(json['userReaction']) : null,
    );
  }

  List<MapEntry<ReactionType, int>> get topReactions {
    final reactions = [
      MapEntry(ReactionType.like, like),
      MapEntry(ReactionType.love, love),
      MapEntry(ReactionType.haha, haha),
      MapEntry(ReactionType.wow, wow),
      MapEntry(ReactionType.sad, sad),
      MapEntry(ReactionType.angry, angry),
    ];
    reactions.sort((a, b) => b.value.compareTo(a.value));
    return reactions.where((e) => e.value > 0).take(3).toList();
  }
}

/// Comment model for status comments
class CommentModel {
  final String id;
  final String statusId;
  final CommentUser user;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Reply fields
  final String? parentCommentId;
  final int replyCount;
  final List<CommentModel> replies;

  // Reaction fields
  final ReactionSummary reactions;

  CommentModel({
    required this.id,
    required this.statusId,
    required this.user,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.parentCommentId,
    this.replyCount = 0,
    this.replies = const [],
    ReactionSummary? reactions,
  }) : reactions = reactions ?? ReactionSummary.empty();

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['_id']?.toString() ?? '',
      statusId: json['status']?.toString() ?? '',
      user: json['user'] != null
          ? CommentUser.fromJson(json['user'] as Map<String, dynamic>)
          : CommentUser(id: '', name: 'Unknown'),
      text: json['text']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
      parentCommentId: json['parentComment']?.toString(),
      replyCount: json['replyCount'] as int? ?? 0,
      reactions: json['reactions'] != null ? ReactionSummary.fromJson(json['reactions'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'status': statusId,
      'user': user.toJson(),
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get relative time (e.g., "2h ago", "5m ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Check if comment was edited
  bool get isEdited {
    return updatedAt.isAfter(createdAt.add(const Duration(seconds: 1)));
  }

  CommentModel copyWith({
    String? id,
    String? statusId,
    CommentUser? user,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      statusId: statusId ?? this.statusId,
      user: user ?? this.user,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Pagination info for comments
class CommentPagination {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final bool hasMore;

  CommentPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.hasMore,
  });

  factory CommentPagination.fromJson(Map<String, dynamic> json) {
    return CommentPagination(
      currentPage: json['currentPage'] as int,
      totalPages: json['totalPages'] as int,
      totalItems: json['totalItems'] as int,
      itemsPerPage: json['itemsPerPage'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'totalItems': totalItems,
      'itemsPerPage': itemsPerPage,
      'hasMore': hasMore,
    };
  }
}
