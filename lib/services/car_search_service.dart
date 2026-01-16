import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:allofcar/data/car_data.dart';


class CarListing {
  final String id;
  final String title;
  final String price;
  final String location;
  final String km;
  final String year;
  final String imageUrl;
  final String link;
  final bool hasHeavyDamage;
  final String? expertiseStatus; // e.g., "Full Orijinal", "3 Parça Boyalı"

  CarListing({
    required this.id,
    required this.title,
    required this.price,
    required this.location,
    required this.km,
    required this.year,
    required this.imageUrl,
    required this.link,
    this.hasHeavyDamage = false,
    this.expertiseStatus,
  });
}

class FilterOptions {
  final String category; // 'otomobil' or 'arazi-suv-pick-up'
  final String? brand;
  final String? series;
  final String? model;
  final String? hardware;
  
  final double minPrice;
  final double maxPrice;
  
  final double minKm;
  final double maxKm;
  
  final int? minYear;
  final int? maxYear;

  final int? minPower; 
  final int? maxPower;
  final int? minVolume;
  final int? maxVolume;
  
  final List<String> gear; 
  final List<String> fuel; 
  final List<String> caseType; 
  final List<String> traction; 
  final List<String> color; 

  final bool? warranty; 
  final bool? heavyDamage; 
  final String? fromWhom; 
  final bool? exchange; 

  final int page;

  FilterOptions({
    required this.category,
    this.brand,
    this.series,
    this.model,
    this.hardware,
    required this.minPrice,
    required this.maxPrice,
    required this.minKm,
    required this.maxKm,
    this.minYear,
    this.maxYear,
    this.minPower,
    this.maxPower,
    this.minVolume,
    this.maxVolume,
    required this.gear,
    required this.fuel,
    required this.caseType,
    required this.traction,
    required this.color,
    this.warranty,
    this.heavyDamage,
    this.fromWhom,
    this.exchange,
    required this.page,
  });
}

class CarSearchService {
  static const String _baseUrl = 'https://www.arabam.com';

  // Cache for blacklist to avoid constant Firestore reads
  static List<String> _cachedBlacklist = [];
  static DateTime? _lastBlacklistFetch;

  Map<String, String> _getHeaders() {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  // Bridge for compatibility
  static Map<String, String> get brandLogos => CarData.carLogos;

  Future<List<String>> getSubCategories(String parentPath) async {
    try {
        debugPrint("Fetching subcategories from: $parentPath");

        String requestUrl;
        if (parentPath.startsWith("http")) {
           requestUrl = parentPath;
        } else {
           String path = parentPath;
           if (!path.startsWith("/")) {
              path = "/$path";
           }
           // If accessing main categories (otomobil, arazi etc) ensure /ikinci-el prefix if missing
           if (!path.startsWith("/ikinci-el") && (path.startsWith("/otomobil") || path.startsWith("/arazi") || path.startsWith("/motosiklet"))) {
              path = "/ikinci-el$path";
           }
           requestUrl = "$_baseUrl$path";
        }
        
        // Ensure slash between domain and path
        if (!requestUrl.contains("arabam.com/") && requestUrl.contains("arabam.com")) {
            requestUrl = requestUrl.replaceFirst("arabam.com", "arabam.com/");
        }
        
        debugPrint("Requesting URL: $requestUrl");
        
        final response = await http.get(
          Uri.parse(requestUrl),
          headers: _getHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) return [];
        var document = parser.parse(response.body);
        
        // Selectors for Arabam.com categories
        var elements = document.querySelectorAll('ul.list-group li a'); 
        if (elements.isEmpty) {
           elements = document.querySelectorAll('.category-list-item a');
        }
        if (elements.isEmpty) {
            elements = document.querySelectorAll('div.category-list a');
        }

        // Blacklist of common menu/sidebar items to exclude
        List<String> blockedKeywords = [
          "Ücretsiz teklif al", "Randevunu yönet", "Otomobil", "Arazi, SUV, Pick-up", "Motosiklet",
          "Minivan & Panelvan", "Ticari Araçlar", "Kiralık Araçlar", "Hasarlı Araçlar",
          "Yedek Parça", "Aksesuar", "Donanım & Tuning", "Traktör", "Tarım & İş Makineleri",
          "Klasik Araçlar", "Elektrikli Araçlar", "ATV & UTV", "Karavan", "Engelli Plakalı",
          "Giriş Yap", "Üye Ol", "İlan Ver", "Bana Özel", "Mesajlar", "Favorilerim", "Garajım",
          "Engelli Araçları", "Modifiyeli Araçlar", "Sedan", "Hatchback", "Station Wagon", 
          "Suv / Pick-up", "Coupe", "Cabrio", "Van / Panelvan", "Minibüs", "Tüm 2. El İlanlar",
          "Bana Araç Öner", "Arabam Kaç Para?", "Sahibinden 2. El İlanlar", "Galeriler",
        ];

        List<String> items = [];
        
        // Sync path for filtering
        String finalPath = Uri.parse(requestUrl).path;
        if (finalPath.endsWith('/')) {
             finalPath = finalPath.substring(0, finalPath.length - 1);
        }

        for (var el in elements) {
           String text = el.text.trim();
           String? href = el.attributes['href'];

           // 1. Basic check
           if (text.isEmpty || href == null) continue;

           // 2. Strict Link Validation
           // The link must be a sub-path of the current page.
           bool startsWithStrict = href.startsWith(finalPath) && href.length > finalPath.length;
           
           // Relaxed check: Accept if it contains the brand name and looks like a model
           // e.g. /ikinci-el/otomobil/passat when we are on /ikinci-el/otomobil/volkswagen
           bool startsWithRelaxed = false;
           String lastSegment = finalPath.split('/').last; // e.g. volkswagen
           
           if (!startsWithStrict && href.contains("/$lastSegment")) {
               startsWithRelaxed = true;
           }
           
           // Special case for top-level keys like "serisi"
           if (!startsWithStrict && !startsWithRelaxed && finalPath.endsWith("serisi")) {
               if (href.startsWith(finalPath.replaceAll("-serisi", ""))) {
                   startsWithRelaxed = true;
               }
           }

           if (!startsWithStrict && !startsWithRelaxed) {
             continue; // Skip unrelated links
           }
           
           items.add(text);
           debugPrint("Found category (HTML): $text -> $href");
        }

        // --- FALLBACK: JSON Parsing (If HTML selectors fail) ---
        if (items.isEmpty) {
           debugPrint("HTML selectors found 0 items. Trying JSON/Script parsing...");
           try {
              // Extract 'var facets = [...]' from the script tag
              final regex = RegExp(r'var facets = (\[.*?\]);', dotAll: true);
              final match = regex.firstMatch(response.body);
              
              if (match != null) {
                  final jsonStr = match.group(1);
                  final List<dynamic> facetsData = jsonDecode(jsonStr!);
                  
                  for (var facet in facetsData) {
                      // Look for 'SelectedCategory' which contains current level context
                      if (facet is Map<String, dynamic> && facet.containsKey('SelectedCategory')) {
                          final selectedCat = facet['SelectedCategory'];
                          if (selectedCat != null && selectedCat['SubCategories'] is List) {
                              final subCats = selectedCat['SubCategories'] as List;
                              for (var sub in subCats) {
                                  if (sub['Name'] != null) {
                                      items.add(sub['Name'].toString());
                                      debugPrint("Found category (JSON): ${sub['Name']}");
                                  }
                              }
                          }
                      }
                  }
              }
           } catch (e) {
              debugPrint("JSON Fallback Error: $e");
           }
        }
           

        
        debugPrint("DEBUG: Found ${items.length} subcategories.");

        // Manual Injection for Volkswagen popular models if not found
        if (finalPath.endsWith("volkswagen")) {
           List<String> vwModels = ["Passat", "Golf", "Polo", "Jetta", "Tiguan", "Caddy", "Transporter"];
           for (var model in vwModels) {
              if (!items.contains(model) && !items.contains("Volkswagen $model")) {
                 items.add(model);
              }
           }
           items.sort();
        }

        // Manual Injection for Fiat (Egea, Linea etc.)
        if (finalPath.endsWith("fiat")) {
           List<String> fiatModels = ["Egea", "Linea", "Doblo", "Fiorino", "Punto", "Panda", "500", "500L", "500X", "Albea", "Palio", "Siena", "Tipo", "Uno"];
           for (var model in fiatModels) {
              if (!items.contains(model) && !items.contains("Fiat $model")) {
                 items.add(model);
              }
           }
           items.sort();
        }

        // Manual Injection for Renault (Clio, Megane etc.)
        if (finalPath.endsWith("renault")) {
           List<String> renaultModels = ["Clio", "Megane", "Symbol", "Captur", "Kadjar", "Fluence", "Kangoo", "Taliant", "Zoe", "Austral", "Twingo", "Laguna", "Latitude", "Scenic", "Grand Scenic", "Koleos", "Talisman"];
           for (var model in renaultModels) {
              if (!items.contains(model) && !items.contains("Renault $model")) {
                 items.add(model);
              }
           }
           items.sort();
        }

        // Manual Injection for Ford (Focus, Fiesta etc.)
        if (finalPath.endsWith("ford")) {
           List<String> fordModels = ["Focus", "Fiesta", "Mondeo", "Kuga", "Puma", "EcoSport", "Ranger", "Transit", "Tourneo Courier", "Tourneo Connect", "C-Max", "B-Max", "S-Max", "Galaxy", "Fusion", "Ka"];
           for (var model in fordModels) {
              if (!items.contains(model) && !items.contains("Ford $model")) {
                 items.add(model);
              }
           }
           items.sort();
        }

        // Manual Injection for Fiat Egea Engines
        if (finalPath.endsWith("fiat-egea")) {
           List<String> egeaEngines = ["1.0 Firefly", "1.3 Multijet", "1.4 Fire", "1.4 T-Jet", "1.5 T4", "1.6 E-Torq", "1.6 Multijet"];
           for (var engine in egeaEngines) {
              if (!items.contains(engine)) {
                 items.add(engine);
              }
           }
           items.sort();
        }

        if (items.isEmpty) {
             debugPrint("Warning: No subcategories found for $finalPath. Using Fallback.");
             // --- FALLBACK MODELS ---
             if (finalPath.contains("volkswagen")) items.addAll(["Passat", "Golf", "Polo", "Jetta", "Tiguan", "Caddy", "Transporter", "Arteon", "T-Roc"]);
             else if (finalPath.contains("audi")) items.addAll(["A3", "A4", "A5", "A6", "Q2", "Q3", "Q5", "Q7"]);
             else if (finalPath.contains("bmw")) items.addAll(["1 Serisi", "2 Serisi", "3 Serisi", "4 Serisi", "5 Serisi", "X1", "X3", "X5"]);
             else if (finalPath.contains("mercedes")) items.addAll(["A Serisi", "C Serisi", "E Serisi", "S Serisi", "CLA", "GLA", "GLC"]);
             else if (finalPath.contains("ford")) items.addAll(["Focus", "Fiesta", "Mondeo", "Kuga", "Puma", "Ranger", "Transit"]);
             else if (finalPath.contains("fiat")) items.addAll(["Egea", "Linea", "Doblo", "Fiorino", "Punto", "Panda", "500"]);
             else if (finalPath.contains("renault")) items.addAll(["Clio", "Megane", "Symbol", "Captur", "Kadjar", "Taliant"]);
             else if (finalPath.contains("toyota")) items.addAll(["Corolla", "Yaris", "C-HR", "Auris", "RAV4", "Proace"]);
             else if (finalPath.contains("honda")) items.addAll(["Civic", "CR-V", "Jazz", "HR-V", "City"]);
             else if (finalPath.contains("hyundai")) items.addAll(["i10", "i20", "i30", "Tucson", "Bayon", "Elantra"]);
             else if (finalPath.contains("peugeot")) items.addAll(["208", "308", "2008", "3008", "5008", "508", "Rifter"]);
             else if (finalPath.contains("opel")) items.addAll(["Corsa", "Astra", "Insignia", "Mokka", "Crossland", "Grandland"]);
             else if (finalPath.contains("skoda")) items.addAll(["Octavia", "Superb", "Fabia", "Kamiq", "Karoq", "Kodiaq", "Scala"]);
             else if (finalPath.contains("seat")) items.addAll(["Leon", "Ibiza", "Ateca", "Arona"]);
             else if (finalPath.contains("citroen")) items.addAll(["C3", "C4", "C5 Aircross", "C-Elysee", "Berlingo"]);
             else if (finalPath.contains("nissan")) items.addAll(["Qashqai", "Juke", "Micra", "X-Trail"]);
             else if (finalPath.contains("dacia")) items.addAll(["Duster", "Sandero", "Lodgy", "Logan"]);
             else if (finalPath.contains("kia")) items.addAll(["Sportage", "Rio", "Ceed", "Stonic", "Picanto"]);
             
             items.sort();
        }

        return items.take(50).toList();
    } catch (e) {
      debugPrint("Error fetching subcategories: $e");
    }
    return [];
  }

  // Public slugify for UI to use
  String slugify(String text) {
    var map = {
      'ç': 'c', 'Ç': 'c',
      'ğ': 'g', 'Ğ': 'g',
      'ı': 'i', 'I': 'i',
      'İ': 'i', 'ö': 'o', 'Ö': 'o',
      'ş': 's', 'Ş': 's',
      'ü': 'u', 'Ü': 'u',
    };
    
    text = text.toLowerCase();
    map.forEach((k, v) => text = text.replaceAll(k, v));
    return text.replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  }

  // Generate URL for Arabam
  String generateUrl(FilterOptions options) {
    // Path structure: /ikinci-el/otomobil/bmw-3-serisi...
    String path = "/ikinci-el/${options.category}";
    
    if (options.brand != null && options.brand != "Tümü") {
      path += "/${slugify(options.brand!)}";
      
      if (options.series != null) {
        path += "-${slugify(options.series!)}";
        if (options.model != null) {
          path += "-${slugify(options.model!)}";
        }
      }
    }

    // Query Parameters
    Map<String, String> queryParams = {};
    
    // Price
    if (options.minPrice > 0) queryParams['minPrice'] = options.minPrice.toInt().toString();
    if (options.maxPrice < 10000000) queryParams['maxPrice'] = options.maxPrice.toInt().toString();
    
    // KM
    if (options.minKm > 0) queryParams['minKilometer'] = options.minKm.toInt().toString();
    if (options.maxKm < 500000) queryParams['maxKilometer'] = options.maxKm.toInt().toString();
    
    // Year
    if (options.minYear != null) queryParams['minYear'] = options.minYear.toString();
    if (options.maxYear != null) queryParams['maxYear'] = options.maxYear.toString();
    
    // Engine
    if (options.minPower != null) queryParams['minHorsePower'] = options.minPower.toString();
    if (options.maxPower != null) queryParams['maxHorsePower'] = options.maxPower.toString();
    
    if (options.minVolume != null) queryParams['minEngineSize'] = options.minVolume.toString();
    if (options.maxVolume != null) queryParams['maxEngineSize'] = options.maxVolume.toString();
    
    // Booleans
    if (options.warranty == true) queryParams['warranty'] = 'true'; 
    if (options.heavyDamage == true) queryParams['hasHeavyDamage'] = 'true'; 
    if (options.exchange == true) queryParams['exchange'] = 'true';
    if (options.fromWhom != null) {
       if (options.fromWhom == "Sahibinden") {
         queryParams['from'] = 'owner';
       } else if (options.fromWhom == "Galeriden") {
         queryParams['from'] = 'gallery';
       } else if (options.fromWhom == "Yetkili Bayiden") {
         queryParams['from'] = 'authorized_dealer';
       }
    }
    
    // Pagination
    if (options.page > 1) {
      queryParams['page'] = options.page.toString();
    }
    
    queryParams['sort'] = 'date_desc';

    String queryString = Uri(queryParameters: queryParams).query;
    if (queryString.isNotEmpty) {
       return "$_baseUrl$path?$queryString";
    }
    return "$_baseUrl$path";
  }

  Future<List<CarListing>> searchCars(FilterOptions options) async {
    String fullUrl = generateUrl(options);
    debugPrint("Scraping URL (Arabam): $fullUrl");

    try {
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: _getHeaders(),
      );
      
      debugPrint("DEBUG: HTTP Status: ${response.statusCode}");
      debugPrint("DEBUG: Body Length: ${response.body.length}");

      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        
        // Strategy 1: Specific Selector
        var rows = document.querySelectorAll('tr.listing-list-item');
        
        // Strategy 2: Fallback to all rows if specific failed
        if (rows.isEmpty) {
           debugPrint("DEBUG: Specific selector failed. Trying all 'tr' elements.");
           rows = document.querySelectorAll('tr'); // Generic Table Rows
        }
        
        debugPrint("DEBUG: Processing ${rows.length} rows...");
        
        List<CarListing> listings = [];

        for (var row in rows) {
          try {
            // Columns by confirmed index from debug screenshot
            // 0: Image (Empty text)
            // 1: Model Name (e.g. Fiat Egea...)
            // 2: Title (e.g. HAZEM MOTORS...)
            // 3: Year (e.g. 2016)
            // 4: KM (e.g. 210.000)
            // 5: Color
            // 6: Price (e.g. 570.000 TL)
            // 7: Date
            // 8: Location
            
            var tds = row.querySelectorAll('td');
            
            String year = "";
            String km = "";
            String location = "";
            String title = "";
            String price = "";
            String link = "";
            String id = "";
            
            if (tds.length >= 7) {
               title = tds[1].text.trim(); // Model as title
               // String userTitle = tds[2].text.trim(); 
               
               year = tds[3].text.trim();
               km = tds[4].text.trim();
               price = tds[6].text.trim(); 
               
               if (tds.length > 8) {
                 location = tds[8].text.trim();
               }

               // Extract Link from Model column (index 1)
               var linkEl = tds[1].querySelector('a');
               if (linkEl != null && linkEl.attributes['href'] != null) {
                  link = "$_baseUrl${linkEl.attributes['href']}";
               }
            }
            
            // Fallback: If title empty, try finding any link with title in row
            if (title.isEmpty) {
               var titleEl = row.querySelector('td:nth-child(2) > a');
               title = titleEl?.text.trim() ?? row.querySelector('td:nth-child(2)')?.text.trim() ?? "";
            }

            // ID generation
            id = row.attributes['id'] ?? (link.isNotEmpty ? link.split('/').last : DateTime.now().millisecondsSinceEpoch.toString());

            // Improved Image Extraction
            var imgEl = row.querySelector('img.listing-image') ?? row.querySelector('img');
            String imageUrl = "";
            
            if (imgEl != null) {
              // Priority order for arabam.com lazy-loading
              imageUrl = imgEl.attributes['data-src'] ?? 
                         imgEl.attributes['data-original'] ?? 
                         imgEl.attributes['src'] ?? 
                         "";
            }
            
            // Clean and resolve URL
            if (imageUrl.isNotEmpty) {
              if (imageUrl.startsWith('//')) {
                imageUrl = 'https:$imageUrl';
              } else if (!imageUrl.startsWith('http')) {
                imageUrl = '$_baseUrl$imageUrl';
              }
              
              // Filter out placeholders
              if (imageUrl.contains("base64") || imageUrl.contains("spacer.gif") || imageUrl.contains("no-image")) {
                imageUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/No-Image-Placeholder.svg/1665px-No-Image-Placeholder.svg.png";
              }
            } else {
               imageUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/No-Image-Placeholder.svg/1665px-No-Image-Placeholder.svg.png";
            }
            
            // Validation
            if (title.isNotEmpty && price.isNotEmpty && !price.toLowerCase().contains("fiyat")) {
               listings.add(CarListing(
                id: id,
                title: title,
                price: price,
                location: location.replaceAll(RegExp(r'\s+'), ' '),
                km: km,
                year: year,
                imageUrl: imageUrl,
                link: link,
                hasHeavyDamage: row.text.contains("Ağır Hasar") || row.text.contains("Pert"),
                expertiseStatus: row.text.contains("Boyasız") ? "Boyasız / Hatasız" : (row.text.contains("Değişenli") ? "Değişen Var" : null),
              ));
            }
          } catch (e) {
             // Swallow generic row parse errors
          }
        }
        
        debugPrint("DEBUG: Parsed ${listings.length} valid listings.");
        return listings;

      } else {
        throw Exception("Bağlantı hatası: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error in searchCars: $e");
      debugPrint("Returning Offline Mock Data for Car Search.");
      
      // Offline Fallback Data
      return [
        CarListing(
          id: "mock-1",
          title: "Fiat Egea 1.4 Fire Easy (Offline)",
          price: "850.000 TL",
          location: "İstanbul / Kadıköy",
          km: "45.000",
          year: "2021",
          imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/fiat.png",
          link: "",
          expertiseStatus: "Boyasız",
        ),
        CarListing(
          id: "mock-2",
          title: "Renault Clio 1.0 TCe Joy (Offline)",
          price: "920.000 TL",
          location: "Ankara / Cankaya",
          km: "25.000",
          year: "2022",
          imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/renault.png",
          link: "",
        ),
        CarListing(
          id: "mock-3",
          title: "Volkswagen Passat 1.5 TSI Business (Offline)",
          price: "1.850.000 TL",
          location: "İzmir / Konak",
          km: "60.000",
          year: "2020",
          imageUrl: "https://arbimg1.mncdn.com/assets/dist/img/logolar-50/volkswagen.png",
          link: "",
          expertiseStatus: "Değişen Var",
        ),
      ];
    }
  }
}
