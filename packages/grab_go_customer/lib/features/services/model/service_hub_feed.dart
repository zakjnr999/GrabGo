class ServiceHubRecommendedFeedSection {
  final List<Map<String, dynamic>> items;
  final int page;
  final bool hasMore;
  final int total;

  const ServiceHubRecommendedFeedSection({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
  });

  factory ServiceHubRecommendedFeedSection.fromJson(Map<String, dynamic> json) {
    return ServiceHubRecommendedFeedSection(
      items: _parseMapList(json['items']),
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['hasMore'] == true,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class ServiceHubFeed {
  final String service;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> deals;
  final List<Map<String, dynamic>> popular;
  final List<Map<String, dynamic>> topRated;
  final ServiceHubRecommendedFeedSection recommended;
  final DateTime? fetchedAt;

  const ServiceHubFeed({
    this.service = '',
    this.categories = const [],
    this.items = const [],
    this.deals = const [],
    this.popular = const [],
    this.topRated = const [],
    this.recommended = const ServiceHubRecommendedFeedSection(),
    this.fetchedAt,
  });

  factory ServiceHubFeed.fromJson(Map<String, dynamic> json) {
    final recommendedJson = json['recommended'];

    return ServiceHubFeed(
      service: json['service']?.toString() ?? '',
      categories: _parseMapList(json['categories']),
      items: _parseMapList(json['items']),
      deals: _parseMapList(json['deals']),
      popular: _parseMapList(json['popular']),
      topRated: _parseMapList(json['topRated']),
      recommended: recommendedJson is Map<String, dynamic>
          ? ServiceHubRecommendedFeedSection.fromJson(recommendedJson)
          : recommendedJson is Map
          ? ServiceHubRecommendedFeedSection.fromJson(
              Map<String, dynamic>.from(recommendedJson),
            )
          : const ServiceHubRecommendedFeedSection(),
      fetchedAt: json['fetchedAt'] == null
          ? null
          : DateTime.tryParse(json['fetchedAt'].toString()),
    );
  }
}

List<Map<String, dynamic>> _parseMapList(dynamic value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: false);
}
