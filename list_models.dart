import 'dart:convert';
import 'dart:io';

void main() async {
  final keys = [
    'AIzaSyDn62jZoSL4tTXsIGTOPMzJigN4kdpM4UY',
    'AIzaSyBOlGdm18JnY8RjnF9WjNg7n9KWV399aqA'
  ];

  final client = HttpClient();

  for (var i = 0; i < keys.length; i++) {
    final key = keys[i];
    print('\n--- Listing Models for Key ${i + 1} ---');

    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$key');
      
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      final responseBody = await response.transform(utf8.decoder).join();
      
      print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody);
        final models = json['models'] as List;
        for (var m in models) {
          // Filter for 'generateContent' supported models
          if (m['supportedGenerationMethods'].contains('generateContent')) {
             print('- ${m['name']}');
          }
        }
      } else {
         print('Error: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }
}
