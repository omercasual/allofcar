import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // --- BURAYA KENDİ KEYİNİ YAPIŞTIR ---
  final String _apiKey = 'AIzaSyCfEEXDwZvbVAzVA-MzHvMj-03DX-RPxkQ';

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_apiKey.contains('AIzaSyCfEEXDwZvbVAzVA-MzHvMj-03DX-RPxkQ') ||
        _apiKey.isEmpty) {
      setState(
        () => _messages.add({
          "role": "model",
          "content": "Lütfen kodun içine Google API Anahtarınızı yapıştırın!",
        }),
      );
      return;
    }

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": _messages
              .map(
                (msg) => {
                  "role": msg['role'] == 'user' ? "user" : "model",
                  "parts": [
                    {"text": msg['content']},
                  ],
                },
              )
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final aiResponse =
            data['candidates']?[0]['content']?['parts']?[0]['text'] ??
            "Cevap yok.";
        setState(() => _messages.add({"role": "model", "content": aiResponse}));
      } else {
        setState(
          () => _messages.add({
            "role": "model",
            "content": "Hata: ${response.statusCode}",
          }),
        );
      }
    } catch (e) {
      setState(
        () =>
            _messages.add({"role": "model", "content": "Bağlantı hatası: $e"}),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AllofCar Asistan",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0059BC),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF0059BC)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15).copyWith(
                        bottomRight: isUser ? Radius.zero : null,
                        bottomLeft: !isUser ? Radius.zero : null,
                      ),
                    ),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Sor bakalım...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'chat_send_message_fab',
                  onPressed: _sendMessage,
                  backgroundColor: const Color(0xFF0059BC),
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
