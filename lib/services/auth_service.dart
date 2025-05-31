import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // 現在のユーザー
  User? _user;
  User? get user => _user;
  
  // ログイン状態
  bool get isLoggedIn => _user != null;
  
  // コンストラクタ
  AuthService() {
    // 認証状態の変更を監視
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }
  
  // Googleアカウントでサインイン
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return null;
    }
  }
  
  // サインアウト
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign Out Error: $e');
    }
  }
  
  // ユーザー情報の更新
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (_user != null) {
        await _user!.updateDisplayName(displayName);
        await _user!.updatePhotoURL(photoURL);
        
        // 更新後のユーザー情報を再取得
        await _user!.reload();
        _user = _auth.currentUser;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Update Profile Error: $e');
    }
  }
  
  // アカウント削除
  Future<bool> deleteAccount() async {
    try {
      if (_user != null) {
        await _user!.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete Account Error: $e');
      return false;
    }
  }
}
