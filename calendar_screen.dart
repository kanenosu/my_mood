import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore をインポート
import 'package:intl/intl.dart'; // 日付フォーマットのため
import 'package:yurufuwa_diary/theme/app_theme.dart'; // AppTheme.emotionColors を使う
import 'package:yurufuwa_diary/screens/diary_entry_screen.dart'; // DiaryEntryScreenへのパス
import 'package:yurufuwa_diary/screens/diary_detail_screen.dart'; // DiaryDetailScreenへのパスを追加
import 'package:yurufuwa_diary/models/diary_entry.dart'; // DiaryEntryモデルのパスを追加

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<int, Map<String, dynamic>> _monthlyDiaryData = {};
  Map<String, dynamic>? _selectedDiaryContent; // Firestoreから取得した生のMapデータ
  bool _isLoadingMonthlyDiaries = true;
  bool _isLoadingSelectedDiary = false;

  final List<Color> _emotionColors = AppTheme.emotionColors;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadMonthlyDiaries();
    if (_selectedDate != null) {
      _loadDiaryForSelectedDate(_selectedDate!);
    }
  }

  Future<void> _loadMonthlyDiaries() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMonthlyDiaries = true;
      _monthlyDiaryData = {};
    });

    final startOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final endOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

    try {
      final querySnapshot = await _firestore
          .collection('diaries')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('date', descending: true)
          .get();

      Map<int, Map<String, dynamic>> newMonthlyData = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final diaryTimestamp = data['date'] as Timestamp?;
        if (diaryTimestamp != null) {
          final diaryDate = diaryTimestamp.toDate();
          if (!newMonthlyData.containsKey(diaryDate.day)) {
            newMonthlyData[diaryDate.day] = {
              'id': doc.id,
              'date': data['date'], // Timestampのまま保持
              'emotionIndex': data['emotionIndex'] as int? ?? 2,
              'content': data['content'] as String? ?? '',
              'imageUrls': List<String>.from(data['imageUrls'] as List<dynamic>? ?? []),
              'userId': data['userId'] as String? ?? 'default_user_id', // userId を取得 (存在しない場合はデフォルト値)
            };
          }
        }
      }
      if (mounted) {
        setState(() {
          _monthlyDiaryData = newMonthlyData;
        });
      }
    } catch (e) {
      print("Error loading monthly diaries: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('月間日記の読み込みに失敗: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMonthlyDiaries = false;
        });
      }
    }
  }

  Future<void> _loadDiaryForSelectedDate(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _isLoadingSelectedDiary = true;
      _selectedDiaryContent = null;
    });

    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      final querySnapshot = await _firestore
          .collection('diaries')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (mounted) {
        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          final data = doc.data();
          setState(() {
            _selectedDiaryContent = {
              'id': doc.id,
              'date': data['date'] as Timestamp,
              'emotionIndex': data['emotionIndex'] as int? ?? 2,
              'content': data['content'] as String? ?? 'この日の日記はありません。',
              'imageUrls': List<String>.from(data['imageUrls'] as List<dynamic>? ?? []),
              'userId': data['userId'] as String? ?? 'default_user_id',
              'createdAt': data['createdAt'] as Timestamp? ?? Timestamp.now(),
              'updatedAt': data['updatedAt'] as Timestamp?,
            };
          });
        } else {
          setState(() {
            _selectedDiaryContent = null;
          });
        }
      }
    } catch (e) {
      print("Error loading selected diary: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選択日の日記読み込みに失敗: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSelectedDiary = false;
        });
      }
    }
  }

  void _navigateToDiaryEntryScreen({String? diaryId, Map<String, dynamic>? existingData}) async {
    Map<String, dynamic>? dataForEntryScreen = existingData;
    if (existingData != null && existingData['date'] is DateTime) {
      dataForEntryScreen = Map.from(existingData);
      dataForEntryScreen['date'] = Timestamp.fromDate(existingData['date'] as DateTime);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryEntryScreen(
          diaryId: diaryId,
          existingDiaryData: dataForEntryScreen,
        ),
      ),
    );

    if (result == true && mounted) {
      _loadMonthlyDiaries();
      if (_selectedDate != null) {
        _loadDiaryForSelectedDate(_selectedDate!);
      }
    }
  }

  void _navigateToDetailScreen(DiaryEntry diary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryDetailScreen(diary: diary),
      ),
    ).then((_) {
      _loadMonthlyDiaries();
      if (_selectedDate != null) {
        _loadDiaryForSelectedDate(_selectedDate!);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'カレンダー',
          style: TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 28),
            tooltip: '新しい日記を書く',
            onPressed: () {
              _navigateToDiaryEntryScreen();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(),
          _buildDiaryPreview(),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFF555555), size: 30),
                tooltip: '前の月',
                onPressed: _previousMonth,
              ),
              Text(
                DateFormat.yMMMM('ja_JP').format(_currentMonth),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFF555555), size: 30),
                tooltip: '次の月',
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['日','月','火','水','木','金','土'].map((dayLabel) {
              return Text(
                dayLabel,
                style: TextStyle(
                  color: dayLabel == '日' ? Colors.redAccent : (dayLabel == '土' ? Colors.blueAccent : Colors.grey[700]),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          _isLoadingMonthlyDiaries
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3,)),
          )
              : _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final firstWeekday = (firstDayOfMonth.weekday == 7) ? 0 : firstDayOfMonth.weekday;

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final rowCount = ((firstWeekday + daysInMonth + 6) / 7).floor();


    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (colIndex) {
              final dayIndex = rowIndex * 7 + colIndex - firstWeekday;

              if (dayIndex < 0 || dayIndex >= daysInMonth) {
                return const SizedBox(width: 40, height: 40);
              }

              final day = dayIndex + 1;
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == date.year &&
                  _selectedDate!.month == date.month &&
                  _selectedDate!.day == date.day;

              Color? bgColor;
              Color textColor = Colors.black87;
              int emotionIdxFromData = -1;

              if (_monthlyDiaryData.containsKey(day)) {
                final diaryDataForDay = _monthlyDiaryData[day]!;
                emotionIdxFromData = diaryDataForDay['emotionIndex'];
                if (emotionIdxFromData >= 0 && emotionIdxFromData < _emotionColors.length) {
                  bgColor = _emotionColors[emotionIdxFromData];
                  textColor = Colors.white;
                } else {
                  bgColor = Colors.grey[200];
                  textColor = Colors.black54;
                }
              }

              bool isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                  _loadDiaryForSelectedDate(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: AppTheme.primaryColor, width: 2.5)
                        : (isToday && bgColor == null
                        ? Border.all(color: AppTheme.primaryColor.withOpacity(0.7), width: 1.5)
                        : Border.all(color: Colors.grey[300]!, width: 0.5)),
                    boxShadow: isSelected && bgColor != null ? [
                      BoxShadow(
                        color: bgColor.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0,2),
                      )
                    ] : [],
                  ),
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isSelected && bgColor == null ? AppTheme.primaryColor : textColor,
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildDiaryPreview() {
    if (_selectedDate == null) {
      return Expanded(
        child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('カレンダーで日付を選択すると、\nその日の日記が表示されます。', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.5)),
            )
        ),
      );
    }

    if (_isLoadingSelectedDiary) {
      return const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    }

    final dateStr = DateFormat('yyyy年 M月 d日 (E)', 'ja_JP').format(_selectedDate!);

    if (_selectedDiaryContent == null) {
      return Expanded(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(dateStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const SizedBox(height: 20),
              Icon(Icons.menu_book, size: 50, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('この日の日記はまだありません。', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('この日の日記を書く'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)
                ),
                onPressed: () {
                  _navigateToDiaryEntryScreen(existingData: {'date': Timestamp.fromDate(_selectedDate!)});
                },
              )
            ],
          ),
        ),
      );
    }

    final DiaryEntry diaryToDisplay = DiaryEntry(
      id: _selectedDiaryContent!['id'] as String,
      date: (_selectedDiaryContent!['date'] as Timestamp).toDate(),
      emotionIndex: _selectedDiaryContent!['emotionIndex'] as int,
      content: _selectedDiaryContent!['content'] as String,
      imageUrls: _selectedDiaryContent!['imageUrls'] as List<String>,
      userId: _selectedDiaryContent!['userId'] as String? ?? 'default_user_id',
      createdAt: (_selectedDiaryContent!['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (_selectedDiaryContent!['updatedAt'] as Timestamp?)?.toDate(),
    );

    final emotionIndex = diaryToDisplay.emotionIndex;
    final content = diaryToDisplay.content;
    final imageUrls = diaryToDisplay.imageUrls;
    final validEmotionIndex = emotionIndex >= 0 && emotionIndex < _emotionColors.length ? emotionIndex : 2;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _navigateToDetailScreen(diaryToDisplay);
        },
        child: Container(
          width: double.infinity,
          color: Colors.grey[50],
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    Icon(Icons.touch_app_outlined, color: AppTheme.primaryColor.withOpacity(0.7), size: 24),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0,2),
                        )
                      ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _emotionColors[validEmotionIndex],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(_getEmotionFace(validEmotionIndex), style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getEmotionName(validEmotionIndex),
                            style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (content.isNotEmpty)
                        Text(
                          content,
                          style: TextStyle(color: Colors.grey[850], fontSize: 15, height: 1.6, overflow: TextOverflow.ellipsis),
                          maxLines: 3,
                        )
                      else
                        Text(
                          "この日の日記には、文章がありません。",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      if (imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text("添付画像 (${imageUrls.length}枚):", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls.length > 3 ? 3 : imageUrls.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network( // ここは cached_network_image を使うとより良い
                                    imageUrls[index],
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 30),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (imageUrls.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text("他 ${imageUrls.length - 3} 枚...", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          )
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _previousMonth() {
    if (!mounted) return;
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _selectedDate = null;
      _selectedDiaryContent = null;
    });
    _loadMonthlyDiaries();
  }

  void _nextMonth() {
    if (!mounted) return;
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _selectedDate = null;
      _selectedDiaryContent = null;
    });
    _loadMonthlyDiaries();
  }

  String _getEmotionFace(int index) {
    if (index < 0 || index >= _emotionColors.length) return '😐';
    switch (index) {
      case 0: return '😢';
      case 1: return '�';
      case 2: return '😐';
      case 3: return '🙂';
      case 4: return '😄';
      default: return '😐';
    }
  }

  String _getEmotionName(int index) {
    if (index < 0 || index >= _emotionColors.length) return '普通';
    switch (index) {
      case 0: return 'とても悲しい';
      case 1: return '少し悲しい';
      case 2: return '普通';
      case 3: return '少しハッピー';
      case 4: return 'とてもハッピー';
      default: return '普通';
    }
  }
}
