import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFF2EEE5);
  static const surface = Color(0xFFFBF9F4);
  static const surfaceLight = Color(0xFFEAE4D7);
  static const border = Color(0xFFDCD4C4);
  static const borderHover = Color(0xFFB8AE9A);
  static const textPrimary = Color(0xFF17150F);
  static const textSecondary = Color(0xFF5B544A);
  static const textMuted = Color(0xFF8A8274);
  static const ink = Color(0xFF17150F);
  // Print palette: ink, signal red and earth tones. The old names are kept so every screen
  // picks the new tones up, but none of them is a blue or purple any more.
  static const blue = Color(0xFF3A3630); // graphite
  static const purple = Color(0xFF7A4B2A); // umber
  static const green = Color(0xFF2E6B4E); // forest
  static const orange = Color(0xFFA8660F); // ochre
  static const red = Color(0xFFC8321A); // signal red
  static const pink = Color(0xFFB4532A); // rust
  static const cyan = Color(0xFF5E6B2E); // olive
  static const paperDark = Color(0xFFE6DFD0);
}

class AppText {
  static TextStyle serif({double size = 28, Color color = AppColors.textPrimary, FontStyle? style}) =>
      GoogleFonts.instrumentSerif(fontSize: size, color: color, height: 1.05, fontStyle: style, letterSpacing: -0.2);

  static TextStyle eyebrow({Color color = AppColors.textMuted}) => GoogleFonts.ibmPlexMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
        color: color,
      );

  static TextStyle mono({double size = 12, Color color = AppColors.textPrimary, FontWeight? weight}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, color: color, fontWeight: weight);
}

class AppTheme {
  static ThemeData get theme {
    final base = GoogleFonts.ibmPlexSansTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    final radius = BorderRadius.circular(2);
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        onPrimary: AppColors.surface,
        secondary: AppColors.red,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.red,
      ),
      textTheme: base.copyWith(
        displayLarge: AppText.serif(size: 48),
        displayMedium: AppText.serif(size: 40),
        headlineLarge: AppText.serif(size: 34),
        headlineMedium: AppText.serif(size: 28),
        headlineSmall: AppText.serif(size: 24),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.serif(size: 26),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        shape: const Border(bottom: BorderSide(color: AppColors.ink, width: 1.5)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.borderHover,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink),
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.ink)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.ink, width: 1.5)),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.red,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.ibmPlexSans(fontSize: 11.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.ibmPlexSans(fontSize: 11),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: radius)),
      snackBarTheme: SnackBarThemeData(backgroundColor: AppColors.ink, contentTextStyle: GoogleFonts.ibmPlexSans(color: AppColors.surface)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink),
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.red,
        labelStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        labelStyle: GoogleFonts.ibmPlexSans(color: AppColors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
      ),
    );
  }
}
