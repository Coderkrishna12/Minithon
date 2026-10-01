import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Nordic Monolith: Pure matte obsidian, raw titanium, bone white
  static const background = Color(0xFF0B0C0E);
  static const surface = Color(0xFF131417);
  static const surfaceLight = Color(0xFF1B1C21);
  static const surfaceElevated = Color(0xFF23252B);
  
  static const border = Color(0xFF222429);
  static const borderHover = Color(0xFF383B43);
  
  static const textPrimary = Color(0xFFF4F4F6);
  static const textSecondary = Color(0xFFA1A3AA);
  static const textMuted = Color(0xFF6B6E78);
  static const titanium = Color(0xFFD4D6DC);

  // Intentional, non-slop minimal accents (stark bone white primary, understated data signals)
  static const blue = Color(0xFFEDEDED); // Monolith Bone White primary
  static const purple = Color(0xFF8E929E); // Muted Titanium
  static const green = Color(0xFF3E9B66); // Mineral Sage
  static const orange = Color(0xFFD97706); // Raw Ochre / Amber
  static const amber = Color(0xFFD97706); // Raw Ochre / Amber
  static const red = Color(0xFFE54D2E); // Raw Vermilion alert
  static const pink = Color(0xFFB5BAC6); // Steel Platinum
  static const cyan = Color(0xFFCFD3DC); // Cold Quartz
}

class AppTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.purple,
        surface: AppColors.surface,
        error: AppColors.red,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.titanium, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.red, width: 1.2),
        ),
        labelStyle: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 0.5),
        hintStyle: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
        contentTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          side: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.textPrimary;
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.borderHover;
          return AppColors.surfaceLight;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.border),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.textPrimary,
        linearTrackColor: AppColors.surfaceLight,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.textPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.0),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        textStyle: GoogleFonts.spaceGrotesk(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
        iconColor: AppColors.titanium,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        unselectedLabelStyle: TextStyle(fontSize: 10, letterSpacing: 0.5),
      ),
      dividerColor: AppColors.border,
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
    );
  }
}
