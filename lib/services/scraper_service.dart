import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/news_model.dart';
import 'firestore_service.dart';

class NewsScraperService {
  final String _baseUrl = "https://www.donanimhaber.com/otomobil-teknolojileri";
  final FirestoreService _firestore = FirestoreService();
  final String _apiKey = 'AIzaSyDn62jZoSL4tTXsIGTOPMzJigN4kdpM4UY';

  Future<List<NewsArticle>> scrapeNews() async {
    final sources = [
      _baseUrl,
      "https://tr.motor1.com/news/",
      "https://shiftdelete.net/otomobil"
    ];

    for (var src in sources) {
      List<NewsArticle> results = await _scrapeFromUrl(src);
      if (results.isNotEmpty) return results;
    }
    
    // Offline Mock News
    debugPrint("NewsScraperService: All sources failed. Returning Mock News.");
    return [
       NewsArticle(
         id: "mock-news-1",
         title: "Yerli Otomobil Togg'dan Yeni Rekor",
         content: "Togg T10X teslimatları hız kesmeden devam ediyor. Geçtiğimiz ay rekor sayıda teslimat gerçekleştirildi.",
         imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/togg.png", // Use logo if simple
         category: "Teknoloji",
         timestamp: DateTime.now().subtract(const Duration(hours: 2)),
       ),
       NewsArticle(
         id: "mock-news-2",
         title: "Yeni Volkswagen Passat Tanıtıldı",
         content: "Volkswagen'in efsane modeli Passat'ın yeni versiyonu station wagon gövde tipiyle sahneye çıktı.",
         imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volkswagen.png",
         category: "Otomobil",
         timestamp: DateTime.now().subtract(const Duration(days: 1)),
       ),
       NewsArticle(
         id: "mock-news-3",
         title: "Elektrikli Araç Satışları Artıyor",
         content: "Türkiye pazarında elektrikli araç satışları geçen yıla göre %150 artış gösterdi.",
         imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/tesla.png",
         category: "Pazar",
         timestamp: DateTime.now().subtract(const Duration(days: 2)),
       ),
    ];
  }

  Future<List<NewsArticle>> _scrapeFromUrl(String url) async {
    try {
      debugPrint("--- Scraping from: $url ---");
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(const Duration(seconds: 20));
      
      debugPrint("Response Status: ${response.statusCode} - Body Length: ${response.body.length}");

      if (response.statusCode != 200) return [];

      final document = parser.parse(response.body);
      final List<NewsArticle> scrapedList = [];

      // Primary selectors for various sites
      var items = document.querySelectorAll('.mListCard, .kl-item, .m1-card, .listItem, .post-item, .post-card, .type-post');
      
      if (items.isEmpty) {
        // Fallback: Just look for news-like links
        final allLinks = document.querySelectorAll('a');
        for (var link in allLinks) {
          final href = link.attributes['href'] ?? "";
          final title = link.text.trim();
          
          if (title.length > 35 && (href.contains('--') || href.contains('/news/') || href.contains('/otomobil/'))) {
            String fullLink = href;
            if (!href.startsWith('http')) {
              final uri = Uri.parse(url);
              fullLink = "${uri.scheme}://${uri.host}$href";
            }
            if (!scrapedList.any((a) => a.id == fullLink)) {
              scrapedList.add(NewsArticle(
                id: fullLink,
                title: title,
                content: "",
                timestamp: DateTime.now(),
                category: "Otomobil",
              ));
            }
          }
        }
      } else {
        for (var element in items) {
          try {
            final titleElement = element.querySelector('a');
            if (titleElement == null) continue;

            final String title = titleElement.text.trim();
            if (title.length < 20) continue;

            String link = titleElement.attributes['href'] ?? "";
            if (!link.startsWith('http')) {
              final uri = Uri.parse(url);
              link = "${uri.scheme}://${uri.host}$link";
            }

            final imgElement = element.querySelector('img');
            String? imageUrl = imgElement?.attributes['data-src'] ?? imgElement?.attributes['src'];

            if (!scrapedList.any((a) => a.id == link)) {
              scrapedList.add(NewsArticle(
                id: link,
                title: title,
                content: "",
                imageUrl: imageUrl,
                category: "Otomobil",
                timestamp: DateTime.now(),
              ));
            }
          } catch (e) {
            debugPrint("Item parse error: $e");
          }
        }
      }

      // SECOND PASS: If image is missing, fetch from detail page (limit to first 10 for performance)
      for (int i = 0; i < scrapedList.length && i < 10; i++) {
        if (scrapedList[i].imageUrl == null || scrapedList[i].imageUrl!.isEmpty) {
           debugPrint("Image missing for: ${scrapedList[i].title}. Fetching from detail page...");
           scrapedList[i] = await _enrichWithDetailData(scrapedList[i]);
        }
      }

      debugPrint("Found ${scrapedList.length} news items from $url");
      return scrapedList;
    } catch (e) {
      debugPrint("Scrape Error for $url: $e");
      return [];
    }
  }

  Future<NewsArticle> _enrichWithDetailData(NewsArticle article) async {
    try {
      final response = await http.get(Uri.parse(article.id)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // 1. Look for og:image (Best quality)
        final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
        
        // 2. Look for twitter:image
        final twitterImage = document.querySelector('meta[name="twitter:image"]')?.attributes['content'];
        
        // 3. Look for larger images in the body
        final articleImage = document.querySelector('article img')?.attributes['src'];

        String? finalImageUrl = ogImage ?? twitterImage ?? articleImage ?? article.imageUrl;

        // Fallback: If still no image, use a high-quality car stock photo pool
        if (finalImageUrl == null || finalImageUrl.isEmpty) {
          final fallbacks = [
            "https://images.unsplash.com/photo-1494976388531-d1058494cdd8?auto=format&fit=crop&q=80&w=1000",
            "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=1000",
            "https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&q=80&w=1000",
            "https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=1000",
          ];
          finalImageUrl = fallbacks[DateTime.now().millisecond % fallbacks.length];
        }

        return NewsArticle(
          id: article.id,
          title: article.title,
          content: article.content,
          imageUrl: finalImageUrl,
          category: article.category,
          timestamp: article.timestamp,
        );
      }
    } catch (e) {
      debugPrint("Detail enrichment failed: $e");
    }
    return article;
  }

  Future<NewsArticle?> rewriteWithAi(NewsArticle article, String prompt) async {
    try {
      final body = jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": "$prompt\n\nHaber Başlığı: ${article.title}\nÖzet: ${article.content}\n\nLütfen bunu AllofCar için yeniden yaz. Yanıtın başında 'BAŞLIK: ' ve devamında 'İÇERİK: ' etiketlerini kullan."}
            ]
          }
        ]
      });

      // Try multiple models as in ai_assistant_screen
      final List<String> models = [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-2.0-flash', 
        'gemini-2.0-flash-exp', 
        'gemini-1.5-flash', 
        'gemini-1.5-pro',
      ];

      for (var modelName in models) {
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=_apiKey'.replaceFirst('_apiKey', _apiKey));
          final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final aiText = data['candidates'][0]['content']['parts'][0]['text'] as String;

            String newTitle = article.title;
            String newContent = article.content;

            if (aiText.contains("BAŞLIK:") && aiText.contains("İÇERİK:")) {
              final titleMatch = RegExp(r"BAŞLIK:\s*(.*)").firstMatch(aiText);
              final contentMatch = RegExp(r"İÇERİK:\s*([\s\S]*)").firstMatch(aiText);
              
              if (titleMatch != null) newTitle = titleMatch.group(1)!.split("\n")[0].trim();
              if (contentMatch != null) newContent = contentMatch.group(1)!.trim();
            }

            return NewsArticle(
              id: article.id,
              title: newTitle,
              content: newContent,
              imageUrl: article.imageUrl,
              category: article.category,
              timestamp: article.timestamp,
            );
          }
        } catch (e) {
          debugPrint("AI Model $modelName failed: $e");
        }
      }
      return article; // Fallback to original
    } catch (e) {
      debugPrint("AI Rewriting Error: $e");
      return article;
    }
  }
}
