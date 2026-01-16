
import 'package:http/http.dart' as http;

Future<void> main() async {
  print("--- ID HUNT (Peugeot 408 -> 7353) ---");
  try {
      // Guessing the model page URL based on previous patterns
      var url = 'https://www.sifiraracal.com/peugeot-modelleri/408'; 
      // Also try price page if model page fails
      var url2 = 'https://www.sifiraracal.com/peugeot-modelleri/408-fiyatlari';

      print("Checking Model Page: $url");
      final response = await http.get(Uri.parse(url)); 
      if (response.statusCode == 200) {
          int idx = response.body.indexOf("7353");
          if (idx != -1) {
              print("FOUND 7353 on Model Page!");
              int start = (idx - 100) < 0 ? 0 : idx - 100;
              int end = (idx + 100) > response.body.length ? response.body.length : idx + 100;
              print(response.body.substring(start, end).replaceAll('\n', ' '));
          } else {
              print("Not found on Model Page.");
          }
      } else {
        print("Model Page Status: ${response.statusCode}");
      }
      
      print("\nChecking Price Page: $url2");
      final response2 = await http.get(Uri.parse(url2)); 
      if (response2.statusCode == 200) {
          int idx = response2.body.indexOf("7353");
          if (idx != -1) {
              print("FOUND 7353 on Price Page!");
              int start = (idx - 100) < 0 ? 0 : idx - 100;
              int end = (idx + 100) > response2.body.length ? response2.body.length : idx + 100;
              print(response2.body.substring(start, end).replaceAll('\n', ' '));
          } else {
               print("Not found on Price Page.");
          }
      }
  } catch (e) {
      print("Err hunter: $e");
  }
}
