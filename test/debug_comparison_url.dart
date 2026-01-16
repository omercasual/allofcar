
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://www.arabalar.com.tr/wp-content/json/data.json';
  print("Checking URL: $url");
  try {
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });
    print("Status Code: ${response.statusCode}");
    if (response.statusCode == 200) {
      print("Success! Body length: ${response.body.length}");
    } else {
      print("Failed. Body preview: ${response.body.substring(0, 100)}");
    }
  } catch (e) {
    print("Error: $e");
  }
}
