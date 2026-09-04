# TrailPulse Design System & Telemetry OS Specification

Extracted from Google Stitch Project: **Trail and Route Navigation Apps** (ID: `3001352759871586452`)

## Color Palette (High-Contrast Tactical Outdoor Theme)

| Token | Hex | Usage |
| :--- | :--- | :--- |
| `background` / `surface` | `#0b1326` | Deep night navy base (optimal for battery on OLED screens) |
| `surface_container` | `#171f33` | Card backgrounds, HUD backings |
| `surface_container_high` | `#222a3d` | High-emphasis telemetry tiles |
| `surface_container_lowest` | `#060e20` | Map viewport and recessed containers |
| `primary_container` | `#ccf22a` / `#d2f832` | **Electric High-Vis Lime** (active route, primary action, speed delta) |
| `secondary_fixed` | `#00eefc` / `#00f0ff` | **Cyan Neon** (breadcrumb path, cadence, ghost racer, telemetry sync) |
| `tertiary_fixed_dim` | `#ffb868` / `#ff9f0a` | **Amber Warm** (moderate slopes 4-7%, warnings, route flags) |
| `error` / `error_container` | `#ffb4ab` / `#93000a` | **Severe Slope (>12%) & High Heart Rate Alerts (Zone 5)** |
| `on_surface` | `#dae2fd` | Crisp high-legibility body text |
| `on_surface_variant` | `#c5c9ad` | Muted telemetry labels, units |

## Typography Scale

Designed for instant readability under sunlight and vibration on bike handlebars:

* **Display / Hero Titles:** `Chivo` (800 / 900 weight, uppercase, tracking-tight)
* **Telemetry Data Metrics:** `JetBrains Mono`
  * `data-metric-xl`: 42px bold (Main Speed, Heart Rate)
  * `data-metric-lg`: 28px bold (Grade %, Cadence)
  * `data-metric-md`: 18px semi-bold (ETA, Watts, Elevation)
* **Labels / Tactical Badges:** `JetBrains Mono` 11px uppercase (`letter-spacing: 0.08em`)
* **Body / Route Info:** `Inter` 14px / 12px

## Core Screens

1. **3D Cockpit & Dynamic Telemetry (`a98e364b275e42c2b31ef9164ad5d096`)**
   * Top 3D Perspective Map Plane with contour lines & 45° dynamic camera tilt
   * Hairpin & turn-by-turn HUD pill (`140m • Hairpin Left • Schauinsland Ridge`)
   * Bento Matrix (6 Tactical metrics: HR, Speed, Grade/Incline, Cadence, ETA/Distance, Power)
   * Vector Elevation Slicer with color-coded steepness gradient (0-3% lime, 4-7% amber, 8-12% red, 15%+ crimson)
   * Big tactile action buttons (Hold to Pause, Mark Lap, SOS Beacon)
2. **Elevation & Route Planner (`1c992d2cf94f4f2e9bfb7e7316cf4555`)**
   * Multi-waypoint route planning, surface breakdown (asphalt vs singletrack), total ascent
3. **Explore & Terrain Discovery (`58f10dfec1ae48c2ab033123088ef0ba`)**
   * Offline map region browser, trail discovery cards, difficulty tags (`SAC T2`, `MTB S1`)
4. **Terrain & Exertion Analytics (`e59d70ef61d54097b4af6ed2b43028a2`)**
   * Post-ride breakdown: VAM, gradient distribution, zone breakdown, power curve
