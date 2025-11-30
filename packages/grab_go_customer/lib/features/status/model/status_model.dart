import 'package:flutter/material.dart';

/// Status Models for the GrabGo Customer App
/// These models map to the backend Status API responses

/// Enum representing status categories
/// Maps to backend: 'daily_special', 'discount', 'new_item', 'video'
enum StatusCategory {
  dailySpecial,
  discount,
  newItem,
  video;

  /// Convert from API string to enum
  static StatusCategory fromString(String value) {
    switch (value) {
      case 'daily_special':
        return StatusCategory.dailySpecial;
      case 'discount':
        return StatusCategory.discount;
      case 'new_item':
        return StatusCategory.newItem;
      case 'video':
        return StatusCategory.video;
      default:
        return StatusCategory.dailySpecial;
    }
  }

  /// Convert enum to API string
  String toApiString() {
    switch (this) {
      case StatusCategory.dailySpecial:
        return 'daily_special';
      case StatusCategory.discount:
        return 'discount';
      case StatusCategory.newItem:
        return 'new_item';
      case StatusCategory.video:
        return 'video';
    }
  }

  /// Get display label
  String get label {
    switch (this) {
      case StatusCategory.dailySpecial:
        return "Today's Special";
      case StatusCategory.discount:
        return 'Discount';
      case StatusCategory.newItem:
        return 'New Item';
      case StatusCategory.video:
        return 'Video';
    }
  }

  /// Get category color
  Color getColor(BuildContext context) {
    switch (this) {
      case StatusCategory.dailySpecial:
        return Colors.orange;
      case StatusCategory.discount:
        return Colors.green;
      case StatusCategory.newItem:
        return Colors.blue;
      case StatusCategory.video:
        return Colors.purple;
    }
  }
}

/// Restaurant info embedded in status
class StatusRestaurant {
  final String id;
  final String name;
  final String? logo;
  final String? address;
  final String? phone;

  StatusRestaurant({required this.id, required this.name, this.logo, this.address, this.phone});

  factory StatusRestaurant.fromJson(Map<String, dynamic> json) {
    return StatusRestaurant(
      id: json['_id'] ?? '',
      name: json['restaurant_name'] ?? 'Unknown Restaurant',
      logo: json['logo'],
      address: json['address'],
      phone: json['phone'],
    );
  }
}

/// Linked food item in status
class StatusLinkedFood {
  final String id;
  final String name;
  final double price;
  final String? image;
  final String? description;

  StatusLinkedFood({required this.id, required this.name, required this.price, this.image, this.description});

  factory StatusLinkedFood.fromJson(Map<String, dynamic> json) {
    return StatusLinkedFood(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      image: json['food_image'],
      description: json['description'],
    );
  }
}

/// Main Status model
class StatusModel {
  final String id;
  final StatusRestaurant restaurant;
  final StatusCategory category;
  final String? title;
  final String? description;
  final String mediaType; // 'image' or 'video'
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? blurHash;
  final double? discountPercentage;
  final String? promoCode;
  final StatusLinkedFood? linkedFood;
  final int viewCount;
  final int likeCount;
  final int avgViewDuration;
  final double engagementScore;
  final bool isActive;
  final bool isRecommended;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool isExpired;

  const StatusModel({
    required this.id,
    required this.restaurant,
    required this.category,
    this.title,
    this.description,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.blurHash,
    this.discountPercentage,
    this.promoCode,
    this.linkedFood,
    required this.viewCount,
    required this.likeCount,
    required this.avgViewDuration,
    required this.engagementScore,
    required this.isActive,
    required this.isRecommended,
    required this.expiresAt,
    required this.createdAt,
    required this.isExpired,
  });

  /// Create a copy with updated fields
  StatusModel copyWith({int? viewCount, int? likeCount, bool? isLiked}) {
    return StatusModel(
      id: id,
      restaurant: restaurant,
      category: category,
      title: title,
      description: description,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      blurHash: blurHash,
      discountPercentage: discountPercentage,
      promoCode: promoCode,
      linkedFood: linkedFood,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      avgViewDuration: avgViewDuration,
      engagementScore: engagementScore,
      isActive: isActive,
      isRecommended: isRecommended,
      expiresAt: expiresAt,
      createdAt: createdAt,
      isExpired: isExpired,
    );
  }

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      id: json['_id'] ?? '',
      restaurant: StatusRestaurant.fromJson(json['restaurant'] ?? {}),
      category: StatusCategory.fromString(json['category'] ?? 'daily_special'),
      title: json['title'],
      description: json['description'],
      mediaType: json['mediaType'] ?? 'image',
      mediaUrl: json['mediaUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      blurHash: json['blurHash'],
      discountPercentage: json['discountPercentage']?.toDouble(),
      promoCode: json['promoCode'],
      linkedFood: json['linkedFood'] != null ? StatusLinkedFood.fromJson(json['linkedFood']) : null,
      viewCount: json['viewCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
      avgViewDuration: json['avgViewDuration'] ?? 0,
      engagementScore: (json['engagementScore'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? true,
      isRecommended: json['isRecommended'] ?? false,
      expiresAt: DateTime.tryParse(json['expiresAt'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isExpired: json['isExpired'] ?? false,
    );
  }

  /// Get time ago string
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

  /// Get time until expiry
  String get expiresIn {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m left';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h left';
    } else {
      return '${difference.inDays}d left';
    }
  }

  /// Check if this is a video status
  bool get isVideo => mediaType == 'video';

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() => {
    '_id': id,
    'restaurant': {
      '_id': restaurant.id,
      'restaurant_name': restaurant.name,
      'logo': restaurant.logo,
      'address': restaurant.address,
      'phone': restaurant.phone,
    },
    'category': category.toApiString(),
    'title': title,
    'description': description,
    'mediaType': mediaType,
    'mediaUrl': mediaUrl,
    'thumbnailUrl': thumbnailUrl,
    'blurHash': blurHash,
    'discountPercentage': discountPercentage,
    'promoCode': promoCode,
    'linkedFood': linkedFood != null
        ? {
            '_id': linkedFood!.id,
            'name': linkedFood!.name,
            'price': linkedFood!.price,
            'food_image': linkedFood!.image,
            'description': linkedFood!.description,
          }
        : null,
    'viewCount': viewCount,
    'likeCount': likeCount,
    'avgViewDuration': avgViewDuration,
    'engagementScore': engagementScore,
    'isActive': isActive,
    'isRecommended': isRecommended,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'isExpired': isExpired,
  };
}

/// Story model for the story ring display
class StoryModel {
  final String restaurantId;
  final String restaurantName;
  final String? logo;
  final int statusCount;
  final List<StatusCategory> categories;
  final int totalViews;
  final int totalLikes;
  final double totalEngagement;
  final DateTime latestStatusAt;
  final StatusCategory latestCategory;
  final String? latestBlurHash; // Blur hash of latest status for loading placeholder
  final bool isViewed; // Tracked locally

  StoryModel({
    required this.restaurantId,
    required this.restaurantName,
    this.logo,
    required this.statusCount,
    required this.categories,
    required this.totalViews,
    required this.totalLikes,
    required this.totalEngagement,
    required this.latestStatusAt,
    required this.latestCategory,
    this.latestBlurHash,
    this.isViewed = false,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'] as List<dynamic>? ?? [];

    return StoryModel(
      restaurantId: json['restaurantId'] ?? '',
      restaurantName: json['restaurantName'] ?? 'Unknown',
      logo: json['logo'],
      statusCount: json['statusCount'] ?? 0,
      categories: categoriesJson.map((c) => StatusCategory.fromString(c.toString())).toList(),
      totalViews: json['totalViews'] ?? 0,
      totalLikes: json['totalLikes'] ?? 0,
      totalEngagement: (json['totalEngagement'] ?? 0).toDouble(),
      latestStatusAt: DateTime.tryParse(json['latestStatusAt'] ?? '') ?? DateTime.now(),
      latestCategory: StatusCategory.fromString(json['latestCategory'] ?? 'daily_special'),
      latestBlurHash: json['latestBlurHash'],
    );
  }

  /// Create a copy with updated isViewed
  StoryModel copyWith({bool? isViewed}) {
    return StoryModel(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      logo: logo,
      statusCount: statusCount,
      categories: categories,
      totalViews: totalViews,
      totalLikes: totalLikes,
      totalEngagement: totalEngagement,
      latestStatusAt: latestStatusAt,
      latestCategory: latestCategory,
      latestBlurHash: latestBlurHash,
      isViewed: isViewed ?? this.isViewed,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() => {
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'logo': logo,
    'statusCount': statusCount,
    'categories': categories.map((c) => c.toApiString()).toList(),
    'totalViews': totalViews,
    'totalLikes': totalLikes,
    'totalEngagement': totalEngagement,
    'latestStatusAt': latestStatusAt.toIso8601String(),
    'latestCategory': latestCategory.toApiString(),
    'latestBlurHash': latestBlurHash,
  };
}

/// Pagination info from API
class StatusPagination {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;

  StatusPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
  });

  factory StatusPagination.fromJson(Map<String, dynamic> json) {
    return StatusPagination(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalItems: json['totalItems'] ?? 0,
      itemsPerPage: json['itemsPerPage'] ?? 50,
    );
  }

  bool get hasMore => currentPage < totalPages;
}

/// Batch view request item
class BatchViewItem {
  final String statusId;
  final int duration; // in milliseconds

  BatchViewItem({required this.statusId, required this.duration});

  Map<String, dynamic> toJson() => {'statusId': statusId, 'duration': duration};
}
