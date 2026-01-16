import '../widgets/brand_logo.dart';
import '../services/comparison_scraper_service.dart';
import '../widgets/arabalar_car_selector.dart';
import '../widgets/comparison_car_selector.dart';
import '../widgets/fuel_price_widget.dart'; // [NEW]
import '../widgets/tire_brand_item.dart'; // [NEW]
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../chatbot_button.dart';
import '../services/car_search_service.dart';
import 'profile_screen.dart';
import '../services/firestore_service.dart'; // [NEW]
import '../services/auth_service.dart'; // [NEW]
import 'package:firebase_auth/firebase_auth.dart' as auth; // [NEW] For auth.User type
import 'support_screen.dart'; // [NEW]
import '../models/user_model.dart'; // [NEW]
import 'fault_detection_screen.dart';
import 'car_companies_screen.dart';
import 'car_finder_screen.dart';
import '../widgets/detailed_car_selector.dart';
import '../services/ai_service.dart';
import 'comparison_result_screen.dart';
import '../services/enhanced_comparison_service.dart';
import '../models/car_comparison.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/car_data.dart';
import '../services/car_selection_state.dart';
import '../services/car_selection_state.dart';
import 'ai_assistant_screen.dart';
import 'maintenance_assistant_screen.dart';
import '../services/theme_service.dart'; // [FIX] Added missing import
import 'forum_screen.dart';
import '../widgets/zero_km_car_selector.dart';
import '../data/brand_data.dart';
import 'brand_grid_screen.dart';
import 'settings_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  late int _selectedIndex; // Current page index
  
  // Karşılaştırma verileri
  String? selectedCar1;
  String? selectedCar2;
  
  // Store raw brand for logo display
  String? selectedBrand1;
  String? selectedBrand2;

  // Store Model Years
  int? selectedYear1;
  int? selectedYear2;

  // [NEW] Store Prices
  String? selectedPrice1;
  String? selectedPrice2;
  
  // [NEW] Comparison IDs (for Scraper)
  String? _comparisonId1;
  String? _comparisonId2;

  final List<String> _availableBrands = CarSearchService.brandLogos.keys.toList()..sort();
  // late final List<Widget> _pages;

  // [NEW] Comparison Mode
  bool _isNewCar = false;
  bool _isLoading = false;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Restore state
    final state = CarSelectionState();
    selectedCar1 = state.selectedCar1;
    selectedCar2 = state.selectedCar2;
    selectedBrand1 = state.selectedBrand1;
    selectedBrand2 = state.selectedBrand2;
    selectedYear1 = state.selectedYear1;
    selectedYear2 = state.selectedYear2;
    _isNewCar = state.isNewCar;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper to switch pages
  int _getPageIndexFromNavIndex(int navIndex) {
    if (navIndex < 2) return navIndex;
    if (navIndex == 2) return 2; // Default to Forum Posts
    return navIndex + 1; // Skip News page for Finder/Profile
  }

  int _getNavIndexFromPageIndex(int pageIndex) {
    if (pageIndex < 2) return pageIndex;
    if (pageIndex == 2 || pageIndex == 3) return 2; // Both Forum and News map to Forum Tab
    return pageIndex - 1;
  }

  void _onItemTapped(int navIndex) {
    int targetPageIndex = _getPageIndexFromNavIndex(navIndex);
    setState(() {
      _selectedIndex = targetPageIndex;
    });
    _pageController.jumpToPage(targetPageIndex);
  }

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  void _openAiAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: AiAssistantScreen(),
        ),
      ),
    );
  }

  void _openCarSelector(int slotNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        if (_isNewCar) {
          // [EXISTING] ZERO KM SELECTOR (Restored)
          return ZeroKmCarSelector(
            onSelectionComplete: (brand, model, version, price, photos, specs) {
              setState(() {
                String fullName = "$brand $model $version".trim();
                // Store standard selection for global state
                if (slotNumber == 1) {
                  selectedCar1 = fullName;
                  selectedBrand1 = brand;
                  selectedPrice1 = price; 
                  // Reset comparison ID for zero km (uses AI)
                  _comparisonId1 = null; 
                } else {
                  selectedCar2 = fullName;
                  selectedBrand2 = brand;
                  selectedPrice2 = price;
                  _comparisonId2 = null;
                }
                
                // Sync to Global State (preserving existing logic)
                final state = CarSelectionState();
                state.isNewCar = true;
                // [FIX] Correct property names: selectedBrand1 instead of brand1, remove model1 (not in state)
                if (slotNumber == 1) { state.selectedBrand1 = brand; state.selectedCar1 = selectedCar1; }
                else { state.selectedBrand2 = brand; state.selectedCar2 = selectedCar2; }

                // UI updates automatically via setState

              });
            },
          );
        } else {
          // [NEW] ARABALAR.COM.TR SELECTOR (For 2nd Hand)
          return ArabalarCarSelector(
            onSelectionComplete: (brand, model, year, version, versionId) {
              setState(() {
                // Format: "Volkswagen Passat 2009 1.6 FSI"
                String fullName = "$brand $model $year $version".trim();
                
                if (slotNumber == 1) {
                  selectedCar1 = fullName;
                  selectedBrand1 = brand;
                  selectedYear1 = int.tryParse(year);
                  _comparisonId1 = versionId; // Capture ID for comparison
                } else {
                  selectedCar2 = fullName;
                  selectedBrand2 = brand;
                  selectedYear2 = int.tryParse(year);
                  _comparisonId2 = versionId; // Capture ID for comparison
                }

                // Sync to Global State
                final state = CarSelectionState();
                state.isNewCar = false;
                // [FIX] Correct property names
                if (slotNumber == 1) { state.selectedBrand1 = brand; state.selectedCar1 = selectedCar1; state.selectedYear1 = selectedYear1; }
                else { state.selectedBrand2 = brand; state.selectedCar2 = selectedCar2; state.selectedYear2 = selectedYear2; }
                
                // UI updates automatically via setState

              });
            },
          );
        }
      },
    );
  }

  Future<void> _startComparison() async {
    if (selectedCar1 == null || selectedCar2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen iki araç seçiniz."))
      );
      return;
    }

    // Safety check for 2nd hand mode
    if (!_isNewCar && (_comparisonId1 == null || _comparisonId2 == null)) {
       // This might happen if they switched modes without re-selecting
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen araçları yeniden seçiniz (Seçim tipi değişti)."))
       );
       return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      CarComparison result;
      
      
      if (_isNewCar) {
        // [OLD LOGIC] AI Service for Zero KM
        final aiService = AiService();
        result = await aiService.compareCars(
          selectedCar1!, 
          selectedCar2!,
          price1: selectedPrice1,
          price2: selectedPrice2
        );
      } else {
        // [ENHANCED LOGIC] Scraper + AI for 2nd Hand
        final enhancedService = EnhancedComparisonService();
        result = await enhancedService.compare(
           _comparisonId1!, 
           _comparisonId2!,
           selectedCar1!,
           selectedCar2!
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComparisonResultScreen(
              car1Name: selectedCar1!,
              car2Name: selectedCar2!,
              comparisonData: result,
              isNewCarMode: _isNewCar,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    // 1. Conditional StreamBuilder Wrapper
    if (currentUser != null) {
      // [FIX] Listen to Auth State Changes
      return StreamBuilder<auth.User?>(
        stream: _authService.authStateChanges,
        builder: (context, authSnapshot) {
          final currentUser = authSnapshot.data;
          
          if (currentUser != null) {
            // Authenticated User -> Listen to User Document for Ban Status
            return StreamBuilder<User?>(
              stream: _firestoreService.getUserStream(currentUser.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData) {
                   final user = userSnapshot.data!;
                   if (user.isBanned) {
                     // Check for Expiration
                     // Check for Expiration
                     // Fix: Use UTC to ensure consistency
                     if (user.banExpiration != null && DateTime.now().toUtc().isAfter(user.banExpiration!.toUtc())) {
                        // Expired -> trigger unban and allow access (Optimistic)
                        _firestoreService.setBanStatus(currentUser.uid, false);
                        return _buildMainScaffold();
                     }
                     
                     // Active Ban -> Show Support Screen
                     return SupportScreen(banExpiration: user.banExpiration); // [BANNED MODE]
                   }
                }
                // User data loading or not banned -> Show App
                return _buildMainScaffold();
              },
            );
          }
          
          // Guest -> Show App
          return _buildMainScaffold(); 
        },
      );
    }

    return _buildMainScaffold();
  }

  Widget _buildMainScaffold() {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // If not on Home tab, go to Home tab
        if (_selectedIndex != 0) {
          _onItemTapped(0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        floatingActionButton: (_selectedIndex == 2 || _selectedIndex == 3) 
          ? null // Hide AI FAB on Forum & News (Forum has its own FAB)
          : Padding(
              padding: const EdgeInsets.only(bottom: 70.0), // Raise the FAB slightly
              child: FloatingActionButton(
                heroTag: 'home_ai_fab',
                onPressed: _openAiAssistant,
                backgroundColor: Theme.of(context).cardColor,
                child: const Text("🤖", style: TextStyle(fontSize: 28)),
              ),
            ),
        body: Stack(
          children: [
            // Content
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(), // Smooth IOS style scrolling
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                children: [
                  _buildHomeContent(),
                  _buildComparisonPage(),
                  ForumTimelineScreen(
                    onTabSwitch: (index) {
                      // index 0 -> Posts (Page 2), index 1 -> News (Page 3)
                      final targetPage = index == 0 ? 2 : 3;
                      _pageController.jumpToPage(targetPage);
                    },
                  ),
                  ForumNewsScreen(
                    onTabSwitch: (index) {
                      final targetPage = index == 0 ? 2 : 3;
                      _pageController.jumpToPage(targetPage);
                    },
                  ),
                  const CarFinderScreen(),
                  const ProfileScreen(),
                ],
              ),
            ),
            
            // Floating Navigation Bar
            ValueListenableBuilder<String>(
              valueListenable: ThemeService().navBarStyleNotifier,
              builder: (context, navStyle, _) {
                final isFloating = navStyle == 'floating';
                return Positioned(
                  left: isFloating ? 20 : 0,
                  right: isFloating ? 20 : 0,
                  bottom: isFloating ? 25 : 0,
                  child: _buildModernBottomNav(),
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  // --- ANA SAYFA İÇERİĞİ ---
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 25),

          _buildCarComparisonSection(isSimple: true), // Updated internal method to handle theme

          _buildNavCard(
            context,
            _t('fault_detection_title'),
            _t('fault_detection_subtitle'),
            Icons.car_crash,
            Colors.redAccent,
            const FaultDetectionScreen(),
          ),

          const SizedBox(height: 15),

          _buildNavCard(
             context,
             _t('maintenance_assistant_title'),
             _t('maintenance_assistant_subtitle'),
             Icons.build_circle,
             Colors.orange,
             const MaintenanceAssistantScreen(),
          ),

          _buildHorizontalBrandList(
            title: _t('vehicle_brands'),
            brands: ["BMW", "Mercedes", "Audi", "Tesla", "Toyota", "Honda", "Fiat", "Ford"],
            forceWhiteBackground: true, // [FIX] Keep white background for non-transparent JPGs
            onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CarCompaniesScreen()),
              );
            },
            logoGetter: (brand) => CarData.getLogoUrl(brand),
            urlGetter: (brand) => CarData.brandUrls[brand],
          ),

          const SizedBox(height: 20),

          _buildTireBrandList(
            title: _t('tire_brands'),
            brands: BrandData.tyreBrands,
            onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BrandGridScreen(
                    title: "Lastik Markaları",
                    brands: BrandData.tyreBrands,
                    logoGetter: (brand) => BrandData.getLogoUrl(brand),
                    urlGetter: (brand) => BrandData.tyreBrandUrls[brand],
                  ),
                ),
              );
            },
            logoGetter: (brand) => BrandData.getLogoUrl(brand),
            urlGetter: (brand) => BrandData.tyreBrandUrls[brand],
          ),

          const SizedBox(height: 20),

          _buildHorizontalBrandList(
            title: _t('oil_brands'),
            brands: BrandData.oilBrands,
            onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BrandGridScreen(
                    title: "Madeni Yağ Markaları",
                    brands: BrandData.oilBrands,
                    logoGetter: (brand) => BrandData.getLogoUrl(brand),
                    urlGetter: (brand) => BrandData.oilBrandUrls[brand],
                  ),
                ),
              );
            },
            logoGetter: (brand) => BrandData.getLogoUrl(brand),
            urlGetter: (brand) => BrandData.oilBrandUrls[brand],
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // --- KARŞILAŞTIRMA SAYFASI (YENİ TASARIM - MAVİ BAŞLIKLI) ---
  Widget _buildComparisonPage() {
    return Column(
      children: [
        // 1. MAVİ ÜST BAŞLIK ALANI
        Container(
          width: double.infinity,
          height: 180, // Yükseklik
          decoration: const BoxDecoration(
            color: Color(0xFF0059BC),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 60), // Status bar boşluğu
            child: Column(
              children: [
                Text(
                  _t('car_compare_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _t('compare_desc'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        // 2. İÇERİK (Kutular biraz yukarı kaysın diye Transform kullanıyoruz)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Kutuyu mavi alanın üzerine hafifçe bindiriyoruz (-40 offset)
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: _buildCarComparisonSection(isSimple: false),
                ),

                const SizedBox(height: 20),
                const Icon(Icons.compare, size: 80, color: Colors.grey),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _t('select_cars_prompt'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- HEADER ---
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20), // Increased bottom padding
      decoration: const BoxDecoration(
        color: Color(0xFF0059BC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      "${_t('welcome')},", 
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "AllofCar",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28, // Increased slightly for visual weight
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t('compare_dream'), 
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // [RESTORED] Fuel Price Widget
              const FuelPriceWidget(), 
              const SizedBox(width: 8), 
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarComparisonSection({required bool isSimple}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark) BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isSimple) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('car_compare_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0059BC),
                  ),
                ),
                Icon(Icons.garage_outlined, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 20),
          ],
          
          if (!isSimple) ...[
             // [NEW] TOGGLE SWITCH FOR NEW / USED
             Container(
               margin: const EdgeInsets.only(bottom: 20),
               width: 240,
               padding: const EdgeInsets.all(4),
               decoration: BoxDecoration(
                 color: isDark ? Colors.grey[800] : Colors.grey.shade200,
                 borderRadius: BorderRadius.circular(30),
               ),
               child: Row(
                 children: [
                   Expanded(child: _buildToggleItem(_t('second_hand_short'), !_isNewCar, () {
                     setState(() {
                        _isNewCar = false;
                        CarSelectionState().isNewCar = false;
                     });
                   })),
                   Expanded(child: _buildToggleItem(_t('zero_km_short'), _isNewCar, () {
                     setState(() {
                        _isNewCar = true;
                        CarSelectionState().isNewCar = true;
                     });
                   })),
                 ],
               ),
             ),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
            children: [
              // Car 1 Selection
              Expanded(
                child: Column(
                  children: [
                    _buildCarSelectBox(1, selectedCar1, selectedBrand1, selectedYear1),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  "VS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Car 2 Selection
              Expanded(
                child: Column(
                  children: [
                    _buildCarSelectBox(2, selectedCar2, selectedBrand2, selectedYear2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // ... (Button remains same)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startComparison, // Use new handler
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0059BC),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: const Color(0xFF0059BC).withOpacity(0.4),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : Text(
                    _t('btn_compare'),
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String text, bool isActive, VoidCallback onTap) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity, // Take all space provided by Expanded
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? (isDark ? Colors.grey[700] : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isActive ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
          ),
          child: Text(
            text, 
            textAlign: TextAlign.center, // Center text
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isActive ? (isDark ? Colors.white : const Color(0xFF0059BC)) : Colors.grey,
              fontSize: 14,
            )
          ),
        ),
      );
  }

  Widget _buildCarSelectBox(int slot, String? currentSelection, String? brandState, int? year) {
    bool isSelected = currentSelection != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
        onTap: () => _openCarSelector(slot),
        child: AspectRatio( // This was causing overflow if inside a Column without flex constraints
          aspectRatio: 1, // Keep aspect ratio but ensure parent constraints

          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? Colors.grey[800] : Colors.white)
                  : (isDark ? Colors.grey[900] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0059BC)
                    : (isDark ? Colors.grey[800]! : Colors.grey.shade300),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                 BoxShadow(color: const Color(0xFF0059BC).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
              ] : [],
            ),
            padding: const EdgeInsets.all(4), // Reduced padding to prevent overflow
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected && brandState != null && CarSearchService.brandLogos.containsKey(brandState))
                   Padding(
                     padding: const EdgeInsets.only(bottom: 2.0), // Reduced from 5
                     child: BrandLogo(
                       logoUrl: CarSearchService.brandLogos[brandState]!, 
                       size: 30, // Reduced from 40 to 30
                     ),
                   )
                else 
                   Icon(
                     isSelected ? Icons.check_circle : Icons.add_circle_outline,
                     color: isSelected ? const Color(0xFF0059BC) : Colors.grey,
                     size: 26, // Reduced from 28
                   ),
                   
                const SizedBox(height: 2), // Reduced from 4
                
                Flexible( // Wrap text
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSelected ? currentSelection! : _t('select_vehicle'),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.black87 : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12, // Reduced from 13
                        ),
                      ),
                      if (year != null && !_isNewCar)
                         Text(
                           "($year)",
                           style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 11), // Reduced from 12
                         ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildNavCard(BuildContext context, String title, String subtitle, IconData icon, Color iconColor, Widget page) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return GestureDetector(
       onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (context) => page));
       },
       child: Container(
         width: double.infinity,
         margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: Theme.of(context).cardColor,
           borderRadius: BorderRadius.circular(20),
           boxShadow: [
             if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
           ],
         ),
         child: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: iconColor.withOpacity(0.1),
                 shape: BoxShape.circle,
               ),
               child: Icon(icon, color: iconColor, size: 28),
             ),
             const SizedBox(width: 15),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                   const SizedBox(height: 4),
                   Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                 ],
               ),
             ),
             const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
           ],
         ),
       ),
     );
  }

  Widget _buildHorizontalBrandList({
    required String title,
    required List<String> brands,
    required VoidCallback onSeeAll,
    required String Function(String) logoGetter,
    required String? Function(String) urlGetter,
    bool forceWhiteBackground = false, // [NEW] Force white bg for non-transparent logos
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: Text(_t('see_all'), style: const TextStyle(color: Color(0xFF0059BC))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brand = brands[index];
              return Padding(
                padding: const EdgeInsets.only(right: 15),
                child: GestureDetector(
                  onTap: () {
                     final url = urlGetter(brand);
                     if (url != null) {
                       launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                     }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // If forceWhiteBackground is true, always white. Else respect theme.
                          color: (forceWhiteBackground || !isDark) ? Colors.white : Colors.grey[800],
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (!isDark || forceWhiteBackground) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                          border: (isDark && !forceWhiteBackground) ? Border.all(color: Colors.grey[700]!) : Border.all(color: Colors.grey.shade100),
                        ),
                        child: BrandLogo(logoUrl: logoGetter(brand), size: 40),
                      ),
                      const SizedBox(height: 5),
                      Text(brand, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTireBrandList({
    required String title,
    required List<String> brands,
    required VoidCallback onSeeAll,
    required String Function(String) logoGetter,
    required String? Function(String) urlGetter,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: Text(_t('see_all'), style: const TextStyle(color: Color(0xFF0059BC))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brand = brands[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8), // Reduced spacing from 15
                child: TireBrandItem(
                  brandName: brand,
                  logoUrl: logoGetter(brand),
                  onTap: () {
                     final url = urlGetter(brand);
                     if (url != null) {
                       launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                     }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernBottomNav() {
    // Hide nav bar if keyboard is visible
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<String>(
      valueListenable: ThemeService().navBarThemeNotifier,
      builder: (context, navTheme, _) {
        return ValueListenableBuilder<String>(
          valueListenable: ThemeService().navBarStyleNotifier,
          builder: (context, navStyle, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final isBlueTheme = navTheme == 'blue';
            final isFloating = navStyle == 'floating';

        // Define nav items
        final List<Map<String, dynamic>> navItems = [
          {'icon': Icons.home_rounded, 'label': _t('tab_home'), 'index': 0},
          {'icon': Icons.compare_arrows_rounded, 'label': _t('tab_compare'), 'index': 1},
          {'icon': Icons.forum_rounded, 'label': _t('tab_forum'), 'index': 2},
          {'icon': Icons.search_rounded, 'label': _t('tab_finder'), 'index': 3},
          {'icon': Icons.person_rounded, 'label': _t('tab_profile'), 'index': 4},
        ];

        return Container(
          padding: isFloating 
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12) 
              : EdgeInsets.only(
                  left: 20, 
                  right: 20, 
                  top: 10, 
                  bottom: MediaQuery.of(context).padding.bottom
                ), // Classic: Top 16, Bottom 16 + Safe Area
          margin: EdgeInsets.zero, 
          decoration: BoxDecoration(
            color: isBlueTheme 
                ? const Color(0xFF0059BC).withOpacity(isFloating ? 0.95 : 1.0) 
                : (isDark ? const Color(0xFF1E1E1E).withOpacity(isFloating ? 0.9 : 1.0) : Colors.white.withOpacity(isFloating ? 0.9 : 1.0)),
            borderRadius: isFloating 
                ? BorderRadius.circular(30) 
                : const BorderRadius.vertical(top: Radius.circular(0)), // Zero radius for classic
            boxShadow: [
              BoxShadow(
                color: isBlueTheme 
                    ? const Color(0xFF0059BC).withOpacity(0.3) 
                    : Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: (isBlueTheme || !isFloating)
                ? null 
                : Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
                    width: 0.5,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: navItems.map((item) {
              final int navItemIndex = item['index'];
              final bool isSelected = _getNavIndexFromPageIndex(_selectedIndex) == navItemIndex;
              
              // Determine colors based on theme and selection
              Color selectedBgColor;
              Color selectedContentColor;
              Color unselectedIconColor;

              if (isBlueTheme) {
                selectedBgColor = Colors.white;
                selectedContentColor = const Color(0xFF0059BC);
                unselectedIconColor = Colors.white.withOpacity(0.6);
              } else {
                selectedBgColor = const Color(0xFF0059BC);
                selectedContentColor = Colors.white;
                unselectedIconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
              }
              
              return GestureDetector(
                onTap: () => _onItemTapped(navItemIndex),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 8, 
                    vertical: 8
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? selectedBgColor 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'],
                        color: isSelected 
                            ? selectedContentColor 
                            : unselectedIconColor,
                        size: 24,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            item['label'],
                            style: TextStyle(
                              color: selectedContentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
          }
        );
      }
    );
  }
}
