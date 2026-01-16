
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

Future<void> main() async {
  print("--- INSPECT RESULT PAGE ---");
  // IDs from earlier: 107318, 107319
  var url = 'https://www.arabalar.com.tr/karsilastirma-sonucu/?ids=107318,107319';
  
  try {
      final response = await http.get(Uri.parse(url)); 
      print("Status: ${response.statusCode}");
      var doc = parser.parse(response.body);
      
      // Look for table rows or specific comparison cards
      // Usually these tables have headers like "Fiyat", "Motor", "Yakıt"
      
      var rows = doc.querySelectorAll('tr');
      print("Found ${rows.length} rows");
      
      for(var r in rows.take(20)) {
          print("Row: ${r.text.replaceAll(RegExp(r'\s+'), ' ').trim()}");
      }
      
  } catch(e) { print(e); }
}
