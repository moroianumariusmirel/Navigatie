import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/telemetry_data.dart';
import '../models/route_model.dart';

class TelemetryService extends ChangeNotifier {
  TelemetryData _currentData = const TelemetryData();
  RouteModel? _activeRoute;
  Timer? _simulationTimer;
  bool _isRecording = true;
  double _simStep = 0;

  TelemetryService({RouteModel? initialRoute}) {
    _activeRoute = initialRoute ?? RouteModel.sampleSchauinsland();
    startSimulation();
  }

  TelemetryData get currentData => _currentData;
  RouteModel? get activeRoute => _activeRoute;
  bool get isRecording => _isRecording;

  void toggleRecording() {
    _isRecording = !_isRecording;
    notifyListeners();
  }

  /// High-fidelity telemetry simulator (10Hz) to test the HUD & 3D Cockpit
  void startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isRecording) return;
      _simStep += 0.05;

      // Realistic cycling dynamics oscillations
      const baseSpeed = 34.0;
      final speedWobble = math.sin(_simStep) * 2.5 + (math.Random().nextDouble() - 0.5) * 0.8;
      final currentSpeed = (baseSpeed + speedWobble).clamp(15.0, 65.0);

      final hrWobble = (math.sin(_simStep * 0.8) * 4).round();
      final hr = (175 + hrWobble).clamp(140, 195);
      final isPeakHr = hr >= 174;

      final cadenceWobble = (math.cos(_simStep * 1.2) * 3).round();
      final cadence = (88 + cadenceWobble).clamp(70, 110);

      final powerWobble = (math.sin(_simStep * 1.5) * 25).round();
      final watts = (310 + powerWobble).clamp(200, 480);

      // Distance & Elevation progression
      final distanceTraveled = (_currentData.distanceTraveledKm + (currentSpeed / 3600.0) * 0.2);
      final distanceLeft = math.max(0.0, _currentData.totalDistanceKm - distanceTraveled);

      _currentData = _currentData.copyWith(
        currentSpeedKmH: double.parse(currentSpeed.toStringAsFixed(1)),
        avgSpeedKmH: 23.8,
        heartRateBpm: hr,
        isHeartRatePeakAlert: isPeakHr,
        cadenceRpm: cadence,
        powerWatts: watts,
        distanceTraveledKm: double.parse(distanceTraveled.toStringAsFixed(2)),
        distanceRemainingKm: double.parse(distanceLeft.toStringAsFixed(1)),
      );

      notifyListeners();
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    stopSimulation();
    super.dispose();
  }
}
