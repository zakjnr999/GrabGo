class PromoCodeListItem {
  final String code;
  final String description;
  final String type;
  final double value;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final List<String> applicableOrderTypes;
  final bool firstOrderOnly;
  final DateTime? endDate;
  final int usedCount;
  final int maxUsesPerUser;
  final double totalSaved;
  final DateTime? lastUsedAt;
  final String? statusReason;

  const PromoCodeListItem({
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    required this.minOrderAmount,
    required this.maxDiscountAmount,
    required this.applicableOrderTypes,
    required this.firstOrderOnly,
    required this.endDate,
    required this.usedCount,
    required this.maxUsesPerUser,
    required this.totalSaved,
    required this.lastUsedAt,
    required this.statusReason,
  });

  factory PromoCodeListItem.fromJson(Map<String, dynamic> json) {
    return PromoCodeListItem(
      code: (json['code'] ?? '').toString().toUpperCase(),
      description: (json['description'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toDouble(),
      applicableOrderTypes:
          ((json['applicableOrderTypes'] as List?) ?? const [])
              .map((entry) => entry.toString())
              .toList(growable: false),
      firstOrderOnly: json['firstOrderOnly'] == true,
      endDate: DateTime.tryParse((json['endDate'] ?? '').toString()),
      usedCount: (json['usedCount'] as num?)?.toInt() ?? 0,
      maxUsesPerUser: (json['maxUsesPerUser'] as num?)?.toInt() ?? 1,
      totalSaved: (json['totalSaved'] as num?)?.toDouble() ?? 0.0,
      lastUsedAt: DateTime.tryParse((json['lastUsedAt'] ?? '').toString()),
      statusReason: json['statusReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'description': description,
      'type': type,
      'value': value,
      'minOrderAmount': minOrderAmount,
      'maxDiscountAmount': maxDiscountAmount,
      'applicableOrderTypes': applicableOrderTypes,
      'firstOrderOnly': firstOrderOnly,
      'endDate': endDate?.toIso8601String(),
      'usedCount': usedCount,
      'maxUsesPerUser': maxUsesPerUser,
      'totalSaved': totalSaved,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'statusReason': statusReason,
    };
  }
}

class PromoCodesBucketResponse {
  final List<PromoCodeListItem> available;
  final List<PromoCodeListItem> used;
  final List<PromoCodeListItem> expired;
  final DateTime? fetchedAt;

  const PromoCodesBucketResponse({
    required this.available,
    required this.used,
    required this.expired,
    required this.fetchedAt,
  });

  factory PromoCodesBucketResponse.fromJson(Map<String, dynamic> json) {
    final availableRaw = (json['available'] as List?) ?? const [];
    final usedRaw = (json['used'] as List?) ?? const [];
    final expiredRaw = (json['expired'] as List?) ?? const [];

    return PromoCodesBucketResponse(
      available: availableRaw
          .whereType<Map>()
          .map(
            (entry) =>
                PromoCodeListItem.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false),
      used: usedRaw
          .whereType<Map>()
          .map(
            (entry) =>
                PromoCodeListItem.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false),
      expired: expiredRaw
          .whereType<Map>()
          .map(
            (entry) =>
                PromoCodeListItem.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false),
      fetchedAt: DateTime.tryParse((json['fetchedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'available': available
          .map((item) => item.toJson())
          .toList(growable: false),
      'used': used.map((item) => item.toJson()).toList(growable: false),
      'expired': expired.map((item) => item.toJson()).toList(growable: false),
      'fetchedAt': fetchedAt?.toIso8601String(),
    };
  }
}

class PromoValidationResult {
  final bool valid;
  final String code;
  final String? description;
  final String? type;
  final double discount;
  final String message;

  const PromoValidationResult({
    required this.valid,
    required this.code,
    required this.description,
    required this.type,
    required this.discount,
    required this.message,
  });
}
