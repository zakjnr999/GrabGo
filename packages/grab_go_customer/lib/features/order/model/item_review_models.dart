class ItemReviewSubmissionEntryRequest {
  final String orderItemId;
  final int rating;
  final List<String> feedbackTags;
  final String? comment;

  const ItemReviewSubmissionEntryRequest({
    required this.orderItemId,
    required this.rating,
    this.feedbackTags = const [],
    this.comment,
  });

  Map<String, dynamic> toJson() => {
    'orderItemId': orderItemId,
    'rating': rating,
    if (feedbackTags.isNotEmpty) 'feedbackTags': feedbackTags,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

class ReviewableOrderItem {
  final String orderItemId;
  final String itemId;
  final String itemType;
  final String name;
  final String? image;

  const ReviewableOrderItem({
    required this.orderItemId,
    required this.itemId,
    required this.itemType,
    required this.name,
    this.image,
  });
}

class ItemReviewSubmissionRequest {
  final List<ItemReviewSubmissionEntryRequest> reviews;

  const ItemReviewSubmissionRequest({required this.reviews});

  Map<String, dynamic> toJson() => {
    'reviews': reviews.map((entry) => entry.toJson()).toList(growable: false),
  };
}

class ItemReviewItemSnapshot {
  final String id;
  final String type;
  final String name;
  final String? image;
  final double rawRating;
  final double weightedRating;
  final double rating;
  final int ratingCount;
  final int totalReviews;

  const ItemReviewItemSnapshot({
    required this.id,
    required this.type,
    required this.name,
    this.image,
    required this.rawRating,
    required this.weightedRating,
    required this.rating,
    required this.ratingCount,
    required this.totalReviews,
  });

  factory ItemReviewItemSnapshot.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ItemReviewItemSnapshot(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString(),
      rawRating: parseDouble(json['rawRating']),
      weightedRating: parseDouble(json['weightedRating']),
      rating: parseDouble(json['rating']),
      ratingCount: parseInt(json['ratingCount']),
      totalReviews: parseInt(json['totalReviews']),
    );
  }
}

class SubmittedItemReviewEntry {
  final String orderItemId;
  final int rating;
  final DateTime? submittedAt;
  final ItemReviewItemSnapshot item;

  const SubmittedItemReviewEntry({
    required this.orderItemId,
    required this.rating,
    required this.submittedAt,
    required this.item,
  });

  factory SubmittedItemReviewEntry.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'] is Map
        ? Map<String, dynamic>.from(json['item'] as Map)
        : const <String, dynamic>{};

    return SubmittedItemReviewEntry(
      orderItemId: json['orderItemId']?.toString() ?? '',
      rating: json['rating'] is num
          ? (json['rating'] as num).toInt()
          : int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      item: ItemReviewItemSnapshot.fromJson(itemJson),
    );
  }
}

class ItemReviewSubmissionResult {
  final String orderId;
  final int submittedCount;
  final int pendingItemReviewCount;
  final List<SubmittedItemReviewEntry> reviews;

  const ItemReviewSubmissionResult({
    required this.orderId,
    required this.submittedCount,
    required this.pendingItemReviewCount,
    required this.reviews,
  });

  factory ItemReviewSubmissionResult.fromJson(Map<String, dynamic> json) {
    final rawReviews = json['reviews'] as List? ?? const [];
    return ItemReviewSubmissionResult(
      orderId: json['orderId']?.toString() ?? '',
      submittedCount: json['submittedCount'] is num
          ? (json['submittedCount'] as num).toInt()
          : int.tryParse(json['submittedCount']?.toString() ?? '') ?? 0,
      pendingItemReviewCount: json['pendingItemReviewCount'] is num
          ? (json['pendingItemReviewCount'] as num).toInt()
          : int.tryParse(json['pendingItemReviewCount']?.toString() ?? '') ?? 0,
      reviews: rawReviews
          .whereType<Map>()
          .map(
            (entry) => SubmittedItemReviewEntry.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ItemReviewReviewer {
  final String id;
  final String name;
  final String? profilePicture;

  const ItemReviewReviewer({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory ItemReviewReviewer.fromJson(Map<String, dynamic> json) {
    return ItemReviewReviewer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'GrabGo customer',
      profilePicture: json['profilePicture']?.toString(),
    );
  }
}

class ItemReviewEntry {
  final String id;
  final int rating;
  final List<String> feedbackTags;
  final String? comment;
  final DateTime? createdAt;
  final ItemReviewReviewer reviewer;

  const ItemReviewEntry({
    required this.id,
    required this.rating,
    required this.feedbackTags,
    required this.comment,
    required this.createdAt,
    required this.reviewer,
  });

  factory ItemReviewEntry.fromJson(Map<String, dynamic> json) {
    final reviewerJson = json['reviewer'] is Map
        ? Map<String, dynamic>.from(json['reviewer'] as Map)
        : const <String, dynamic>{};

    return ItemReviewEntry(
      id: json['id']?.toString() ?? '',
      rating: json['rating'] is num
          ? (json['rating'] as num).toInt()
          : int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      feedbackTags: (json['feedbackTags'] as List? ?? const [])
          .map((entry) => entry.toString())
          .toList(growable: false),
      comment: json['comment']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      reviewer: ItemReviewReviewer.fromJson(reviewerJson),
    );
  }
}

class ItemReviewFeed {
  final ItemReviewItemSnapshot item;
  final String sort;
  final int page;
  final int limit;
  final Map<int, int> breakdown;
  final List<ItemReviewEntry> reviews;

  const ItemReviewFeed({
    required this.item,
    required this.sort,
    required this.page,
    required this.limit,
    required this.breakdown,
    required this.reviews,
  });

  factory ItemReviewFeed.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'] is Map
        ? Map<String, dynamic>.from(json['item'] as Map)
        : const <String, dynamic>{};
    final rawBreakdown = json['breakdown'] is Map
        ? Map<String, dynamic>.from(json['breakdown'] as Map)
        : const <String, dynamic>{};
    final rawReviews = json['reviews'] as List? ?? const [];

    return ItemReviewFeed(
      item: ItemReviewItemSnapshot.fromJson(itemJson),
      sort: json['sort']?.toString() ?? 'popular',
      page: json['page'] is num
          ? (json['page'] as num).toInt()
          : int.tryParse(json['page']?.toString() ?? '') ?? 1,
      limit: json['limit'] is num
          ? (json['limit'] as num).toInt()
          : int.tryParse(json['limit']?.toString() ?? '') ?? 20,
      breakdown: rawBreakdown.map(
        (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0,
        ),
      ),
      reviews: rawReviews
          .whereType<Map>()
          .map(
            (entry) =>
                ItemReviewEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false),
    );
  }
}
