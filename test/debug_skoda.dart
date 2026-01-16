import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print("Starting Skoda debug scrape...");
  const String url = "https://www.arabam.com/sifir-km/skoda";
  final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  try {
      final response = await http.get(Uri.parse(url), headers: headers);
      print("Status Code: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        
        // 1. Check strict selector used in App for HTML scraping
        var anchors = document.querySelectorAll('a[href^="/sifir-km/skoda-"]');
        print("\n--- HTML Anchors found: ${anchors.length} ---");
        
        for(var a in anchors) {
             String href = a.attributes['href']!;
             String fullText = a.text.trim().replaceAll(RegExp(r'\s+'), ' ');
             print("Link: $href");
             print("   Text: $fullText");
        }
        
        // 3. Test Pagination
        print("\n--- Testing Pagination ---");
        var params = ["?page=2", "?take=100", "?limit=100"];
        for(var p in params) {
           String pUrl = "$url$p";
           var resp = await http.get(Uri.parse(pUrl), headers: headers);
           if (resp.statusCode == 200) {
              var pDoc = parser.parse(resp.body);
              var pAnchors = pDoc.querySelectorAll('a[href^="/sifir-km/skoda-"]');
              print("Param '$p' found ${pAnchors.length} items.");
              if (pAnchors.isNotEmpty && pAnchors.first.attributes['href']!.contains("elroq")) {
                    print("   -> Same as Page 1 (Pagination FAILED)");
              } else if (pAnchors.isNotEmpty) {
                    print("   -> DIFFERENT from Page 1 (Pagination SUCCESS)");
              }
           }
        }

        // 4. Test SuperB Variants
        print("\n--- Testing SuperB Variants ---");
        var candidates = [
            "/sifir-km/skoda-superb",
            "/sifir-km/skoda-superb-sedan",
            "/sifir-km/skoda-superb-sedan-fiyat-listesi",
            "/sifir-km/skoda-superb-kombi",
            "/sifir-km/skoda-superb-kombi-fiyat-listesi",
            "/sifir-km/skoda-superb-combi", // Just in case
            "/sifir-km/skoda-superb-combi-fiyat-listesi"
        ];
        
        for(var path in candidates) {
            String cUrl = "https://www.arabam.com$path";
            var resp = await http.get(Uri.parse(cUrl), headers: headers);
            print("Checking $path -> Status: ${resp.statusCode}, Length: ${resp.body.length}");
        }
        // 5. Find SuperB JSON friendlyUrl
        print("\n--- Context for SuperB JSON ---");
        int idx = response.body.indexOf("\"name\":\"Superb\""); // Case sensitive? 'Superb' or 'SuperB'?
        if (idx == -1) idx = response.body.indexOf("\"name\":\"SuperB\"");
        
        if (idx != -1) {
             int start = idx;
             int end = (idx + 200) > response.body.length ? response.body.length : idx + 200;
             print("...${response.body.substring(start, end)}...");
        } else {
             print("Could not find SuperB in JSON.");
        }
      }
  } catch (e) {
      print("Error: $e");
  }
}
