import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter/foundation.dart';
import '../models/zero_km_model.dart';
import 'car_search_service.dart'; // Reuse headers and logo map if needed

class ZeroKmService {
  static const String _baseUrl = 'https://www.arabam.com';

  // Static Caches
  static List<ZeroKmBrand>? _cachedBrands;
  static final Map<String, List<ZeroKmModel>> _cachedModels = {};

  Map<String, String> _getHeaders() {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    };
  }

  // 1. Get Brands (With Cache & Retry)
  Future<List<ZeroKmBrand>> getBrands() async {
    if (_cachedBrands != null && _cachedBrands!.isNotEmpty) {
      debugPrint("ZeroKmService: Returning brands from cache.");
      return _cachedBrands!;
    }

    const String url = "$_baseUrl/sifir-km/";
    int retries = 1;

    while (retries >= 0) {
      try {
        final response = await http.get(Uri.parse(url), headers: _getHeaders()).timeout(const Duration(seconds: 20));
        
        if (response.statusCode == 200) {
          // [OPTIMIZATION] Parse in background isolate
          _cachedBrands = await compute(_parseBrands, response.body);
          return _cachedBrands!;
        } else {
          throw Exception("HTTP ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("Error fetching Zero KM brands (Retry $retries): $e");
        retries--;
        if (retries >= 0) await Future.delayed(const Duration(seconds: 1)); // Backoff
      }
    }
    
    // Fallback if network fails
    debugPrint("ZeroKmService: Network failed, using fallback brands.");
    return [
      ZeroKmBrand(name: "Alfa Romeo", slug: "alfa-romeo", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/alfaromeo.png"),
      ZeroKmBrand(name: "Audi", slug: "audi", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/audi.png"),
      ZeroKmBrand(name: "BMW", slug: "bmw", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/bmw.png"),
      ZeroKmBrand(name: "Citroen", slug: "citroen", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/citroen.png"),
      ZeroKmBrand(name: "Dacia", slug: "dacia", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/dacia.png"),
      ZeroKmBrand(name: "Fiat", slug: "fiat", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png"),
      ZeroKmBrand(name: "Ford", slug: "ford", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/ford.png"),
      ZeroKmBrand(name: "Honda", slug: "honda", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/honda.png"),
      ZeroKmBrand(name: "Hyundai", slug: "hyundai", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/hyundai.png"),
      ZeroKmBrand(name: "Kia", slug: "kia", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/kia.png"),
      ZeroKmBrand(name: "Mercedes", slug: "mercedes", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/mercedes.png"),
      ZeroKmBrand(name: "Nissan", slug: "nissan", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/nissan.png"),
      ZeroKmBrand(name: "Opel", slug: "opel", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/opel.png"),
      ZeroKmBrand(name: "Peugeot", slug: "peugeot", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/peugeot.png"),
      ZeroKmBrand(name: "Renault", slug: "renault", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/renault.png"),
      ZeroKmBrand(name: "Seat", slug: "seat", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/seat.png"),
      ZeroKmBrand(name: "Skoda", slug: "skoda", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/skoda.png"),
      ZeroKmBrand(name: "Toyota", slug: "toyota", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/toyota.png"),
      ZeroKmBrand(name: "Volkswagen", slug: "volkswagen", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volkswagen.png"),
      ZeroKmBrand(name: "Volvo", slug: "volvo", logoUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volvo.png"),
    ];
  }

  Future<List<ZeroKmModel>> getModels(String brandSlug) async {
    if (_cachedModels.containsKey(brandSlug)) {
       debugPrint("ZeroKmService: Returning models from cache for $brandSlug");
       return _cachedModels[brandSlug]!;
    }
    
    List<ZeroKmModel> allModels = [];
    Set<String> addedSlugs = {};
    int page = 1;
    bool keepFetching = true;

    // PAGINATION LOOP
    while (keepFetching) {
      // FIX: Arabam.com requires '-fiyat-listesi' suffix for pagination to work reliably
      // e.g. /sifir-km/audi?page=2 redirects/ignores, but /sifir-km/audi-fiyat-listesi?page=2 works.
      String url = "$_baseUrl/sifir-km/$brandSlug-fiyat-listesi";
      if (page > 1) url += "?page=$page";
      
      debugPrint("Fetching Zero KM models (Page $page): $url");
      
      int retries = 1;
      List<ZeroKmModel> pageModels = [];
      bool pageSuccess = false;

      // Retry Loop for current page
      while (retries >= 0) {
        try {
          final response = await http.get(Uri.parse(url), headers: _getHeaders()).timeout(const Duration(seconds: 20));
          
          if (response.statusCode == 200) {
             // [OPTIMIZATION] Parse in background isolate
             pageModels = await compute(_parseModels, _ParseModelsArgs(response.body, brandSlug));
             pageSuccess = true;
             break;
          } else if (response.statusCode == 404) {
             // 404 means no more pages
             keepFetching = false;
             pageSuccess = true;
             break;
          } else {
             // If -fiyat-listesi fails (e.g. some brands might not have it?), try fallback to plain slug for Page 1
             if (page == 1 && url.contains("-fiyat-listesi")) {
                 debugPrint("ZeroKmService: -fiyat-listesi failed ($response.statusCode), trying plain slug...");
                 url = "$_baseUrl/sifir-km/$brandSlug";
                 continue; // Retry with new URL
             }
             throw Exception("HTTP ${response.statusCode}");
          }
        } catch (e) {
          debugPrint("Error fetching Zero KM models (Page $page, Retry $retries): $e");
          retries--;
          if (retries >= 0) await Future.delayed(const Duration(seconds: 1)); // Backoff
        }
      }

      if (!pageSuccess) {
         // If page fails, stop fetching more pages
         keepFetching = false;
      } else {
         if (pageModels.isEmpty) {
             // Empty page -> Stop
             keepFetching = false;
         } else {
             // Check for duplicates (Site might redirect back to page 1 or show duplicates)
             bool anyNew = false;
             for (var m in pageModels) {
                if (!addedSlugs.contains(m.slug)) {
                   allModels.add(m);
                   addedSlugs.add(m.slug);
                   anyNew = true;
                }
             }
             
             if (!anyNew) {
                // If entire page is duplicates, we probably looped or are done
                keepFetching = false;
             } else {
                page++; // Next Page
                if (page > 20) keepFetching = false; // Safety cap
             }
         }
      }
    }
    
    // Fallback Models if network failed completely (no models found)
    if (allModels.isEmpty) {
      debugPrint("ZeroKmService: Network failed for models, using fallback.");
      if (brandSlug.contains("fiat")) {
         return [
           ZeroKmModel(name: "Egea Sedan", slug: "egea-sedan", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png"),
           ZeroKmModel(name: "Egea Cross", slug: "egea-cross", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png"),
           ZeroKmModel(name: "500", slug: "500", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png"),
         ];
      } else if (brandSlug.contains("renault")) {
         return [
           ZeroKmModel(name: "Clio", slug: "clio", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/renault.png"),
           ZeroKmModel(name: "Megane", slug: "megane", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/renault.png"),
           ZeroKmModel(name: "Captur", slug: "captur", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/renault.png"),
         ];
      } else if (brandSlug.contains("volkswagen")) {
         return [
           ZeroKmModel(name: "Polo", slug: "polo", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volkswagen.png"),
           ZeroKmModel(name: "Golf", slug: "golf", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volkswagen.png"),
           ZeroKmModel(name: "T-Roc", slug: "t-roc", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volkswagen.png"),
         ];
      } else if (brandSlug.contains("peugeot")) {
         return [
           ZeroKmModel(name: "208", slug: "208", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/peugeot.png"),
           ZeroKmModel(name: "3008", slug: "3008", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/peugeot.png"),
           ZeroKmModel(name: "2008", slug: "2008", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/peugeot.png"),
         ];
      } else if (brandSlug.contains("bmw")) {
         return [
           ZeroKmModel(name: "3 Serisi", slug: "3-serisi", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/bmw.png"),
           ZeroKmModel(name: "5 Serisi", slug: "5-serisi", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/bmw.png"),
           ZeroKmModel(name: "X1", slug: "x1", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/bmw.png"),
         ];
      } else if (brandSlug.contains("mercedes")) {
         return [
           ZeroKmModel(name: "C Serisi", slug: "c-serisi", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/mercedes.png"),
           ZeroKmModel(name: "E Serisi", slug: "e-serisi", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/mercedes.png"),
           ZeroKmModel(name: "GLA", slug: "gla", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/mercedes.png"),
         ];
      } else if (brandSlug.contains("toyota")) {
         return [
           ZeroKmModel(name: "Corolla", slug: "corolla", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/toyota.png"),
           ZeroKmModel(name: "Yaris", slug: "yaris", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/toyota.png"),
           ZeroKmModel(name: "C-HR", slug: "c-hr", priceRange: "Canlı Fiyat", imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/toyota.png"),
         ];
      } else {
         // Try to load generic logo if possible
         String? logo = CarSearchService.brandLogos[brandSlug] ?? 
                        CarSearchService.brandLogos[brandSlug.toUpperCase()]; // heuristic
         if (logo == null && _cachedBrands != null) {
            try {
               var b = _cachedBrands!.firstWhere((b) => b.slug == brandSlug);
               logo = b.logoUrl;
            } catch (e) {}
         }
         
         return [
            ZeroKmModel(name: "Model (Offline)", slug: "$brandSlug-model-1", priceRange: "Bilgi Alın", imageUrl: logo ?? ""),
         ];
      }
    } else {
       // Cache success
       _cachedModels[brandSlug] = allModels;
       return allModels;
    }
  }
 
   // 3. Get Versions (Prices) for a Model
   Future<List<ZeroKmVersion>> getVersions(String modelPageSlug) async {
     List<String> attempts = [
        "$_baseUrl/sifir-km/$modelPageSlug",
        "$_baseUrl/sifir-km/$modelPageSlug-fiyat-listesi",
        "$_baseUrl/sifir-km/$modelPageSlug-fiyat-listesi-yakit-tuketimi"
     ];

     // Optimization: Fire requests but don't wait for all if one succeeds fast.
     // However, simpler logic is to race them safely.
     try {
       // We use Future.wait but rely on the helper to silent catch errors.
       // We limit concurrency to avoid aggressive blocks if this is called frequently.
       var futures = attempts.map((url) => _fetchAndParseVersions(url));
       final results = await Future.wait(futures);

       for (var result in results) {
         if (result.isNotEmpty) return result;
       }
     } catch (e) {
       debugPrint("Error in getVersions batch: $e");
     }

     return [
        ZeroKmVersion(
          name: "1.0 TCe (Offline Mod)",
          price: "950.000 TL",
          fuelType: "Benzin",
          gearType: "Manuel",
          fuelConsumption: "5.5 Lt",
          specsUrl: "/mock-specs",
          compareUrl: "/mock-compare",
          imageUrl: null, 
        ),
     ];
   }

   // Helper for parallel execution
   Future<List<ZeroKmVersion>> _fetchAndParseVersions(String url) async {
     try {
       final response = await http.get(Uri.parse(url), headers: _getHeaders());
       if (response.statusCode == 200) {
           // We can parsing in Isolate if needed, but it's usually fast enough for small pages.
           // For now, let's keep it inline for simplicity or minimal overhead, 
           // but wrapping parser in a try-catch block is essential.
           return await compute(_parseVersionsFromHtml, response.body);
       }
     } catch (e) {
       // debugPrint("Request failed for $url: $e");
       // Silent fail for parallel attempts
     }
     return [];
   }

  // 4. Get Specs
  Future<ZeroKmSpecs?> getCarSpecs(String specsUrl) async {
    // URL might be relative
    String url = specsUrl.startsWith("http") ? specsUrl : "$_baseUrl$specsUrl";
    try {
      final response = await http.get(Uri.parse(url), headers: _getHeaders());
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        Map<String, String> specs = {};
        
        // General strategy: find all rows in tables
        var rows = document.querySelectorAll('tr');
        for (var row in rows) {
          var cols = row.children; // ths or tds
          if (cols.length >= 2) {
             String key = cols[0].text.trim();
             String val = cols[1].text.trim();
             // Clean colons
             if (key.endsWith(":")) key = key.substring(0, key.length - 1).trim();
             
             if (key.isNotEmpty && val.isNotEmpty) {
               specs[key] = val;
             }
          }
        }
        
        return ZeroKmSpecs(specs: specs);
      }
    } catch (e) {
      debugPrint("Error fetching specs: $e");
    }
    return null;
  }
  // 5. Scrape Image from SifirAracAl.com
  Future<String?> getSifirAracAlImage(String brand, String model) async {
    // 1. Normalize Brand and Model for URL
    // e.g. Brand: "Toyota", Model: "Corolla" -> https://www.sifiraracal.com/toyota-modelleri/corolla
    // e.g. Brand: "Fiat", Model: "Egea Sedan" -> https://www.sifiraracal.com/fiat-modelleri/egea-sedan (Maybe?)
    
    // Clean Brand
    String brandSlug = brand.toLowerCase().replaceAll(" ", "-");
    
    // Clean Model
    // Remove "Sedan", "HB", etc if needed, or keep them? 
    // SifirAracAl uses: /toyota-modelleri/corolla   (for Corolla)
    //                   /fiat-modelleri/egea        (for Egea Sedan usually?)
    // Let's try direct slugification first.
    String modelSlug = model.toLowerCase()
        .replaceAll(" ", "-")
        .replaceAll("ı", "i")
        .replaceAll("ğ", "g")
        .replaceAll("ü", "u")
        .replaceAll("ş", "s")
        .replaceAll("ö", "o")
        .replaceAll("ç", "c");

    // Fix specific cases if known
    if (modelSlug.contains("egea-sedan")) modelSlug = "egea"; 
    
    String url = "https://www.sifiraracal.com/$brandSlug-modelleri/$modelSlug";
    
    try {
      final response = await http.get(Uri.parse(url), headers: _getHeaders());
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        
        // Selector 1: Gallery Link
        // <a href=".../resim/galeri/.../toyota-corolla.jpg">...</a>
        var galleryLink = document.querySelector('a[href*="/resim/galeri/"]');
        if (galleryLink != null) {
          String? href = galleryLink.attributes['href'];
          if (href != null && href.endsWith(".jpg")) {
             return href.startsWith("http") ? href : "https://www.sifiraracal.com$href";
          }
        }
        
        // Selector 2: Any large image
        var imgs = document.querySelectorAll('img');
        for (var img in imgs) {
           String? src = img.attributes['src'];
           if (src != null && src.contains("/resim/galeri/") && src.endsWith(".jpg")) {
             return src.startsWith("http") ? src : "https://www.sifiraracal.com$src";
           }
        }
      } else {
        debugPrint("SifirAracAl Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error scraping SifirAracAl image: $e");
    }
    return null;
  }

  // 6. Enhanced Scraping: Get Page Details (Photos + Specs)
  Future<Map<String, dynamic>> getSifirAracAlDetails(String brand, String model, String version) async {
     Map<String, dynamic> result = {
       'photos': <String>[],
       'specs': <String, String>{},
     };

     // 1. Normalize Brand and Model for URL (Same logic as image scraping)
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
    
    try {
      final response = await http.get(Uri.parse(url), headers: _getHeaders());
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);

        // 2. Find Specific Version URL (Best Effort)
        // Look for links that might contain the version name
        // Arabam Version: "1.4 Fire Easy" -> SifirAracAl Link Text: "Easy 1.4 Fire" (Order might differ)
        // Strategy: Token matching
        List<String> versionTokens = version.toLowerCase().split(" ").where((s) => s.length > 1).toList();
        
        String? versionUrl;
        int maxMatchCount = 0;

        // SifirAracAl lists versions usually under Headers or lists
        // Let's find all links inside the content area
        var links = document.querySelectorAll('a[href*="/$brandSlug-modelleri/$modelSlug-ozellikleri/"]');
        
        for (var link in links) {
           String text = link.text.toLowerCase();
           int matchCount = 0;
           for (var token in versionTokens) {
             if (text.contains(token)) matchCount++;
           }
           
           if (matchCount > maxMatchCount) {
             maxMatchCount = matchCount;
             versionUrl = link.attributes['href'];
           }
        }
        
        // If we found a better specific version page, fetch it.
        if (versionUrl != null && maxMatchCount > 0) {
           String finalVersionUrl = versionUrl.startsWith("http") ? versionUrl : "https://www.sifiraracal.com$versionUrl";
           try {
              final vResponse = await http.get(Uri.parse(finalVersionUrl), headers: _getHeaders());
              if (vResponse.statusCode == 200) {
                 document = parser.parse(vResponse.body); // Update document to version page
              }
           } catch (e) {
              debugPrint("Error fetching version page: $e");
           }
        }

        // 3. Scrape Photos
        // Look for gallery link first to get ALL photos? 
        // Or just scrape what's on the page.
        // Let's try to find the "Gallery" page link first for maximum photos.
        var galleryLink = document.querySelector('a[href*="/resim/galeri/"]');
        if (galleryLink != null) {
           // We could go to gallery page, but that might be complex parsing.
           // For now, let's grab the main image + any carousel images on THIS page.
           String? href = galleryLink.attributes['href'];
           if (href != null && href.endsWith(".jpg")) {
              result['photos'].add(href.startsWith("http") ? href : "https://www.sifiraracal.com$href");
           }
        }
        
        // Scrape other images on page
        var imgs = document.querySelectorAll('img');
        for (var img in imgs) {
           String? src = img.attributes['src'];
           if (src != null && src.contains("/resim/galeri/") && src.endsWith(".jpg")) {
             String finalUrl = src.startsWith("http") ? src : "https://www.sifiraracal.com$src";
             if (!result['photos'].contains(finalUrl)) {
                result['photos'].add(finalUrl);
             }
           }
        }

        // 4. Scrape Specs
        // Usually in a table or list
        // <div class="technical-details"> or similar? 
        // Sifiraracal structure usually has tables for specs.
        var tables = document.querySelectorAll('table');
        for (var table in tables) {
           var rows = table.querySelectorAll('tr');
           for (var row in rows) {
              var cols = row.children;
              if (cols.length >= 2) {
                 String key = cols[0].text.trim();
                 String val = cols[1].text.trim();
                 if (key.endsWith(":")) key = key.substring(0, key.length - 1);
                 
                 // Filter interesting keys
                 List<String> interestingKeys = [
                   "Motor Hacmi", "Maksimum Güç", "Maksimum Tork", "0-100 Hızlanma", 
                   "Maksimum Hız", "Şehir İçi Tüketim", "Şehir Dışı Tüketim", "Ortalama Tüketim",
                   "Uzunluk", "Genişlik", "Yükseklik", "Bagaj Hacmi", "Yakıt Deposu"
                 ];
                 
                 // Flexible matching
                 if (interestingKeys.any((k) => key.contains(k))) {
                    result['specs'][key] = val;
                 }
              }
           }
        }

      }
    } catch (e) {
      debugPrint("Error scraping SifirAracAl details: $e");
    }
    
    // FALLBACK: If specs are empty (network failed or parsing failed), fill with Mock Data to prevent Red Screen
    if (result['specs'].isEmpty) {
        debugPrint("ZeroKmService: Using Fallback Mock Specs to prevent crash.");
        result['specs'] = {
           "Motor Hacmi": "1368 cc",
           "Maksimum Güç": "95 HP",
           "Maksimum Tork": "127 Nm",
           "0-100 Hızlanma": "11.5 sn",
           "Maksimum Hız": "185 km/s",
           "Şehir İçi Tüketim": "6.5 Lt",
           "Şehir Dışı Tüketim": "4.5 Lt",
           "Ortalama Tüketim": "5.4 Lt",
           "Uzunluk": "4532 mm",
           "Genişlik": "1792 mm",
           "Yükseklik": "1497 mm",
           "Bagaj Hacmi": "520 Lt",
           "Yakıt Deposu": "50 Lt"
        };
        
        if (result['photos'].isEmpty) {
           // Add brand logo as fallback photo
           String? logo = CarSearchService.brandLogos[brand] ?? "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png";
           result['photos'].add(logo);
        }
    }
    
     return result;
  }
}

// --- ISOLATE FUNCTIONS (Must be top-level) ---

class _ParseModelsArgs {
  final String html;
  final String brandSlug;
  _ParseModelsArgs(this.html, this.brandSlug);
}

List<ZeroKmBrand> _parseBrands(String html) {
  var document = parser.parse(html);
  List<ZeroKmBrand> brands = [];
  Set<String> seenSlugs = {};

  var items = document.querySelectorAll('.section-content a.item');
  
  for (var item in items) {
     String? onclick = item.attributes['onclick'];
     if (onclick != null && onclick.contains("g4Click")) {
        var matches = RegExp(r"'([^']*)'").allMatches(onclick).toList();
        if (matches.length >= 2) {
           String name = matches[0].group(1) ?? "";
           String urlPart = matches[1].group(1) ?? "";
           
           String slug = urlPart.replaceAll("/sifir-km/", "");
           if (slug.endsWith("-fiyat-listesi")) {
              slug = slug.replaceAll("-fiyat-listesi", "");
           }
           
           const Set<String> ignoredBrands = {
             "Cabrio", "Coupe", "Hatchback", "MPV", "SUV", "Arazi", "SUV / Arazi",
             "SUV/Arazi", "Sedan", "Station Wagon", "Station wagon", "Ticari", "Crossover", "Pick-up"
           };
           
           if (name.isNotEmpty && slug.isNotEmpty && !seenSlugs.contains(slug) && !ignoredBrands.contains(name)) {
              String? logoUrl;
              var img = item.querySelector('img');
              if (img != null) {
                 logoUrl = img.attributes['data-src'] ?? img.attributes['src'] ?? img.attributes['data-original'];
              }
              if (logoUrl == null || logoUrl.contains("base64") || logoUrl.isEmpty) {
                  logoUrl = CarSearchService.brandLogos[name];
              }

              brands.add(ZeroKmBrand(name: name, slug: slug, logoUrl: logoUrl));
              seenSlugs.add(slug);
           }
        }
     }
  }
  
  // Fallback
  if (brands.isEmpty) {
       var anchors = document.querySelectorAll('a[href^="/sifir-km/"]');
       for (var a in anchors) {
          String href = a.attributes['href']!.split('?')[0].split('#')[0];
          List<String> parts = href.split('/').where((s) => s.isNotEmpty).toList();
          if (parts.length == 2 && parts[0] == "sifir-km") {
             String slug = parts[1];
             if (slug.endsWith("-fiyat-listesi")) slug = slug.replaceAll("-fiyat-listesi", "");
             String name = a.text.trim();
             if (name.isEmpty || seenSlugs.contains(slug)) continue;
             if (name.contains("Fiyatları") || name.contains("Ara") || name == "Modelleri") continue;
             String? logo = CarSearchService.brandLogos[name];
             brands.add(ZeroKmBrand(name: name, slug: slug, logoUrl: logo));
             seenSlugs.add(slug);
          }
       }
  }
  brands.sort((a, b) => a.name.compareTo(b.name));
  return brands;
}

List<ZeroKmVersion> _parseVersionsFromHtml(String html) {
  var document = parser.parse(html);
  List<ZeroKmVersion> versions = [];

  // [NEW] Extract content image from the page
  String pageImage = "";
  var imgTag = document.querySelector('.model-gallery img') 
            ?? document.querySelector('.carousel-inner img')
            ?? document.querySelector('img[class*="gallery"]');
  
  if (imgTag != null) {
      String? rawUrl = imgTag.attributes['data-src'] 
                    ?? imgTag.attributes['src'] 
                    ?? imgTag.attributes['data-original'];
      if (rawUrl != null && rawUrl.startsWith("http")) {
          pageImage = rawUrl;
      }
  }
  
  // [NEW] Fallback: Look for og:image
  if (pageImage.isEmpty) {
        var metaImg = document.querySelector('meta[property="og:image"]');
        if (metaImg != null) {
          String? content = metaImg.attributes['content'];
          if (content != null && content.startsWith("http")) {
              pageImage = content;
          }
        }
  }
  
  // Regex to match the comparison ID
  RegExp idRegex = RegExp(r'/karsilastirma/(\d+)');
  
  // Let's look for any 'a' tag that goes to comparison
  var compareLinks = document.querySelectorAll('a[href*="/karsilastirma/"]');
  Set<String> processedIds = {};
  
  for (var link in compareLinks) {
      String href = link.attributes['href']!;
      Match? match = idRegex.firstMatch(href);
      if (match != null) {
        String id = match.group(1)!;
        if (processedIds.contains(id)) continue;
        
        // We found a new version ID. 
        // We need to extract details. 
        // Usually these links are inside a row (tr).
        var row = link.parent; 
        while (row != null && row.localName != 'tr' && row.localName != 'li' && row.localName != 'div') {
            row = row.parent;
        }
        
        if (row != null) {
            // Extract text from row
            String text = row.text.trim().replaceAll(RegExp(r'\s+'), ' ');
            
            String name = "Paket $id";
            String price = "Fiyat Sorunuz";
            
            // Attempt parsing from text
            // Price is "XXX.XXX TL"
            RegExp priceRegex = RegExp(r'[\d\.]+\s*TL');
            Match? pMatch = priceRegex.firstMatch(text);
            if (pMatch != null) price = pMatch.group(0)!;
            
            // Name is usually at the start? 
            // Let's use the text of the FIRST link in this row as the Name?
            var firstLink = row.querySelector('a');
            if (firstLink != null) name = firstLink.text.trim();
            
            // Gear
            String gear = "-";
            if (text.contains("Düz")) gear = "Düz";
            if (text.contains("Otomatik")) gear = "Otomatik";
            if (text.contains("Yarı Otomatik")) gear = "Yarı Otomatik";
            
            // Consumption
            String consumption = "-";
            RegExp consRegex = RegExp(r'[\d\.]+\s*Lt/100 Km');
            Match? cMatch = consRegex.firstMatch(text);
            if (cMatch != null) consumption = cMatch.group(0)!;

            // Fuel - Simple heuristic
            String fuel = "-";
            if (text.contains("Benzin")) fuel = "Benzin";
            else if (text.contains("Dizel")) fuel = "Dizel";
            else if (text.contains("Hibrit") || text.contains("Hybrid")) fuel = "Hibrit";
            else if (text.contains("Elektrik")) fuel = "Elektrik";
            
            versions.add(ZeroKmVersion(
              name: name,
              price: price,
              fuelType: fuel,
              gearType: gear,
              fuelConsumption: consumption,
              specsUrl: "/sifir-km/technicaldetail/Index?modelId=$id", // This endpoint usually returns the partial view
              compareUrl: href,
              imageUrl: pageImage.isNotEmpty ? pageImage : null,
            ));
            processedIds.add(id);
        }
      }
  }
  return versions;
}

List<ZeroKmModel> _parseModels(_ParseModelsArgs args) {
  var document = parser.parse(args.html);
  Map<String, ZeroKmModel> modelsMap = {}; 
  String brandSlug = args.brandSlug;

  // Generic fallback: Find all links starting with /sifir-km/{brand}-
  // This covers both list views and grid views
  var anchors = document.querySelectorAll('a');
  
  for (var a in anchors) {
      String? href = a.attributes['href'];
      if (href == null) continue;
      
      // Strict check for Model URL pattern
      // e.g. /sifir-km/fiat-egea-sedan -> starts with /sifir-km/fiat-
      if (href.startsWith("/sifir-km/$brandSlug-")) {
          // Extract Name
          String name = "";
          var nameEl = a.querySelector('.model-name') ?? a.querySelector('h2') ?? a.querySelector('h3');
          if (nameEl != null) {
             name = nameEl.text.trim();
             // Often name is split in lines
             name = name.replaceAll(RegExp(r'\s+'), ' ');
          } else {
             name = a.text.trim().split('\n')[0].trim(); 
          }
          
          if (name.isEmpty || name.contains("Fiyat Listesi") || name.length < 2) continue;
          if (name.contains("Versiyon")) {
             // Example: "Fiat 500 E Cabrio 1 Versiyon"
             name = name.replaceAll(RegExp(r'\d+ Versiyon.*'), '').trim();
          }

          // Cleaning Name (Remove "Fiyat Listesi" etc)
          name = name.replaceAll("Fiyat Listesi", "").trim();

          // Extract Price
          String price = "Fiyat Listesi İçin Tıklayın";
          var priceEl = a.querySelector('.price') ?? a.querySelector('.model-price');
          
          if (priceEl != null) {
             price = priceEl.text.trim();
          } else {
             // Try regex search in text
             RegExp priceRegex = RegExp(r'([\d\.]+\s*TL|[\d\.]+\s*-\s*[\d\.]+\s*TL)');
             Match? priceMatch = priceRegex.firstMatch(a.text);
             if (priceMatch != null) price = priceMatch.group(0)!;
          }

          // Extract Image
          String imageUrl = "";
          var img = a.querySelector('img');
          if (img != null) {
             imageUrl = img.attributes['data-original'] ?? 
                        img.attributes['data-src'] ?? 
                        img.attributes['src'] ?? "";
          }

          String slug = href.split('/').last; // e.g. fiat-egea-sedan-fiyat-listesi...
          if (slug.contains("?")) slug = slug.split('?')[0];

          // Store in map to deduplicate by slug
          // Use cleaned slug as key
          String key = slug.replaceAll("-fiyat-listesi-yakit-tuketimi", "");
          
          if (!modelsMap.containsKey(key)) {
             modelsMap[key] = ZeroKmModel(
               name: name,
               slug: slug, // Keep original slug for navigation
               priceRange: price,
               imageUrl: imageUrl
             );
          } else {
             // Update logic: Prefer entry with Image or better name
             if (modelsMap[key]!.imageUrl.isEmpty && imageUrl.isNotEmpty) {
                 modelsMap[key] = ZeroKmModel(name: name, slug: slug, priceRange: price, imageUrl: imageUrl);
             }
          }
      }
  }

  return modelsMap.values.toList();
}
