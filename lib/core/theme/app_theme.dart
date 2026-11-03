import 'package:flutter/material.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';

/// 构建工时记录应用唯一的亮色主题。
class AppTheme {
  const AppTheme._();

  static ThemeData buildLightTheme() {
    final ColorScheme colorScheme = _buildColorScheme();
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      dividerTheme: const DividerThemeData(color: AppGlassTokens.softBorder),
      filledButtonTheme: _buildFilledButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      chipTheme: _buildChipTheme(),
      popupMenuTheme: _buildPopupMenuTheme(),
      dialogTheme: _buildDialogTheme(),
    );
  }

  static ColorScheme _buildColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppGlassTokens.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppGlassTokens.primary,
      onPrimary: Colors.white,
      surface: AppGlassTokens.strongSurface,
      onSurface: AppGlassTokens.content,
    );
  }

  static FilledButtonThemeData _buildFilledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppGlassTokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppGlassTokens.primaryMuted,
        backgroundColor: AppGlassTokens.softSurface,
        side: const BorderSide(color: AppGlassTokens.primaryBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppGlassTokens.softSurface,
      hintStyle: const TextStyle(color: AppGlassTokens.tertiaryContent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _buildInputBorder(AppGlassTokens.softBorder),
      enabledBorder: _buildInputBorder(AppGlassTokens.softBorder),
      focusedBorder: _buildInputBorder(AppGlassTokens.primary, width: 1.5),
    );
  }

  static OutlineInputBorder _buildInputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ChipThemeData _buildChipTheme() {
    return ChipThemeData(
      backgroundColor: AppGlassTokens.subtleSurface,
      selectedColor: AppGlassTokens.primarySoft,
      disabledColor: AppGlassTokens.subtleSurface,
      side: const BorderSide(color: AppGlassTokens.softBorder),
      selectedShadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        color: AppGlassTokens.secondaryContent,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppGlassTokens.primaryMuted,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  static PopupMenuThemeData _buildPopupMenuTheme() {
    return PopupMenuThemeData(
      color: AppGlassTokens.strongSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppGlassTokens.glassBorder),
      ),
    );
  }

  static DialogTheme _buildDialogTheme() {
    return DialogTheme(
      backgroundColor: AppGlassTokens.strongSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppGlassTokens.standardRadius),
        side: const BorderSide(color: AppGlassTokens.glassBorder),
      ),
    );
  }
}
