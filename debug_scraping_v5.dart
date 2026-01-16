
import 'package:http/http.dart' as http;

Future<void> main() async {
  print("--- ATTRIBUTE CHECK ---");
  try {
      var url = 'https://www.sifiraracal.com/peugeot-modelleri/408'; 
      final response = await http.get(Uri.parse(url)); 
      if (response.statusCode == 200) {
          // Look for "7353" and get surrounding characters
          int idx = response.body.indexOf("7353");
          if (idx != -1) {
              int start = (idx - 20) < 0 ? 0 : idx - 20;
              print(response.body.substring(start, idx + 10)); // e.g. data-versiyon="7353"
          }
      }
  } catch (e) { print(e); }
}
