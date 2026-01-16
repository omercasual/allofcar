import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print("Starting debug scrape...");
  const String url = "https://www.arabam.com/sifir-km/";
  final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  };

  try {
      final response = await http.get(Uri.parse(url), headers: headers);
      print("Status Code: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var items = document.querySelectorAll('.section-content a.item');
        print("Found items: ${items.length}");
        
        int validBrands = 0;
        for (var item in items) {
           String? onclick = item.attributes['onclick'];
           if (onclick != null && onclick.contains("g4Click")) {
              var matches = RegExp(r"'([^']*)'").allMatches(onclick).toList();
              if (matches.length >= 2) {
                 String name = matches[0].group(1) ?? "";
                 String urlPart = matches[1].group(1) ?? "";
                 String slug = urlPart.replaceAll("/sifir-km/", "");
                 if (slug.endsWith("-fiyat-listesi")) slug = slug.replaceAll("-fiyat-listesi", "");
                 
                 print("Brand Found: $name -> Slug: $slug");
                 validBrands++;
              }
           }
        }
        print("Total valid brands extracted: $validBrands");
      }

      // TEST MODEL URL
      print("\n--- Testing Model URL ---");
      var modelUrl = "https://www.arabam.com/sifir-km/fiat"; // Try simple slug first
      var resp2 = await http.get(Uri.parse(modelUrl), headers: headers);
      print("GET /sifir-km/fiat -> Status: ${resp2.statusCode}");
      if (resp2.statusCode == 404) {
         print("Simple slug failed.");
      } else {
         print("Simple slug content size: ${resp2.body.length}");
      }
      
      var listUrl = "https://www.arabam.com/sifir-km/fiat-fiyat-listesi"; 
      var resp3 = await http.get(Uri.parse(listUrl), headers: headers);
      print("GET /sifir-km/fiat-fiyat-listesi -> Status: ${resp3.statusCode}");
      if(resp3.statusCode == 200) {
          int count = parser.parse(resp3.body).querySelectorAll('a[href*="-fiyat-listesi"]').length;
          print("Found $count model links in list page - check heuristics.");
      }
  } catch (e) {
      print("Error: $e");
  }
}
