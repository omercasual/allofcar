
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firestore_service.dart';
import 'language_service.dart';

class GeminiService {
  // Singleton pattern
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  
  GeminiService._internal() {
    _initializeKeys();
  }

  // API Keys Pool
  List<String> _apiKeys = [];

  void _initializeKeys() {
    // 1. Load initial keys from .env
    final envKey1 = dotenv.env['GEMINI_API_KEY_1'] ?? '';
    final envKey2 = dotenv.env['GEMINI_API_KEY_2'] ?? '';
    _updateKeyList(envKey1, envKey2);

    // 2. Listen to Firestore updates for dynamic keys
    FirestoreService().fetchGeminiKeys().listen((keys) {
      final firestoreKey1 = keys['key1'] ?? '';
      final firestoreKey2 = keys['key2'] ?? '';
      
      // If Firestore has keys, they override or add to the pool.
      // Logic: If Firestore keys exist, use them. If not, fallback to .env (already loaded).
      // Actually, let's merge/prioritize.
      
      String k1 = firestoreKey1.isNotEmpty ? firestoreKey1 : envKey1;
      String k2 = firestoreKey2.isNotEmpty ? firestoreKey2 : envKey2;
      
      if (k1.isNotEmpty || k2.isNotEmpty) {
         _updateKeyList(k1, k2);
         debugPrint("🔄 GeminiService: API Keys updated from Firestore/Env.");
      }
    });
  }

  void _updateKeyList(String k1, String k2) {
    _apiKeys = [k1, k2].where((key) => key.isNotEmpty).toList();
  }

  int _currentKeyIndex = 0;

  // Models to try in order of priority
  final List<String> _models = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];

  /// Rotates the API key to the next available one.
  void _rotateKey() {
    if (_apiKeys.length <= 1) return; // No other key to switch to
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    debugPrint("⚠️ GeminiService: Switching to API Key index $_currentKeyIndex");
  }

  String get _currentKey => _apiKeys[_currentKeyIndex];

  /// Generates content using Gemini API with automatic key rotation and model fallback.
  Future<String?> generateContent(String systemPrompt, String userMessage, {List<String>? imageParts}) async {
    // We will try each model in the list until one succeeds
    // If a model fails with Quota Limit (429), we rotate the key AND retry the SAME model before moving on.
    
    // Simplification for stability: We try models in order. 
    // If a key fails (429), we switch key and retry the current model loop.
    
    // To prevent infinite loops, we can limit the total attempts.
    
    for (var model in _models) {
      bool keyRotatedForThisModel = false;
      
      // Try the model (potentially twice if we rotate keys)
      for (int attempt = 0; attempt < (_apiKeys.length > 1 ? 2 : 1); attempt++) {
        debugPrint("🤖 GeminiService: Call $_currentKeyIndex | Model: $model | Attempt: $attempt");
        
        try {
          String finalSystemPrompt = systemPrompt;
          
          // Only add language instruction if not already present explicitly or generic
          if (!finalSystemPrompt.contains("Respond in")) {
             final currentLang = LanguageService().currentLanguage;
             final langName = currentLang == 'tr' ? 'Turkish' : 'English';
             finalSystemPrompt += "\n\nCRITICAL: Respond in $langName language.";
          }

          final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_currentKey');
          
          final List<Map<String, dynamic>> parts = [
            {"text": "$finalSystemPrompt\n\nINPUT: $userMessage"}
          ];

          if (imageParts != null) {
            for (var imgBase64 in imageParts) {
              parts.add({
                "inline_data": {
                  "mime_type": "image/png",
                  "data": imgBase64
                }
              });
            }
          }
          
          final Map<String, dynamic> body = {
            "contents": [
              {
                "role": "user",
                "parts": parts
              }
            ]
          };
          
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['candidates'] != null && data['candidates'].isNotEmpty) {
               return data['candidates'][0]['content']['parts'][0]['text'];
            }
          } else if (response.statusCode == 429) {
            debugPrint("🛑 Quota Exceeded for Key $_currentKeyIndex on model $model");
            _rotateKey();
            keyRotatedForThisModel = true;
            // Loop continues to retry with new key
          } else {
             debugPrint("❌ Model $model failed: ${response.statusCode}");
             // If 404 (Not Found), it means model doesn't exist/supported, break inner loop to try next model
             if (response.statusCode == 404) break; 
          }
          
        } catch (e) {
          debugPrint("🔥 Exception working with $model: $e");
        }
        
        // If we successfully rotated, we retry loop. 
        // If we didn't rotate (e.g. not 429, or only 1 key), break inner loop to try next model
        if (!keyRotatedForThisModel) break; 
      }
    }
    
    return null; // All attempts failed
  }

  /// AI Supervisor: Evaluate User Feedback on Fault Log
  Future<Map<String, dynamic>?> evaluateFaultFeedback(String problem, String aiResponse, String userCorrection) async {
    const systemPrompt = """
Role: Senior Automotive Supervisor & AI Trainer.
Task: Evaluate a user's negative feedback on an AI fault diagnosis to decide if the AI made a mistake worth tracking/fixing or if the user feedback should be ignored.

Input:
1. User Reported Problem
2. AI Diagnosis
3. User Correction (Feedback)

Output Format: JSON only.
{
  "suggestion": "track" | "ignore", 
  "reasoning": "Short explanation (max 2 sentences) in Turkish."
}

Rules:
- suggestion = "track": If the AI likely missed something, gave dangerous advice, or the user's correction is technically valid and specific (e.g., "It's the ignition coil, not spark plug").
- suggestion = "ignore": If the user's feedback is vague ("bad", "wrong"), abusive, irrelevant, or clearly incorrect based on the problem description.
    """;

    final userMessage = """
PROBLEM: $problem
AI DIAGNOSIS: $aiResponse
USER CORRECTION: $userCorrection
    """;

    try {
      final jsonResponse = await generateContent(systemPrompt, userMessage);
      if (jsonResponse != null) {
        // Clean markdown code blocks if present
        String cleanJson = jsonResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanJson);
      }
    } catch (e) {
      debugPrint("AI Supervisor Error: $e");
    }
    return null;
  }

  /// AI Supervisor: Evaluate Reported Content (Moderation)
  Future<Map<String, dynamic>?> evaluateModerationContent(String content, String reason, String type) async {
    const systemPrompt = """
Role: Senior Community Moderator & Safety AI.
Task: Evaluate a reported content piece to determine if it truly violates community guidelines or is safe.

Input:
1. Content Type (Post/Comment)
2. Content Text
3. Report Reason

Output Format: JSON only.
{
  "suggestion": "safe" | "unsafe", 
  "reasoning": "Short explanation (max 2 sentences) in Turkish.",
  "confidence": 0.0 to 1.0
}

Rules:
- suggestion = "unsafe": If content contains hate speech, severe insults, spam, illegal content, or explicitly violates standard safe-for-work guidelines.
- suggestion = "safe": If content is just an opinion, a mild complaint, or unrelated to the reported reason.
    """;

    final userMessage = """
TYPE: $type
CONTENT: $content
REPORT REASON: $reason
    """;

    try {
      final jsonResponse = await generateContent(systemPrompt, userMessage);
      if (jsonResponse != null) {
        String cleanJson = jsonResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanJson);
      }
    } catch (e) {
      debugPrint("AI Moderation Error: $e");
    }
    return null;
  }

  /// AI Assistant: Generate or Refine Support Reply
  Future<String?> generateSupportReply(String userMessage, {String? draft}) async {
    String systemPrompt = """
Role: Professional Customer Support Representative for 'AllofCar' (Automotive App).
Task: Write a polite, helpful, and professional reply to a user's support request.

Context:
- App Name: AllofCar
- Tone: Professional, Empathetic, Solution-Oriented, Polite (Turkish Language).
- User Message: The user's original complaint or question.
- Draft: (Optional) A rough draft provided by the admin to be refined.

Instructions:
1. If a 'Draft' is provided: Refine it to be more professional and polite while keeping the original meaning. Correct grammar/spelling.
2. If NO 'Draft' is provided: Generate a complete, appropriate response based on the 'User Message'. Acknowledge the issue, apologize if necessary, and provide a helpful next step or reassurance.
3. Language: TURKISH (Türkçe).
4. Output: Return ONLY the reply text. No JSON, no "Here is the reply:", just the content.
    """;

    String combinedMessage = "USER MESSAGE: $userMessage";
    if (draft != null && draft.isNotEmpty) {
      combinedMessage += "\nADMIN DRAFT: $draft\nINSTRUCTION: Refine the draft above.";
    } else {
      combinedMessage += "\nINSTRUCTION: Generate a full reply from scratch.";
    }

    try {
      final response = await generateContent(systemPrompt, combinedMessage);
      return response?.trim();
    } catch (e) {
      debugPrint("AI Support Reply Error: $e");
      return null;
    }
  }

  // Duyuru Metni Güzelleştir (Admin Paneli)
  Future<String?> refineAnnouncement(String draftText) async {
    try {
      const systemPrompt = """
Sen profesyonel bir metin yazarısın. 
Aşağıdaki duyuru metnini daha ilgi çekici, heyecan verici ve akıcı bir hale getir. 
Emoji kullanımı serbesttir ancak abartma.

Görevin:
Sadece düzeltilmiş metni yaz. Ek açıklama veya tırnak işareti kullanma.
""";
      
      final content = await generateContent(systemPrompt, "Duyuru Taslağı: $draftText");
      return content?.trim();
    } catch (e) {
      debugPrint("Announcement Refinement Error: $e");
      return draftText;
    }
  }

  /// AI News Bot: Refine News Title and Body
  Future<Map<String, String>?> refineNews(String draftsTitle, String draftContent) async {
    try {
      const systemPrompt = """
Sen 'AllofCar' haber botu kimliğine sahip, profesyonel bir otomotiv gazetecisisin.
Görevin: Kullanıcının girdiği ham haber başlığını ve içeriğini alıp, "Clickbait olmayan ama dikkat çekici" bir başlık ve "Okuyucuyu içine çeken, akıcı ve bilgilendirici" bir haber metni oluşturmak.

Kurallar:
1. Başlık: Çarpıcı, merak uyandırıcı ama dürüst olsun. (Maks 10-12 kelime)
2. İçerik: Paragraflara bölünmüş, profesyonel, akıcı bir dil kullan. Emoji kullanımı: Sadece gerektiğinde ve az (haber ciddiyetini bozmadan).
3. Çıktı Formatı: SADECE JSON. Ek açıklama yok.
{
  "title": "Yeni Düzenlenmiş Başlık",
  "content": "Yeni Düzenlenmiş Haber İçeriği..."
}
      """;

      final userMessage = "BAŞLIK: $draftsTitle\nİÇERİK: $draftContent";
      
      final jsonResponse = await generateContent(systemPrompt, userMessage);
      
      if (jsonResponse != null) {
        // Clean markdown if present
        String cleanJson = jsonResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        final decoded = jsonDecode(cleanJson);
        return {
          "title": decoded['title'] ?? draftsTitle,
          "content": decoded['content'] ?? draftContent
        };
      }
    } catch (e) {
      debugPrint("News Refinement Error: $e");
    }
    return null;
  }

  /// AI Photo Prompter: Generate Image Prompt from News Text
  Future<String?> generateImagePrompt(String newsTitle, String newsContent) async {
    try {
      const systemPrompt = """
Role: Expert AI Image Prompt Engineer.
Task: Create a detailed, high-quality, photorealistic image description (prompt) in English based on the provided news title and summary.

Rules:
1. Output language: English ONLY.
2. Style: Photorealistic, 8k resolution, cinematic lighting, highly detailed.
3. Content: Focus on the main subject of the news (e.g., specific car model, technology, concept).
4. Length: Short paragraph (30-50 words).
5. Output format: Just the prompt text. No "Here is the prompt" or quotes.
      """;

      final userMessage = "HABER BAŞLIĞI: $newsTitle\nÖZET: $newsContent";
      
      final response = await generateContent(systemPrompt, userMessage);
      return response?.trim();
    } catch (e) {
      debugPrint("Image Prompt Generation Error: $e");
      return null;
    }
  }

  /// Get AI Image URL from Pollinations.ai (Free)
  String getAiImageUrl(String prompt) {
    // Clean prompt for URL
    final encodedPrompt = Uri.encodeComponent(prompt);
    final randomSeed = DateTime.now().millisecondsSinceEpoch;
    // Using 'flux' model for high quality or 'midjourney' style
    return "https://image.pollinations.ai/prompt/$encodedPrompt?width=1080&height=720&model=flux&nolog=true&seed=$randomSeed";
  }
}
