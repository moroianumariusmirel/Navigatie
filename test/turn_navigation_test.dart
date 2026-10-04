import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/core/models/maneuver_instruction.dart';
import 'package:trailpulse/core/models/route_model.dart';
import 'package:trailpulse/core/navigation/audio_navigation_service.dart';
import 'package:trailpulse/core/navigation/turn_navigation_engine.dart';
import 'package:trailpulse/core/telemetry/telemetry_service.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => null,
    );
  });

  group('Turn Navigation Engine & Audio Service Tests', () {
    test('AudioNavigationService synthesizes valid RIFF/WAVE PCM audio in memory', () {
      final audioService = AudioNavigationService();

      final approachBytes = audioService.approachChime;
      final immediateBytes = audioService.immediateChime;
      final offRouteBytes = audioService.offRouteChime;
      final arrivalBytes = audioService.arrivalChime;

      expect(approachBytes.isNotEmpty, isTrue);
      expect(immediateBytes.isNotEmpty, isTrue);
      expect(offRouteBytes.isNotEmpty, isTrue);
      expect(arrivalBytes.isNotEmpty, isTrue);

      // Verify RIFF header format
      final riffHeader = ascii.decode(approachBytes.sublist(0, 4));
      final waveHeader = ascii.decode(approachBytes.sublist(8, 12));
      final fmtHeader = ascii.decode(approachBytes.sublist(12, 16));
      final dataHeader = ascii.decode(approachBytes.sublist(36, 40));

      expect(riffHeader, equals('RIFF'));
      expect(waveHeader, equals('WAVE'));
      expect(fmtHeader, equals('fmt '));
      expect(dataHeader, equals('data'));

      // Mode switching
      expect(audioService.mode, equals(NavigationAudioMode.voiceAndChimes));
      audioService.setMode(NavigationAudioMode.chimesOnly);
      expect(audioService.mode, equals(NavigationAudioMode.chimesOnly));
      audioService.setMode(NavigationAudioMode.muted);
      expect(audioService.mode, equals(NavigationAudioMode.muted));
      audioService.setMode(NavigationAudioMode.voiceAndChimes);
    });

    test('TurnNavigationEngine extracts turns and headings correctly from coordinates', () {
      // Create an L-shaped track: Start -> Go East 500m -> Turn North 500m -> Arrive
      const start = LatLng(47.9000, 7.8000);
      const turnPoint = LatLng(47.9000, 7.8070); // ~520m East
      const endPoint = LatLng(47.9045, 7.8070);  // ~500m North

      final coords = <LatLng>[
        start,
        const LatLng(47.9000, 7.8020),
        const LatLng(47.9000, 7.8040),
        turnPoint,
        const LatLng(47.9015, 7.8070),
        const LatLng(47.9030, 7.8070),
        endPoint,
      ];

      final maneuvers = TurnNavigationEngine.extractManeuversFromCoordinates(
        coordinates: coords,
        activityType: ActivityType.cycling,
        routeName: 'Ridge Crest Loop',
      );

      expect(maneuvers.isNotEmpty, isTrue);
      // First maneuver should be depart / start
      expect(maneuvers.first.maneuverType, equals(ManeuverType.straight));
      expect(maneuvers.first.stepIndex, equals(0));

      // There should be a left turn detected at the corner (heading changed from East ~90 deg to North ~0 deg -> ~ -90 deg delta = turnLeft)
      final turnLeftManeuvers = maneuvers.where((m) => m.maneuverType == ManeuverType.turnLeft || m.maneuverType == ManeuverType.slightLeft);
      expect(turnLeftManeuvers.isNotEmpty, isTrue);

      // Final maneuver should be destination
      expect(maneuvers.last.maneuverType, equals(ManeuverType.destination));
      expect(maneuvers.last.distanceAlongRouteM, greaterThan(800.0));
    });

    test('TurnNavigationEngine tracks live countdown and fires approach & immediate alerts', () {
      final engine = TurnNavigationEngine(enabled: true);

      const route = RouteModel(
        id: 'test_engine_route',
        name: 'Trailhead Alpine',
        activityType: ActivityType.cycling,
        totalDistanceKm: 1.0,
        totalAscentM: 50.0,
        totalDescentM: 50.0,
        maxElevationM: 1200.0,
        minElevationM: 1100.0,
        estimatedDuration: '10m',
        difficultyRating: 'S1',
        surfaceBreakdown: {'Gravel': 1.0},
        elevationProfile: [],
        coordinates: [
          LatLng(47.9000, 7.8000),
          LatLng(47.9050, 7.8000),
          LatLng(47.9050, 7.8050),
        ],
        maneuvers: [
          ManeuverInstruction(
            stepIndex: 0,
            distanceAlongRouteM: 200.0,
            distanceToManeuverMeters: 200,
            maneuverType: ManeuverType.turnRight,
            instructionTitle: 'Turn Right',
            trailName: 'Schauinsland Path',
            surfaceType: 'Gravel',
            apexElevationM: 1200.0,
          ),
          ManeuverInstruction(
            stepIndex: 1,
            distanceAlongRouteM: 600.0,
            distanceToManeuverMeters: 400,
            maneuverType: ManeuverType.destination,
            instructionTitle: 'Arrive at Summit',
            trailName: 'Summit Peak',
            surfaceType: 'Rock',
            apexElevationM: 1284.0,
          ),
        ],
      );

      engine.initRoute(route);
      expect(engine.currentManeuver, isNotNull);
      expect(engine.currentIndex, equals(0));
      expect(engine.currentManeuver!.distanceToManeuverMeters, equals(200));

      // 1. Advance to 100m traveled (100m away from 200m turn: outside cycling approach threshold 85m)
      var updated = engine.updateProgress(
        distanceTraveledM: 100.0,
        isOffRoute: false,
        activityType: ActivityType.cycling,
      );
      expect(updated, isNotNull);
      expect(updated!.distanceToManeuverMeters, equals(100));
      expect(updated.hasAlertedApproach, isFalse);
      expect(updated.hasAlertedImmediate, isFalse);

      // 2. Advance to 130m traveled (70m away: inside approach threshold 85m)
      updated = engine.updateProgress(
        distanceTraveledM: 130.0,
        isOffRoute: false,
        activityType: ActivityType.cycling,
      );
      expect(updated!.distanceToManeuverMeters, equals(70));
      expect(updated.hasAlertedApproach, isTrue); // Approach chime fired
      expect(updated.hasAlertedImmediate, isFalse);

      // 3. Advance to 185m traveled (15m away: inside immediate threshold 20m)
      updated = engine.updateProgress(
        distanceTraveledM: 185.0,
        isOffRoute: false,
        activityType: ActivityType.cycling,
      );
      expect(updated!.distanceToManeuverMeters, equals(15));
      expect(updated.hasAlertedApproach, isTrue);
      expect(updated.hasAlertedImmediate, isTrue); // Immediate double-beep chime fired

      // 4. Pass the maneuver (220m traveled > 200m + 15m buffer -> transitions to next maneuver)
      updated = engine.updateProgress(
        distanceTraveledM: 220.0,
        isOffRoute: false,
        activityType: ActivityType.cycling,
      );
      expect(engine.currentIndex, equals(1));
      expect(updated!.maneuverType, equals(ManeuverType.destination));
      expect(updated.distanceToManeuverMeters, equals(380)); // 600 - 220
    });

    test('TelemetryService initializes with TurnNavigationEngine and updates currentManeuver', () {
      final telemetry = TelemetryService(
        initialRoute: RouteModel.sampleSchauinsland(),
        autoStartSimulation: false,
      );

      expect(telemetry.currentManeuver, isNotNull);
      expect(telemetry.audioMode, equals(NavigationAudioMode.voiceAndChimes));

      telemetry.setAudioMode(NavigationAudioMode.chimesOnly);
      expect(telemetry.audioMode, equals(NavigationAudioMode.chimesOnly));

      // Ensure active route maneuver updates properly
      telemetry.updateActiveRoute(RouteModel.sampleFeldbergHike());
      expect(telemetry.currentManeuver, isNotNull);
      expect(telemetry.activeRoute?.name, equals('Feldberg Cirque & Alpine Ridge Trek'));
    });

    test('TelemetryService navigation lifecycle transitions (start, pause, resume, stop, toggle)', () {
      final telemetry = TelemetryService(autoStartSimulation: false);
      expect(telemetry.navigationState, equals(NavigationState.stopped));
      expect(telemetry.isNavigating, isFalse);

      // Start navigation with fallback route
      telemetry.startNavigation();
      expect(telemetry.navigationState, equals(NavigationState.active));
      expect(telemetry.isNavigating, isTrue);
      expect(telemetry.activeRoute, isNotNull);

      // Pause navigation
      telemetry.pauseNavigation();
      expect(telemetry.navigationState, equals(NavigationState.paused));
      expect(telemetry.isNavigationPaused, isTrue);
      expect(telemetry.currentData.currentSpeedKmH, equals(0.0));

      // Resume navigation
      telemetry.resumeNavigation();
      expect(telemetry.navigationState, equals(NavigationState.active));
      expect(telemetry.isNavigationActive, isTrue);

      // Toggle pauses
      telemetry.togglePlayPauseNavigation();
      expect(telemetry.navigationState, equals(NavigationState.paused));

      // Toggle resumes
      telemetry.togglePlayPauseNavigation();
      expect(telemetry.navigationState, equals(NavigationState.active));

      // Stop navigation
      telemetry.stopNavigation();
      expect(telemetry.navigationState, equals(NavigationState.stopped));
      expect(telemetry.isNavigating, isFalse);
      expect(telemetry.turnEngine.isEnabled, isFalse);
      expect(telemetry.currentData.distanceTraveledKm, equals(0.0));
    });

    test('TurnNavigationEngine does NOT fire any alerts when disabled (stopped)', () {
      final fakeAudio = _FakeAudioNavigationService();
      final engine = TurnNavigationEngine(audioService: fakeAudio, enabled: false);

      const route = RouteModel(
        id: 'test_engine_route_disabled',
        name: 'Trailhead Alpine',
        activityType: ActivityType.cycling,
        totalDistanceKm: 1.0,
        totalAscentM: 50.0,
        totalDescentM: 50.0,
        maxElevationM: 1200.0,
        minElevationM: 1100.0,
        estimatedDuration: '10m',
        difficultyRating: 'S1',
        surfaceBreakdown: {'Gravel': 1.0},
        elevationProfile: [],
        coordinates: [
          LatLng(47.9000, 7.8000),
          LatLng(47.9050, 7.8000),
          LatLng(47.9050, 7.8050),
        ],
        maneuvers: [
          ManeuverInstruction(
            stepIndex: 0,
            distanceAlongRouteM: 200.0,
            distanceToManeuverMeters: 200,
            maneuverType: ManeuverType.turnRight,
            instructionTitle: 'Turn Right',
            trailName: 'Schauinsland Path',
            surfaceType: 'Gravel',
          ),
          ManeuverInstruction(
            stepIndex: 1,
            distanceAlongRouteM: 600.0,
            distanceToManeuverMeters: 400,
            maneuverType: ManeuverType.destination,
            instructionTitle: 'Arrive at Summit',
            trailName: 'Summit Peak',
            surfaceType: 'Rock',
          ),
        ],
      );

      engine.initRoute(route);
      expect(engine.isEnabled, isFalse);

      // Attempt to update progress while off-route and inside turn threshold
      final result = engine.updateProgress(
        distanceTraveledM: 185.0,
        isOffRoute: true,
        activityType: ActivityType.cycling,
      );

      // Engine returns null and no alerts are fired
      expect(result, isNull);
      expect(fakeAudio.offRouteCalls, equals(0));
      expect(fakeAudio.approachCalls, equals(0));
      expect(fakeAudio.immediateCalls, equals(0));
      expect(fakeAudio.arrivalCalls, equals(0));

      // Once enabled (e.g. user taps Start in Cockpit), alerts can fire
      engine.setEnabled(true);
      expect(engine.isEnabled, isTrue);

      final enabledResult = engine.updateProgress(
        distanceTraveledM: 185.0,
        isOffRoute: true,
        activityType: ActivityType.cycling,
      );

      expect(enabledResult, isNotNull);
      expect(fakeAudio.offRouteCalls, equals(1));
      expect(fakeAudio.immediateCalls, equals(1));
    });

    test('TelemetryService keeps TurnNavigationEngine disabled upon loading route until startNavigation', () {
      final telemetry = TelemetryService(autoStartSimulation: false);
      expect(telemetry.navigationState, equals(NavigationState.stopped));
      expect(telemetry.turnEngine.isEnabled, isFalse);

      // Loading a new route must keep turn engine disabled
      telemetry.updateActiveRoute(RouteModel.sampleSchauinsland());
      expect(telemetry.navigationState, equals(NavigationState.stopped));
      expect(telemetry.turnEngine.isEnabled, isFalse);

      // Starting navigation enables turn engine
      telemetry.startNavigation();
      expect(telemetry.navigationState, equals(NavigationState.active));
      expect(telemetry.turnEngine.isEnabled, isTrue);

      // Pausing disables turn engine
      telemetry.pauseNavigation();
      expect(telemetry.navigationState, equals(NavigationState.paused));
      expect(telemetry.turnEngine.isEnabled, isFalse);

      // Resuming re-enables turn engine
      telemetry.resumeNavigation();
      expect(telemetry.navigationState, equals(NavigationState.active));
      expect(telemetry.turnEngine.isEnabled, isTrue);

      // Stopping disables turn engine
      telemetry.stopNavigation();
      expect(telemetry.navigationState, equals(NavigationState.stopped));
      expect(telemetry.turnEngine.isEnabled, isFalse);
    });
  });
}

class _FakeAudioNavigationService extends AudioNavigationService {
  _FakeAudioNavigationService() : super.test();

  int approachCalls = 0;
  int immediateCalls = 0;
  int offRouteCalls = 0;
  int arrivalCalls = 0;
  int stopAllCalls = 0;

  @override
  Future<void> playApproachAlert({required String spokenText}) async {
    approachCalls++;
  }

  @override
  Future<void> playImmediateAlert({required String spokenText}) async {
    immediateCalls++;
  }

  @override
  Future<void> playOffRouteAlert() async {
    offRouteCalls++;
  }

  @override
  Future<void> playArrivalAlert() async {
    arrivalCalls++;
  }

  @override
  Future<void> stopAll() async {
    stopAllCalls++;
  }
}
