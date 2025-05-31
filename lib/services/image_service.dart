import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:yurufuwa_diary/services/storage_service.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final uuid = const Uuid();
  
  // カメラから画像を取得
  Future<File?> getImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('カメラからの画像取得エラー: $e');
      return null;
    }
  }
  
  // ギャラリーから画像を取得
  Future<File?> getImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('ギャラリーからの画像取得エラー: $e');
      return null;
    }
  }
  
  // 複数の画像をギャラリーから取得
  Future<List<File>> getMultipleImagesFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      return images.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      debugPrint('複数画像取得エラー: $e');
      return [];
    }
  }
  
  // 画像をアップロードしてURLを取得
  Future<String?> uploadImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final fileName = '${uuid.v4()}.jpg';
      return await _storageService.uploadImage(
        userId: userId,
        imageFile: imageFile,
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('画像アップロードエラー: $e');
      return null;
    }
  }
  
  // 複数の画像をアップロードしてURLのリストを取得
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
  
  // 一時ファイルとして画像を保存
  Future<File?> saveImageToTemp(File imageFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = '${uuid.v4()}.jpg';
      final targetPath = '${tempDir.path}/$fileName';
      
      return await imageFile.copy(targetPath);
    } catch (e) {
      debugPrint('一時ファイル保存エラー: $e');
      return null;
    }
  }
  
  // 画像をキャッシュディレクトリに保存
  Future<File?> saveImageToCache(File imageFile) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final fileName = '${uuid.v4()}.jpg';
      final targetPath = '${cacheDir.path}/$fileName';
      
      return await imageFile.copy(targetPath);
    } catch (e) {
      debugPrint('キャッシュ保存エラー: $e');
      return null;
    }
  }
  
  // 画像を永続的に保存
  Future<File?> saveImagePermanently(File imageFile) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = '${uuid.v4()}.jpg';
      final targetPath = '${docDir.path}/$fileName';
      
      return await imageFile.copy(targetPath);
    } catch (e) {
      debugPrint('永続保存エラー: $e');
      return null;
    }
  }
  
  // 画像ファイルを削除
  Future<bool> deleteImageFile(File imageFile) async {
    try {
      if (await imageFile.exists()) {
        await imageFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('画像ファイル削除エラー: $e');
      return false;
    }
  }
}
