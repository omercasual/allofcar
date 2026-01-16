import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/car_search_service.dart';
import '../services/gemini_service.dart';
import '../data/brand_data.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialPrompt; 

  const AiAssistantScreen({super.key, this.initialPrompt});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService(); // [NEW]
  final FirestoreService _firestoreService = FirestoreService();
  final CarSearchService _carSearchService = CarSearchService();

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  final List<AssistantMessage> _messages = [];
  bool _isTyping = false;
  
  // Image Picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  // Autocomplete Variables
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _filteredBrands = [];
  List<String> _filteredModels = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    if (widget.initialPrompt != null) {
      // If there is context, start immediately with it (simulated user message)
      _addMessage(widget.initialPrompt!, true);
      _handleSend(overrideText: widget.initialPrompt);
    } else {
      // Otherwise show standard greeting
      _startGreeting();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _hideOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onTextChanged() async {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.baseOffset < 0) return;

    // Detect Trigger: "@..."
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAt = textBeforeCursor.lastIndexOf('@');
    
    if (lastAt != -1) {
       final rawQuery = textBeforeCursor.substring(lastAt + 1);
       if (rawQuery.contains(' ')) return; // Multi-word constraint

       final parts = rawQuery.split('_');
       final level = parts.length - 1; // 0=Brand, 1=Model, 2=Version, 3=Package...
       
       if (level == 0) {
          // MODE: Brand Selection
          final query = parts[0];
          final matches = BrandData.carBrands.where((b) => b.toLowerCase().startsWith(query.toLowerCase())).toList();
          
          if (matches.isNotEmpty) {
            _showOverlay(matches, (selected) {
               _replaceSegment(lastAt, parts, 0, selected, addUnderscore: true);
            });
            return;
          }
       } else {
          // MODE: Dynamic Levels (Model, Version, etc.)
          final brandName = parts[0];
          
          // Verify Brand first
          if (BrandData.carBrands.contains(brandName)) {
             // Construct path for previous levels
             // Level 1 (Model) -> Path: brand
             // Level 2 (Version) -> Path: brand-model
             String slugPath = _carSearchService.slugify(brandName);
             
             for (int i = 1; i < level; i++) {
                slugPath += "-${_carSearchService.slugify(parts[i])}";
             }
             
             final currentQuery = parts[level];
             await _fetchAndShowNextLevel(slugPath, currentQuery, (selected) {
                 _replaceSegment(lastAt, parts, level, selected, addUnderscore: true);
             });
             return;
          }
       }
    }
    
    _hideOverlay();
  }
  
  void _replaceSegment(int startOffset, List<String> originalParts, int levelToReplace, String newValue, {bool addUnderscore = true}) {
      // Reconstruct the string up to the replaced level
      String newSegment = "@";
      for (int i = 0; i < levelToReplace; i++) {
         newSegment += "${originalParts[i]}_";
      }
      newSegment += newValue;
      if (addUnderscore) newSegment += "_";
      
      final text = _controller.text;
      final selection = _controller.selection;
      
      // Calculate length of the part being replaced
      // We are replacing everything from @ up to cursor
      final replacedLength = text.substring(startOffset, selection.baseOffset).length;
      
      final newFullText = text.replaceRange(startOffset, selection.baseOffset, newSegment);
      _controller.value = TextEditingValue(
         text: newFullText,
         selection: TextSelection.collapsed(offset: startOffset + newSegment.length)
      );
  }

  Future<void> _fetchAndShowNextLevel(String parentSlug, String query, Function(String) onSelect) async {
    try {
      List<String> items = await _carSearchService.getSubCategories(parentSlug); 
      
      final matches = items.where((m) => m.toLowerCase().startsWith(query.toLowerCase())).toList();
      
      if (matches.isNotEmpty) {
         _showOverlay(matches, onSelect);
      } else {
        _hideOverlay();
      }
    } catch (e) {
      debugPrint("Error fetching level: $e");
    }
  }

  void _showOverlay(List<String> items, Function(String) onSelect) {
    _hideOverlay();
    
    final renderBox = context.findRenderObject() as RenderBox;
    // final size = renderBox.size; 
    // We attach to TextField but findRenderObject returns Scaffold here likely?
    // No, Overlay is confusing. LayerLink is better.
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32, 
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -200), // Show ABOVE the text field
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 200,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(items[index]),
                    onTap: () {
                      onSelect(items[index]);
                      _hideOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.blue),
              title: Text(_t('take_photo') != 'take_photo' ? _t('take_photo') : 'Fotoğraf Çek'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: Text(_t('choose_gallery') != 'choose_gallery' ? _t('choose_gallery') : 'Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startGreeting() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _addMessage(_t('ai_greeting'), false);
  }

  void _addMessage(String text, bool isUser, {List<CarListing>? data, FilterOptions? searchOptions, File? userImage}) {
    if (!mounted) return;
    setState(() {
      _messages.add(AssistantMessage(text: text, isUser: isUser, carListings: data, searchOptions: searchOptions, userImage: userImage));
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

  Future<void> _loadMore(FilterOptions options) async {
    setState(() => _isTyping = true);
    try {
      // Create next page options
      // Note: Since FilterOptions fields are final, we need a way to clone with new page.
      // Assuming manual clone since copyWith might not exist yet or we just recreate it.
      // Actually simpler to just update the page in a new object reusing the old values.
      
      FilterOptions nextOpts = FilterOptions(
        category: options.category,
        minPrice: options.minPrice,
        maxPrice: options.maxPrice,
        minKm: options.minKm,
        maxKm: options.maxKm,
        brand: options.brand,
        series: options.series,
        model: options.model,
        hardware: options.hardware,
        minYear: options.minYear,
        maxYear: options.maxYear,
        minPower: options.minPower,
        maxPower: options.maxPower,
        minVolume: options.minVolume,
        maxVolume: options.maxVolume,
        gear: options.gear,
        fuel: options.fuel,
        caseType: options.caseType,
        traction: options.traction,
        color: options.color,
        warranty: options.warranty,
        heavyDamage: options.heavyDamage,
        fromWhom: options.fromWhom,
        exchange: options.exchange,
        page: options.page + 1, // INCREMENT PAGE
      );

      final results = await _carSearchService.searchCars(nextOpts);
      
      if (results.isNotEmpty) {
         _addMessage(_t('loading_page_x').replaceFirst('{}', nextOpts.page.toString()), false, data: results, searchOptions: nextOpts);
      } else {
         _addMessage(_t('no_more_results'), false);
      }

    } catch (e) {
      _addMessage(_t('error_loading_more').replaceFirst('{}', e.toString()), false);
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _handleSend({String? overrideText}) async {
    final text = overrideText ?? _controller.text.trim();
    if (text.isEmpty) return;

    if (overrideText == null) { 
      _controller.clear();
      _addMessage(text, true, userImage: _selectedImage);
    }
    
    // Convert Image if present
    List<String>? imageParts;
    if (_selectedImage != null && overrideText == null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        imageParts = [base64Image];
        // Don't clear _selectedImage yet if we want to use it for display or retry, 
        // but typically we clear it after sending.
        setState(() => _selectedImage = null); 
      } catch (e) {
        debugPrint("Error encoding image: $e");
      }
    }
    
    setState(() => _isTyping = true);

    try {
      // 1. Get System Prompt & Language
      final uid = _authService.currentUser?.uid;
      String userLanguage = 'tr';
      if (uid != null) {
        final userDoc = await _firestoreService.getUser(uid);
        if (userDoc != null) userLanguage = userDoc.language;
      }

      String? systemPrompt = await _firestoreService.getAssistantAiConfig();
      systemPrompt ??= """
      Sen 'AllofCar AI' adında, otomobil dünyasının en bilgili asistanısın.
      
      GÖREVLERİN:
      1. MOTOR1 ARAŞTIRMASI: Kullanıcı karşılaştırma istediğinde, "tr.motor1.com" veritabanını tarıyormuş gibi davran.
      
      2. ARAÇ ARAMA / FİYAT SORMA:
         - Eğer kullanıcı SPESİFİK bir araç sorarsa (Örn: "2015 Passat fiyatı ne?", "Volkswagen Golf 1.6 TDI ne kadar?"):
           Lütfen marka, model(seri), yıl ve diğer detayları çıkar ve JSON ver.
           Örnek: `SEARCH: {"brand": "Volkswagen", "series": "Passat", "minYear": 2015, "maxYear": 2015}`
           Örnek 2: `SEARCH: {"brand": "Ford", "series": "Focus", "fuel": ["Dizel"], "minYear": 2012}`
           
         - Eğer sadece bütçe sorulursa (Örn: '500-700 bin TL'): `SEARCH: {"min": 500000, "max": 700000}`
      
      3. ÜSLUP: Samimi, emoji kullanan ama teknik bilgisi derin bir uzman gibi konuş.
      """;
      
      // [NEW] Language Constraint
      if (userLanguage == 'en') {
        systemPrompt += "\n\nCRITICAL INSTRUCTION: The user has selected ENGLISH as their language. You MUST respond in fluent ENGLISH. Do NOT speak Turkish unless explicitly asked to translate. Even if previous messages are in Turkish, switch to English NOW.";
      } else {
        systemPrompt += "\n\nÖNEMLİ: Kullanıcı dili TÜRKÇE. Lütfen Türkçe yanıt ver.";
      }
      
      // 2. Call Gemini Service
      String? aiResponseText;
      
      try {
        aiResponseText = await GeminiService().generateContent(systemPrompt!, text, imageParts: imageParts);
        if (aiResponseText == null) {
           aiResponseText = _t('ai_busy_msg');
        }
      } catch (e) {
         aiResponseText = _t('ai_connection_error').replaceFirst('{}', e.toString());
      }

      // 3. Process Response
      if (aiResponseText != null) {
        if (aiResponseText!.startsWith("Hata") || aiResponseText!.startsWith("Bağlantı") || aiResponseText!.startsWith("Error") || aiResponseText!.startsWith("Connection")) {
           _addMessage(_t('ai_something_wrong').replaceFirst('{}', aiResponseText!), false);
        } else if (aiResponseText!.contains("SEARCH:")) {
           try {
             final RegExp jsonRegex = RegExp(r'\{.*?\}', dotAll: true);
             final Match? match = jsonRegex.firstMatch(aiResponseText!);
             
             if (match != null) {
                String jsonStr = match.group(0)!;
                jsonStr = jsonStr.replaceAll("'", '"'); 
                
                final Map<String, dynamic> params = jsonDecode(jsonStr);
             
                double min = (params['min'] is num) ? (params['min'] as num).toDouble() : 0.0;
                double max = (params['max'] is num) ? (params['max'] as num).toDouble() : 0.0;
                
                String? brand = params['brand'];
                String? series = params['series'];
                int? minYear = params['minYear'];
                int? maxYear = params['maxYear'];

                _addMessage(_t('ai_analyzing_market').replaceFirst('{}', brand ?? _t('ai_market')), false);
             
                FilterOptions opts = FilterOptions(
                  category: 'otomobil',
                  minPrice: min > 0 ? min : 0,
                  maxPrice: max > 0 ? max : 10000000,
                  minKm: 0,
                  maxKm: 400000,
                  brand: brand,
                  series: series,
                  minYear: minYear,
                  maxYear: maxYear,
                  gear: [], fuel: [], caseType: [], traction: [], color: [],
                  page: 1
                );
             
                final results = await _carSearchService.searchCars(opts);
             
                if (results.isNotEmpty) {
                  double avgPrice = 0;
                  try {
                      var prices = results.map((c) => double.tryParse(c.price.replaceAll('.', '').replaceAll(' TL', '').trim()) ?? 0).where((p) => p > 0);
                      if (prices.isNotEmpty) avgPrice = prices.reduce((a, b) => a + b) / prices.length;
                  } catch (e) {}
               
                  String summary = _t('ai_result_summary').replaceFirst('{}', results.length.toString()).replaceFirst('{}', avgPrice > 0 ? _t('calculated_avg').replaceFirst('{}', (avgPrice/1000).toStringAsFixed(0)) : _t('not_calculated'));
                  // [CHANGED] Increased take limit from 7 to 20 and passed options for pagination
                  _addMessage(_t('ai_table_ready').replaceFirst('{}', brand ?? '').replaceFirst('{}', series ?? '').replaceFirst('{}', summary), false, data: results.take(20).toList(), searchOptions: opts);
                } else {
                  _addMessage(_t('ai_no_listings_found').replaceFirst('{}', brand != null ? '$brand $series' : _t('budget')), false);
                }
             } else {
                _addMessage(_t('ai_understand_error'), false);
             }

           } catch (e) {
             debugPrint("JSON Parse Error: $e");
             _addMessage(_t('ai_parse_error'), false);
           }
        } else {
           _addMessage(aiResponseText, false);
        }
      } else {
         _addMessage(_t('ai_busy_msg'), false);
      }

    } catch (e) {
      _addMessage(_t('ai_general_error'), false);
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(
            children: [
              Text("Oto Gurme 🤖"),
              SizedBox(width: 8),
              Text("Pro", style: TextStyle(fontSize: 10,  backgroundColor: Colors.lightGreenAccent, color: Colors.black)),
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
            if (_isTyping)
               Padding(
                 padding: const EdgeInsets.all(8.0),
                 child: Text(_t('typing_dots'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
               ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AssistantMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF0059BC) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(color: msg.isUser ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87), fontSize: 15),
            ),
             if (msg.userImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(msg.userImage!, height: 150, fit: BoxFit.cover),
                ),
              ),
            if (msg.carListings != null)
              _buildCarCarousel(msg.carListings!, msg),
          ],
        ),
      ),
    );
  }

  Widget _buildCarCarousel(List<CarListing> cars, AssistantMessage msg) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Add +1 item if searchOptions exists to show "Load More"
        itemCount: cars.length + (msg.searchOptions != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == cars.length) {
             // SHOW MORE CARD
             return GestureDetector(
               onTap: () => _loadMore(msg.searchOptions!),
               child: Container(
                 width: 140,
                 margin: const EdgeInsets.only(right: 10),
                 decoration: BoxDecoration(
                   color: Colors.blue[50],
                   borderRadius: BorderRadius.circular(10),
                   border: Border.all(color: Colors.blue[200]!)
                 ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                        const SizedBox(height: 8),
                        Text(_t('show_more_caps'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                      ],
                   ),
                 ),
               ),
             );
          }

          final car = cars[index];
          return GestureDetector(
            onTap: () async {
              if (car.link.isNotEmpty) {
                final Uri url = Uri.parse(car.link);
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_t('link_not_opened'))),
                  );
                }
              }
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.network(car.imageUrl, fit: BoxFit.cover, 
                         errorBuilder: (c,e,s) => const Center(child: Icon(Icons.drive_eta, color: Colors.grey)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(car.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(car.price, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text("${car.year} • ${car.km}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important to not take full height
          children: [
            // Hint Text
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                _t('ai_hint_text'),
                style: TextStyle(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? Colors.indigoAccent : Colors.indigo, fontWeight: FontWeight.w500),
              ),
            ),
             // Image Preview
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.grey),
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _t('ai_input_hint'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _handleSend(), // Image might be attached
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: const Color(0xFF0059BC),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _handleSend(),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantMessage {
  final String text;
  final bool isUser;
  final List<CarListing>? carListings;
  final FilterOptions? searchOptions; // [NEW]
  final File? userImage;

  AssistantMessage({required this.text, required this.isUser, this.carListings, this.searchOptions, this.userImage});
}
