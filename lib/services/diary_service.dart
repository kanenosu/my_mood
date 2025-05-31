import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:yurufuwa_diary/models/diary_entry.dart';
import 'package:yurufuwa_diary/services/auth_service.dart';
import 'package:yurufuwa_diary/services/image_service.dart';

class DiaryService {
  // Firestoreインスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImageService _imageService = ImageService();
  final uuid = const Uuid();
  
  // 日記コレクション参照
  CollectionReference get _diariesRef => _firestore.collection('diaries');
  
  // 日記エントリーを保存（画像アップロード含む）
  Future<String?> saveDiaryEntryWithImages({
    required String userId,
    required DateTime date,
    required int emotionIndex,
    required String content,
    required List<File> images,
  }) async {
    try {
      // 1. 画像をアップロード
      List<String> imageUrls = [];
      if (images.isNotEmpty) {
        imageUrls = await _imageService.uploadMultipleImages(
          userId: userId,
          imageFiles: images,
        );
      }
      
      // 2. 日記データを保存
      final diaryData = {
        'userId': userId,
        'date': Timestamp.fromDate(date),
        'emotionIndex': emotionIndex,
        'content': content,
        'imageUrls': imageUrls,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      
      final docRef = await _diariesRef.add(diaryData);
      return docRef.id;
    } catch (e) {
      debugPrint('日記保存エラー: $e');
      return null;
    }
  }
  
  // 日記エントリーを更新（画像アップロード含む）
  Future<bool> updateDiaryEntryWithImages({
    required String diaryId,
    required String userId,
    required DateTime date,
    required int emotionIndex,
    required String content,
    required List<String> existingImageUrls,
    required List<File> newImages,
  }) async {
    try {
      // 1. 新しい画像をアップロード
      List<String> newImageUrls = [];
      if (newImages.isNotEmpty) {
        newImageUrls = await _imageService.uploadMultipleImages(
          userId: userId,
          imageFiles: newImages,
        );
      }
      
      // 2. 既存の画像URLと新しい画像URLを結合
      final allImageUrls = [...existingImageUrls, ...newImageUrls];
      
      // 3. 日記データを更新
      final diaryData = {
        'date': Timestamp.fromDate(date),
        'emotionIndex': emotionIndex,
        'content': content,
        'imageUrls': allImageUrls,
        'updatedAt': Timestamp.now(),
      };
      
      await _diariesRef.doc(diaryId).update(diaryData);
      return true;
    } catch (e) {
      debugPrint('日記更新エラー: $e');
      return false;
    }
  }
  
  // 日記エントリーを削除（画像も削除）
  Future<bool> deleteDiaryEntry({
    required String diaryId,
    required List<String> imageUrls,
  }) async {
    try {
      // 1. Firestoreから日記を削除
      await _diariesRef.doc(diaryId).delete();
      
      // 2. Storageから画像を削除
      final storage = FirebaseStorage.instance;
      for (var imageUrl in imageUrls) {
        try {
          final ref = storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('画像削除エラー: $e');
          // 画像削除に失敗しても処理を続行
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('日記削除エラー: $e');
      return false;
    }
  }
  
  // ユーザーの日記エントリーを取得
  Future<List<DiaryEntry>> getUserDiaries({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    try {
      Query query = _diariesRef
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true);
      
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DiaryEntry.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('日記取得エラー: $e');
      return [];
    }
  }
  
  // 特定の日の日記エントリーを取得
  Future<DiaryEntry?> getDiaryByDate({
    required String userId,
    required DateTime date,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final querySnapshot = await _diariesRef
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      
      return DiaryEntry.fromFirestore(data, doc.id);
    } catch (e) {
      debugPrint('日記取得エラー: $e');
      return null;
    }
  }
  
  // 月ごとの感情データを取得
  Future<Map<DateTime, int>> getMonthlyEmotionData({
    required String userId,
    required DateTime month,
  }) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      
      final querySnapshot = await _diariesRef
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();
      
      final Map<DateTime, int> emotionData = {};
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['date'] as Timestamp).toDate();
        final emotionIndex = data['emotionIndex'] as int;
        
        // 日付のみを保持（時間情報を削除）
        final dateOnly = DateTime(date.year, date.month, date.day);
        emotionData[dateOnly] = emotionIndex;
      }
      
      return emotionData;
    } catch (e) {
      debugPrint('感情データ取得エラー: $e');
      return {};
    }
  }
  
  // 感情統計データを取得
  Future<Map<int, int>> getEmotionStats({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _diariesRef.where('userId', isEqualTo: userId);
      
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final querySnapshot = await query.get();
      
      // 感情レベルごとの集計
      final Map<int, int> stats = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0};
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final emotionIndex = data['emotionIndex'] as int;
        
        if (stats.containsKey(emotionIndex)) {
          stats[emotionIndex] = stats[emotionIndex]! + 1;
        }
      }
      
      return stats;
    } catch (e) {
      debugPrint('感情統計取得エラー: $e');
      return {0: 0, 1: 0, 2: 0, 3: 0, 4: 0};
    }
  }
  
  // 日記のリアルタイム更新を監視
  Stream<List<DiaryEntry>> streamUserDiaries({
    required String userId,
    int limit = 20,
  }) {
    try {
      return _diariesRef
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DiaryEntry.fromFirestore(data, doc.id);
          }).toList();
        });
    } catch (e) {
      debugPrint('日記ストリーム取得エラー: $e');
      return Stream.value([]);
    }
  }
  
  // サンプルデータを削除
  Future<bool> deleteAllSampleData() async {
    try {
      // すべての日記エントリーを取得
      final querySnapshot = await _diariesRef.get();
      
      // 各ドキュメントを削除
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrls = List<String>.from(data['imageUrls'] ?? []);
        
        // 画像を削除
        final storage = FirebaseStorage.instance;
        for (var imageUrl in imageUrls) {
          try {
            final ref = storage.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            debugPrint('画像削除エラー: $e');
          }
        }
        
        // ドキュメントを削除
        await doc.reference.delete();
      }
      
      return true;
    } catch (e) {
      debugPrint('サンプルデータ削除エラー: $e');
      return false;
    }
  }
}
