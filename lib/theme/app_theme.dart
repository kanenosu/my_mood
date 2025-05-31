import 'package:flutter/material.dart';

class AppTheme {
  // テーマカラー
  static const Color primaryColor = Color(0xFFF8BBD0); // ライトピンク
  static const Color secondaryColor = Color(0xFFB3E5FC); // ライトブルー
  static const Color accentColor = Color(0xFFFFCCBC); // ライトオレンジ
  static const Color backgroundColor = Color(0xFFFFFAFA); // オフホワイト
  static const Color textPrimaryColor = Color(0xFF5D4037); // ブラウン
  static const Color textSecondaryColor = Color(0xFF8D6E63); // ライトブラウン
  
  // 感情カラー（5段階）
  static const List<Color> emotionColors = [
    Color(0xFF2E3A59), // レベル1: ダークネイビー
    Color(0xFF6A8DAD), // レベル2: スレートブルー
    Color(0xFFA8D5BA), // レベル3: ミントグリーン
    Color(0xFFF7EC88), // レベル4: パステルイエロー
    Color(0xFFFF6F61), // レベル5: コーラルピンク
  ];
  
  // 感情ラベル
  static const List<String> emotionLabels = [
    '落ち着いた',
    '少し落ち着いた',
    '普通',
    '少し嬉しい',
    '嬉しい',
  ];
  
  // 感情アイコン
  static const List<IconData> emotionIcons = [
    Icons.nightlight_round,
    Icons.nights_stay,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
    Icons.sentiment_very_satisfied,
  ];
  
  // ライトテーマ
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        background: backgroundColor,
        surface: Colors.white,
        onPrimary: textPrimaryColor,
        onSecondary: textPrimaryColor,
        onBackground: textPrimaryColor,
        onSurface: textPrimaryColor,
      ),
      
      // テキストテーマ
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 16,
          color: textPrimaryColor,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 14,
          color: textPrimaryColor,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 12,
          color: textSecondaryColor,
        ),
      ),
      
      // アプリバーテーマ
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
      ),
      
      // ボタンテーマ
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textPrimaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      
      // カードテーマ
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
      
      // 入力フィールドテーマ
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      
      // スナックバーテーマ
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimaryColor,
        contentTextStyle: const TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // ダイアログテーマ
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      
      // ボトムシートテーマ
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
    );
  }
}
