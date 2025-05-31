import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  // Firebase Storageインスタンス
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final uuid = const Uuid();
  
  // 画像をアップロード
  Future<String?> uploadImage({
    required String userId,
    required File imageFile,
    String? fileName,
  }) async {
    try {
      // ファイル名が指定されていない場合はUUIDを生成
      final name = fileName ?? '${uuid.v4()}.jpg';
      
      // ユーザーごとのディレクトリに保存
      final storageRef = _storage.ref().child('users/$userId/images/$name');
      
      // メタデータを設定
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      // アップロード実行
      final uploadTask = storageRef.putFile(imageFile, metadata);
      
      // アップロード完了を待機
      final snapshot = await uploadTask;
      
      // ダウンロードURLを取得
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('画像アップロードエラー: $e');
      return null;
    }
  }
  
  // 複数の画像をアップロード
  Future<List<String>> uploadMultipleImages({
    required String userId,
    required List<File> imageFiles,
  }) async {
    try {
      final List<String> imageUrls = [];
      
      for (var imageFile in imageFiles) {
        final url = await uploadImage(
          userId: userId,
          imageFile: imageFile,
        );
        
        if (url != null) {
          imageUrls.add(url);
        }
      }
      
      return imageUrls;
    } catch (e) {
      debugPrint('複数画像アップロードエラー: $e');
      return [];
    }
  }
  
  // 画像を削除
  Future<bool> deleteImage({
    required String imageUrl,
  }) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('画像削除エラー: $e');
      return false;
    }
  }
  
  // 複数の画像を削除
  Future<bool> deleteMultipleImages({
    required List<String> imageUrls,
  }) async {
    try {
      for (var imageUrl in imageUrls) {
        await deleteImage(imageUrl: imageUrl);
      }
      return true;
    } catch (e) {
      debugPrint('複数画像削除エラー: $e');
      return false;
    }
  }
  
  // ユーザーの全画像を削除（アカウント削除時など）
  Future<bool> deleteAllUserImages({
    required String userId,
  }) async {
    try {
      final storageRef = _storage.ref().child('users/$userId');
      
      // ユーザーディレクトリ内のすべてのアイテムを取得
      final ListResult result = await storageRef.listAll();
      
      // すべてのアイテムを削除
      for (var item in result.items) {
        await item.delete();
      }
      
      // サブディレクトリがある場合は再帰的に削除
      for (var prefix in result.prefixes) {
        final subResult = await prefix.listAll();
        for (var item in subResult.items) {
          await item.delete();
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('ユーザー画像削除エラー: $e');
      return false;
    }
  }
}
