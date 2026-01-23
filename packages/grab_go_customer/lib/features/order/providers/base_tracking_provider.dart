import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/tracking_models.dart';

abstract class BaseTrackingProvider extends ChangeNotifier {
  bool get isLoading;
  String? get error;
  TrackingData? get trackingData;
  Set<Marker> get markers;
  Set<Polyline> get polylines;
  Set<Circle> get circles;
  bool get isSocketConnected;

  Future<void> initializeTracking(String orderId);
  void setMapController(GoogleMapController controller);
  Future<void> refreshTracking();
  void reCenterCamera();
  void stopTracking();
}
