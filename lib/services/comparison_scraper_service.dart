import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter/foundation.dart';
import '../models/car_comparison.dart';

class ComparisonScraperService {
  static const String _baseUrl = 'https://www.arabalar.com.tr';
  static const String _dataJsonUrl = 'https://www.arabalar.com.tr/wp-content/json/data.json';

  // Cache the full data structure
  List<dynamic>? _cachedData;

  // Singleton pattern for caching
  static final ComparisonScraperService _instance = ComparisonScraperService._internal();
  factory ComparisonScraperService() => _instance;
  ComparisonScraperService._internal();

  /// initializes the service by fetching the big JSON file
  Future<void> initializeData() async {
    if (_cachedData != null) return;

    try {
      debugPrint('Fetching arabalar.com.tr data.json...');
      final response = await http.get(Uri.parse(_dataJsonUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json.containsKey('markalar')) {
          _cachedData = json['markalar'];
          debugPrint('Data loaded: ${_cachedData?.length} brands found.');
          return;
        }
      }
      throw Exception('Failed to load data.json: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error initializing ComparisonScraperService: $e');
      debugPrint('Loading Fallback Data...');
      _loadFallbackData();
    }
  }

  void _loadFallbackData() {
    // Basic fallback data structure consistent with the expected JSON format
    _cachedData = [
       {
         'name': 'Alfa Romeo', 'id': 'alfa-romeo', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/alfaromeo.png',
         'modeller': [
            {'name': 'Giulia', 'id': 'giulia', 'yillar': []},
            {'name': 'Tonale', 'id': 'tonale', 'yillar': []},
            {'name': 'Stelvio', 'id': 'stelvio', 'yillar': []}
         ]
       },
       {
         'name': 'Audi', 'id': 'audi', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/audi.png',
         'modeller': [
            {'name': 'A3', 'id': 'a3', 'yillar': []},
            {'name': 'A4', 'id': 'a4', 'yillar': []},
            {'name': 'A5', 'id': 'a5', 'yillar': []},
            {'name': 'A6', 'id': 'a6', 'yillar': []},
            {'name': 'Q2', 'id': 'q2', 'yillar': []},
            {'name': 'Q3', 'id': 'q3', 'yillar': []},
            {'name': 'Q5', 'id': 'q5', 'yillar': []},
            {'name': 'Q7', 'id': 'q7', 'yillar': []}
         ]
       },
       {
         'name': 'BMW', 'id': 'bmw', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/bmw.png',
         'modeller': [
            {'name': '1 Serisi', 'id': '1-serisi', 'yillar': []},
            {'name': '2 Serisi', 'id': '2-serisi', 'yillar': []},
            {'name': '3 Serisi', 'id': '3-serisi', 'yillar': []},
            {'name': '4 Serisi', 'id': '4-serisi', 'yillar': []},
            {'name': '5 Serisi', 'id': '5-serisi', 'yillar': []},
            {'name': 'X1', 'id': 'x1', 'yillar': []},
            {'name': 'X3', 'id': 'x3', 'yillar': []},
            {'name': 'X5', 'id': 'x5', 'yillar': []}
         ]
       },
       {'name': 'Citroen', 'id': 'citroen', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/citroen.png', 'modeller': [{'name': 'C3', 'id': 'c3', 'yillar': []}, {'name': 'C4', 'id': 'c4', 'yillar': []}, {'name': 'C5 Aircross', 'id': 'c5-aircross', 'yillar': []}]},
       {'name': 'Dacia', 'id': 'dacia', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/dacia.png', 'modeller': [{'name': 'Duster', 'id': 'duster', 'yillar': []}, {'name': 'Sandero', 'id': 'sandero', 'yillar': []}]},
       {
         'name': 'Fiat', 'id': 'fiat', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png',
         'modeller': [
            {'name': 'Egea', 'id': 'egea', 'yillar': []},
            {'name': '500', 'id': '500', 'yillar': []},
            {'name': 'Panda', 'id': 'panda', 'yillar': []},
            {'name': 'Doblo', 'id': 'doblo', 'yillar': []},
            {'name': 'Fiorino', 'id': 'fiorino', 'yillar': []}
         ]
       },
       {
         'name': 'Ford', 'id': 'ford', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/ford.png',
         'modeller': [
            {'name': 'Focus', 'id': 'focus', 'yillar': []},
            {'name': 'Fiesta', 'id': 'fiesta', 'yillar': []},
            {'name': 'Puma', 'id': 'puma', 'yillar': []},
            {'name': 'Kuga', 'id': 'kuga', 'yillar': []},
            {'name': 'Ranger', 'id': 'ranger', 'yillar': []}
         ]
       },
       {'name': 'Honda', 'id': 'honda', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/honda.png', 'modeller': [{'name': 'Civic', 'id': 'civic', 'yillar': []}, {'name': 'City', 'id': 'city', 'yillar': []}, {'name': 'HR-V', 'id': 'hr-v', 'yillar': []}, {'name': 'CR-V', 'id': 'cr-v', 'yillar': []}]},
       {'name': 'Hyundai', 'id': 'hyundai', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/hyundai.png', 'modeller': [{'name': 'i10', 'id': 'i10', 'yillar': []}, {'name': 'i20', 'id': 'i20', 'yillar': []}, {'name': 'i30', 'id': 'i30', 'yillar': []}, {'name': 'Bayon', 'id': 'bayon', 'yillar': []}, {'name': 'Tucson', 'id': 'tucson', 'yillar': []}]},
       {'name': 'Kia', 'id': 'kia', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/kia.png', 'modeller': [{'name': 'Picanto', 'id': 'picanto', 'yillar': []}, {'name': 'Rio', 'id': 'rio', 'yillar': []}, {'name': 'Stonic', 'id': 'stonic', 'yillar': []}, {'name': 'Sportage', 'id': 'sportage', 'yillar': []}]},
       {
         'name': 'Mercedes', 'id': 'mercedes', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/mercedes.png',
         'modeller': [
            {'name': 'A Serisi', 'id': 'a-serisi', 'yillar': []},
            {'name': 'C Serisi', 'id': 'c-serisi', 'yillar': []},
            {'name': 'E Serisi', 'id': 'e-serisi', 'yillar': []},
            {'name': 'CLA', 'id': 'cla', 'yillar': []},
            {'name': 'GLA', 'id': 'gla', 'yillar': []},
            {'name': 'GLC', 'id': 'glc', 'yillar': []}
         ]
       },
       {'name': 'Nissan', 'id': 'nissan', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/nissan.png', 'modeller': [{'name': 'Micra', 'id': 'micra', 'yillar': []}, {'name': 'Juke', 'id': 'juke', 'yillar': []}, {'name': 'Qashqai', 'id': 'qashqai', 'yillar': []}]},
       {'name': 'Opel', 'id': 'opel', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/opel.png', 'modeller': [{'name': 'Corsa', 'id': 'corsa', 'yillar': []}, {'name': 'Astra', 'id': 'astra', 'yillar': []}, {'name': 'Mokka', 'id': 'mokka', 'yillar': []}, {'name': 'Crossland', 'id': 'crossland', 'yillar': []}, {'name': 'Grandland', 'id': 'grandland', 'yillar': []}]},
       {'name': 'Peugeot', 'id': 'peugeot', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/peugeot.png', 'modeller': [{'name': '208', 'id': '208', 'yillar': []}, {'name': '308', 'id': '308', 'yillar': []}, {'name': '2008', 'id': '2008', 'yillar': []}, {'name': '3008', 'id': '3008', 'yillar': []}, {'name': '408', 'id': '408', 'yillar': []}, {'name': '5008', 'id': '5008', 'yillar': []}]},
       {
         'name': 'Renault', 'id': 'renault', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/renault.png',
         'modeller': [
            {'name': 'Clio', 'id': 'clio', 'yillar': []},
            {'name': 'Taliant', 'id': 'taliant', 'yillar': []},
            {'name': 'Megane', 'id': 'megane', 'yillar': []},
            {'name': 'Captur', 'id': 'captur', 'yillar': []},
            {'name': 'Austral', 'id': 'austral', 'yillar': []},
            {'name': 'Koleos', 'id': 'koleos', 'yillar': []}
         ]
       },
       {'name': 'Seat', 'id': 'seat', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/seat.png', 'modeller': [{'name': 'Ibiza', 'id': 'ibiza', 'yillar': []}, {'name': 'Leon', 'id': 'leon', 'yillar': []}, {'name': 'Arona', 'id': 'arona', 'yillar': []}, {'name': 'Ateca', 'id': 'ateca', 'yillar': []}]},
       {'name': 'Skoda', 'id': 'skoda', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/skoda.png', 'modeller': [{'name': 'Fabia', 'id': 'fabia', 'yillar': []}, {'name': 'Scala', 'id': 'scala', 'yillar': []}, {'name': 'Octavia', 'id': 'octavia', 'yillar': []}, {'name': 'Kamiq', 'id': 'kamiq', 'yillar': []}, {'name': 'Karoq', 'id': 'karoq', 'yillar': []}, {'name': 'Kodiaq', 'id': 'kodiaq', 'yillar': []}, {'name': 'Superb', 'id': 'superb', 'yillar': []}]},
       {
         'name': 'Toyota', 'id': 'toyota', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/toyota.png',
         'modeller': [
            {'name': 'Corolla', 'id': 'corolla', 'yillar': []},
            {'name': 'Yaris', 'id': 'yaris', 'yillar': []},
            {'name': 'C-HR', 'id': 'c-hr', 'yillar': []},
            {'name': 'RAV4', 'id': 'rav4', 'yillar': []},
            {'name': 'Proace', 'id': 'proace', 'yillar': []},
            {'name': 'Hilux', 'id': 'hilux', 'yillar': []}
         ]
       },
       {
         'name': 'Volkswagen', 'id': 'volkswagen', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volkswagen.png',
         'modeller': [
            {'name': 'Polo', 'id': 'polo', 'yillar': []},
            {'name': 'Golf', 'id': 'golf', 'yillar': []},
            {'name': 'T-Roc', 'id': 't-roc', 'yillar': []},
            {'name': 'Taigo', 'id': 'taigo', 'yillar': []},
            {'name': 'Tiguan', 'id': 'tiguan', 'yillar': []},
            {'name': 'Passat', 'id': 'passat', 'yillar': []},
            {'name': 'Caddy', 'id': 'caddy', 'yillar': []},
            {'name': 'Transporter', 'id': 'transporter', 'yillar': []}
         ]
       },
       {'name': 'Volvo', 'id': 'volvo', 'logo': 'https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volvo.png', 'modeller': [{'name': 'XC40', 'id': 'xc40', 'yillar': []}, {'name': 'XC60', 'id': 'xc60', 'yillar': []}, {'name': 'XC90', 'id': 'xc90', 'yillar': []}, {'name': 'S60', 'id': 's60', 'yillar': []}, {'name': 'S90', 'id': 's90', 'yillar': []}]},
    ];
  }

  // --- Getters for Selection Flow ---

  Future<List<Map<String, String>>> getBrands() async {
    if (_cachedData == null) await initializeData();
    if (_cachedData == null) return [];

    return _cachedData!.map<Map<String, String>>((brand) {
      return {
        'name': brand['name'].toString(),
        'id': brand['id'].toString(),
        'logo': brand['logo']?.toString() ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, String>>> getModels(String brandName) async {
    if (_cachedData == null) await initializeData();
    
    final brand = _cachedData?.firstWhere(
      (b) => b['name'].toString() == brandName, 
      orElse: () => null
    );

    if (brand != null && brand['modeller'] != null) {
      return (brand['modeller'] as List).map<Map<String, String>>((model) {
        return {
          'name': model['name'].toString(),
          'id': model['id'].toString(),
        };
      }).toList();
    }
    return [];
  }

  Future<List<String>> getYears(String brandName, String modelName) async {
    if (_cachedData == null) await initializeData();

    final brand = _cachedData?.firstWhere(
      (b) => b['name'].toString() == brandName,
      orElse: () => null
    );
    if (brand == null) return [];

    final model = (brand['modeller'] as List).firstWhere(
        (m) => m['name'].toString() == modelName,
        orElse: () => null
    );

    if (model != null && model['yillar'] != null) {
      var list = (model['yillar'] as List).map<String>((y) => y['name'].toString()).toList();
      if (list.isNotEmpty) return list;
    }
    // Fallback if empty (Offline)
    return ["2024", "2023", "2022"];
  }

  Future<List<Map<String, String>>> getVersions(String brandName, String modelName, String year) async {
    if (_cachedData == null) await initializeData();

    final brand = _cachedData?.firstWhere(
            (b) => b['name'].toString() == brandName,
        orElse: () => null
    );
    // if (brand == null) return []; // Fallback down below

    final model = (brand != null && brand['modeller'] != null) ? (brand['modeller'] as List).firstWhere(
            (m) => m['name'].toString() == modelName,
        orElse: () => null
    ) : null;
    
    // if (model == null) return [];

    final yearData = (model != null && model['yillar'] != null) ? (model['yillar'] as List).firstWhere(
            (y) => y['name'].toString() == year,
        orElse: () => null
    ) : null;

    if (yearData != null && yearData['araclar'] != null) {
      var list = (yearData['araclar'] as List).map<Map<String, String>>((v) {
        return {
          'name': v['name'].toString(),
          'id': v['id'].toString(), // crucial for comparison
        };
      }).toList();
      if (list.isNotEmpty) return list;
    }
    
    // Fallback Mock Versions (Offline)
    return [
       {'name': '1.0 TSI Style', 'id': 'mock-1'},
       {'name': '1.5 eTSI R-Line', 'id': 'mock-2'},
       {'name': '1.6 TDI Elegance', 'id': 'mock-3'},
    ];
  }

  // --- Comparison Logic ---

  Future<CarComparison> getComparison(String id1, String id2) async {
    final url = '$_baseUrl/karsilastirma-sonucu/?ids=$id1,$id2';
    debugPrint('Scraping Comparison: $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch comparison page');
      }

      final document = parser.parse(response.body);
      
      String car1Name = "Araç 1";
      String car2Name = "Araç 2";
      String? photoA;
      String? photoB;
      String price1 = "N/A";
      String price2 = "N/A";
      
      // Attempt to find images in the table header or top section
      // Usually arabalar.com comparison has images in the first row <th> or <td>
      var images = document.querySelectorAll('img');
      List<String> foundImages = [];
      for (var img in images) {
         String? src = img.attributes['src'];
         // Filter relevant car images (heuristic: often contains 'modeller' or similar, not icons)
         if (src != null && src.contains('arabalar.com.tr') && !src.contains('logo') && !src.contains('icon')) {
            foundImages.add(src);
         }
      }
      if (foundImages.length >= 2) {
         photoA = foundImages[0];
         photoB = foundImages[1];
      }

      var rows = document.querySelectorAll('tr');
      Map<String, String> features1 = {};
      Map<String, String> features2 = {};
      
      bool namesFound = false;

      for(var row in rows) {
        var cols = row.querySelectorAll('td');
        if (cols.length >= 2) {
             if (cols.length == 3) {
               String val1 = cols[0].text.trim();
               String label = cols[1].text.trim();
               String val2 = cols[2].text.trim();
               
               // Try to extract images from specific rows if generic search failed
               if (photoA == null) {
                  var img1 = cols[0].querySelector('img');
                  var img2 = cols[2].querySelector('img');
                  if (img1 != null) photoA = img1.attributes['src'];
                  if (img2 != null) photoB = img2.attributes['src'];
               }

               if (label == "Fiyat") {
                 price1 = val1;
                 price2 = val2;
               } else if (!namesFound && (label == "Marka" || label == "Model" || label == "Versiyon")) {
                   // This logic is tricky without seeing HTML. 
                   // If we are in the loop, usually the first row with 3 cols is headers or names if there's no th.
               } else {
                 features1[label] = val1;
                 features2[label] = val2;
               }
             }
             
             // Check TH for names
             var ths = row.querySelectorAll('th');
             if (ths.length >= 2 && !namesFound) {
                // Heuristic: If row has specific car names
                // Often standard comparison tables have names in th
             }
        }
      }
      
      // Fix Names if defaults
      // We can infer names from the features if available, e.g. Marka + Model
      if (car1Name == "Araç 1" && features1.containsKey("Marka") && features1.containsKey("Model")) {
         car1Name = "${features1['Marka']} ${features1['Model']}";
         car2Name = "${features2['Marka']} ${features2['Model']}";
      }
      
      StringBuffer comparisonText = StringBuffer();
      // comparisonText.writeln("### Karşılaştırma Özeti"); // Removing text header as we will use visual bars now
      // comparisonText.writeln("- **$car1Name** vs **$car2Name**");
      
      List<Map<String, dynamic>> featuresList = [];

      features1.forEach((key, val1) {
        String val2 = features2[key] ?? "-";
        
        if (val1 != val2 && val1.isNotEmpty && val2.isNotEmpty) {
           // comparisonText.writeln("- **$key**: $val1 (vs $val2)"); // Keep text for details backup? No, user wants bars.
           
           // Attempt to parse numbers for bar chart
           // Remove non-numeric chars except dots/commas
           String clean1 = val1.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
           String clean2 = val2.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
           
           double? num1 = double.tryParse(clean1);
           double? num2 = double.tryParse(clean2);
           
           if (num1 != null && num2 != null) {
              // Determine logic (Higher is better? Lower is better?)
              bool higherIsBetter = true;
              if (key.contains("Hızlanma") || key.contains("Tüketim") || key.contains("Ağırlık")) {
                 higherIsBetter = false;
              }
              
              String winner = "Equal";
              if (num1 != num2) {
                 if (higherIsBetter) {
                    winner = num1 > num2 ? "A" : "B";
                 } else {
                    winner = num1 < num2 ? "A" : "B";
                 }
              }
              
              featuresList.add({
                 'title': key,
                 'valA': val1,
                 'valB': val2,
                 'numA': num1,
                 'numB': num2,
                 'winner': winner,
                 'higherIsBetter': higherIsBetter
              });
           } else {
              // Non-numeric difference, just append to legacy text details if needed OR handled by UI text list
              comparisonText.writeln("- **$key**: $val1 (vs $val2)");
           }
        }
      });

      return CarComparison(
        winner: featuresList.where((f) => f['winner'] == 'A').length > featuresList.where((f) => f['winner'] == 'B').length ? car1Name : car2Name, // Simple winner determination based on feature count
        details: comparisonText.toString(),
        scoreA: 0,
        scoreB: 0,
        radarScoresA: [5,5,5,5,5], 
        radarScoresB: [5,5,5,5,5], 
        year1: null,
        year2: null,
        priceA: price1,
        priceB: price2,
        photoA: photoA,
        photoB: photoB,
        comparisonFeatures: featuresList, // [NEW]
      );

    } catch (e) {
      debugPrint("Comparison scraping failed: $e");
      
      // Fallback: Return Mock Comparison Data
      return CarComparison(
        winner: "Offline Mod: Veri Yok",
        details: "İnternet bağlantısı olmadığı için karşılaştırma verileri canlı çekilemedi. Bu örnek bir gösterimdir.",
        scoreA: 85,
        scoreB: 82,
        radarScoresA: [8, 9, 7, 8, 9],
        radarScoresB: [7, 8, 9, 7, 8],
        year1: 2023,
        year2: 2023,
        priceA: "1.200.000 TL",
        priceB: "1.150.000 TL",
        photoA: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/alfa-romeo.png", // Generic placeholders
        photoB: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/audi.png",
        comparisonFeatures: [
           {'title': 'Motor', 'valA': '1.0 TSI', 'valB': '1.5 TSI', 'winner': 'B', 'higherIsBetter': true},
           {'title': 'Beygir', 'valA': '110 HP', 'valB': '150 HP', 'winner': 'B', 'higherIsBetter': true},
           {'title': 'Yakıt', 'valA': '5.5 Lt', 'valB': '6.0 Lt', 'winner': 'A', 'higherIsBetter': false},
           {'title': '0-100', 'valA': '10.5 sn', 'valB': '8.5 sn', 'winner': 'B', 'higherIsBetter': false},
        ],
      );
    }
  }
}
