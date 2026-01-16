
import 'package:allofcar/services/car_search_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Second Hand Car Search Test', () async {
    final service = CarSearchService();
    
    // Create basic filter
    final filter = FilterOptions(
      category: 'otomobil',
      brand: 'Tümü', // Test "All" first
      minPrice: 0,
      maxPrice: 10000000,
      minKm: 0,
      maxKm: 500000,
      gear: [],
      fuel: [],
      caseType: [],
      traction: [],
      color: [],
      page: 1,
    );

    print("--- Starting Search ---");
    try {
      final results = await service.searchCars(filter);
      print("Found ${results.length} listings.");
      
      if (results.isNotEmpty) {
        print("First item: ${results.first.title} - ${results.first.price}");
        print("Image: ${results.first.imageUrl}");
      } else {
        print("No results found. This indicates the issue.");
      }
    } catch (e) {
      print("Error during search: $e");
    }
  });
}
