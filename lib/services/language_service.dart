import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  // Singleton instance
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  // ValueNotifier for listening to language changes
  final ValueNotifier<String> languageNotifier = ValueNotifier<String>('tr');

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // Initialize: Load language from Firestore (if logged in) or keep default
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedLang = prefs.getString('language_code');

      if (savedLang != null) {
        languageNotifier.value = savedLang;
      }
      
      final uid = _authService.currentUser?.uid;
      if (uid != null && savedLang == null) {
         // If no local preference, try to fetch from Firestore eventually
         // For now, we prioritize local first.
      }
    } catch (e) {
      debugPrint("Language init error: $e");
    }
  }

  // Update language: Update notifier and persist to Firestore
  Future<void> setLanguage(String languageCode) async {
    if (languageNotifier.value != languageCode) {
      languageNotifier.value = languageCode;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', languageCode);
      
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        await _firestoreService.updateLanguage(uid, languageCode);
      }
    }
  }
  
  // Getter for current language
  String get currentLanguage => languageNotifier.value;
}
