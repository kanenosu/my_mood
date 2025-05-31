import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  final String id;
  final String userId;
  final DateTime date;
  final int emotionIndex;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  DiaryEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.emotionIndex,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    this.updatedAt,
  });
  
  // Firestoreのドキュメントからインスタンスを作成
  factory DiaryEntry.fromFirestore(Map<String, dynamic> data, String docId) {
    return DiaryEntry(
      id: docId,
      userId: data['userId'] ?? '',
      date: data['date']?.toDate() ?? DateTime.now(),
      emotionIndex: data['emotionIndex'] ?? 2,
      content: data['content'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }
  
  // Firestoreに保存するデータに変換
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'emotionIndex': emotionIndex,
      'content': content,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
  
  // コピーを作成して一部のプロパティを更新
  DiaryEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    int? emotionIndex,
    String? content,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      emotionIndex: emotionIndex ?? this.emotionIndex,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
