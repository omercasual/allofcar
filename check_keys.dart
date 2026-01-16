import 'dart:convert';
import 'dart:io';

void main() async {
  final keys = [
    'AIzaSyDn62jZoSL4tTXsIGTOPMzJigN4kdpM4UY',
    'AIzaSyBOlGdm18JnY8RjnF9WjNg7n9KWV399aqA'
  ];

  final models = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];

  final client = HttpClient();

  for (var i = 0; i < keys.length; i++) {
    final key = keys[i];
    print('\n--- Testing Key ${i + 1} ---');

    for (var model in models) {
      try {
        final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
        
        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'application/json');
        
        final body = jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "Hello, are you active?"}
              ]
            }
          ]
        });
        
        request.write(body);
        final response = await request.close();
        
        final responseBody = await response.transform(utf8.decoder).join();
        
        print('Model: $model -> Status: ${response.statusCode}');
        if (response.statusCode != 200) {
           print('Error: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}');
        } else {
           print('Result Length: ${responseBody.length}'); // Just to confirm we got data
        }
      } catch (e) {
        print('Exception testing $model: $e');
      }
    }
  }
}
