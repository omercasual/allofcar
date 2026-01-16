import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Şu anki kullanıcıyı getir
  User? get currentUser => _auth.currentUser;

  // Durum değişikliklerini dinle
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Giriş Yap
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint("DEBUG AUTH ERROR: $e");
      return null;
    }
  }

  // Kayıt Ol
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  // Şifre Sıfırlama E-postası Gönder
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Şifre ile Yeniden Kimlik Doğrulama (Güvenlik İçin)
  Future<bool> reauthenticate(String password) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint("Reauth Error: $e");
      return false;
    }
  }

  // Şifre Güncelleme
  Future<bool> updatePassword(String newPassword) async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.updatePassword(newPassword);
      return true;
    } catch (e) {
      debugPrint("Password Update Error: $e");
      return false;
    }
  }

  // Çıkış Yap
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
