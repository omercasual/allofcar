import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

Future<void> main() async {
  await testScrape('Toyota', 'Corolla');
  await testScrape('Fiat', 'Egea');
  await testScrape('Renault', 'Clio');
}

Future<void> testScrape(String brand, String model) async {
  String brandSlug = brand.toLowerCase().replaceAll(" ", "-");
  
  String modelSlug = model.toLowerCase()
      .replaceAll(" ", "-")
      .replaceAll("ı", "i")
      .replaceAll("ğ", "g")
      .replaceAll("ü", "u")
      .replaceAll("ş", "s")
      .replaceAll("ö", "o")
      .replaceAll("ç", "c");

  if (modelSlug.contains("egea-sedan")) modelSlug = "egea"; 
  
  String url = "https://www.sifiraracal.com/$brandSlug-modelleri/$modelSlug";
  
  print("Testing URL: $url");
  
  try {
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });
    
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      
      // Check Selector 1
      var galleryLink = document.querySelector('a[href*="/resim/galeri/"]');
      if (galleryLink != null) {
        String href = galleryLink.attributes['href']!;
        String finalUrl = href.startsWith("http") ? href : "https://www.sifiraracal.com$href";
        print("FOUND (Selector 1): $finalUrl");
        return;
      }
      
      // Check Selector 2
      var imgs = document.querySelectorAll('img');
      bool found = false;
      for (var img in imgs) {
         String? src = img.attributes['src'];
         if (src != null && src.contains("/resim/galeri/") && src.endsWith(".jpg")) {
           String finalUrl = src.startsWith("http") ? src : "https://www.sifiraracal.com$src";
           print("FOUND (Selector 2): $finalUrl");
           found = true;
           break;
         }
      }
      if (!found) {
        print("NOT FOUND. Dumping first 10 img srcs:");
        for(var img in imgs.take(10)) {
           print(" - ${img.attributes['src']}");
        }
      }
      
    } else {
      print("Error: ${response.statusCode}");
    }
  } catch (e) {
    print("Exception: $e");
  }
}
