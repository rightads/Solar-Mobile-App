import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_pro/shared/animations/motion.dart';

// ─── Brand Colors — "Pixel Sunrise" (light) ──────────────────────────────────
// Lavender-white canvas, white outlined cards, deep indigo ink and an amber
// call-to-action. Token names are kept from the original dark navy/gold
// palette so every screen inherits the new look:
//   navy*  → surface ramp   (900 = canvas, 800 = card, 700 = fill, 600 = border)
//   gold*  → amber primary
//   grey*  → text ramp      (50 = strongest ink … 900 = faintest tint)
//   fg*    → foreground ink (replaces the old Colors.white text/icons)
class AppColors {
  AppColors._();

  // Surface ramp (formerly navy)
  static const Color navy900 = Color(0xFFF6F4FD);
  static const Color navy800 = Color(0xFFFFFFFF);
  static const Color navy700 = Color(0xFFF1EEFB);
  static const Color navy600 = Color(0xFFDDD7F2);
  static const Color navy500 = Color(0xFFC4BBE8);
  static const Color navy400 = Color(0xFF8E80D6);

  // Amber primary (formerly gold)
  static const Color gold500 = Color(0xFFF7A21B);
  static const Color gold400 = Color(0xFFE5860B);
  static const Color gold300 = Color(0xFFFBBF4D);
  static const Color gold200 = Color(0xFFFDD993);
  static const Color gold100 = Color(0xFFFFF2D9);
  static const Color goldDeep = Color(0xFFC96A00);

  // Ink & foreground
  static const Color ink900 = Color(0xFF211650);
  static const Color ink700 = Color(0xFF3A2F78);
  static const Color fg     = ink900;
  static const Color fg70   = Color(0xB3211650);
  static const Color fg24   = Color(0x3D211650);
  static const Color fg12   = Color(0x1F211650);
  static const Color fg10   = Color(0x1A211650);
  static const Color shadow = Color(0xFF3B2F80);

  // Accent
  static const Color violet500  = Color(0xFF5B4CE0);
  static const Color violet400  = Color(0xFF7D70EA);
  static const Color violet100  = Color(0xFFECE9FF);
  static const Color teal500    = Color(0xFF0FA89A);
  static const Color teal400    = Color(0xFF14B8A6);
  static const Color orange500  = Color(0xFFF26B1D);
  static const Color orange400  = Color(0xFFF7853F);
  static const Color green500   = Color(0xFF1FA75A);
  static const Color green400   = Color(0xFF26B866);
  static const Color red500     = Color(0xFFE5484D);
  static const Color purple500  = Color(0xFF7B4DE8);
  static const Color purple400  = Color(0xFF9775F0);
  static const Color cyan400    = Color(0xFF0E9BC4);
  static const Color sky300     = Color(0xFF9FD8F5);
  static const Color leaf500    = Color(0xFF5DBB46);

  // Neutral text ramp (dark → light)
  static const Color white      = Color(0xFFFFFFFF);
  static const Color grey50     = Color(0xFF1C1446);
  static const Color grey100    = Color(0xFF2A2160);
  static const Color grey200    = Color(0xFF3A3170);
  static const Color grey300    = Color(0xFF4D4580);
  static const Color grey400    = Color(0xFF6C6596);
  static const Color grey500    = Color(0xFF8A84AE);
  static const Color grey600    = Color(0xFFA8A3C6);
  static const Color grey700    = Color(0xFFCCC7E3);
  static const Color grey800    = Color(0xFFE6E2F4);
  static const Color grey900    = Color(0xFFF3F1FA);

  // Semantic
  static const Color success    = Color(0xFF1FA75A);
  static const Color warning    = Color(0xFFF59E0B);
  static const Color error      = Color(0xFFE5484D);
  static const Color info       = Color(0xFF5B4CE0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFECE9FF), Color(0xFFF8F6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Main call-to-action gradient (amber → orange).
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFBB437), Color(0xFFF7951B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient violetGradient = LinearGradient(
    colors: [Color(0xFF7D70EA), Color(0xFF5B4CE0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFF6F4FD), Color(0xFFEFEBFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient skyGradient = LinearGradient(
    colors: [Color(0xFFE9E4FF), Color(0xFFFFF4E2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F6FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF4F1FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Text Styles ─────────────────────────────────────────────────────────────
// Pixelify Sans for display/titles, Outfit for everything else.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get pixel => GoogleFonts.pixelifySans(
    color: AppColors.ink900,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static TextStyle get displayLarge => GoogleFonts.pixelifySans(
    fontSize: 40,
    fontWeight: FontWeight.w500,
    color: AppColors.fg,
    letterSpacing: 0.4,
    height: 1.1,
  );

  static TextStyle get displayMedium => GoogleFonts.pixelifySans(
    fontSize: 30,
    fontWeight: FontWeight.w500,
    color: AppColors.fg,
    letterSpacing: 0.3,
    height: 1.15,
  );

  static TextStyle get displaySmall => GoogleFonts.pixelifySans(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: AppColors.fg,
    letterSpacing: 0.2,
  );

  static TextStyle get headlineLarge => GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.fg,
    letterSpacing: -0.4,
  );

  static TextStyle get headlineMedium => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.fg,
    letterSpacing: -0.2,
  );

  static TextStyle get headlineSmall => GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.fg,
    letterSpacing: -0.1,
  );

  static TextStyle get bodyLarge => GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.grey300,
    height: 1.55,
  );

  static TextStyle get bodyMedium => GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.grey300,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.grey400,
    height: 1.4,
  );

  static TextStyle get labelLarge => GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.fg,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.grey300,
    letterSpacing: 0.1,
  );

  static TextStyle get caption => GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.grey500,
    letterSpacing: 0.1,
  );
}

// ─── Spacing & Radius ────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 16;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double xxl  = 48;
  static const double xxxl = 64;
}

class AppRadius {
  AppRadius._();
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 10;
  static const double lg   = 12;
  static const double xl   = 14;
  static const double xxl  = 20;
  static const double pill = 100;
}

// ─── Motion tokens ───────────────────────────────────────────────────────────
class AppMotion {
  AppMotion._();
  static const Duration fast   = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow   = Duration(milliseconds: 520);
  static const Duration page   = Duration(milliseconds: 440);

  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve spring     = Curves.easeOutBack;
}

// ─── Decorations ─────────────────────────────────────────────────────────────
class AppDecor {
  AppDecor._();

  /// White outlined card with the hard offset "pixel" shadow from the mockups.
  static BoxDecoration card({
    Color color = AppColors.navy800,
    Color border = AppColors.navy500,
    double radius = AppRadius.xl,
    double shadowOffset = 3,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy500.withValues(alpha: 0.55),
            offset: Offset(0, shadowOffset),
            blurRadius: 0,
          ),
        ],
      );
}

// ─── App Theme ────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final bodyText = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme)
        .apply(bodyColor: AppColors.fg, displayColor: AppColors.fg);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.navy500, width: 1.4),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.navy900,
      primaryColor: AppColors.gold500,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold500,
        secondary: AppColors.violet500,
        tertiary: AppColors.teal500,
        surface: AppColors.navy800,
        surfaceContainerHighest: AppColors.navy700,
        error: AppColors.error,
        onPrimary: AppColors.ink900,
        onSecondary: AppColors.white,
        onSurface: AppColors.ink900,
        outline: AppColors.navy500,
      ),
      textTheme: bodyText.copyWith(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        displaySmall: AppTextStyles.displaySmall,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.headlineMedium,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SpPageTransitionsBuilder(),
          TargetPlatform.iOS: SpPageTransitionsBuilder(),
          TargetPlatform.windows: SpPageTransitionsBuilder(),
          TargetPlatform.macOS: SpPageTransitionsBuilder(),
          TargetPlatform.linux: SpPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SpPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy900,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.ink900),
        titleTextStyle: AppTextStyles.headlineMedium,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink900),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navy800,
        selectedItemColor: AppColors.gold400,
        unselectedItemColor: AppColors.grey500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: AppColors.violet500, width: 1.8),
        ),
        errorBorder: outline.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: outline.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
        labelStyle: AppTextStyles.bodyMedium,
        floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.violet500),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        prefixIconColor: AppColors.grey400,
        suffixIconColor: AppColors.grey400,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold500,
          foregroundColor: AppColors.ink900,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.goldDeep, width: 1.4),
          ),
          textStyle: AppTextStyles.labelLarge.copyWith(fontSize: 15),
          elevation: 0,
          animationDuration: AppMotion.fast,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold500,
          foregroundColor: AppColors.ink900,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink900,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.navy500, width: 1.4),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.labelLarge.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.violet500,
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold500,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.goldDeep, width: 1.4),
        ),
        extendedTextStyle: AppTextStyles.labelLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.navy800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.navy600, width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.navy600,
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.navy800,
        selectedColor: AppColors.gold100,
        labelStyle: AppTextStyles.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: const BorderSide(color: AppColors.navy500),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.ink900,
        unselectedLabelColor: AppColors.grey500,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelMedium,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.navy500, width: 1.2),
        ),
        splashBorderRadius: BorderRadius.circular(AppRadius.md),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.navy800,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.navy800,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: const BorderSide(color: AppColors.navy500, width: 1.4),
        ),
        titleTextStyle: AppTextStyles.headlineMedium,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink900,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold500,
        linearTrackColor: AppColors.navy600,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold500 : AppColors.navy500,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold500 : AppColors.white,
        ),
        checkColor: WidgetStateProperty.all(AppColors.ink900),
        side: const BorderSide(color: AppColors.navy400, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.navy800,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.navy500),
        ),
        textStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.grey400,
        textColor: AppColors.fg,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink900,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
      ),
    );
  }

  /// Kept for call sites that still reference the old name.
  static ThemeData get darkTheme => lightTheme;
}
