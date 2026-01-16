
import 'package:allofcar/services/car_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Car Search SubCategories Test', () async {
    final service = CarSearchService();
    
    // Test known path
    // e.g. /ikinci-el/otomobil/fiat
    final parentPath = "/ikinci-el/otomobil/fiat";
    print("Fetching subcategories for: $parentPath");
    
    final items = await service.getSubCategories(parentPath);
    print("Found ${items.length} items:");
    for (var item in items) {
       print("- $item");
    }
  });
}
