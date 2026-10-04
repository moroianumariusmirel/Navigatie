# Report: Voice navigation starts immediately after loading a GPX track

## Symptom
After loading a GPX track, voice/chime alerts (e.g. "Caution. Off planned route.", "In 80 meters, turn left…") play right away, even though the user has not tapped **Start** in the cockpit header.

## Root cause
Audio alerts are **not gated by the navigation state**. The `NavigationState` (`stopped` / `active` / `paused`) is used for the UI and for recording, but the code that feeds the voice engine ignores it.

### Chain of events
1. A GPX is loaded → `TelemetryService.updateActiveRoute()` ([telemetry_service.dart:494](file:///home/marius/Documents/APP/Navigatie/lib/core/telemetry/telemetry_service.dart#L494)) sets the route and calls `_turnEngine.initRoute(newRoute)`. State remains `stopped`. This is fine so far.
2. The device GPS stream is already running (`initGpsTracking()` is called from the constructor, [L255](file:///home/marius/Documents/APP/Navigatie/lib/core/telemetry/telemetry_service.dart#L255)). Every fix calls `_onGpsPositionUpdate()` ([L1034](file:///home/marius/Documents/APP/Navigatie/lib/core/telemetry/telemetry_service.dart#L1034)).
3. Inside it, as soon as `_activeRoute != null`, it **unconditionally** calls `_turnEngine.updateProgress(...)` ([L1072](file:///home/marius/Documents/APP/Navigatie/lib/core/telemetry/telemetry_service.dart#L1072)). There is no check of `isNavigationActive`.
4. `TurnNavigationEngine.updateProgress()` ([turn_navigation_engine.dart:56](file:///home/marius/Documents/APP/Navigatie/lib/core/navigation/turn_navigation_engine.dart#L56)) has no "enabled" flag either. It plays:
   - `playOffRouteAlert()` on the rising edge of `isOffRoute` — this is the most common trigger. The user is usually far from the freshly loaded track (`distanceOffRouteMeters > 40`), so "Caution. Off planned route." plays immediately.
   - `playApproachAlert()` / `playImmediateAlert()` if the user happens to be near a maneuver.
5. `AudioNavigationService.play*Alert()` ([audio_navigation_service.dart:99-162](file:///home/marius/Documents/APP/Navigatie/lib/core/navigation/audio_navigation_service.dart#L99-L162)) only checks the mute mode, not whether navigation was started.

### Secondary contributors
- The simulation timer ([L688-729](file:///home/marius/Documents/APP/Navigatie/lib/core/telemetry/telemetry_service.dart#L688-L729)) also calls `updateProgress` but is guarded by `_isRecording`, so it is correct. It is **not** the cause, but it shows the intended guard is missing in the GPS path.
- `TelemetryService(autoStartSimulation: true)` forces `NavigationState.active` ([L251-253](file:///home/marius/Documents/APP/Navigatie/lib/core/telemetry/telemetry_service.dart#L251-L253)). Verify it is not enabled in `main.dart` or in the load path (currently it appears only in the constructor).
- Because `_wasOffRoute` is reset in `initRoute()`, every newly loaded GPX re-arms the off-route alert, so the effect repeats on each load.

## Proposed fix (not applied)

### 1. Primary: gate the engine by navigation state (in `TelemetryService`)
In `_onGpsPositionUpdate`, only call the turn engine when navigation is active:

```dart
if (isNavigationActive) {
  _turnEngine.updateProgress(
    distanceTraveledM: projection.distanceTraveledKm * 1000.0,
    isOffRoute: isOff,
    activityType: _activityType,
  );
}
```
The HUD data (`_currentData.copyWith(...)`, off-route flag, etc.) keeps updating so the map and cockpit still follow the user. Only the audio and maneuver progression are suppressed.

### 2. Defense in depth: add an `enabled` flag to the engine
In `TurnNavigationEngine`:
```dart
bool _enabled = false;
void setEnabled(bool v) { _enabled = v; if (v) { _wasOffRoute = false; } }
// in updateProgress(): if (!_enabled) return null;
```
`TelemetryService` would call `setEnabled(true)` in `startNavigation()` and `resumeNavigation()`, and `setEnabled(false)` in `pauseNavigation()` and `stopNavigation()`. This keeps audio silent from any code path, including future ones.

### 3. Re-arm the off-route alert on Start
Reset `_wasOffRoute` / `hasAlertedApproach` flags in `startNavigation()` (via `initRoute` or the `setEnabled(true)` above). This avoids an immediate off-route announcement from stale state, and optionally suppress the first alert for a couple of seconds after Start until the first valid projection.

### 4. Optional: silence on pause or stop
Call `_tts.stop()` and the player `stop()` in `pauseNavigation()` and `stopNavigation()` so a queued announcement does not play after the user stops.

## Verification plan
1. Load a GPX while standing away from it, with navigation **stopped** → no chime and no voice. HUD and map still update.
2. Tap **Start** → "Depart on Route" and normal turn alerts begin. Going off route plays the caution once.
3. Pause → silence. Resume → alerts continue.
4. Stop → silence, engine reset.
5. Add a unit test in `test/` that calls `_onGpsPositionUpdate` (or `updateProgress` through the service) with `NavigationState.stopped` and asserts that no `AudioNavigationService` alert is fired. Use a fake audio service injected via `TurnNavigationEngine(audioService: ...)`.

## Files to touch
- [telemetry_service.dart](file:///home/marius/Documents/APP/Navigatie/lib/core/telemetry/telemetry_service.dart) (fixes 1, 3, 4)
- [turn_navigation_engine.dart](file:///home/marius/Documents/APP/Navigatie/lib/core/navigation/turn_navigation_engine.dart) (fix 2)
- [audio_navigation_service.dart](file:///home/marius/Documents/APP/Navigatie/lib/core/navigation/audio_navigation_service.dart) (fix 4, optional `stopAll()`)
