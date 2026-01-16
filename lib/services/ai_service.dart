import 'dart:async';
import 'dart:math';
import '../models/car_comparison.dart';

class AiService {
  // Mock AI Engine for prototype
  Future<CarComparison> compareCars(String car1, String car2, {int? year1, int? year2, String? price1, String? price2}) async {
    // Yapay zeka düşünüyor efekti için 1.5 saniye bekle
    await Future.delayed(const Duration(milliseconds: 1500));

    // Randomize scores slightly for dynamic feel
    final random = Random();
    
    // Yıl etkisi: Yeni araç (yıl büyükse) biraz avantajlı olsun
    double yearBonusA = 0;
    double yearBonusB = 0;
    if (year1 != null && year2 != null) {
      if (year1 > year2) yearBonusA = 0.5;
      if (year2 > year1) yearBonusB = 0.5;
    }

    double scoreA = 7.5 + random.nextDouble() * 2.0 + yearBonusA; 
    double scoreB = 7.0 + random.nextDouble() * 2.0 + yearBonusB;
    
    // Normalize to max 10
    if (scoreA > 10) scoreA = 9.9;
    if (scoreB > 10) scoreB = 9.9;

    List<double> radarA = List.generate(5, (_) => 5.0 + random.nextDouble() * 4.0 + (yearBonusA));
    List<double> radarB = List.generate(5, (_) => 5.0 + random.nextDouble() * 4.0 + (yearBonusB));

    String winner = scoreA > scoreB ? car1 : car2;
    
    // Dinamik Yorum Oluşturma
    String yearComment = "";
    if (year1 != null && year2 != null) {
       if ((year1 - year2).abs() > 3) {
         String newer = year1 > year2 ? car1 : car2;
         yearComment = "\n\nAraçlar arasında belirgin bir yaş farkı var. $newer, daha güncel teknolojilere ve güvenlik standartlarına sahip olmasıyla öne çıkıyor.";
       } else {
         yearComment = "\n\nHer iki araç da benzer model yıllarına sahip olduğu için teknolojik altyapıları birbirine yakın.";
       }
    }

    // Fiyat Yorumu (Eğer varsa)
    String priceComment = "";
    if (price1 != null && price2 != null) {
       priceComment = "\n\nFiyat Analizi:\nAraç 1: $price1\nAraç 2: $price2\nBu fiyat/performans dengesinde seçim bütçenize göre şekillenebilir.";
    }

    return CarComparison(
      winner: winner, 
      scoreA: double.parse(scoreA.toStringAsFixed(1)),
      scoreB: double.parse(scoreB.toStringAsFixed(1)),
      radarScoresA: radarA,
      radarScoresB: radarB,
      year1: year1,
      year2: year2,
      priceA: price1,
      priceB: price2,
      details:
          "AI Analiz Raporu:\n\n"
          "$car1, sürüş dinamikleri ve yol tutuş konusunda oldukça iddialı bir performans sergiliyor. "
          "Özellikle şehir içi kullanımda sunduğu pratiklik ve yakıt verimliliği dikkat çekici. Teknoloji tarafında ise modern multimedya sistemi ile öne çıkıyor.\n\n"
          "$car2 ise daha çok konfor ve uzun yol deneyimine odaklanmış durumda. Geniş iç hacmi ve sessiz kabini ile rakiplerinden ayrılıyor. "
          "Eğer performans önceliğiniz ise $car1, ancak aile konforu arıyorsanız $car2 daha mantıklı bir tercih olabilir.$yearComment$priceComment",
    );
  }
}
