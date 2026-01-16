import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Resim seçme paketi
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../models/car_model.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'fault_history_screen.dart'; // Import for detail screen navigation
import '../utils/app_localizations.dart';
import '../services/language_service.dart';
import '../widgets/detailed_car_selector.dart';

class FaultDetectionScreen extends StatefulWidget {
  const FaultDetectionScreen({super.key});

  @override
  State<FaultDetectionScreen> createState() => _FaultDetectionScreenState();
}

class _FaultDetectionScreenState extends State<FaultDetectionScreen> {
  final TextEditingController _problemController = TextEditingController();
  File? _selectedImage;
  String _aiResult = "";
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // --- API KEY BURAYA ---
  // --- API KEY REMOVED (Handled by GeminiService) ---
  // final String _apiKey = '...'; 

  // Garaj verisi için

  // Garaj verisi için
  // Garaj verisi için
  final FirestoreService _firestoreService = FirestoreService();
  Car? _selectedCar; // Seçilen araç (null ise 'Garaj Dışı')
  List<Car> _garageCars = []; // Garajdaki araçlar listesi
  bool _isGarageEmpty = false; // Garaj boş mu kontrolü
  
  // Manuel Araç Girişi İçin
  final TextEditingController _manualBrandController = TextEditingController();
  final TextEditingController _manualModelController = TextEditingController();
  final TextEditingController _manualKmController = TextEditingController();

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  void initState() {
    super.initState();
    _loadGarageCars();
  }

  @override
  void dispose() {
    _problemController.dispose();
    _manualBrandController.dispose();
    _manualModelController.dispose();
    _manualKmController.dispose();
    super.dispose();
  }

  // Kullanıcının garajındaki araçları çek
  Future<void> _loadGarageCars() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final cars = await _firestoreService.getGarage(user.uid).first;
        if (mounted) {
          setState(() {
            _garageCars = cars;
            _isGarageEmpty = cars.isEmpty;
            // Eğer garajda araç varsa ilkini seç, yoksa null (Garaj Dışı) kalsın
            if (_garageCars.isNotEmpty) {
              _selectedCar = _garageCars.first;
            } else {
              _selectedCar = null;
            }
          });
        }
      } catch (e) {
        debugPrint("Garaj yüklenirken hata: $e");
      }
    }
  }

  // Medyadan Resim Seçme (Galeri veya Kamera)
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(_t('take_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(_t('pick_gallery')),
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

  // Modern Car Selection Modal
  void _showCarSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Text(
                _t('select_vehicle'), 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)
              ),
              const SizedBox(height: 20),
              
              // Garage Cars
              if (_garageCars.isNotEmpty)
                ..._garageCars.map((car) => _buildCarSelectionItem(
                  icon: Icons.directions_car_filled,
                  title: "${car.brand} ${car.model}",
                  subtitle: "${car.plate} • ${car.currentKm} KM",
                  isSelected: _selectedCar == car,
                  color: const Color(0xFF0059BC),
                  onTap: () {
                    setState(() => _selectedCar = car);
                    Navigator.pop(context);
                  },
                )),

              // Divider
              if (_garageCars.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.grey[200]),
                ),

              // Outside Garage with Detailed Selector
              _buildCarSelectionItem(
                icon: Icons.edit_road,
                title: "Garaj Dışı / Farklı Araç",
                subtitle: "Listeden araç seçimi yapın",
                isSelected: _selectedCar != null && _selectedCar!.id == null, // Temp car has no ID
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context); // Close selection modal first
                  _openDetailedSelector();
                },
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  void _openDetailedSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DetailedCarSelector(
        isYearSelectionEnabled: true,
        onSelectionComplete: (brand, series, model, hardware, year) {
           // On selection, ask for KM
           Future.delayed(const Duration(milliseconds: 300), () {
             _showKmInputDialog(brand, series, model, hardware, year);
           });
        },
      ),
    );
  }

  void _showKmInputDialog(String brand, String series, String model, String hardware, int? year) {
    TextEditingController kmController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Kilometre Bilgisi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$brand $series $model aracınızın güncel kilometresini giriniz:"),
            const SizedBox(height: 10),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Örn: 120000",
                border: OutlineInputBorder(),
                suffixText: "KM",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (kmController.text.isNotEmpty) {
                int km = int.tryParse(kmController.text) ?? 0;
                // Create Temp Car
                Car tempCar = Car(
                  id: null, // Indicates temporary/outside garage
                  name: "$brand $series $model",
                  brand: brand,
                  model: "$series $model",
                  hardware: hardware,
                  modelYear: year,
                  currentKm: km,
                  nextMaintenanceKm: 0,
                  history: [],
                );
                
                setState(() {
                  _selectedCar = tempCar;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0059BC), foregroundColor: Colors.white),
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  Widget _buildCarSelectionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected ? color : Colors.grey.shade100,
              radius: 20,
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
               Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  // Yapay Zeka Analizi
  Future<void> _analyzeFault() async {
    final text = _problemController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('please_enter_issue')),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _aiResult = "";
    });

    try {
      final List<Map<String, dynamic>> parts = [];
      String contextInfo = "";

      // 1. BAĞLAM OLUŞTURMA
      if (_selectedCar != null) {
        // --- GARAJ ARACI SEÇİLDİ ---
        final car = _selectedCar!;
        contextInfo += "SEÇİLEN ARAÇ (GARAJ):\n";
        contextInfo += "Marka/Model: ${car.brand ?? 'Bilinmiyor'} ${car.model ?? ''} (${car.modelYear ?? 'Yıl Yok'})\n";
        contextInfo += "Paket/Motor: ${car.hardware ?? 'Belirtilmemiş'}\n";
        contextInfo += "Kilometre: ${car.currentKm} KM\n";
        contextInfo += "Yakıt: ${car.expertiseReport['Yakıt Tipi'] ?? 'Bilinmiyor'}\n";
        
        // EKLENEN: DETAYLI EKSPERTİZ RAPORU
        if (car.expertiseReport.isNotEmpty) {
           contextInfo += "EKSPERTİZ / KAZA DURUMU:\n";
           car.expertiseReport.forEach((key, value) {
             // Yakıt tipini zaten ekledik, onu tekrar etmeyelim
             if (key != 'Yakıt Tipi' && key != 'date') {
                contextInfo += " - $key: $value\n";
             }
           });
           contextInfo += "(Not: Boyalı veya değişen parçalar, sensör veya montaj hatalarına işaret edebilir. Bunu analizinde göz önünde bulundur.)\n";
        }

        // Bakım Durumu
        int kmDiff = car.nextMaintenanceKm - car.currentKm;
        if (kmDiff < 0) {
          contextInfo += "BAKIM DURUMU: !!! BAKIM GECİKMİŞ !!! (${-kmDiff} KM)\n";
        } else {
          contextInfo += "BAKIM DURUMU: Bakıma $kmDiff KM var\n";
        }

        // Bakım Geçmişi (Son 3)
        if (car.history.isNotEmpty) {
           contextInfo += "BAKIM GEÇMİŞİ:\n";
           final recentHistory = car.history.reversed.take(3);
           for (var rec in recentHistory) {
              final type = rec['type'] ?? 'Bakım';
              final notes = rec['notes'] ?? '';
              contextInfo += " * $type: $notes\n";
           }
        }
        contextInfo += "\n";

      } else {
        // --- GARAJ DIŞI SEÇİLDİ ---
        String brand = _manualBrandController.text.trim();
        String model = _manualModelController.text.trim();
        String km = _manualKmController.text.trim();
        
        contextInfo += "SEÇİLEN ARAÇ (GARAJ DIŞI / MANUEL):\n";
        if (brand.isNotEmpty || model.isNotEmpty) {
           contextInfo += "Marka/Model: $brand $model\n";
        } else {
           contextInfo += "Kullanıcı araç markası belirtmedi.\n";
        }
        
        if (km.isNotEmpty) {
           contextInfo += "Kilometre: $km KM\n";
        }
        contextInfo += "\n";
      }

      contextInfo += "GÖREV: Kullanıcı bir sorun bildirdi. Yukarıdaki araç bilgilerini dikkate alarak analiz yap.\n\n";

      // 2. Prompt Hazırlığı
      String? dynamicSystemPrompt = await _firestoreService.getAiConfig();
      String promptText = dynamicSystemPrompt ?? """
Sen 'Haynes Repair Manuals' standartlarına hakim, aynı zamanda Türkiye'deki 'Şikayetvar', 'DonanımHaber Otomobil Forumları' ve 'Otomacerası.com' gibi platformlardaki kullanıcı deneyimlerini çok iyi bilen profesyonel bir araç tamir ustasısın.
GÖREVİN: Kullanıcının belirttiği sorunu, araç modelini ve kilometresini analiz ederek nokta atışı tespitler yapmak.
- EĞER bir gösterge paneli işareti sorulursa: 'acamar.com.tr' üzerindeki ikaz lambaları anlamlarını baz al.
- Kronik sorunları (örn: Ford Powershift şanzıman, VW DSG titreme, Fiat Egea yağ yakma) mutlaka belirt.
- Çözüm önerilerin "Sanayiye git" demek yerine, "Önce bujileri kontrol et, sonra bobine bak" gibi teknik ve yönlendirici olsun.
""";
      
      if (_selectedImage != null) {
        promptText += "Ekli fotoğraftaki sorunu analiz et. ";
      }
      if (text.isNotEmpty) {
        promptText += "Kullanıcı sorunu: '$text'. ";

        // [NEW] Özel Kaynak Talimatı
        if (text.contains("Gösterge panelindeki") || text.toLowerCase().contains("arıza ışığı") || text.toLowerCase().contains("uyarı lambası")) {
             promptText += "\n\nÖZEL TALİMAT: 1. Bu analizde 'https://www.acamar.com.tr/blog/arac-uyari-isiklari-ve-anlamlari' kaynağını referans alarak görseldeki işaretin ne olduğunu ve o sitedeki teknik anlamını belirle.\n";
             promptText += "2. ANCAK SADECE BU KAYNAĞA BAĞLI KALMA. Yukarıda verilen 'SEÇİLEN ARAÇ' bilgilerini (Kilometre, Bakım Geçmişi, Ekspertiz Raporu) de mutlaka analizine dahil et.\n";
             promptText += "3. Örneğin: İşaret 'Motor Arızası' ise ve araçta 'Bakım Gecikmiş' bilgisi varsa, bu ikisi arasındaki ilişkiyi kurarak yorumla.\n";
        }
      }
      
      if (!promptText.contains("GÖREVLERİN")) {
          promptText += "\n\nGÖREVLERİN:\n";
          promptText += "1. Olası nedenleri sırala.\n";
          promptText += "2. Pratik çözüm önerileri sun.\n";
          promptText += "3. Kronik sorun olup olmadığını belirt.\n";
      }

      // 3. Gemini Service Call & Image Upload
      List<String>? imageParts;
      String? uploadedImageUrl;

      // Start Image Upload (Parallel if possible, but sequential here for simplicity)
      if (_selectedImage != null) {
        // Prepare for Gemini
        final bytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        imageParts = [base64Image];
        
        // Upload to Storage
        if (FirebaseAuth.instance.currentUser != null) {
           debugPrint("Starting image upload...");
           uploadedImageUrl = await _firestoreService.uploadImage(_selectedImage!, 'fault_images');
           debugPrint("Upload Result URL: $uploadedImageUrl");
        } else {
           debugPrint("User not logged in, skipping upload.");
        }
      } else {
        debugPrint("No image selected for upload.");
      }

      final result = await GeminiService().generateContent(
        promptText, 
        contextInfo, 
        imageParts: imageParts
      );

      if (result != null) {
        setState(() => _aiResult = result);
        
         // --- LOGGING ---
        final user = FirebaseAuth.instance.currentUser;
        String? logId;

        if (user != null) {
           String carNameLog = "";
           if (_selectedCar != null) {
             carNameLog = "${_selectedCar!.brand} ${_selectedCar!.model}";
           } else {
             // Manuel veri
             String b = _manualBrandController.text.trim();
             String m = _manualModelController.text.trim();
             if (b.isNotEmpty || m.isNotEmpty) {
               carNameLog = "$b $m (Harici)";
             } else {
               carNameLog = "Genel / Belirtilmedi";
             }
            }

            logId = await _firestoreService.addFaultLog(user.uid, {
              'problem': text,
              'aiResponse': result,
              'carName': carNameLog,
              'carId': _selectedCar?.id, // Null if manual
              'hasImage': _selectedImage != null,
              'imageUrl': uploadedImageUrl, // SAVE URL
            });
         }
         
         // [NEW] Navigate directly to Detail Screen with result
         if (mounted) {
           Navigator.push(
             context,
             MaterialPageRoute(
               builder: (_) => FaultDetailScreen(
                 log: {
                   'id': logId,
                   'carName': _selectedCar != null ? "${_selectedCar!.brand} ${_selectedCar!.model}" : "Genel / Manuel",
                   'problem': text,
                   'aiResponse': result,
                   'timestamp': Timestamp.now(),
                 },
                 localImage: _selectedImage, // Pass local file!
               ),
             ),
           );
         }

      } else {
        setState(() => _aiResult = _t('analysis_failed'));
      }

    } catch (e) {
      setState(() => _aiResult = "Hata: $e");
    } finally {
      setState(() => _isLoading = false);
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_t('fault_detection_title'), style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF0059BC),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. ARAÇ SEÇİMİ (YENİ TASARIM) ---
            GestureDetector(
              onTap: _showCarSelectionModal,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                  border: Border.all(color: const Color(0xFF0059BC).withOpacity(0.15), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0059BC).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car, color: Color(0xFF0059BC), size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCar != null 
                              ? "${_selectedCar!.brand} ${_selectedCar!.model}" 
                              : (_t('vehicle_details_opt').contains("Manuel") ? "Harici Araç / Manuel Giriş" : "Araç Seçiniz"),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (_selectedCar != null)
                             Text(
                               "${_selectedCar!.plate} • ${_selectedCar!.currentKm} km",
                               style: TextStyle(color: Colors.grey[600], fontSize: 13),
                             )
                          else
                             Text(
                               _t('tap_to_select_car'),
                               style: TextStyle(color: Colors.grey[500], fontSize: 13),
                             ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // --- 2. MANUEL GİRİŞ FORMU REMOVED ---


            // Bilgi Kutusu
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF0059BC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0059BC).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.build_circle, color: Color(0xFF0059BC), size: 30),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _t('fault_input_hint'),
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30), // Increased spacing for better separation

            // --- DASHBOARD SEÇİCİ (YENİ) ---
            Row(
              children: [
                const Icon(Icons.dashboard_customize, color: Color(0xFF0059BC)),
                const SizedBox(width: 10),
                Text(
                   _t('dashboard_panel'),
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Tooltip / Instruction
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 20, color: Colors.orange.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "İşareti seçmek için ekrana basılı tutun ve parmağınızı sürükleyin.",
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              // height: 300, // REMOVE FIXED HEIGHT
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black, // Dark frame
              ),
              child: DashboardSelector(
                onSelectionConfirmed: (File croppedImage) {
                  setState(() {
                    _selectedImage = croppedImage;
                    _problemController.text = _t('dashboard_query_text');
                  });
                  // Otomatik analiz başlatılabilir veya kullanıcı "Analiz" butonuna basabilir.
                  // _analyzeFault(); // Removed auto-analysis
                },
              ),
            ),
            const SizedBox(height: 20),


            // Fotoğraf Yükleme
            GestureDetector(
              onTap: _showImageSourceActionSheet,
              child: Container(
                height: 100, // Reduced height since we have dashboard now
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey),
                ),
                child: _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_selectedImage!, fit: BoxFit.contain),
                          ),
                          Positioned(
                            right: 5,
                            top: 5,
                            child: InkWell(
                              onTap: () => setState(() => _selectedImage = null),
                              child: CircleAvatar(
                                backgroundColor: Colors.grey.shade700,
                                radius: 12,
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 30, color: Colors.grey),
                          SizedBox(width: 10),
                          Text(
                            _t('upload_own_photo'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Sorun Yazma
            TextField(
              controller: _problemController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _t('problem_hint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Analiz Butonu
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeFault,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search, color: Colors.white),
              label: Text(
                _isLoading ? _t('analyzing') : _t('detect_fault_btn'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0059BC),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 30),

            // SONUÇ
            if (_aiResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('master_view'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const Divider(),
                    Text(_aiResult, style: const TextStyle(fontSize: 15, height: 1.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}

class DashboardSelector extends StatefulWidget {
  final Function(File) onSelectionConfirmed;

  const DashboardSelector({super.key, required this.onSelectionConfirmed});

  @override
  State<DashboardSelector> createState() => _DashboardSelectorState();
}

class _DashboardSelectorState extends State<DashboardSelector> {
  Offset? _tapPosition;
  bool _isInteracting = false; 
  final double _spotlightRadius = 15.0; // Reduced radius further for single icon precision
  final double _magnifierScale = 2.5; 
  final double _magnifierRadius = 60.0; // Slightly larger lens
  
  ui.Image? _fullImage;
  final GlobalKey _imageKey = GlobalKey();

  String _t(String key) => AppLocalizations.get(key, LanguageService().currentLanguage);

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/images/dashboard_full.jpg');
    final list = Uint8List.view(data.buffer);
    final codec = await ui.instantiateImageCodec(list);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _fullImage = frame.image;
      });
    }
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
      _isInteracting = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
      _isInteracting = true;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isInteracting = false;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
      _isInteracting = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isInteracting = false;
    });
  }

  Future<void> _processSelection() async {
    if (_tapPosition == null || _fullImage == null) return;
    
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      
      final Size widgetSize = renderBox.size;
      final double scaleX = _fullImage!.width / widgetSize.width;
      final double scaleY = _fullImage!.height / widgetSize.height;
      
      // Calculate crop rect in source image coordinates
      final double realX = _tapPosition!.dx * scaleX;
      final double realY = _tapPosition!.dy * scaleY;

      // Crop matches the visual spotlight radius exactly
      // User requested "halka alanı" size (15.0 scaled)
      final double cropRadius = _spotlightRadius * scaleX; 
      
      final Rect srcRect = Rect.fromCenter(
        center: Offset(realX, realY), 
        width: cropRadius * 2, 
        height: cropRadius * 2
      );
      
      final Rect destRect = Rect.fromLTWH(0, 0, cropRadius * 2, cropRadius * 2);
      
      canvas.drawImageRect(_fullImage!, srcRect, destRect, Paint());
      
      final picture = recorder.endRecording();
      final int size = (cropRadius * 2).ceil();
      if (size <= 0) return;

      final img = await picture.toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'dashboard_crop_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');
        
        await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
        debugPrint("Cropped image saved to: ${file.path}, Size: ${await file.length()} bytes");
        
        widget.onSelectionConfirmed(file);
      } else {
        debugPrint("ByteData is null.");
      }
    } catch (e) {
      debugPrint("Crop error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fullImage == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF0059BC))),
      );
    }

    final double aspectRatio = _fullImage!.width.toDouble() / _fullImage!.height.toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = width / aspectRatio;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Grayscale Base (Clipped to Box)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.saturation),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                          child: Image.asset(
                            'assets/images/dashboard_full.jpg',
                            key: _imageKey,
                            width: width,
                            height: height,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),

                    // 2. Spotlight Layer (Only Visual)
                    if (_tapPosition != null)
                      Positioned(
                        left: _tapPosition!.dx - _spotlightRadius,
                        top: _tapPosition!.dy - _spotlightRadius,
                        width: _spotlightRadius * 2,
                        height: _spotlightRadius * 2,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orangeAccent.withOpacity(0.6),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Clipped Icon
                            ClipOval(
                              child: OverflowBox(
                                maxWidth: width,
                                maxHeight: height,
                                minWidth: width,
                                minHeight: height,
                                alignment: Alignment.topLeft,
                                child: Transform.translate(
                                  offset: Offset(
                                    -(_tapPosition!.dx - _spotlightRadius),
                                    -(_tapPosition!.dy - _spotlightRadius),
                                  ),
                                  child: Image.asset(
                                    'assets/images/dashboard_full.jpg',
                                    width: width,
                                    height: height,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 3. MAGNIFIER LENS
                      if (_tapPosition != null && _isInteracting)
                        Positioned(
                          left: _tapPosition!.dx - _magnifierRadius,
                          top: _tapPosition!.dy - _magnifierRadius * 2.5, // Even higher
                          width: _magnifierRadius * 2,
                          height: _magnifierRadius * 2,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
                              ],
                              color: Colors.black,
                            ),
                            child: ClipOval(
                              child: CustomPaint(
                                painter: _MagnifierPainter(
                                  image: _fullImage!,
                                  position: _tapPosition!,
                                  scale: _magnifierScale,
                                  widgetSize: Size(width, height), // Pass current size
                                ),
                              ),
                            ),
                          ),
                        ),

                    // Hint Text
                    if (_tapPosition == null)
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            "${_t('find_icon_hint')} 🔎",
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 14, 
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Query Button (Moved Outside)
            if (_tapPosition != null && !_isInteracting) ...[
              const SizedBox(height: 16), // Spacing
              FloatingActionButton.extended(
                onPressed: _processSelection,
                label: Text(_t('query_btn')),
                icon: const Icon(Icons.auto_awesome),
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black87,
              ),
            ]
          ],
        );
      },
    );
  }
}

class _MagnifierPainter extends CustomPainter {
  final ui.Image image;
  final Offset position;
  final double scale;
  final Size widgetSize;

  _MagnifierPainter({
    required this.image,
    required this.position,
    required this.scale,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image transformed to provide zoom at position
    // Center of this canvas is (size.width/2, size.height/2)
    
    // 1. Calculate source rectangle from image based on position
    final double srcScaleX = image.width / widgetSize.width;
    final double srcScaleY = image.height / widgetSize.height;
    
    final double centerX = position.dx * srcScaleX;
    final double centerY = position.dy * srcScaleY;
    
    // We want to show an area that is size / scale
    final double srcWidth = size.width / scale * srcScaleX; // Width in source px
    final double srcHeight = size.height / scale * srcScaleY;
    
    final Rect srcRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: srcWidth,
      height: srcHeight,
    );
    
    final Rect destRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    canvas.drawImageRect(image, srcRect, destRect, Paint());
    
    // Crosshair
    final Paint paint = Paint()
      ..color = const Color(0xFF0059BC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 3, paint);
  }

  @override
  bool shouldRepaint(covariant _MagnifierPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.widgetSize != widgetSize;
  }
}
