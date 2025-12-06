/// User information embedded in comment
class CommentUser {
  final String id;
  final String name;
  final String? email;
  final String? profileImage;

  CommentUser({required this.id, required this.name, this.email, this.profileImage});

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: json['_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      profileImage: json['profileImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'email': email, 'profileImage': profileImage};
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

  CommentModel({
    required this.id,
    required this.statusId,
    required this.user,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['_id'] as String,
      statusId: json['status'] as String,
      user: CommentUser.fromJson(json['user'] as Map<String, dynamic>),
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
