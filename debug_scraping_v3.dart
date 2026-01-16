
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

Future<void> main() async {
  print("--- FIAT PRICE LIST HUNT ---");
  try {
      // Trying the main price list page for the brand
      var url = 'https://www.sifiraracal.com/fiat-fiyat-listesi';
      final response = await http.get(Uri.parse(url)); 
      
      print("Status: ${response.statusCode}");
      if (response.statusCode == 200) {
          var doc = parser.parse(response.body);
          
          // Look for hidden inputs or data attributes in the price table
          var versionRows = doc.querySelectorAll('tr'); // Assuming table structure
          print("Found ${versionRows.length} rows");
          
          for(var r in versionRows.take(15)) {
              print("Row: ${r.text.replaceAll('\n', ' ').trim().substring(0, min(80, r.text.length))}...");
              
              // Key: Look for any numbers that look like IDs in links or inputs
              var links = r.querySelectorAll('a');
              for(var l in links) {
                 if (l.attributes['href']?.contains('-') == true) { // IDs often at end
                    print(" - Link: ${l.attributes['href']}");
                 }
              }
              
              var inputs = r.querySelectorAll('input');
              for(var i in inputs) {
                 print(" - Input: name=${i.attributes['name']} val=${i.attributes['value']}");
              }
          }
      }
  } catch (e) {
      print("Err price list: $e");
  }
  
  print("\n--- KNOWN COMPARISON PAGE TEST ---");
  try {
      var url = 'https://www.sifiraracal.com/arac-karsilastirma/peugeot-408-7353-VS-volkswagen-tiguan-5639';
      final response = await http.get(Uri.parse(url));
      print("Comparison Page Status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
          var doc = parser.parse(response.body);
          var winner = doc.querySelector('.winner-badge, .kazanan')?.text ?? "Winner badge not found";
          var scores = doc.querySelectorAll('.score, .puan');
          print("Winner logic check: $winner");
          print("Found ${scores.length} score elements");
          
          // Check for specific data points
          var techData = doc.querySelectorAll('.tech-data, .teknik-veri');
          print("Found ${techData.length} technical data points");
      }
  } catch (e) {
      print("Err comparison: $e");
  }
}
int min(int a, int b) => a < b ? a : b;
