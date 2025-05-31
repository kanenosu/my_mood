import 'package:flutter/material.dart';
import 'package:yurufuwa_diary/screens/calendar_screen.dart';
import 'package:yurufuwa_diary/screens/diary_entry_screen.dart';
import 'package:yurufuwa_diary/screens/emotion_graph_screen.dart';
import 'package:yurufuwa_diary/screens/diary_detail_screen.dart';
import 'package:yurufuwa_diary/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore をインポート
import 'package:intl/intl.dart'; // 日付フォーマット用
import 'package:yurufuwa_diary/models/diary_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _HomeContent(),
    const CalendarScreen(), // CalendarScreenもFirebase対応が必要
    const EmotionGraphScreen(), // EmotionGraphScreenもFirebase対応が必要
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ゆるふわ日記'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'カレンダー',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '感情グラフ',
          ),
        ],
        selectedItemColor: AppTheme.primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // DiaryEntryScreen に今日の日付や既存の日記IDを渡すようにしても良い
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DiaryEntryScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  int _selectedEmotionIndex = -1; // 今日の気分選択用
  late Stream<QuerySnapshot> _diariesStream;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _diariesStream = _firestore
        .collection('diaries')
        .orderBy('date', descending: true)
        .snapshots();
    _loadTodaysEmotion(); // 今日の感情を読み込んで選択状態に反映
  }

  // 今日の日記があれば、その感情をUIに反映する
  Future<void> _loadTodaysEmotion() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      final querySnapshot = await _firestore
          .collection('diaries')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final todayDiary = querySnapshot.docs.first.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _selectedEmotionIndex = todayDiary['emotionIndex'] as int? ?? -1;
          });
        }
      }
    } catch (e) {
      print("Error loading today's emotion: $e");
    }
  }


  Future<void> _saveOrUpdateTodaysEmotion(int emotionIndex) async {
    final now = DateTime.now();
    // 日付の比較を正確にするため、時刻部分をリセットした日付を使用
    final todayDateForQuery = DateTime(now.year, now.month, now.day);

    // FirestoreのTimestamp型で保存する日付 (実際の保存時刻)
    final Timestamp todayTimestamp = Timestamp.now();

    try {
      // 今日（日付のみで比較）の日記が既に存在するか確認
      final querySnapshot = await _firestore
          .collection('diaries')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayDateForQuery))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59)))
          .limit(1) // 念のため1件に絞る
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 既に今日の日記が存在する場合、emotionIndexを更新
        final docId = querySnapshot.docs.first.id;
        await _firestore.collection('diaries').doc(docId).update({
          'emotionIndex': emotionIndex,
          'updatedAt': FieldValue.serverTimestamp(), // 更新日時を記録
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('今日の気分を更新しました！ (${_getEmotionFace(emotionIndex)})'), duration: const Duration(seconds: 2)),
          );
        }
      } else {
        // 今日の日記が存在しない場合、新規作成
        await _firestore.collection('diaries').add({
          'date': todayTimestamp, // 保存する日付 (時刻も含む)
          'emotionIndex': emotionIndex,
          'content': '', // 本文はDiaryEntryScreenで入力
          'createdAt': FieldValue.serverTimestamp(), // 作成日時を記録
          // 必要であれば 'userId': FirebaseAuth.instance.currentUser?.uid なども追加
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('今日の気分を保存しました！ (${_getEmotionFace(emotionIndex)})'), duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      print("Error saving/updating today's emotion: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('気分の保存に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarPreview(),
            const SizedBox(height: 24),
            _buildEmotionSelector(),
            const SizedBox(height: 24),
            _buildRecentEntries(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarPreview() {
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month);

    return StreamBuilder<QuerySnapshot>(
      stream: _diariesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("CalendarPreview Stream Error: ${snapshot.error}");
          return const Text('カレンダープレビューの表示エラー');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final diaryDocs = snapshot.data?.docs ?? [];
        Map<int, int> monthlyEmotions = {};
        for (var doc in diaryDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final diaryTimestamp = data['date'] as Timestamp?;
          if (diaryTimestamp != null) {
            final diaryDate = diaryTimestamp.toDate();
            if (diaryDate.year == currentMonthDate.year && diaryDate.month == currentMonthDate.month) {
              monthlyEmotions[diaryDate.day] = data['emotionIndex'] as int? ?? 2;
            }
          }
        }

        final firstDayOfMonth = DateTime(currentMonthDate.year, currentMonthDate.month, 1);
        final firstWeekday = firstDayOfMonth.weekday % 7;
        final daysInMonth = DateTime(currentMonthDate.year, currentMonthDate.month + 1, 0).day;
        final rowCount = ((firstWeekday + daysInMonth -1) / 7).ceil();
        final months = ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'];

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${currentMonthDate.year}年 ${months[currentMonthDate.month - 1]}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Text('日', style: TextStyle(color: Color(0xFFF44336), fontWeight: FontWeight.bold)),
                  Text('月', style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.bold)),
                  Text('火', style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.bold)),
                  Text('水', style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.bold)),
                  Text('木', style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.bold)),
                  Text('金', style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.bold)),
                  Text('土', style: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: List.generate(rowCount, (rowIndex) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2), // 日付行の間隔を少し調整
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (colIndex) {
                        final dayIndex = rowIndex * 7 + colIndex - firstWeekday;
                        if (dayIndex < 0 || dayIndex >= daysInMonth) {
                          return const SizedBox(width: 32, height: 32); // サイズ調整
                        }
                        final day = dayIndex + 1;
                        Color? bgColor;
                        Color textColor = const Color(0xFF333333);

                        if (monthlyEmotions.containsKey(day)) {
                          final emotionIdx = monthlyEmotions[day]!;
                          if (emotionIdx >= 0 && emotionIdx < AppTheme.emotionColors.length) {
                            bgColor = AppTheme.emotionColors[emotionIdx];
                            textColor = Colors.white; // 背景色がある場合は白文字
                          }
                        }

                        bool isToday = now.year == currentMonthDate.year &&
                            now.month == currentMonthDate.month &&
                            now.day == day;

                        return Container(
                          width: 32, // サイズ調整
                          height: 32, // サイズ調整
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(16), // 丸くする
                              border: isToday && bgColor == null // 今日かつ感情未登録の場合のみ枠線
                                  ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                                  : null,
                              boxShadow: isToday && bgColor != null // 今日かつ感情登録済の場合、少し浮き上がらせる
                                  ? [ BoxShadow(color: bgColor.withOpacity(0.5), blurRadius: 3, offset: Offset(0,1)) ]
                                  : []
                          ),
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: isToday && bgColor == null ? AppTheme.primaryColor : textColor,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmotionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日の気分はどう？',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (index) {
            bool isSelected = _selectedEmotionIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEmotionIndex = index;
                });
                _saveOrUpdateTodaysEmotion(index); // タップ時に保存処理を呼び出す
              },
              child: Container(
                width: 52, // 少し大きく
                height: 52, // 少し大きく
                decoration: BoxDecoration(
                  color: AppTheme.emotionColors[index].withOpacity(isSelected ? 1.0 : 0.7), // 非選択時は少し薄く
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.3), // 非選択時も薄い枠線
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: AppTheme.emotionColors[index].withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ]
                      : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    _getEmotionFace(index),
                    style: TextStyle(
                      fontSize: isSelected ? 30 : 26, // 選択時は少し大きく
                      color: Colors.white.withOpacity(isSelected ? 1.0 : 0.8),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _getEmotionFace(int index) {
    if (index < 0 || index >= 5) return ''; // 不正な場合は空
    switch (index) {
      case 0: return '😢';
      case 1: return '😕';
      case 2: return '😐';
      case 3: return '🙂';
      case 4: return '😄';
      default: return '';
    }
  }

  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近の日記',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _diariesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('RecentEntries Stream Error: ${snapshot.error}');
              return const Text('最近の日記の読み込みに失敗しました。');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('まだ日記がありません。\n最初の記録をつけよう！✨', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),)),
              );
            }

            final diaryDocs = snapshot.data!.docs;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: diaryDocs.length > 5 ? 5 : diaryDocs.length, // 最大5件表示
              itemBuilder: (context, index) {
                final doc = diaryDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final diaryTimestamp = data['date'] as Timestamp?;
                String formattedDate = '日付不明';
                if (diaryTimestamp != null) {
                  formattedDate = DateFormat('M/d', 'ja_JP').format(diaryTimestamp.toDate());
                }
                final emotionIndex = data['emotionIndex'] as int? ?? 2;
                final content = data['content'] as String? ?? '';

                return _buildEntryCard(
                    date: formattedDate,
                    emotionIndex: emotionIndex,
                    content: content.isEmpty ? "（今日の気分のみ記録）" : content,
                    onTap: () {
                      // DiaryEntryを生成して詳細画面に遷移
                      final diaryEntry = DiaryEntry.fromFirestore(data, doc.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiaryDetailScreen(diary: diaryEntry),
                        ),
                      );
                    }
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEntryCard({
    required String date,
    required int emotionIndex,
    required String content,
    VoidCallback? onTap,
  }) {
    final validEmotionIndex = emotionIndex >= 0 && emotionIndex < AppTheme.emotionColors.length
        ? emotionIndex
        : 2;

    return InkWell( // タップ可能にする
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAEAEA)), // 少し薄く
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08), // 影をさらに薄く
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // 中央揃えに
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.emotionColors[validEmotionIndex],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column( // 日付と曜日を縦に並べる
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.split('/')[1], // 日付部分
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "${date.split('/')[0]}月", // 月部分
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, // 感情アイコンとテキストの縦位置を中央に
                children: [
                  Text(
                    _getEmotionFace(validEmotionIndex),
                    style: const TextStyle(fontSize: 22),
                  ),
                  if (content.isNotEmpty && content != "（今日の気分のみ記録）") ...[ // 本文がある場合のみ表示
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        color: Color(0xFF555555), // 少し濃く
                        fontSize: 13.5, // 微調整
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (content == "（今日の気分のみ記録）") ...[ // 気分のみ記録の場合
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
            ),
            if (onTap != null) // タップ可能な場合は矢印アイコン表示
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
