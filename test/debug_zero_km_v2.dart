
import 'package:flutter_test/flutter_test.dart';
import 'package:allofcar/services/zero_km_service.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('ZeroKmService scraping test', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final service = ZeroKmService();
    
    print("--- 1. Testing Brands ---");
    final brands = await service.getBrands();
    print("Found ${brands.length} brands.");
    if (brands.isNotEmpty) {
      print("First brand: ${brands.first.name} - Logo: ${brands.first.logoUrl}");
    }

    print("\n--- 2. Testing Models (Fiat) ---");
    final models = await service.getModels('fiat');
    print("Found ${models.length} Fiat models.");
    
    for (var m in models) {
      print("Model: ${m.name} | Price: ${m.priceRange} | Image: ${m.imageUrl}");
    }
  });
}
