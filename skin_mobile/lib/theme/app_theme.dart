import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cream & brown color palette for DermaScanAI mobile - shared with the
/// web app's patient-facing pages (see skin_web/src/index.css
/// .theme-patient), while the web admin panel keeps its own indigo/teal
/// scheme by design.
class AppColors {
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;

  final Color text;
  final Color textMuted;
  final Color textLight;

  final Color primary;
  final Color primaryDeep;
  final Color primarySoft;

  final Color low;
  final Color lowSoft;
  final Color med;
  final Color medSoft;
  final Color high;
  final Color highSoft;

  final Color uncertain;
  final Color uncertainSoft;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textLight,
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.low,
    required this.lowSoft,
    required this.med,
    required this.medSoft,
    required this.high,
    required this.highSoft,
    required this.uncertain,
    required this.uncertainSoft,
  });

  static const AppColors light = AppColors(
    background: Color(0xFFF5EAD9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0E2CC),
    border: Color(0xFFE3D2B8),
    text: Color(0xFF2B1A10),
    textMuted: Color(0xFF8A7360),
    textLight: Color(0xFFB5A190),
    primary: Color(0xFF7B4B2A),
    primaryDeep: Color(0xFF4E2F1A),
    primarySoft: Color(0xFFF0DFC8),
    low: Color(0xFF6E8B4F),
    lowSoft: Color(0xFFE7EEDD),
    med: Color(0xFFC08A3E),
    medSoft: Color(0xFFF7E9D2),
    high: Color(0xFFB5482F),
    highSoft: Color(0xFFF6DCD3),
    uncertain: Color(0xFF8C6A9C),
    uncertainSoft: Color(0xFFEDE3F0),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF1E140D),
    surface: Color(0xFF2A1D13),
    surface2: Color(0xFF34251A),
    border: Color(0xFF4A3423),
    text: Color(0xFFF5EAD9),
    textMuted: Color(0xFFB5A190),
    textLight: Color(0xFF8A7360),
    primary: Color(0xFFC99A6C),
    primaryDeep: Color(0xFF8A5A34),
    primarySoft: Color(0xFF3D2B1A),
    low: Color(0xFF9BBF7E),
    lowSoft: Color(0xFF24301C),
    med: Color(0xFFE0AC5C),
    medSoft: Color(0xFF3A2A12),
    high: Color(0xFFE0785C),
    highSoft: Color(0xFF3A1E16),
    uncertain: Color(0xFFB48FC9),
    uncertainSoft: Color(0xFF2E2438),
  );

  /// Returns the color pair (fg, bg) for a severity string.
  static List<Color> severityColors(AppColors c, String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return [c.high, c.highSoft];
      case 'MEDIUM':
        return [c.med, c.medSoft];
      case 'LOW':
      default:
        return [c.low, c.lowSoft];
    }
  }
}

/// ThemeExtension wrapper so AppColors can be looked up via
/// `Theme.of(context).extension<AppColorsExtension>()!.colors`.
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppColors colors;
  const AppColorsExtension(this.colors);

  @override
  AppColorsExtension copyWith({AppColors? colors}) {
    return AppColorsExtension(colors ?? this.colors);
  }

  @override
  AppColorsExtension lerp(
    ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColorsExtension>()!.colors;
}

class AppTheme {
  static const double radiusLg = 18;
  static const double radiusMd = 16;
  static const double radiusSm = 14;

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      fontFamily: GoogleFonts.manrope().fontFamily,
      textTheme: GoogleFonts.manropeTextTheme(
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ).apply(bodyColor: c.text, displayColor: c.text),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: brightness == Brightness.dark ? c.text : Colors.white,
        secondary: c.primaryDeep,
        onSecondary: Colors.white,
        error: c.high,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.text,
      ),
      extensions: [AppColorsExtension(c)],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: c.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: c.textMuted),
        hintStyle: TextStyle(color: c.textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.border),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.primaryDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
    return base;
  }

  static ThemeData get lightTheme => _build(AppColors.light, Brightness.light);
  static ThemeData get darkTheme => _build(AppColors.dark, Brightness.dark);
}
