import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for DermaScanAI mobile. Same values as the web patient theme
/// (skin_web/src/styles/patient-theme.css): cream surfaces, one deep-teal
/// accent (mint in dark mode), flat cards, severity colors for status only.
/// The web admin panel keeps its own indigo/teal scheme by design.
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

  /// Text/icon color to use on top of [primary].
  final Color onPrimary;

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
    required this.onPrimary,
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
    background: Color(0xFFFCF5EC),
    surface: Color(0xFFFFFDF8),
    surface2: Color(0xFFF3EBDD),
    border: Color(0xFFE8DECE),
    text: Color(0xFF0E2A2F),
    textMuted: Color(0xFF5E6F70),
    textLight: Color(0xFF8A9899),
    primary: Color(0xFF0B3B42),
    primaryDeep: Color(0xFF072A30),
    primarySoft: Color(0xFFDCEFE6),
    onPrimary: Color(0xFFFFFFFF),
    low: Color(0xFF2F7D5B),
    lowSoft: Color(0xFFE0F0E7),
    med: Color(0xFFA86A12),
    medSoft: Color(0xFFF8EBD2),
    high: Color(0xFFB4402F),
    highSoft: Color(0xFFF7DFD9),
    uncertain: Color(0xFF5E6F70),
    uncertainSoft: Color(0xFFEAE6DC),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF07161A),
    surface: Color(0xFF0D2228),
    surface2: Color(0xFF12303A),
    border: Color(0xFF1B3A44),
    text: Color(0xFFEAF3F1),
    textMuted: Color(0xFF9DB5B3),
    textLight: Color(0xFF6F8A8A),
    primary: Color(0xFF4FB8A5),
    primaryDeep: Color(0xFF1F6F63),
    primarySoft: Color(0xFF14403F),
    onPrimary: Color(0xFF04201F),
    low: Color(0xFF5FCF9F),
    lowSoft: Color(0xFF123A2C),
    med: Color(0xFFE3A94F),
    medSoft: Color(0xFF3A2C12),
    high: Color(0xFFEF8573),
    highSoft: Color(0xFF3D1C16),
    uncertain: Color(0xFF9DB5B3),
    uncertainSoft: Color(0xFF12303A),
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

/// Spacing scale shared with the web theme (--space-1 .. --space-7).
class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class AppTheme {
  // Radii: card 20, control 14, small 10, pill 999.
  static const double radiusLg = 20;
  static const double radiusMd = 14;
  static const double radiusSm = 10;
  static const double radiusPill = 999;

  /// Serif display style (Fraunces) for page titles and card headings.
  static TextStyle display(AppColors c, {double size = 28}) {
    return GoogleFonts.fraunces(
      color: c.text,
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.15,
    );
  }

  /// Small uppercase accent label above a title.
  static TextStyle eyebrow(AppColors c) {
    return TextStyle(
      color: c.primary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    );
  }

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
        onPrimary: c.onPrimary,
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
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          color: c.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
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
        fillColor: c.surface,
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
          foregroundColor: c.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: c.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? c.primary : c.textLight,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? c.primary : c.textLight,
          );
        }),
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
