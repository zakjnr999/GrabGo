class PromoBanner {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String discount;
  final String backgroundColor;
  final String? targetUrl;

  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.discount,
    required this.backgroundColor,
    this.targetUrl,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    return PromoBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      discount: json['discount']?.toString() ?? '',
      backgroundColor: json['backgroundColor']?.toString() ?? json['background_color']?.toString() ?? '#FE6132',
      targetUrl: json['targetUrl']?.toString() ?? json['target_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'discount': discount,
      'backgroundColor': backgroundColor,
      'targetUrl': targetUrl,
    };
  }
}
