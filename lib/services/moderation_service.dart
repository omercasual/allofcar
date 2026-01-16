import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class ModerationResult {
  final bool isSafe;
  final String? reason;

  ModerationResult({required this.isSafe, this.reason});
}

class ModerationService {
  // Key & Models managed by GeminiService now.

  Future<ModerationResult> checkText(String text) async {
    if (text.isEmpty) return ModerationResult(isSafe: true);

    const systemPrompt = """
    Sen bir forum moderatörüsün. Sana gönderilen metni analiz et.
    Eğer metinde küfür, ağır argo, hakaret, cinsellik, şiddet veya topluluk kurallarını bozan 
    herhangi bir içerik varsa 'UNSAFE' ve sebebini dön.
    Eğer içerik temizse sadece 'SAFE' dön.
    
    Format:
    Status: SAFE veya UNSAFE
    Reason: (Sadece UNSAFE ise burayı doldur)
    """;

    // GeminiService calls add "Kullanıcı: " prefix, so we just pass text
    final result = await GeminiService().generateContent(systemPrompt, text);
    if (result != null) {
      return _parseResult(result);
    }
    return ModerationResult(isSafe: true); // Fail safe
  }

  /// Checks images (Base64) for inappropriate or obscene content.
  Future<ModerationResult> checkImage(String base64Image) async {
    const systemPrompt = """
    Sen bir görsel analiz uzmanısın. Sana gönderilen görseli analiz et.
    Görselde müstehcenlik, çıplaklık, aşırı şiddet veya yasa dışı içerik varsa 'UNSAFE ve sebebini dön.
    Görsel temizse sadece 'SAFE' dön.
    
    Format:
    Status: SAFE veya UNSAFE
    Reason: (Sadece UNSAFE ise burayı doldur)
    """;

    final result = await GeminiService().generateContent(
      systemPrompt, 
      "Lütfen bu görseli analiz et.",
      imageParts: [base64Image]
    );

    if (result != null) {
      return _parseResult(result);
    }
    return ModerationResult(isSafe: true);
  }

  // _callGemini methods removed as GeminiService handles it.

  ModerationResult _parseResult(String aiText) {
    final lines = aiText.split('\n');
    bool isSafe = true;
    String? reason;

    for (var line in lines) {
      if (line.toUpperCase().contains('STATUS: UNSAFE')) {
        isSafe = false;
      }
      if (line.toUpperCase().contains('REASON:')) {
        reason = line.split(':').last.trim();
      }
    }

    return ModerationResult(isSafe: isSafe, reason: reason);
  }
}
