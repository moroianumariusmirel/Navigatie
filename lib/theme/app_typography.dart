import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // Headlines (Chivo / Heavy athletic sans)
  static TextStyle displayHero = GoogleFonts.chivo(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    color: AppColors.primary,
    height: 1.1,
  );

  static TextStyle headlineLg = GoogleFonts.chivo(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.primary,
  );

  static TextStyle headlineMd = GoogleFonts.chivo(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static TextStyle headlineSm = GoogleFonts.chivo(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  // Telemetry Metrics (JetBrains Mono / Precision tabular figures)
  static TextStyle dataMetricXl = GoogleFonts.jetBrainsMono(
    fontSize: 42,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    color: AppColors.primary,
    height: 1.0,
  );

  static TextStyle dataMetricLg = GoogleFonts.jetBrainsMono(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.primary,
    height: 1.1,
  );

  static TextStyle dataMetricMd = GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static TextStyle labelCaps = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: AppColors.onSurfaceVariant,
  );

  static TextStyle microCaps = GoogleFonts.jetBrainsMono(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.onSurfaceVariant,
  );

  // Body Text (Inter)
  static TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  static TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle bodySm = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );
}
