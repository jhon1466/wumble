import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Wumbleheme {
  // Brand Colors (Wumble Vibes: Vibrant & Social)
  static const Color primaryColor = Color(0xFF7F4DFF); // Vibrant Purple
  static const Color secondaryColor = Color(0xFFFF4D8D); // Energetic Pink
  static const Color accentColor = Color(0xFF00E5FF); // Cyber Blue
  
  static const Color backgroundColor = Color(0xFF0D0D0E); // Deep Matte Gray
  static const Color surfaceColor = Color(0xFF161618); // Refined Gray Surface
  
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8B949E);
  
  static final List<String> _fontFallbacks = [
    'Roboto', // Android default
    GoogleFonts.notoSansMath().fontFamily!, // Support for Mathematical Alphanumeric Symbols 
    GoogleFonts.notoSansSymbols().fontFamily!, // Support for varied symbols
    'Apple Color Emoji', // iOS Emojis
    'Segoe UI Emoji', // Windows Emojis
    'Segoe UI Symbol', // Symbols
    'Noto Sans', // General coverage
  ];
  
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: GoogleFonts.outfit().fontFamily,
    fontFamilyFallback: _fontFallbacks,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    textTheme: _buildTextThemeWithFallbacks(GoogleFonts.outfitTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
    )),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );

  static TextTheme _buildTextThemeWithFallbacks(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFamilyFallback: _fontFallbacks),
      displayMedium: base.displayMedium?.copyWith(fontFamilyFallback: _fontFallbacks),
      displaySmall: base.displaySmall?.copyWith(fontFamilyFallback: _fontFallbacks),
      headlineLarge: base.headlineLarge?.copyWith(fontFamilyFallback: _fontFallbacks),
      headlineMedium: base.headlineMedium?.copyWith(fontFamilyFallback: _fontFallbacks),
      headlineSmall: base.headlineSmall?.copyWith(fontFamilyFallback: _fontFallbacks),
      titleLarge: base.titleLarge?.copyWith(fontFamilyFallback: _fontFallbacks),
      titleMedium: base.titleMedium?.copyWith(fontFamilyFallback: _fontFallbacks),
      titleSmall: base.titleSmall?.copyWith(fontFamilyFallback: _fontFallbacks),
      bodyLarge: base.bodyLarge?.copyWith(fontFamilyFallback: _fontFallbacks),
      bodyMedium: base.bodyMedium?.copyWith(fontFamilyFallback: _fontFallbacks),
      bodySmall: base.bodySmall?.copyWith(fontFamilyFallback: _fontFallbacks),
      labelLarge: base.labelLarge?.copyWith(fontFamilyFallback: _fontFallbacks),
      labelMedium: base.labelMedium?.copyWith(fontFamilyFallback: _fontFallbacks),
      labelSmall: base.labelSmall?.copyWith(fontFamilyFallback: _fontFallbacks),
    );
  }
}
