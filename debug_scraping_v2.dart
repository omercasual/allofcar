
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

Future<void> main() async {
  // 1. Try "Markalar" page for brands
  print("--- MARKALAR ---");
  try {
      // Try common URL
      final response = await http.get(Uri.parse('https://www.sifiraracal.com/markalar')); 
      // If 404, try homepage and look for brand links
      if (response.statusCode == 200) {
          var doc = parser.parse(response.body);
          var links = doc.querySelectorAll('.brand-list a, .brands a, .marka-listesi a');
          if (links.isEmpty) links = doc.querySelectorAll('a'); // Fallback
          
          print("Found ${links.length} links on Markalar page");
          int count = 0;
          for(var l in links) {
              String href = l.attributes['href'] ?? "";
              // Look for clean links like /marka-fiyatlari or just /marka
              if (href.length < 30 && !href.contains('karsilastirma') && !href.contains('haber')) {
                  print("Brand Link?: ${l.text.trim()} -> $href");
                  count++;
                  if(count > 10) break;
              }
          }
      } else {
          print("Markalar page 404/Error: ${response.statusCode}");
      }
  } catch (e) { print("Err markalar: $e"); }

  // 2. Retry Models (Fiat) with looser filter
  print("\n--- MODELS (Fiat) ---");
  try {
      final response = await http.get(Uri.parse('https://www.sifiraracal.com/fiat-modelleri')); 
      if (response.statusCode == 200) {
          var doc = parser.parse(response.body);
          var links = doc.querySelectorAll('a');
          int count = 0;
          for(var l in links) {
              String href = l.attributes['href'] ?? "";
              // Just print anything that looks like a sub-page
              if (href.startsWith('/') && href.split('/').length < 4) {
                 print("Link: ${l.text.trim()} -> $href");
                 count++;
                 if(count > 20) break;
              }
          }
      }
  } catch (e) {
      print("Err models: $e");
  }
}
