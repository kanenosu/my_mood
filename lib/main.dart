import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:flutter_localizations/flutter_localizations.dart'; // Flutterのローカライゼーション ← これを追加！
import 'package:intl/date_symbol_data_local.dart'; // intlパッケージのデートフォーマット初期化
import 'package:yurufuwa_diary/screens/home_screen.dart'; // HomeScreenへのパス（実際のパスに合わせてください）
import 'firebase_options.dart'; // Firebase CLIで生成されるファイル（flutterfire configure）
// import 'package:yurufuwa_diary/theme/app_theme.dart'; // アプリのテーマ（必要に応じてコメント解除）

void main() async {
  // Flutterエンジンとウィジェットツリーのバインディングを初期化
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // firebase_options.dartからプラットフォームに応じた設定を読み込む
  );

  // 日付フォーマットのローカライゼーションデータを初期化 (日本語向け)
  // これにより、DateFormatが日本語の書式を正しく扱えるようになります。
  await initializeDateFormatting('ja_JP', null);

  // アプリケーションを起動
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ゆるふわ日記', // アプリのタイトル

      // アプリのテーマ設定
      theme: ThemeData(
        // primaryColor: AppTheme.primaryColor, // AppTheme がある場合はこちらを優先
        // colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor), // Material 3 向け
        primarySwatch: Colors.pink, // フォールバックとしてピンク系統の色を使用
        fontFamily: 'NotoSansJP', // アプリ全体のフォント（別途設定が必要な場合）
        appBarTheme: const AppBarTheme( // AppBarのデフォルトスタイル
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF333333), // テキストやアイコンの色
          elevation: 0.5, // AppBarの影を少しつける
          titleTextStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        // useMaterial3: true, // Material 3 デザインを利用する場合
      ),

      // ローカライゼーション設定
      // これにより、DatePickerDialogなどのMaterialウィジェットが日本語表示になります。
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // Material Designウィジェットのローカライゼーション
        GlobalWidgetsLocalizations.delegate,  // 基本的なウィジェットのテキスト方向など
        GlobalCupertinoLocalizations.delegate, // Cupertinoウィジェット（iOS風）のローカライゼーション
      ],
      supportedLocales: const [
        Locale('ja', 'JP'), // 日本語をサポート
        // Locale('en', 'US'), // 必要であれば他の言語も追加
      ],
      locale: const Locale('ja', 'JP'), // アプリのデフォルトロケールを日本語に設定

      debugShowCheckedModeBanner: false, // デバッグバナーを非表示にする

      // アプリの最初の画面
      home: const HomeScreen(),
    );
  }
}
