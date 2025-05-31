import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yurufuwa_diary/services/image_service.dart'; // 画像選択サービス
import 'package:yurufuwa_diary/theme/app_theme.dart';
import 'package:yurufuwa_diary/widgets/image_preview.dart'; // 画像プレビューウィジェット
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication をインポート
import 'package:yurufuwa_diary/services/diary_service.dart';

// ColorUtils の darken 拡張メソッドは、app_theme.dart や専用のユーティリティファイルに定義し、
// ここからは削除するか、そこからインポートするようにしてください。
// 例: import 'package:yurufuwa_diary/utils/color_utils.dart';

class DiaryEntryScreen extends StatefulWidget {
  final String? diaryId; // 編集モード用に日記IDを受け取る (任意)
  final Map<String, dynamic>? existingDiaryData; // 編集モード用に既存データを受け取る (任意)

  const DiaryEntryScreen({
    Key? key,
    this.diaryId,
    this.existingDiaryData,
  }) : super(key: key);

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  int _selectedEmotionIndex = 2; // デフォルトは普通
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _diaryTextController = TextEditingController();
  final List<File> _attachedImages = []; // ローカルファイルのリスト
  List<String> _existingImageUrls = []; // 編集時の既存画像のURLリスト
  String? _currentUserId; // 現在のユーザーIDを保持

  final ImageService _imageService = ImageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuthのインスタンス
  final DiaryService _diaryService = DiaryService();

  bool _isSaving = false; // 保存処理中フラグ
  bool _isSelectingImage = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid; // 現在のユーザーIDを取得

    if (widget.diaryId != null && widget.existingDiaryData != null) {
      // 編集モードの場合、既存データをセット
      _selectedDate = (widget.existingDiaryData!['date'] as Timestamp).toDate();
      _selectedEmotionIndex =
          widget.existingDiaryData!['emotionIndex'] as int? ?? 2;
      _diaryTextController.text =
          widget.existingDiaryData!['content'] as String? ?? '';
      _existingImageUrls = List<String>.from(
          widget.existingDiaryData!['imageUrls'] as List<dynamic>? ?? []);
    } else {
      if (widget.existingDiaryData != null && widget.existingDiaryData!['date'] is Timestamp) {
        _selectedDate = (widget.existingDiaryData!['date'] as Timestamp).toDate();
      }
    }
  }

  @override
  void dispose() {
    _diaryTextController.dispose();
    super.dispose();
  }

  Future<List<String>> _uploadImages(List<File> images) async {
    List<String> imageUrls = [];
    for (File imageFile in images) {
      try {
        String fileName =
            'users/${_currentUserId ?? "guest_uploads"}/diary_images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        Reference ref = _storage.ref().child(fileName);
        UploadTask uploadTask = ref.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        print('Error uploading image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                Text('画像のアップロードに失敗: ${imageFile.path.split('/').last}'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
    return imageUrls;
  }

  void _saveEntry() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日記を保存するにはログインが必要です。'), backgroundColor: Colors.orange),
      );
      // return;
    }

    if (_diaryTextController.text.trim().isEmpty &&
        _attachedImages.isEmpty &&
        _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日記の内容または写真を入力してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      List<String> uploadedImageUrls = [];
      if (_attachedImages.isNotEmpty) {
        uploadedImageUrls = await _uploadImages(_attachedImages);
      }

      List<String> finalImageUrls = [
        ..._existingImageUrls,
        ...uploadedImageUrls
      ];

      Map<String, dynamic> diaryData = {
        'date': Timestamp.fromDate(_selectedDate),
        'emotionIndex': _selectedEmotionIndex,
        'content': _diaryTextController.text.trim(),
        'imageUrls': finalImageUrls,
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': _currentUserId ?? 'anonymous_user',
      };

      if (widget.diaryId != null) {
        await _firestore
            .collection('diaries')
            .doc(widget.diaryId)
            .update(diaryData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('日記を更新しました！')),
          );
        }
      } else {
        diaryData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('diaries').add(diaryData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('日記を保存しました！')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error saving diary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('日記の保存に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _deleteEntry() async {
    if (widget.diaryId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('日記を削除'),
        content: const Text('この日記を本当に削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _isDeleting = true; });
    try {
      final success = await _diaryService.deleteDiaryEntry(
        diaryId: widget.diaryId!,
        imageUrls: _existingImageUrls,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日記を削除しました。')),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('削除に失敗しました');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('日記の削除に失敗: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
        Text(widget.diaryId != null ? '日記を編集' : '新しい日記'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF333333)),
          tooltip: '閉じる',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isSaving ? null : _saveEntry,
              style: TextButton.styleFrom(
                backgroundColor: _isSaving ? Colors.grey[300] : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ))
                  : const Text(
                '保存する',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (widget.diaryId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _isSaving || _isDeleting ? null : _deleteEntry,
                style: TextButton.styleFrom(
                  backgroundColor: _isDeleting ? Colors.grey[300] : Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ))
                    : const Text(
                        '削除',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 80),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSelector(),
                  const SizedBox(height: 24),
                  _buildEmotionSelector(),
                  const SizedBox(height: 24),
                  _buildDiaryTextInput(),
                  const SizedBox(height: 24),
                  _buildPhotoAttachment(),
                  if (_attachedImages.isNotEmpty ||
                      _existingImageUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildImagePreviews(),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_isSaving || _isSelectingImage)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text("処理中です...", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  )
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: _showDatePicker,
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                _formatDate(_selectedDate),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          )
      ),
    );
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('yyyy年 M月 d日 (E)', 'ja_JP');
    return formatter.format(date);
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ja', 'JP'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildEmotionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日の気分',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 58 : 52,
                height: isSelected ? 58 : 52,
                decoration: BoxDecoration(
                  color: AppTheme.emotionColors[index].withOpacity(isSelected ? 1.0 : 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    // isSelected 時の AppTheme.emotionColors[index].darken(0.2) は削除
                    color: isSelected
                        ? AppTheme.primaryColor // 例: 代わりにプライマリカラーを使用
                        : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 3.0 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                        color:
                        AppTheme.emotionColors[index].withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 1)
                    )
                  ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    _getEmotionFace(index),
                    style: TextStyle(
                        fontSize: isSelected ? 30 : 26,
                        color: Colors.white
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
    if (index < 0 || index >= 5) return '😐';
    switch (index) {
      case 0: return '😢';
      case 1: return '😕';
      case 2: return '�';
      case 3: return '🙂';
      case 4: return '😄';
      default: return '😐';
    }
  }

  Widget _buildDiaryTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日記を書く',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCCCCC)),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0,1)
                )
              ]),
          child: TextField(
            controller: _diaryTextController,
            maxLines: 10,
            minLines: 6,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
              hintText: '今日はどんな一日でしたか？\n嬉しかったこと、悲しかったこと、気づいたことなど、\n自由に記録してみましょう。',
              hintStyle: TextStyle(
                  color: Color(0xFFAAAAAA), fontSize: 15, height: 1.5),
            ),
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoAttachment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '写真を追加 (任意)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildAttachmentButton(
                Icons.camera_alt_rounded, 'カメラで撮影', _takePhoto),
            const SizedBox(width: 12),
            _buildAttachmentButton(
                Icons.photo_library_rounded, 'ギャラリーから選択', _pickPhoto),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachmentButton(
      IconData icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 85,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: AppTheme.primaryColor, size: 30),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  // AppTheme.primaryColor.darken(0.1) は削除
                  color: AppTheme.primaryColor, // 例: 代わりにプライマリカラーを使用
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviews() {
    List<dynamic> allImages = [..._existingImageUrls, ..._attachedImages];

    if (allImages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '添付画像 (${allImages.length}枚)',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: allImages.length,
          itemBuilder: (context, index) {
            final item = allImages[index];
            Widget imageWidget;

            if (item is String) {
              imageWidget = Image.network(
                item,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryColor,));
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36)
                  );
                },
              );
            } else if (item is File) {
              imageWidget = Image.file(item, fit: BoxFit.cover);
            } else {
              imageWidget = Container(color: Colors.red[100], child: const Icon(Icons.error_outline, color: Colors.red, size: 36));
            }

            return Hero(
              tag: 'image_preview_$index',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (item is File) {
                        final localFiles = allImages.whereType<File>().toList();
                        final fileIndex = localFiles.indexOf(item);
                        if (fileIndex != -1) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ImagePreviewScreen(images: localFiles, initialIndex: fileIndex)));
                        }
                      } else if (item is String) {
                        print("Network image preview tapped: $item");
                      }
                    },
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: Offset(1,1)
                              )
                            ]
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: imageWidget,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _removeImage(index, item is String),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isSelectingImage = true);
      final imageFile = await _imageService.getImageFromCamera();
      if (imageFile != null) {
        if (_attachedImages.length + _existingImageUrls.length < 5) {
          setState(() => _attachedImages.add(imageFile));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("写真は5枚まで添付できます。")));
        }
      }
    } catch (e) {
      print("Error taking photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("カメラの起動に失敗しました: $e"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSelectingImage = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      setState(() => _isSelectingImage = true);
      final imageFile = await _imageService.getImageFromGallery();
      if (imageFile != null) {
        if (_attachedImages.length + _existingImageUrls.length < 5) {
          setState(() => _attachedImages.add(imageFile));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("写真は5枚まで添付できます。")));
        }
      }
    } catch (e) {
      print("Error picking photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("ギャラリーの起動に失敗しました: $e"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSelectingImage = false);
    }
  }

  void _removeImage(int index, bool isExistingUrl) {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('画像の削除'),
            content: const Text('この画像を削除しますか？\nこの操作は元に戻せません。'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('キャンセル', style: TextStyle(color: Colors.grey))),
              TextButton(
                  style: TextButton.styleFrom(backgroundColor: Colors.red[50]),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      String? urlToRemove;
                      if (isExistingUrl) {
                        if (index < _existingImageUrls.length) {
                          urlToRemove = _existingImageUrls.removeAt(index);
                          print("Marked existing image for removal (will be removed on save): $urlToRemove");
                        }
                      } else {
                        final localImageIndex = index - _existingImageUrls.length;
                        if (localImageIndex >= 0 && localImageIndex < _attachedImages.length) {
                          _attachedImages.removeAt(localImageIndex);
                        }
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画像をリストから削除しました'), duration: Duration(seconds: 1),));
                  },
                  child: const Text('削除する', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          );
        });
  }

}