# TrailPulse - Tactical Offline Outdoor Navigation OS

An offline-first navigation app designed specifically for **cyclists and hikers**, built with Flutter, OpenStreetMap vector tiles, and on-device routing (Strategy B), featuring the **3D Cockpit & Dynamic Telemetry** design system from Google Stitch.

---

## Key Features

1. **3D Perspective Cockpit & Spatial HUD:**
   - 45° dynamic camera tilt orientation tracking user heading.
   - Topographic contour lines & illuminated neon active route polyline.
   - Real-time radar scan cone and GPS satellite telemetry (`18 SATS • ±1.2m`).
   - Personal Best (PB) Ghost racer indicator (`PB GHOST (-14s)`).
2. **Dynamic Biomechanical & Tactical Bento Matrix:**
   - **Heart Rate Alert Tile:** High threshold visual warning (Z5 PEAK, VO2 Max %, >90% Max Alert).
   - **Real-Time Speed:** Live speed with PB differential pill (`+4.1 vs PB`), avg, and max.
   - **Grade & Incline:** Gradient % with slope classification (`STEEP WALL`) and Vertical Ascent Meters/Hour (`VAM 1,150 m/h`).
   - **Cadence:** RPM gauge with Smoothness Index.
   - **ETA & Summit Progress:** Gap calculation, remaining distance, and percentage completion.
   - **Power Output:** Current wattage, FTP % badge, and Normalized Power (W/kg).
3. **Segmented Vector Elevation Slicer:**
   - Multi-gradient color-coded slope severity:
     - `0 - 3%`: Electric Lime (Flat / Rollers)
     - `4 - 7%`: Amber (Moderate Climb)
     - `8 - 12%`: Coral Red (Steep Alpine)
     - `15%+`: Deep Crimson (Extreme Wall)
   - Dynamic user position scrubber pill (`YOU • KM 24.1 (1,811m)`).
   - Summit Apex callout marker (`Apex 2,191m • +16.2% MAX`).
4. **Offline Architecture (Strategy B):**
   - **Map Rendering:** OpenStreetMap vector tiles via **PMTiles** single-file archives.
   - **On-Device Routing:** Valhalla C++ graph tiles for offline turn recalculation in airplane mode.
   - **Corridor Snapping:** 30m threshold map-matching and off-route alerts.
   - **Offline POI Search:** SQLite R*Tree spatial indexing for water springs, alpine huts, summits, and bike stations.

---

## Project Structure

```
├── assets/
│   ├── fonts/
│   ├── offline_tiles/       # PMTiles vector maps & DEM elevation
│   └── styles/
│       └── outdoor_dark.json# MapLibre outdoor 3D topo style
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── theme/
│   │   ├── app_colors.dart  # High-contrast OLED palette (#0b1326, #ccf22a, #00eefc)
│   │   ├── app_typography.dart # Chivo headlines & JetBrains Mono metrics
│   │   └── app_theme.dart
│   ├── core/
│   │   ├── models/          # TelemetryData, ManeuverInstruction, RouteModel
│   │   ├── telemetry/       # 10Hz TelemetryService & Dynamics Simulator
│   │   ├── routing/         # OnDeviceOfflineRouter & MapMatcher (Corridor snapping)
│   │   └── offline/         # OfflineTileManager (Regional downloads)
│   └── ui/
│       ├── cockpit/         # 3D Cockpit screen & tactical HUD widgets
│       ├── planner/         # Elevation & Route Planner
│       ├── explore/         # Terrain Discovery & Region Downloader
│       ├── analytics/       # Performance & Gradient distribution
│       └── navigation/      # Bottom navigation bar
├── stitch_assets/           # Stitch screens, HTML & design tokens
└── test/                    # Telemetry unit tests & Widget test suite
```

## Running the App

```bash
# Run unit & widget tests
flutter test

# Run the app on a connected device or emulator
flutter run
```
