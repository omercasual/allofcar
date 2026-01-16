import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/car_model.dart';
import '../data/brand_data.dart';
import '../services/gemini_service.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class MaintenanceAssistantScreen extends StatefulWidget {
  const MaintenanceAssistantScreen({super.key});

  @override
  State<MaintenanceAssistantScreen> createState() => _MaintenanceAssistantScreenState();
}

class _MaintenanceAssistantScreenState extends State<MaintenanceAssistantScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<MaintenanceMessage> _messages = [];
  bool _isTyping = false;
  final String _apiKey = 'AIzaSyDn62jZoSL4tTXsIGTOPMzJigN4kdpM4UY'; 

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage); 

  List<Car> _userCars = [];
  
  // Confirmation State
  Car? _pendingConfirmationCar;
  bool _isWaitingForConfirmation = false;
  
  // Suggestion Chips Data
  List<String> get _currentSuggestions {
    if (_isWaitingForConfirmation) {
      return ["Evet, Devam Et", "Farklı Araç Seç"];
    }
    return [
      "Aracıma hangi yağı koymalıyım?",
      "Bakım zamanı geldi mi?", 
      "Ağır bakımda neler değişir?",
      "Lastik basıncı kaç olmalı?"
    ];
  }

  @override
  void initState() {
    super.initState();
    _fetchUserGarage();
    _startGreeting();
  }
  
  void _fetchUserGarage() {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _firestoreService.getGarage(uid).listen((cars) {
        if (mounted) {
           setState(() {
             _userCars = cars;
           });
        }
      });
    }
  }

  void _startGreeting() async {
    // Optimized Delays: Faster appearance
    await Future.delayed(const Duration(milliseconds: 200));
    _addMessage(_t('maintenance_welcome'), false);
    
    // Wait a bit more and show sheet
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _showCarSelectionSheet(null);
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(MaintenanceMessage(text: text, isUser: isUser));
    });
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Handle Suggestion Click
  void _onSuggestionClick(String suggestion) {
    if (_isWaitingForConfirmation) {
      if (suggestion == "Evet, Devam Et") {
        _confirmCarSelection();
      } else {
        // Cancel/Change
        _addMessage("Farklı bir araç seçmek istiyorum.", true);
        setState(() {
          _isWaitingForConfirmation = false;
          _pendingConfirmationCar = null;
        });
        _showCarSelectionSheet(null);
      }
      return;
    }

    // 1. Ask "Which Car?"
    _showCarSelectionSheet(suggestion);
  }

  // Show Car Selection Menu
  void _showCarSelectionSheet(String? originalQuery) {
    if (_userCars.isEmpty) {
      if (originalQuery != null) {
         // No cars, just send message normally
         _controller.text = originalQuery;
         _handleSend();
      } else {
        _addMessage(_t('garage_empty_warning'), false);
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow Sheet to take needed height but not full screen unless needed
      backgroundColor: Colors.transparent, // Remove default tint/background
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(_t('select_vehicle'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text(_t('which_car_support'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 20),
                
                // Car List
                ..._userCars.asMap().entries.map((entry) {
                  int idx = entry.key + 1;
                  Car car = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        child: Text("$idx", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(car.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text("${car.plate ?? ''} • ${car.currentKm} km", style: TextStyle(color: Colors.grey[600])),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        if (originalQuery != null) {
                          _handleSendWithContext(originalQuery, car);
                        } else {
                          _handleCarSelection(car);
                        }
                      },
                    ),
                  );
                }),
                
                const SizedBox(height: 10),
                
                // Skip Button
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(_t('maintenance_continue_without_vehicle'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                
                const SizedBox(height: 24),
                
                // Tip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blueAccent, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t('maintenance_tip'),
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20), // Bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleCarSelection(Car car) {
    // Ask for Confirmation
    setState(() {
      _pendingConfirmationCar = car;
      _isWaitingForConfirmation = true;
    });
    _addMessage("${car.brand ?? ''} ${car.name} aracını seçtiniz. Bu araçla devam etmek istiyor musunuz?", false);
  }

  Future<void> _confirmCarSelection() async {
    if (_pendingConfirmationCar == null) return;
    final car = _pendingConfirmationCar!;
    
    _addMessage("Evet, devam et", true);
    
    setState(() {
      _isWaitingForConfirmation = false;
      _pendingConfirmationCar = null;
    });

    // Proceed with logic
    String carContext = """
    [SECİLEN ARAÇ BİLGİLERİ]
    Marka/Model: ${car.brand ?? ''} ${car.name}
    Yıl: ${car.modelYear ?? 'Bilinmiyor'}
    KM: ${car.currentKm}
    Yakıt/Motor: ${car.hardware ?? 'Bilinmiyor'}
    
    [BAKIM GEÇMİŞİ]
    """;
    // Add History logic
    if (car.history.isNotEmpty) {
      var recentHistory = car.history.reversed.take(5);
      for (var record in recentHistory) {
         carContext += "- Tarih: ${record['date']}, İşlem: ${record['action']}, KM: ${record['km']}\n";
      }
    } else {
      carContext += "Kayıtlı bakım geçmişi yok.\n";
    }

    await _performGeminiCall(_t('maintenance_prompt_initial'), carContext);
  }

  Future<void> _handleSendWithContext(String text, Car car) async {
    _addMessage(text, true); // Show user message
    
    setState(() => _isTyping = true);

    // Build Context String
    String carContext = """
    [SECİLEN ARAÇ BİLGİLERİ]
    Marka/Model: ${car.brand ?? ''} ${car.name}
    Yıl: ${car.modelYear ?? 'Bilinmiyor'}
    KM: ${car.currentKm}
    Yakıt/Motor: ${car.hardware ?? 'Bilinmiyor'}
    
    [BAKIM GEÇMİŞİ ve YAĞ BİLGİLERİ]
    """;

    // Add History (Last 5 items for context)
    if (car.history.isNotEmpty) {
      var recentHistory = car.history.reversed.take(5);
      for (var record in recentHistory) {
         carContext += "- Tarih: ${record['date']}, İşlem: ${record['action']}, KM: ${record['km']}";
         if (record['oilBrand'] != null) carContext += ", Yağ Markası: ${record['oilBrand']}";
         if (record['oilViscosity'] != null) carContext += ", Viskozite: ${record['oilViscosity']}";
         carContext += "\n";
      }
    } else {
      carContext += "Kayıtlı bakım geçmişi yok.\n";
    }

    // Append standard logic
    await _performGeminiCall(text, carContext);
  }

  Future<void> _handleSend() async {
    if (_isTyping) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _addMessage(text, true);

    // Command: @garaj
    if (text.toLowerCase() == "@garaj") {
      if (_userCars.isEmpty) {
        _addMessage(_t('garage_empty_warning'), false);
      } else {
        String msg = _t('garage_cars_title');
        for (int i = 0; i < _userCars.length; i++) {
           msg += "${i + 1}) ${_userCars[i].brand ?? ''} ${_userCars[i].name}\n";
        }
        _addMessage(msg, false);
      }
      return; // Do not call AI
    }

    await _performGeminiCall(text, null);
  }

  Future<void> _performGeminiCall(String userMessage, String? contextData) async {
    setState(() => _isTyping = true);

    try {
      String? systemPrompt = await _firestoreService.getMaintenanceAiConfig();
      // String? systemPrompt = null; // Removed force null

      String tyreBrands = BrandData.tyreBrands.join(", ");
      String oilBrands = BrandData.oilBrands.join(", ");

      systemPrompt ??= """
      Sen araç bakımı, yağ değişimi ve lastik seçimi konusunda uzman, Haynes Manuals ve teknik servis bültenlerine hakim bir "Oto Bakım Asistanı"sın.
      
      GÖREVLERİN:
      1. Araca en uygun motor yağı, filtreler ve periyodik bakım önerilerini yap.
      2. Kullanıcının araç bilgilerini (KM, Yıl, Motor Tipi) titizlikle analiz et.
      3. Lastik önerilerinde bulunurken KESİNLİKLE "lastiksiparis.com" standartlarını, ürün portföyünü ve stoklarını baz al. Başka kaynak kullanma.
         - Özellikle şu markaları önceliklendir (Çünkü uygulamamızda bu markaların ürünleri var): $tyreBrands.
      4. Motor yağı önerilerinde KESİNLİKLE "turkoilmarket.com" verilerini, viskozite standartlarını ve güncel ürün kataloglarını baz al. Başka kaynak kullanma.
         - Özellikle şu markaları önceliklendir (Çünkü uygulamamızda bu markaların ürünleri var): $oilBrands.

      ÖNEMLİ KURALLAR:
      - Kullanıcıya öneri yaparken, "lastiksiparis.com verilerine göre..." veya "turkoilmarket.com standartlarına dayanarak..." gibi ifadeler kullan. Bu kaynaklardan beslendiğini açıkça belirt.
      - Uygulamamızda yer alan (listelenen) markaları (yukarıda belirtilenler) her zaman ilk sıraya koy. "Uygulamamızdaki güvenilir markalardan..." diyerek bu markaları tavsiye et.
      
      YANIT STRATEJİN:
      - Eğer kullanıcı "hangi yağı koymalıyım" veya "hangi lastiği almalıyım" derse:
        * Mutlaka aracın motor koduna (varsa) ve kullanım şartlarına göre spesifik viskozite (örn: 5W-30) veya lastik ölçüsü öner.
        * Önerilerini yaparken "lastiksiparis.com" ve "turkoilmarket.com" üzerindeki profesyonel verileri referans göster.
        * Marka öneririrken objektif ol ama listemizde olan güvenilir markaları (Liqui Moly, Mobil, Castrol, Michelin, Continental vb.) ön planda tut.
      - Teknik terimleri açıklayıcı ama profesyonel bir dille kullan.
      """;

      // Inject Context if available
      if (contextData != null) {
        systemPrompt += "\n\n$contextData";
      }
      
      // Use the centralized GeminiService
      final response = await GeminiService().generateContent(systemPrompt, userMessage);

      if (response != null) {
         _addMessage(response, false);
      } else {
         _addMessage(_t('service_busy'), false);
      }

    } catch (e) {
      _addMessage(_t('ai_general_error'), false);
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text("${_t('maintenance_assistant_title')} 🛠️"),
            const SizedBox(width: 8),
            const Text("AI", style: TextStyle(fontSize: 10,  backgroundColor: Colors.blueAccent, color: Colors.white)),
          ],
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          
          // SUGGESTION CHIPS AREA
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _currentSuggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: ActionChip(
                    label: Text(suggestion),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                    elevation: 2,
                    onPressed: () => _onSuggestionClick(suggestion),
                  ),
                );
              }).toList(),
            ),
          ),
  
          if (_isTyping)
             Padding(
               padding: const EdgeInsets.all(8.0),
               child: Text(_t('typing_dots'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
             ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MaintenanceMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.orange[800] : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white), // Orange for user (different from blue app theme)
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ]
        ),
        child: Text(
          msg.text,
          style: TextStyle(color: msg.isUser ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87), fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _t('maintenance_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              backgroundColor: Colors.orange[800],
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _handleSend,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class MaintenanceMessage {
  final String text;
  final bool isUser;

  MaintenanceMessage({required this.text, required this.isUser});
}
