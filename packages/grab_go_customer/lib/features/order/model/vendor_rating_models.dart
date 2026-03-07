class VendorRatingRequest {
  final int rating;
  final List<String> feedbackTags;
  final String? comment;

  const VendorRatingRequest({
    required this.rating,
    this.feedbackTags = const [],
    this.comment,
  });

  Map<String, dynamic> toJson() => {
    'rating': rating,
    if (feedbackTags.isNotEmpty) 'feedbackTags': feedbackTags,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

class VendorRatingVendorSnapshot {
  final String id;
  final String type;
  final double rawRating;
  final double weightedRating;
  final double rating;
  final int ratingCount;
  final int totalReviews;

  const VendorRatingVendorSnapshot({
    required this.id,
    required this.type,
    required this.rawRating,
    required this.weightedRating,
    required this.rating,
    required this.ratingCount,
    required this.totalReviews,
  });

  factory VendorRatingVendorSnapshot.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return VendorRatingVendorSnapshot(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      rawRating: parseDouble(json['rawRating']),
      weightedRating: parseDouble(json['weightedRating']),
      rating: parseDouble(json['rating']),
      ratingCount: parseInt(json['ratingCount']),
      totalReviews: parseInt(json['totalReviews']),
    );
  }
}

class VendorRatingResult {
  final String orderId;
  final int rating;
  final DateTime? submittedAt;
  final VendorRatingVendorSnapshot vendor;

  const VendorRatingResult({
    required this.orderId,
    required this.rating,
    required this.submittedAt,
    required this.vendor,
  });

  factory VendorRatingResult.fromJson(Map<String, dynamic> json) {
    final vendorJson = json['vendor'] is Map
        ? Map<String, dynamic>.from(json['vendor'] as Map)
        : const <String, dynamic>{};

    return VendorRatingResult(
      orderId: json['orderId']?.toString() ?? '',
      rating: json['rating'] is num
          ? (json['rating'] as num).toInt()
          : int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      vendor: VendorRatingVendorSnapshot.fromJson(vendorJson),
    );
  }
}
