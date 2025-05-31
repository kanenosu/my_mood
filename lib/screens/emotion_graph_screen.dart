import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore をインポート
import 'package:intl/intl.dart'; // 日付フォーマットのため
import 'package:yurufuwa_diary/models/diary_entry.dart'; // DiaryEntryモデル (必要に応じて作成・調整)
import 'package:yurufuwa_diary/theme/app_theme.dart'; // AppTheme をインポート
// import 'package:firebase_auth/firebase_auth.dart'; // ユーザー認証を使う場合

class EmotionGraphScreen extends StatefulWidget {
  const EmotionGraphScreen({Key? key}) : super(key: key);

  @override
  State<EmotionGraphScreen> createState() => _EmotionGraphScreenState();
}

class _EmotionGraphScreenState extends State<EmotionGraphScreen> {
  String _period = 'week'; // 'week' or 'month'
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance; // ユーザー認証を使う場合

  List<DiaryEntry> _fetchedDiaryEntries = []; // Firestoreから取得した日記データ
  bool _isLoading = true; // データロード中フラグ

  // AppThemeから感情の色を取得
  final List<Color> _emotionColors = AppTheme.emotionColors;

  // 感情タグの分布データ（サンプル） - 今回は折れ線グラフに注力するため、一旦コメントアウトまたは削除
  // final Map<String, double> _emotionTagData = { ... };

  @override
  void initState() {
    super.initState();
    _fetchDiaryData();
  }

  Future<void> _fetchDiaryData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _fetchedDiaryEntries = [];
    });

    // final userId = _auth.currentUser?.uid; // ユーザー認証を使う場合
    // if (userId == null && _period != 'demo') { // デモモード以外でuserIdがない場合は処理中断 (任意)
    //   if (mounted) setState(() => _isLoading = false);
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('グラフを表示するにはログインが必要です。'), backgroundColor: Colors.orange),
    //   );
    //   return;
    // }

    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59); // 今日の終わりまで

    if (_period == 'week') {
      // 今週の日曜日から土曜日まで (週の始まりを日曜とするか月曜とするかで調整)
      int currentWeekday = now.weekday; // 1 (月曜) から 7 (日曜)
      // 週の始まりを日曜日にする場合
      startDate = DateTime(now.year, now.month, now.day - (currentWeekday % 7));
      // 週の終わりを土曜日にする場合
      // endDate = DateTime(now.year, now.month, now.day + (6 - (currentWeekday % 7)), 23, 59, 59);
    } else if (_period == 'month') {
      startDate = DateTime(now.year, now.month, 1); // 今月の初め
    } else { // デモデータ用 (任意)
      // startDate = DateTime(now.year, now.month, now.day - 6);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      Query query = _firestore
          .collection('diaries')
      // .where('userId', isEqualTo: userId) // ユーザー認証を使う場合
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false); // 日付順に取得

      final querySnapshot = await query.get();
      // 修正点: DiaryEntry.fromFirestore に doc.data() と doc.id を渡す
      //        また、mapの結果を List<DiaryEntry> に正しくキャストする
      final List<DiaryEntry> diaries = querySnapshot.docs.map((doc) {
        // doc.data() が Map<String, dynamic> であることを確認し、nullチェックも行う
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return DiaryEntry.fromFirestore(data, doc.id); // 修正: 引数を2つ渡す
        }
        return null; // データがない場合はnullを返す (後でフィルタリング)
      }).whereType<DiaryEntry>().toList(); // nullを除去し、型を確定させる

      if (mounted) {
        setState(() {
          _fetchedDiaryEntries = diaries;
        });
      }
    } catch (e, stackTrace) { // stackTraceもキャッチして詳細なエラーログを出す
      print("Error fetching diary data for graph: $e");
      print("Stack trace: $stackTrace"); // スタックトレースも出力
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('グラフデータの読み込みに失敗: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '感情グラフ', // タイトル変更
          style: TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold, // 太字に
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1, // 少し影をつける
        leading: IconButton( // 戻るボタンは状況に応じて
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 画面タイトルはAppBarにあるので削除しても良い
              // const Text(
              //   'Emotion Graph', ...
              // ),
              // const SizedBox(height: 24),
              _buildPeriodSelector(),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 50.0),
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ))
                  : _buildEmotionGraph(),
              const SizedBox(height: 32),
              // 感情タグ分布は今回スコープ外
              // _buildEmotionTags(),
              if (!_isLoading && _fetchedDiaryEntries.isEmpty && _period != 'demo')
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: Text(
                      'この期間の日記データがありません。\n記録を続けてグラフを育てよう！🌱',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPeriodTab('今週', 'week'), // ラベルを日本語に
        const SizedBox(width: 30), // 間隔調整
        _buildPeriodTab('今月', 'month'), // ラベルを日本語に
        // const SizedBox(width: 24),
        // _buildPeriodTab('Demo', 'demo'), // デモデータ用 (任意)
      ],
    );
  }

  Widget _buildPeriodTab(String label, String value) {
    final isSelected = _period == value;
    return GestureDetector(
      onTap: () {
        if (_period != value) {
          setState(() {
            _period = value;
          });
          _fetchDiaryData(); // 期間変更時にデータを再取得
        }
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17, // 少し大きく
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, // 太さ調整
              color: isSelected ? AppTheme.primaryColor : Colors.grey[700], // 色変更
            ),
          ),
          const SizedBox(height: 6), // 間隔調整
          AnimatedContainer( // 下線の表示にアニメーション
            duration: const Duration(milliseconds: 200),
            height: 3, // 少し太く
            width: isSelected ? 50 : 0, // 選択時のみ幅を持たせる
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionGraph() {
    if (_fetchedDiaryEntries.isEmpty && _period != 'demo') {
      // データがない場合の表示はメインのbuildメソッドで対応済み
      return const SizedBox(height: 250); // 高さを維持するための空のコンテナ
    }

    return Container(
      height: 280, // 少し高く
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10), // パディング調整
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 角丸を大きく
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomPaint( // fl_chartなどのライブラリ推奨
              size: const Size(double.infinity, 200),
              painter: EmotionGraphPainter(
                diaryEntries: _fetchedDiaryEntries, // DiaryEntryのリストを渡す
                period: _period,
                emotionColors: _emotionColors, // AppThemeの色を使用
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildXAxisLabels(), // X軸ラベル生成メソッドを呼び出し
        ],
      ),
    );
  }

  Widget _buildXAxisLabels() {
    List<String> labels;
    DateTime now = DateTime.now();

    if (_period == 'week') {
      labels = List.generate(7, (index) {
        // 週の始まりを日曜日にする場合
        final day = DateTime(now.year, now.month, now.day - (now.weekday % 7) + index);
        return DateFormat('E', 'ja_JP').format(day); // '日', '月', ...
      });
    } else if (_period == 'month') {
      // 月の週ごとのラベル (簡易版)
      // より正確には、各週の開始日などを表示する
      labels = ['1週', '2週', '3週', '4週'];
      // final firstDayOfMonth = DateTime(now.year, now.month, 1);
      // final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      // int weekCount = (daysInMonth / 7).ceil();
      // labels = List.generate(weekCount, (index) => '${index + 1}週');
    } else {
      labels = []; // Demo用など
    }

    if (labels.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.map((label) => Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11))).toList(),
    );
  }

// 感情タグ分布ウィジェットは今回スコープ外 (必要なら別途実装)
// Widget _buildEmotionTags() { ... }
}

// 感情グラフ描画用のCustomPainter
class EmotionGraphPainter extends CustomPainter {
  final List<DiaryEntry> diaryEntries; // 日記データのリスト
  final String period;
  final List<Color> emotionColors; // AppThemeの色

  EmotionGraphPainter({
    required this.diaryEntries,
    required this.period,
    required this.emotionColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5; // 少し太く

    final gridPaint = Paint()
      ..color = Colors.grey[200]! // グリッドの色を薄く
      ..strokeWidth = 0.8; // グリッド線を細く

    // 横線 (感情レベル0-4に対応)
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i * size.height / 4); // Y軸の向きを修正 (0が下、4が上)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 縦線 (期間に応じて)
    final divisions = period == 'week' ? 7 : (period == 'month' ? 4 : 1); // 月の場合は週単位で4分割など
    if (divisions > 1) {
      for (int i = 0; i <= divisions; i++) {
        final x = i * size.width / divisions;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    if (diaryEntries.isEmpty) return; // データがなければ描画しない

    // データを期間に合わせて整形
    List<double?> processedData; // null許容でデータがない日も表現
    DateTime now = DateTime.now();

    if (period == 'week') {
      processedData = List.filled(7, null, growable: false);
      DateTime startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday % 7));
      for (var entry in diaryEntries) {
        int dayIndex = entry.date.difference(startOfWeek).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          // 同じ日に複数の記録がある場合、平均値や最後の値などを採用 (ここでは最後の値)
          processedData[dayIndex] = entry.emotionIndex.toDouble();
        }
      }
    } else if (period == 'month') {
      // 月間データを週ごとの平均感情レベルで集計 (簡易版)
      processedData = List.filled(4, null, growable: false); // 4週間分と仮定
      List<List<int>> weeklyEmotions = List.generate(4, (_) => []);

      DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
      for (var entry in diaryEntries) {
        int dayOfMonth = entry.date.day;
        int weekIndex = ((dayOfMonth -1) / 7).floor(); // 0-indexed week
        if (weekIndex >=0 && weekIndex < 4) {
          weeklyEmotions[weekIndex].add(entry.emotionIndex);
        }
      }
      for (int i=0; i < weeklyEmotions.length; i++) {
        if (weeklyEmotions[i].isNotEmpty) {
          processedData[i] = weeklyEmotions[i].reduce((a, b) => a + b) / weeklyEmotions[i].length;
        }
      }
    } else {
      processedData = []; // Demoなど
    }


    if (processedData.where((d) => d != null).isEmpty) return; // プロットできるデータがない

    final path = Path();
    final pointPaint = Paint()..style = PaintingStyle.fill;
    final pointStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    bool firstPoint = true;
    for (int i = 0; i < processedData.length; i++) {
      if (processedData[i] == null) continue; // データがない日はスキップ

      final double emotionLevel = processedData[i]!; // 0.0 (悲しい) から 4.0 (嬉しい)
      final x = (size.width / (divisions > 1 ? divisions : 1)) * i + (size.width / (divisions > 1 ? divisions * 2 : 2) ); // 各区間の中央にプロット
      final y = size.height - (emotionLevel / 4.0 * size.height); // Y軸を0-4の感情レベルに合わせる

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }

      // ポイントの色を感情レベルに対応させる
      Color pointColor = emotionColors[emotionLevel.round().clamp(0, emotionColors.length - 1)];
      pointPaint.color = pointColor;
      pointStrokePaint.color = pointColor.withOpacity(0.7);

      canvas.drawCircle(Offset(x, y), 5, pointPaint); // ポイントを少し大きく
      // canvas.drawCircle(Offset(x, y), 5, pointStrokePaint); // 枠線は任意
    }

    paint.color = AppTheme.primaryColor.withOpacity(0.8); // 線の色
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EmotionGraphPainter oldDelegate) {
    return oldDelegate.diaryEntries != diaryEntries || oldDelegate.period != period;
  }
}

// 感情タグ円グラフのPainterは今回スコープ外 (必要なら別途実装)
// class EmotionPieChartPainter extends CustomPainter { ... }
