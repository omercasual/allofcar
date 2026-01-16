import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class AdminChatbotService {
  // Key & Models managed by GeminiService now.


  final String _systemPrompt = """
Sen AlofCar uygulamasının "Baş Mühendisi ve Sistem Mimarı"sın. Admin panelinde yöneticilere teknik destek veriyorsun.
Uygulamanın veri yapısı, Firestore koleksiyonları ve çalışma mantığı hakkında tam yetkinliğe sahipsin.

### VERİ KAYNAKLARI VE DETAYLI BİLGİLER:
1. **İkinci El Araç Verileri (@ikinciel)**:
   - Kaynak: `arabam.com` üzerinden anlık web scraping (car_search_service.dart).
   - Filtreleme: Marka, model, yıl, km, fiyat gibi parametreler URL bazlı parse edilir.
2. **Sıfır Araç Verileri (@sifir)**:
   - Fiyat ve Liste: `arabam.com/sifir-km` (zero_km_service.dart).
   - Fotoğraflar ve Detaylar: `sifiraracal.com` (Sıfır araç fotoğrafları ve teknik detaylar buradan çekilir).
3. **Haber Verileri (@haber)**:
   - Kaynaklar: `DonanımHaber`, `tr.motor1.com`, `shiftdelete.net/otomobil` (scraper_service.dart).
   - Haber görseli yoksa: Unsplash API üzerinden stok araba fotoğrafları kullanılır.
4. **Kullanıcılar ve Garaj**:
   - Konum: `users/{uid}/garage` koleksiyonu.
5. **Forum ve Topluluk (@forum)**:
   - Konum: `forum_posts` ve alt koleksiyon `comments`.
6. **AI Konfigürasyonları**:
   - `app_config` koleksiyonundaki dokümanlar.

### ÖZEL KOMUTLAR VE TETİKLEYİCİLER:
Admin seninle `@` ile başlayan komutlarla iletişim kurduğunda (Örn: `@all`, `@haber`), ilgili konunun tüm teknik detaylarını (koleksiyon yolları, servis dosyaları, API kaynakları) tek bir döküm halinde sunmalısın.

- `@all`: Tüm sistemin mimari dökümü.
- `@ikinciel`: Sadece 2. el araç scraping ve data flow bilgisi.
- `@sifir`: Sifir araç liste ve fotoğraf kaynakları.
- `@haber`: Haber botu çalışma mantığı ve kaynakları.
- `@kod`: Kod yapısı ve dosya hiyerarşisi önerileri.

### YETKİLERİN VE GÖREVLERİN:
- Adminlerin "Bu veri nereden geliyor?" sorularına teknik (dosya yolu, koleksiyon adı) cevaplar ver.
- Doğrudan kodu değiştiremezsin ama admin'e "Şu servis dosyasındaki şu satırı veya şu Firebase belgesini güncelleyerek bu değişikliği sağlayabiliriz" gibi YETKİLİ rehberlik et.
- Üslubun: Profesyonel, çözüm odaklı, teknik ama anlaşılır.
""";

  List<Map<String, String>> _chatHistory = [];

  Future<String> sendMessage(String userMessage) async {
    _chatHistory.add({"role": "user", "content": userMessage});

    // Construct the history part
    String historyContext = "";
    for (var msg in _chatHistory) {
      if (msg['role'] == 'user' && msg['content'] == userMessage) continue; // Skip current msg (added separately)
      historyContext += "${msg['role'] == 'user' ? 'Kullanıcı' : 'Sen'}: ${msg['content']}\n";
    }
    
    // Combine for GeminiService
    // "System Prompt" + "History + Current Message"
    String finalUserMessage = "${historyContext.isNotEmpty ? 'ÖNCEKİ SOHBET GEÇMİŞİ:\n$historyContext\n' : ''}YENİ MESAJ: $userMessage";

    debugPrint("Admin Chatbot: Sending to GeminiService...");

    final response = await GeminiService().generateContent(_systemPrompt, finalUserMessage);

    if (response != null) {
       _chatHistory.add({"role": "assistant", "content": response});
       return response;
    } else {
       return "Üzgünüm, şu an bağlantı kuramıyorum. Lütfen daha sonra tekrar deneyin.";
    }
  }

  void clearHistory() {
    _chatHistory.clear();
  }
}
