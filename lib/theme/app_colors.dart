import 'package:flutter/material.dart';

/// Tactical High-Contrast Outdoor OLED Palette for TrailPulse
/// Mapped directly from Stitch design tokens.
class AppColors {
  AppColors._();

  // Dark OLED Surfaces
  static const Color background = Color(0xFF0B1326);
  static const Color surface = Color(0xFF0B1326);
  static const Color surfaceDim = Color(0xFF0B1326);
  static const Color surfaceBright = Color(0xFF31394D);
  static const Color surfaceContainerLowest = Color(0xFF060E20);
  static const Color surfaceContainerLow = Color(0xFF131B2E);
  static const Color surfaceContainer = Color(0xFF171F33);
  static const Color surfaceContainerHigh = Color(0xFF222A3D);
  static const Color surfaceContainerHighest = Color(0xFF2D3449);

  // High-Vis Neon Accents
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFCCF22A); // Electric Lime
  static const Color primaryFixed = Color(0xFFCCF22A);
  static const Color primaryFixedDim = Color(0xFFB1D400);
  static const Color onPrimary = Color(0xFF2A3400);
  static const Color onPrimaryContainer = Color(0xFF171E00);

  // Cyan Secondary Accents (Ghost route, telemetry sync, cadence)
  static const Color secondary = Color(0xFFD3FBFF);
  static const Color secondaryContainer = Color(0xFF00EEFC); // Neon Cyan
  static const Color secondaryFixed = Color(0xFF7DF4FF);
  static const Color secondaryFixedDim = Color(0xFF00DBE9);
  static const Color onSecondary = Color(0xFF00363A);
  static const Color onSecondaryContainer = Color(0xFF002022);

  // Amber / Warm Slopes (4-7% grade, flags)
  static const Color tertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFDDBB);
  static const Color tertiaryFixed = Color(0xFFFFDDBB);
  static const Color tertiaryFixedDim = Color(0xFFFFB868); // Amber
  static const Color onTertiary = Color(0xFF482900);
  static const Color onTertiaryContainer = Color(0xFF2B1700);

  // Severe Slopes (>12%) & Heart Rate Peaks
  static const Color error = Color(0xFFFFB4AB); // Bright Coral
  static const Color errorContainer = Color(0xFF93000A); // Deep Crimson
  static const Color onError = Color(0xFF690005);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Text & Outlines
  static const Color onSurface = Color(0xFFDAE2FD); // Crisp ice white
  static const Color onSurfaceVariant = Color(0xFFC5C9AD); // Tactical olive gray
  static const Color outline = Color(0xFF8F937A);
  static const Color outlineVariant = Color(0xFF454934);

  // Elevation Steepness Gradient Colors
  static const Color slopeFlat = Color(0xFFB1D400);     // 0 - 3% (Green/Lime)
  static const Color slopeModerate = Color(0xFFFFB868); // 4 - 7% (Amber)
  static const Color slopeSteep = Color(0xFFFFB4AB);    // 8 - 12% (Red)
  static const Color slopeExtreme = Color(0xFF93000A);  // 15%+ (Deep Crimson)
}
