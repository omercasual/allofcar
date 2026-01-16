import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print("Starting Mercedes debug scrape...");
  const String url = "https://www.arabam.com/sifir-km/mercedes-benz";
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
        print("Page Size: ${response.body.length}");

        // 1. Check strict selector used in App
        var brandSlug = "mercedes-benz";
        var strictSelector = 'a[href^="/sifir-km/$brandSlug-"]';
        var appAnchors = document.querySelectorAll(strictSelector);
        print("\n--- App Selector '$strictSelector' found: ${appAnchors.length} items ---");
        for(var a in appAnchors) {
           print(" -> ${a.attributes['href']}");
        }
        
        // 6. Find JSON Array Start
        print("\n--- Context for JSON Array Start ---");
        int idx = response.body.indexOf("\"GLA Serisi\"");
        if (idx != -1) {
             // Look backwards for "items" or "["
             int start = (idx - 2000) < 0 ? 0 : idx - 2000;
             int end = idx;
             print(response.body.substring(start, end));
        }
        
      }
  } catch (e) {
      print("Error: $e");
  }
}
