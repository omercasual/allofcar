import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/car_comparison.dart';
import 'comparison_scraper_service.dart';
import 'gemini_service.dart';
import 'firestore_service.dart';

class EnhancedComparisonService {
  final ComparisonScraperService _scraper = ComparisonScraperService();
  final GeminiService _gemini = GeminiService();
  final FirestoreService _firestore = FirestoreService(); // [NEW]

  Future<CarComparison> compare(String versionId1, String versionId2, String car1Name, String car2Name) async {
    // 1. Get Technical Specs (Base Data)
    debugPrint("🔍 EnhancedComparison: Fetching technical specs...");
    CarComparison technicalData;
    try {
       technicalData = await _scraper.getComparison(versionId1, versionId2);
    } catch (e) {
       debugPrint("⚠️ Scraper failed, using empty base: $e");
       rethrow;
    }

    // 2. Get AI Insights (Oto Gurme)
    debugPrint("🤖 EnhancedComparison: Asking Oto Gurme with Technical Data...");
    Map<String, dynamic> aiInsights = await _getAiInsights(car1Name, car2Name, technicalData);

    // 3. Merge Data
    // Check if AI gave valid scores, otherwise use calculate scores from Technical Data locally
    bool aiFailed = aiInsights['scoresA'] == null || (aiInsights['scoresA'] as List).isEmpty;
    
    List<double> scoresA = [];
    List<double> scoresB = [];
    double finalScoreA = 0;
    double finalScoreB = 0;
    String marketText = aiInsights['market']?.toString() ?? "";
    String reliabilityText = aiInsights['reliability']?.toString() ?? "";

    if (aiFailed || scoresA.isEmpty) {
       debugPrint("⚠️ AI Scores Missing - Calculating Fallback Scores Locally...");
       
       // [NEW] Log to Admin Panel
       _firestore.logEvent(
         "AI_FAILURE", 
         "Oto Gurme failed to provide scores for $car1Name vs $car2Name",
         metadata: {'error': 'Empty or Null Scores', 'techDataAvailable': technicalData.comparisonFeatures != null}
       );

       final fallbackData = _calculateFallbackScores(technicalData);
       scoresA = fallbackData['scoresA'];
       scoresB = fallbackData['scoresB'];
       finalScoreA = fallbackData['finalScoreA'];
       finalScoreB = fallbackData['finalScoreB'];
       
       if (marketText.length < 10) marketText = _generateFallbackMarketText(car1Name, car2Name);
       if (reliabilityText.length < 10) reliabilityText = "Genel olarak periyodik bakımları yapıldığında uzun ömürlü araçlardır. Motor ve şanzıman kondisyonu ekspertiz ile kontrol edilmelidir.";
    } else {
       scoresA = (aiInsights['scoresA'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
       scoresB = (aiInsights['scoresB'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
       finalScoreA = (aiInsights['scoreA_total'] as num?)?.toDouble() ?? technicalData.scoreA;
       finalScoreB = (aiInsights['scoreB_total'] as num?)?.toDouble() ?? technicalData.scoreB;
    }
    
    // AI determines winner name explicitly
    String winnerName = aiInsights['winner']?.toString() ?? technicalData.winner;
    if (winnerName == "Araç 2" || winnerName == "Araç 1" || winnerName.isEmpty) {
       winnerName = finalScoreA > finalScoreB ? car1Name : car2Name;
    }

    return CarComparison(
      winner: winnerName, 
      details: aiInsights['tech_summary']?.toString() ?? technicalData.details,
      scoreA: finalScoreA,
      scoreB: finalScoreB,
      radarScoresA: scoresA,
      radarScoresB: scoresB,
      year1: technicalData.year1,
      year2: technicalData.year2,
      priceA: technicalData.priceA,
      priceB: technicalData.priceB,
      photoA: technicalData.photoA,
      photoB: technicalData.photoB,
      comparisonFeatures: technicalData.comparisonFeatures, 
      
      // New Fields
      marketAnalysis: marketText,
      reliabilityInfo: reliabilityText,
      userReviews: aiInsights['reviews']?.toString() ?? "Kullanıcı yorumu özeti oluşturulamadı.",
    );
  }

  // --- Fallback Logic for when AI Fails ---
  Map<String, dynamic> _calculateFallbackScores(CarComparison data) {
    // Default values (Average)
    double scoreA_Perf = 7.0, scoreA_Conf = 7.5, scoreA_Fuel = 7.0, scoreA_Tech = 7.0, scoreA_Safe = 7.5;
    double scoreB_Perf = 7.0, scoreB_Conf = 7.5, scoreB_Fuel = 7.0, scoreB_Tech = 7.0, scoreB_Safe = 7.5;

    if (data.comparisonFeatures != null) {
      for (var f in data.comparisonFeatures!) {
        String title = f['title'].toString().toLowerCase();
        double valA = f['numA'] ?? 0;
        double valB = f['numB'] ?? 0;
        
        // 1. Performance (HP, 0-100, Torque)
        if (title.contains('güç') || title.contains('hp') || title.contains('ps')) {
           if (valA > valB) { scoreA_Perf += 1.0; scoreB_Perf -= 0.5; }
           else { scoreB_Perf += 1.0; scoreA_Perf -= 0.5; }
        } else if (title.contains('hızlanma') || title.contains('0-100')) {
           // Lower is better
           if (valA < valB) { scoreA_Perf += 1.0; scoreB_Perf -= 0.5; }
           else { scoreB_Perf += 1.0; scoreA_Perf -= 0.5; }
        } else if (title.contains('tork')) {
           if (valA > valB) { scoreA_Perf += 0.5; } 
           else { scoreB_Perf += 0.5; }
        }

        // 2. Fuel (Consumption)
        if (title.contains('tüketim') || title.contains('ortalama')) {
           // Lower is better
           if (valA < valB) { scoreA_Fuel += 1.5; scoreB_Fuel -= 1.0; }
           else { scoreB_Fuel += 1.5; scoreA_Fuel -= 1.0; }
        }

        // 3. Comfort/Tech (Width, Wheelbase, Trunk)
        if (title.contains('bagaj')) {
           if (valA > valB) { scoreA_Conf += 0.5; }
           else { scoreB_Conf += 0.5; }
        }
        if (title.contains('aks') || title.contains('genişlik')) {
           if (valA > valB) { scoreA_Conf += 0.5; }
           else { scoreB_Conf += 0.5; }
        }
      }
    }

    // Clamp scores 1-10
    List<double> normalize(List<double> s) => s.map((e) => e.clamp(1.0, 9.9)).toList();
    
    List<double> finalA = normalize([scoreA_Perf, scoreA_Conf, scoreA_Fuel, scoreA_Tech, scoreA_Safe]);
    List<double> finalB = normalize([scoreB_Perf, scoreB_Conf, scoreB_Fuel, scoreB_Tech, scoreB_Safe]);

    double avgA = finalA.reduce((a, b) => a + b) / 5;
    double avgB = finalB.reduce((a, b) => a + b) / 5;

    return {
       'scoresA': finalA,
       'scoresB': finalB,
       'finalScoreA': double.parse(avgA.toStringAsFixed(1)),
       'finalScoreB': double.parse(avgB.toStringAsFixed(1)),
    };
  }

  String _generateFallbackMarketText(String car1, String car2) {
     List<String> popularBrands = ["Volkswagen", "Renault", "Fiat", "Toyota", "Honda", "Ford", "Opel", "Hyundai", "Peugeot"];
     
     bool car1Pop = popularBrands.any((b) => car1.contains(b));
     bool car2Pop = popularBrands.any((b) => car2.contains(b));
     
     if (car1Pop && car2Pop) return "Her iki araç da Türkiye ikinci el piyasasında oldukça popülerdir ve hızlı alıcı bulur.";
     if (car1Pop) return "$car1 piyasada daha hızlı alıcı bulabilir, $car2 daha spesifik bir kitleye hitap eder.";
     if (car2Pop) return "$car2 piyasada daha hızlı alıcı bulabilir, $car1 daha spesifik bir kitleye hitap eder.";
     
     return "Marka bilinirliği ve kondisyonuna göre ikinci el performansı değişebilir.";
  }

  Future<Map<String, dynamic>> _getAiInsights(String car1, String car2, CarComparison techData) async {
    // Format technical data for the AI context
    StringBuffer techBuffer = StringBuffer();
    if (techData.comparisonFeatures != null) {
      for (var f in techData.comparisonFeatures!) {
        techBuffer.writeln("- ${f['title']}: ${f['valA']} vs ${f['valB']}");
      }
    }
    String techContext = techBuffer.toString();

    // 2. Prompt Hazırlığı (Firestore'dan al)
    String? dbPrompt = await _firestore.getComparisonAiConfig();
    
    final systemPrompt = dbPrompt ?? """
Sen "Oto Gurme" adında, Türkiye otomobil piyasasına hakim, esprili ama teknik bilgisi derin bir otomobil uzmanısın.
Motor1.com, Arabalar.com.tr ve arabavs.com gibi otoritelerin test kriterlerine (yol tutuş, yalıtım, malzeme kalitesi, fiyat/performans) göre araçları kıyasla.

GÖREV: İki aracı aşağıda verilen TEKNİK VERİLERE dayanarak karşılaştır ve puanla.

[TEKNİK VERİLER]
$techContext

PUANLAMA KURALLARI (1-10 Puan):
- Performans: 0-100 hızlanması düşük olan, Tork/Beygir gücü yüksek olan kazanır.
- Konfor: Aks mesafesi uzun olan, genişlik ve bagaj hacmi büyük olan kazanır.
- Yakıt: Karma tüketim değeri düşük olan kazanır.
- Donanım/Güvenlik: Eğer veri yoksa üretim yılına göre tahmin et (Yeni olan iyidir).

CEVAP FORMATI (SADECE JSON):
{
  "market": "İkinci el piyasa durumu (Hızlı satılır mı? Değer kaybı? Kimler alır?)",
  "reliability": "Kronik sorunlar (DSG, Enjektör vb.), motor ömrü, bakım maliyetleri.",
  "reviews": "Kullanıcı yorumları özeti (Şikayetvar ve forumlardaki genel kanı).",
  "scoresA": [8.5, 7.0, 9.0, 7.5, 8.0], // Performans, Konfor, Yakıt, Donanım, Güvenlik
  "scoresB": [7.5, 8.0, 8.5, 8.0, 7.5], // Aynı sıra
  "scoreA_total": 8.0,
  "scoreB_total": 7.9,
  "winner": "Kazanan Tam Model Adı",
  "tech_summary": "Kısa teknik ve sürüş odaklı özet."
}
""";

    final userMessage = "Karşılaştırılan Araçlar: $car1 vs $car2";

    try {
      final response = await _gemini.generateContent(systemPrompt, userMessage);
      
      if (response != null) {
        String cleanJson = response.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("❌ AI Insight Error: $e");
    }

    return {
      'market': "",
      // Return empty structures to avoid cast errors
      'scoresA': <double>[],
      'scoresB': <double>[],
    };
  }
}
