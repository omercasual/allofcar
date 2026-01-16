import 'dart:io';

Future<void> main() async {
  final url = "https://m.atcdn.co.uk/schemes/media/w64/audi/226b3dbffe2b4155a69702dc9d547f4d.jpg";
  final client = HttpClient();
  
  try {
    final request = await client.getUrl(Uri.parse(url));
    
    // mimic the header I added in the app
    request.headers.set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36");
    
    final response = await request.close();
    
    print("Status Code: ${response.statusCode}");
    print("Headers:");
    response.headers.forEach((name, values) {
      print("$name: $values");
    });
    
    final bytes = <int>[];
    await response.listen((data) {
      bytes.addAll(data);
    }).asFuture();
    
    print("Downloaded ${bytes.length} bytes.");
    String prefix = String.fromCharCodes(bytes.take(10));
    print("First 10 bytes (string): $prefix");
    print("First 10 bytes (hex): ${bytes.take(10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
    
  } catch (e) {
    print("Error: $e");
  }
}
