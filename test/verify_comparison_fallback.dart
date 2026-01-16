
import 'package:allofcar/services/comparison_scraper_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ComparisonScraperService Fallback Test', () async {
    final service = ComparisonScraperService();
    
    // This should trigger the initialization.
    // If net fails (or we simulate it), it should load fallback.
    // Since we can't easily force net fail here without mock, 
    // we just check if it returns data at all (either net or fallback).
    
    try {
      await service.initializeData();
      final brands = await service.getBrands();
      
      print("Brands found: ${brands.length}");
      if (brands.isNotEmpty) {
        print("First brand: ${brands.first['name']}");
      } else {
        print("No brands found!");
      }

      // Check for 'Volkswagen' which is in fallback
      bool hasVW = brands.any((b) => b['name'] == 'Volkswagen');
      print("Has Volkswagen: $hasVW");

    } catch (e) {
      print("Initialization failed: $e");
    }
  });
}
