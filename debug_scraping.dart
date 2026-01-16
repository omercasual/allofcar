import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  // Test Fiat Egea presence
  String url = "https://www.arabam.com/ikinci-el/otomobil/fiat";
  print("Fetching $url");

  var response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  });

  print("Status: ${response.statusCode}");
  
  Uri finalUri = response.request?.url ?? Uri.parse(url);
  String finalPath = finalUri.path;
  if (finalPath.endsWith('/')) finalPath = finalPath.substring(0, finalPath.length - 1);
  
  print("Final Path (after redirect): $finalPath");

  var document = parser.parse(response.body);

  var elements = document.querySelectorAll('ul.category-list li a, ul.list-group li a, div.category-section ul li a');
  print("Selector found: ${elements.length} elements");

  if (elements.isEmpty) {
    print("Trying fallback 'ul li a'");
    elements = document.querySelectorAll('ul li a');
  }

  for (var el in elements) {
    String text = el.text.trim();
    String? href = el.attributes['href'];
    
    if (href == null) continue;
    
    // Mimic the strict check in CarSearchService
    bool strictMatch = href.startsWith(finalPath);
    
    if (text.isNotEmpty) {
       print("[$text] -> $href (Strict match: $strictMatch)");
    }
  }
}
