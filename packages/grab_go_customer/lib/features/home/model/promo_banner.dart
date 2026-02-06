class PromoBanner {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String discount;
  final String backgroundColor;
  final String targetUrl;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int priority;
  final String targetAudience;

  PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.discount,
    required this.backgroundColor,
    required this.targetUrl,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.priority,
    required this.targetAudience,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    return PromoBanner(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? json['description'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      discount: (json['discount'] ?? '').toString(),
      backgroundColor: (json['backgroundColor'] ?? json['bgColor'] ?? '#FFFFFF').toString(),
      targetUrl: (json['targetUrl'] ?? json['linkValue'] ?? '').toString(),
      startDate: json['startDate'] != null 
          ? (json['startDate'] is DateTime ? json['startDate'] as DateTime : DateTime.parse(json['startDate'].toString()))
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? (json['endDate'] is DateTime ? json['endDate'] as DateTime : DateTime.parse(json['endDate'].toString()))
          : DateTime.now().add(const Duration(days: 30)),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      priority: json['priority'] is int ? json['priority'] as int : 0,
      targetAudience: (json['targetAudience'] ?? 'all').toString(),
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
