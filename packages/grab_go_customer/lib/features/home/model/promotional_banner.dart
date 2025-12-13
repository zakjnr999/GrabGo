class PromotionalBanner {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? discount;
  final String backgroundColor;
  final String? targetUrl;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int priority;
  final String targetAudience;

  PromotionalBanner({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.discount,
    required this.backgroundColor,
    this.targetUrl,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.priority,
    required this.targetAudience,
  });

  factory PromotionalBanner.fromJson(Map<String, dynamic> json) {
    return PromotionalBanner(
      id: json['_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String,
      discount: json['discount'] as String?,
      backgroundColor: json['backgroundColor'] as String? ?? '#FFFFFF',
      targetUrl: json['targetUrl'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      isActive: json['isActive'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
      targetAudience: json['targetAudience'] as String? ?? 'all',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'discount': discount,
      'backgroundColor': backgroundColor,
      'targetUrl': targetUrl,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'priority': priority,
      'targetAudience': targetAudience,
    };
  }
}
