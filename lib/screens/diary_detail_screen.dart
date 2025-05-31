import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yurufuwa_diary/models/diary_entry.dart'; // DiaryEntryモデルのパス
import 'package:yurufuwa_diary/screens/diary_entry_screen.dart'; // DiaryEntryScreenへのパス
import 'package:yurufuwa_diary/theme/app_theme.dart';
import 'package:yurufuwa_diary/widgets/image_grid_view.dart'; // ImageGridViewウィジェットのパス

class DiaryDetailScreen extends StatefulWidget { // StatelessWidgetからStatefulWidgetに変更 (任意: データ更新後に再描画する場合)
  final DiaryEntry diary;

  const DiaryDetailScreen({
    Key? key,
    required this.diary,
  }) : super(key: key);

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  late DiaryEntry _currentDiary; // 編集後に更新される可能性を考慮

  @override
  void initState() {
    super.initState();
    _currentDiary = widget.diary;
  }

  // 日付フォーマット (変更なし)
  String _formatDate(DateTime date) {
    // final formatter = DateFormat('yyyy年M月d日 (E)', 'ja_JP'); // 曜日も入れる場合
    final formatter = DateFormat('yyyy年 M月 d日', 'ja_JP');
    return formatter.format(date);
  }

  // 感情に対応する顔文字を返す (変更なし)
  String _getEmotionFace(int index) {
    if (index < 0 || index >= AppTheme.emotionColors.length) return '😐'; // 不正な場合は普通の顔
    switch (index) {
      case 0: return '😢';
      case 1: return '😕';
      case 2: return '😐';
      case 3: return '🙂';
      case 4: return '😄';
      default: return '�';
    }
  }

  // 感情に対応する名前を返す (変更なし)
  String _getEmotionName(int index) {
    if (index < 0 || index >= AppTheme.emotionColors.length) return '普通'; // 不正な場合は普通
    switch (index) {
      case 0: return 'とても悲しい';
      case 1: return '悲しい';
      case 2: return '普通';
      case 3: return '嬉しい';
      case 4: return 'とても嬉しい';
      default: return '普通';
    }
  }

  void _navigateToEditScreen() async {
    // DiaryEntryScreen に diaryId と existingDiaryData を渡す
    // DiaryEntryScreen が pop されたときに結果を受け取る (例: 保存されたら true)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryEntryScreen(
          diaryId: _currentDiary.id,
          existingDiaryData: _currentDiary.toFirestore(), // toFirestoreMapをtoFirestoreに変更
        ),
      ),
    );

    if (result == true && mounted) {
      // もしDiaryEntryScreenでデータが更新されたら、この詳細画面も更新する必要がある
      // 簡単な方法としては、前の画面に戻ってリストを再読み込みさせるか、
      // この画面で再度Firebaseからデータをフェッチする。
      // ここでは、popで戻ってきただけではデータは自動更新されないので、
      // 必要に応じて、diaryIdを使ってFirebaseから最新データを再取得し、setStateでUIを更新するロジックを追加する。
      // 例: _loadDiaryById(_currentDiary.id);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日記が更新されました。画面を再読み込みしてください。'), duration: Duration(seconds: 2),)
      );
      // もっと高度な状態管理（Provider, Riverpodなど）を使えば、よりスムーズなデータ同期が可能。
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _formatDate(_currentDiary.date),
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w500,
            fontSize: 18, // 少し調整
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5, // 少し影をつける
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF333333), size: 20), // アイコン変更
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_outlined, color: AppTheme.primaryColor, size: 28), // アイコン変更と色付け
            tooltip: '日記を編集',
            onPressed: _navigateToEditScreen, // 編集画面への遷移メソッドを呼び出す
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // スクロール時の挙動
        child: Padding(
          padding: const EdgeInsets.all(20.0), // パディング調整
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmotionDisplay(),
              const SizedBox(height: 28), // 間隔調整
              _buildDiaryContent(),
              if (_currentDiary.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildImageDisplay(),
              ],
              const SizedBox(height: 40), // 下部の余白
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmotionDisplay() {
    return Container( // 外側に少しパディングと背景
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.emotionColors[_currentDiary.emotionIndex].withOpacity(0.1), // 薄い背景色
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Hero( // 感情アイコンにHeroアニメーション（任意）
            tag: 'emotion_icon_${_currentDiary.id}',
            child: Container(
              width: 52, // 少し小さく
              height: 52,
              decoration: BoxDecoration(
                  color: AppTheme.emotionColors[_currentDiary.emotionIndex],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.emotionColors[_currentDiary.emotionIndex].withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0,2)
                    )
                  ]
              ),
              child: Center(
                child: Text(
                  _getEmotionFace(_currentDiary.emotionIndex),
                  style: const TextStyle(fontSize: 28, color: Colors.white), // 文字色を白に
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded( // 感情名が長い場合にも対応
            child: Text(
              _getEmotionName(_currentDiary.emotionIndex),
              style: TextStyle(
                fontSize: 19, // 少し調整
                fontWeight: FontWeight.bold, // 太字に
                color: AppTheme.emotionColors[_currentDiary.emotionIndex].darken(0.2), // 少し濃い色
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryContent() {
    if (_currentDiary.content.trim().isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Text(
          "この日の日記には、文章がありません。",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // パディング調整
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)), // 枠線を少し濃く
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
      ),
      child: Text(
        _currentDiary.content,
        style: const TextStyle(
          color: Color(0xFF424242), // テキストの色を少し濃く
          fontSize: 15.5, // フォントサイズ調整
          height: 1.7, // 行間調整
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '思い出の写真', // 見出し変更
          style: TextStyle(
            fontSize: 17, // 少し調整
            fontWeight: FontWeight.bold, // 太字に
            color: const Color(0xFF333333).withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 12), // 間隔調整
        ImageGridView(
          imageUrls: _currentDiary.imageUrls,
          // ここでImageGridViewにタップ時の動作などを渡せるようにしても良い
          //例: onImageTap: (index) => _showFullScreenImage(index),
        ),
      ],
    );
  }
}

// AppTheme.emotionColorsの各色を少し暗くする拡張メソッド（任意）
extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}