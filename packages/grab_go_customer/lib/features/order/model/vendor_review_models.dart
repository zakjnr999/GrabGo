class VendorReviewVendorSnapshot {
  final String id;
  final String type;
  final String name;
  final String? image;
  final double rawRating;
  final double weightedRating;
  final double rating;
  final int ratingCount;
  final int totalReviews;

  const VendorReviewVendorSnapshot({
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

  factory VendorReviewVendorSnapshot.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return VendorReviewVendorSnapshot(
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

class VendorReviewReviewer {
  final String id;
  final String name;
  final String? profilePicture;

  const VendorReviewReviewer({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory VendorReviewReviewer.fromJson(Map<String, dynamic> json) {
    return VendorReviewReviewer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'GrabGo customer',
      profilePicture: json['profilePicture']?.toString(),
    );
  }
}

class VendorReviewEntry {
  final String id;
  final int rating;
  final List<String> feedbackTags;
  final String? comment;
  final DateTime? createdAt;
  final VendorReviewReviewer reviewer;

  const VendorReviewEntry({
    required this.id,
    required this.rating,
    required this.feedbackTags,
    required this.comment,
    required this.createdAt,
    required this.reviewer,
  });

  factory VendorReviewEntry.fromJson(Map<String, dynamic> json) {
    final reviewerJson = json['reviewer'] is Map
        ? Map<String, dynamic>.from(json['reviewer'] as Map)
        : const <String, dynamic>{};

    return VendorReviewEntry(
      id: json['id']?.toString() ?? '',
      rating: json['rating'] is num
          ? (json['rating'] as num).toInt()
          : int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      feedbackTags: (json['feedbackTags'] as List? ?? const [])
          .map((entry) => entry.toString())
          .toList(growable: false),
      comment: json['comment']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      reviewer: VendorReviewReviewer.fromJson(reviewerJson),
    );
  }
}

class VendorReviewFeed {
  final VendorReviewVendorSnapshot vendor;
  final String sort;
  final int page;
  final int limit;
  final Map<int, int> breakdown;
  final List<VendorReviewEntry> reviews;

  const VendorReviewFeed({
    required this.vendor,
    required this.sort,
    required this.page,
    required this.limit,
    required this.breakdown,
    required this.reviews,
  });

  factory VendorReviewFeed.fromJson(Map<String, dynamic> json) {
    final vendorJson = json['vendor'] is Map
        ? Map<String, dynamic>.from(json['vendor'] as Map)
        : const <String, dynamic>{};
    final rawBreakdown = json['breakdown'] is Map
        ? Map<String, dynamic>.from(json['breakdown'] as Map)
        : const <String, dynamic>{};
    final rawReviews = json['reviews'] as List? ?? const [];

    return VendorReviewFeed(
      vendor: VendorReviewVendorSnapshot.fromJson(vendorJson),
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
                VendorReviewEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false),
    );
  }
}
