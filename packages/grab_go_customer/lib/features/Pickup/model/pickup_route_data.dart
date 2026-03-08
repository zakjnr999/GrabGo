class PickupRouteData {
  final String polyline;
  final int distanceMeters;
  final int durationSeconds;

  const PickupRouteData({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory PickupRouteData.fromJson(Map<String, dynamic> json) {
    return PickupRouteData(
      polyline: json['polyline']?.toString() ?? '',
      distanceMeters: (json['distanceMeters'] as num?)?.round() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.round() ?? 0,
    );
  }
}
