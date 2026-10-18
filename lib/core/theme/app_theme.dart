import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  AppTheme._();

  // ── Global Theme State ──────────────────────────────────────────────────
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static bool get isLight => themeModeNotifier.value == ThemeMode.light;

  // ── Brand Accents (Consistent Across Themes) ────────────────────────────
  static const Color urgentAccent = Color(0xFFFF3B30);      // Neon Red
  static const Color bufferAccent = Color(0xFF0A84FF);      // Cyan/Icy Blue
  static const Color spamAccent = Color(0xFF8E8E93);        // Muted Grey

  // ── Dark Theme Static Palette (Pure OLED Black) ─────────────────────────
  static const Color _darkSurface = Color(0xFF000000);       // Pure OLED Black
  static const Color _darkCard = Color(0xFF000000);          // Borderless cards
  static const Color _darkElevated = Color(0xFF0A0A0A);
  static const Color _darkBorder = Color(0xFF1C1C1E);        // Ultra-thin borders
  static const Color _darkTextPrimary = Color(0xFFFFFFFF);
  static const Color _darkTextSecondary = Color(0xFF8E8E93);
  static const Color _darkTextMuted = Color(0xFF3A3A3C);
  static const Color _darkPrimary = Color(0xFFFFFFFF);

  // ── Light Theme Static Palette (Crisp High-Contrast Modern) ─────────────
  static const Color _lightSurface = Color(0xFFF6F6F9);      // Clean Off-White Background
  static const Color _lightCard = Color(0xFFFFFFFF);         // Pure Card White
  static const Color _lightElevated = Color(0xFFFFFFFF);
  static const Color _lightBorder = Color(0xFFE5E5EA);       // Subtle Crisp Border
  static const Color _lightTextPrimary = Color(0xFF111111);   // High Contrast Deep Slate
  static const Color _lightTextSecondary = Color(0xFF6E6E73); // Neutral Secondary
  static const Color _lightTextMuted = Color(0xFFA1A1A6);     // Muted Captions
  static const Color _lightPrimary = Color(0xFF111111);

  // ── Dynamic Adaptive Getters (Updates EVERY screen and nook instantly) ────
  static Color get primaryColor => isLight ? _lightPrimary : _darkPrimary;
  static Color get surfaceDark => isLight ? _lightSurface : _darkSurface;
  static Color get surfaceCard => isLight ? _lightCard : _darkCard;
  static Color get surfaceElevated => isLight ? _lightElevated : _darkElevated;
  static Color get surfaceBorder => isLight ? _lightBorder : _darkBorder;
  static Color get textPrimary => isLight ? _lightTextPrimary : _darkTextPrimary;
  static Color get textSecondary => isLight ? _lightTextSecondary : _darkTextSecondary;
  static Color get textMuted => isLight ? _lightTextMuted : _darkTextMuted;

  // ── Adaptive Gradients ──────────────────────────────────────────────────
  static LinearGradient get primaryGradient => isLight
      ? const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  static LinearGradient get cardGradient => isLight
      ? const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF2F2F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF1A1A30), Color(0xFF16162A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  // ── Dark Theme Data ─────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: bufferAccent,
        error: urgentAccent,
        surface: _darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: _darkTextPrimary,
        onError: Colors.white,
        surfaceContainerHighest: _darkElevated,
        outline: _darkBorder,
      ),
      scaffoldBackgroundColor: _darkSurface,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: _darkTextPrimary,
          letterSpacing: 0.15,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: _darkTextSecondary,
          letterSpacing: 0.25,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: _darkTextMuted,
          letterSpacing: 0.4,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.25,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _darkTextPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: _darkSurface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkCard,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: _darkTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkCard,
        indicatorColor: _darkPrimary.withAlpha(50),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _darkPrimary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _darkTextMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _darkPrimary, size: 24);
          }
          return const IconThemeData(color: _darkTextMuted, size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkTextPrimary,
          side: const BorderSide(color: _darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: _darkTextMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: _darkTextSecondary, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _darkPrimary;
          return _darkTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkPrimary.withAlpha(80);
          }
          return _darkBorder;
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkElevated,
        contentTextStyle: GoogleFonts.inter(color: _darkTextPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Light Theme Data ────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: bufferAccent,
        error: urgentAccent,
        surface: _lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _lightTextPrimary,
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFFEBEBF0),
        outline: _lightBorder,
      ),
      scaffoldBackgroundColor: _lightSurface,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: _lightTextPrimary,
          letterSpacing: 0.15,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: _lightTextSecondary,
          letterSpacing: 0.25,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: _lightTextMuted,
          letterSpacing: 0.4,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.25,
        ),
      ),
      cardTheme: const CardThemeData(
        color: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: _lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _lightTextPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: _lightSurface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightCard,
        selectedItemColor: _lightPrimary,
        unselectedItemColor: _lightTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightCard,
        indicatorColor: _lightPrimary.withAlpha(25),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _lightPrimary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _lightTextMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _lightPrimary, size: 24);
          }
          return const IconThemeData(color: _lightTextMuted, size: 24);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightElevated,
        contentTextStyle: GoogleFonts.inter(color: _lightTextPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Global Theme Persistence & Toggle ───────────────────────────────────
  static Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLight = prefs.getBool('app_theme_is_light') ?? false;
      themeModeNotifier.value = isLight ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {}
  }

  static Future<void> toggleTheme() async {
    final nextMode = themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    themeModeNotifier.value = nextMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_theme_is_light', nextMode == ThemeMode.light);
    } catch (_) {}
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_theme_is_light', mode == ThemeMode.light);
    } catch (_) {}
  }
}
