import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print("Starting Standalone Logic Test...");
  String brandSlug = "mercedes-benz";
  String url = "https://www.arabam.com/sifir-km/$brandSlug";
  
  // Headers
  final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        Map<String, dynamic> modelsMap = {}; 

        // 1. SCARPE HTML
        var anchors = document.querySelectorAll('a[href^="/sifir-km/$brandSlug-"]');
        for (var a in anchors) {
          String href = a.attributes['href']!.split('?')[0];
          if (href.endsWith("fiyat-listesi-yakit-tuketimi") || href.endsWith("fiyat-listesi")) {
             String slug = href.replaceAll("/sifir-km/", "").replaceAll("-fiyat-listesi-yakit-tuketimi", "").replaceAll("-fiyat-listesi", "");
             String fullText = a.text.trim().replaceAll(RegExp(r'\s+'), ' ');
             String name = slug.replaceAll("-", " ").toUpperCase();
             if (fullText.contains("Versiyon")) {
                name = fullText.split("Versiyon")[0].trim();
             } else {
                if (fullText.length < 50) name = fullText;
             }
             if (!modelsMap.containsKey(slug)) {
               modelsMap[slug] = {"name": name, "source": "HTML"};
             }
          }
        }

        // 2. PARSE JSON FILTERS - SCOPED
        int modelIndex = response.body.indexOf('"name":"Model"');
        if (modelIndex != -1) {
            int itemsStart = response.body.indexOf('"items":[', modelIndex);
            if (itemsStart != -1) {
                int itemsEnd = response.body.indexOf(']', itemsStart);
                if (itemsEnd != -1) {
                    String itemsJson = response.body.substring(itemsStart, itemsEnd + 1);
                    RegExp jsonRegex = RegExp(r'\{"name":"([^"]+)","value":"[^"]+","displayValue":"[^"]+","selected":(?:true|false),"friendlyUrl":"([^"]+)"\}');
                    var matches = jsonRegex.allMatches(itemsJson);
                    for (var m in matches) {
                       if (m.groupCount >= 2) {
                          String name = m.group(1) ?? "";
                          String friendlyUrl = m.group(2) ?? "";
                          if (name.isNotEmpty && friendlyUrl.isNotEmpty) {
                             String slug = "$brandSlug-$friendlyUrl";
                             if (!modelsMap.containsKey(slug)) {
                                modelsMap[slug] = {"name": name, "source": "JSON"};
                             }
                          }
                       }
                    }
                }
            }
        }
        
        // Print Results
        print("Found ${modelsMap.length} total models.");
        
        bool foundGLA = modelsMap.values.any((m) => m['name'].toString().contains("GLA"));
        bool foundHTML = modelsMap.values.any((m) => m['source'] == "HTML");
        bool foundJSON = modelsMap.values.any((m) => m['source'] == "JSON");
        
        print("HTML Source Used: $foundHTML");
        print("JSON Source Used: $foundJSON");
        print("Found GLA: $foundGLA");
        
        modelsMap.forEach((k,v) {
             print("[$k] -> ${v['name']} (${v['source']})");
        });
        
      }
  } catch (e) {
      print("Error: $e");
  }
}
