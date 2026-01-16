import 'dart:convert'; // [NEW] Base64 Decode
import 'package:allofcar/data/car_data.dart';
import '../utils/app_localizations.dart';
import 'package:allofcar/screens/car_details_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/material.dart' as material; // Removed

import '../models/car_model.dart'; // Yeni model dosyası
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/car_expertise_widget.dart';
import '../widgets/detailed_car_selector.dart';
import '../widgets/zero_km_car_selector.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure font access if needed, or just default
import '../widgets/turkish_license_plate.dart'; 
import 'fault_history_screen.dart';
import '../widgets/paged_car_card.dart';
import '../widgets/photo_carousel.dart';
import 'gallery_screen.dart';
import '../data/oil_catalog.dart';
import '../data/brand_data.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

// Global Helper
String _t(String key) {
  return AppLocalizations.get(key, LanguageService().currentLanguage);
}

class GarageScreen extends StatefulWidget {
  final int initialIndex;
  final bool isReadOnly; // [NEW] Read-Only Mode

  final bool showAddCarOnLoad; // [NEW] Araç ekleme diyaloğu ile aç
  const GarageScreen({super.key, this.initialIndex = 0, this.isReadOnly = false, this.showAddCarOnLoad = false});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  // Localization Helper
  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  // Date Helper
  String _formatDate(dynamic date) {
    if (date == null) return "Bilinmiyor";
    if (date is Timestamp) {
      DateTime dt = date.toDate();
      return "${dt.day}.${dt.month}.${dt.year}";
    }
    if (date is DateTime) {
      return "${date.day}.${date.month}.${date.year}";
    }
    return date.toString();
  }

  late PageController _pageController;
  late int _currentCarIndex;

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  String? get uid => _authService.currentUser?.uid;

  late Stream<List<Car>> _garageStream;

  @override
  void initState() {
    super.initState();
    _currentCarIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    if (uid != null) {
      _garageStream = _firestoreService.getGarage(uid!);
    } else {
      _garageStream = const Stream.empty();
    }

    // [NEW] Check if we should open Add Car Dialog
    if (widget.showAddCarOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddCarDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Giriş yapmalısınız.")));
    }

    return StreamBuilder<List<Car>>(
      stream: _garageStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_t('my_garage'), style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF0059BC),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(child: Text("Hata: ${snapshot.error}")),
          );
        }

        List<Car> myCars = snapshot.data ?? [];

        if (myCars.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_t('my_garage'), style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF0059BC),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.no_crash, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(_t('empty_garage'), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showAddCarDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(_t('add_new_car'), style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0059BC)),
                  ),
                ],
              ),
            ),
          );
        }

        if (_currentCarIndex >= myCars.length) {
          _currentCarIndex = 0;
        }

        Car activeCar = myCars[_currentCarIndex];

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. SCROLLABLE BLUE HEADER
              Stack(
                clipBehavior: Clip.none,
                children: [
                // 0. SPACER TO FORCE STACK HEIGHT (Fixes overlapping issue)
                SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.28 + 360,
                ),

                // 1. BLUE HEADER BACKGROUND
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0059BC), Color(0xFF004499)],
                      ),
                    ),
                  ),
                ),

                // 2. PAGEVIEW (Dynamic Background + Card)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.85,
                  child: PageView.builder(
                    key: const PageStorageKey('garage_page_view'),
                    controller: _pageController,
                    itemCount: myCars.length,
                    onPageChanged: (index) => setState(() => _currentCarIndex = index),
                    itemBuilder: (context, index) {
                      Car car = myCars[index];
                      bool hasPhoto = car.photos.isNotEmpty;

                      return Stack(
                        children: [
// Add imports at top (I will assume I can't easily add imports with `replace_file_content` if not targeting top, so I will rely on manual addition or smart replace if range allows. 
// Actually I viewed lines 1-250, so I can replace lines 18-208 to include imports? No, that's too much.
// I will just replace content inside `itemBuilder` and add imports separately or assume I can add them if I target line 18 area too? No, tool allows contiguous edit. 
// I'll do two edits if needed, or one big one.
// Let's do the content replacement first. The imports might be needed for it to compile.
// I will target `lines 160-207` roughly.

                          // A. BACKGROUND VISUAL WITH CAROUSEL
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: MediaQuery.of(context).size.height * 0.4, // Cover header area
                            child: PhotoCarousel(
                              photos: car.photos,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GalleryScreen(
                                      car: car,
                                      onUpdate: () => setState(() {}), // Refresh UI on return
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // B. CAR CARD
                          Positioned(
                            top: MediaQuery.of(context).size.height * 0.28,
                            left: 0,
                            right: 0,
                            child: SizedBox(
                              height: 320, // Standardized height
                              child: PagedCarCard(
                                car: car,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => CarDetailsScreen(car: car)),
                                  );
                                },
                                onDelete: widget.isReadOnly ? null : () => _deleteCarDialog(car),
                                onEditKm: widget.isReadOnly ? null : () {
                                  debugPrint("DEBUG: KM Tap Reached GarageScreen");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_t('km_edit_mode_msg')), duration: const Duration(milliseconds: 500)),
                                  );
                                  _updateKmDialog(car);
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 3. TITLE ROW (Overlay on top)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('my_garage'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                                ),
                              ),
                              Text(
                                "${_t('cars_label')}: ${myCars.length}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 30, color: Colors.white),
                            onPressed: _showAddCarDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. DELETE BUTTON
                Positioned(
                   top: MediaQuery.of(context).size.height * 0.28 - 25,
                   right: 25, 
                   child: InkWell(
                       onTap: () => _deleteCarDialog(activeCar),
                       child: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.25),
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
                       ),
                     ),
                  ),
                ],
              ),

              const SizedBox(height: 20), // Small padding before indicators

              // 3. PAGE INDICATORS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(myCars.length, (idx) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentCarIndex == idx ? const Color(0xFF0059BC) : Colors.grey[300],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 25),

              // 4. DETAILS SECTION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildInspectionStatus(activeCar),
                    const SizedBox(height: 25),
                    _buildMaintenanceStatus(activeCar),
                    const SizedBox(height: 25),

                    _buildMaintenanceHistorySummaryCard(activeCar), // [NEW] Summary Card
                    const SizedBox(height: 25),
                    _buildExpertiseStatus(activeCar),
                    const SizedBox(height: 25),
                    _buildFaultHistoryStatus(activeCar),
                    const SizedBox(height: 25),

                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'garage_add_maintenance_fab',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddMaintenanceScreen(car: activeCar)),
              );
              if (result != null && uid != null) {
                  int km = int.tryParse(result['km']?.toString() ?? '0') ?? 0;
                DateTime date = DateTime.now();
                if (result['date'] != null) {
                  try {
                    List<String> parts = result['date'].split('/');
                    if (parts.length == 3) {
                      date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                    }
                  } catch (e) {
                    debugPrint("Date parse error: $e");
                  }
                }
                if (km > activeCar.currentKm) {
                  await _firestoreService.updateCarKm(uid!, activeCar.id!, km);
                }
                try {
                  await _firestoreService.addMaintenance(uid!, activeCar.id!, result, km, date, true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('new_maintenance_added'))));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
                  }
                }
              }
            },
            backgroundColor: const Color(0xFF0059BC),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }


  Widget _buildMaintenanceStatus(Car activeCar) {
    // Bakım Yüzdesi Hesaplama
    double progress = activeCar.currentKm / activeCar.nextMaintenanceKm;
    if (progress > 1.0) progress = 1.0;
    int remainingKm = activeCar.nextMaintenanceKm - activeCar.currentKm;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${activeCar.brand ?? _t('car_default')} ${_t('maintenance_status')}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.build_circle_outlined, color: Color(0xFF0059BC), size: 22),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('next_maintenance'), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              Text(
                "${activeCar.nextMaintenanceKm} KM",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
              color: remainingKm < 1000 ? Colors.red : const Color(0xFF0059BC),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remainingKm > 0
                ? _t('maintenance_remaining_msg').replaceAll('{km}', remainingKm.toString())
                : _t('maintenance_time_warning'),
            style: TextStyle(
              color: remainingKm < 1000 ? Colors.red : Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('next_maintenance_date')),
              GestureDetector(
                onTap: () => _pickMaintenanceDate(activeCar),
                child: Row(
                  children: [
                    if (activeCar.nextMaintenanceDate != null &&
                        activeCar.nextMaintenanceDate!.isBefore(DateTime.now()))
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(Icons.warning, color: Colors.red, size: 16),
                      ),
                    Text(
                      activeCar.nextMaintenanceDate != null
                          ? "${activeCar.nextMaintenanceDate!.day}/${activeCar.nextMaintenanceDate!.month}/${activeCar.nextMaintenanceDate!.year}"
                          : _t('set_date'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (activeCar.nextMaintenanceDate != null &&
                                activeCar.nextMaintenanceDate!.isBefore(DateTime.now()))
                            ? Colors.red
                            : const Color(0xFF0059BC),
                        decoration: activeCar.nextMaintenanceDate == null
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- GEÇMİŞ ARIZA ANALİZLERİ (ARAÇ BAZLI) ---
  Widget _buildFaultHistoryStatus(Car car) {
    if (uid == null || car.id == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getFaultLogsForCar(uid!, car.id!),
      builder: (context, snapshot) {
        // Just show a summary card, not the full list
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.length;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isDark) BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.shade100),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FaultHistoryScreen(carId: car.id)),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.health_and_safety, color: Colors.redAccent, size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('past_fault_analyses'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            count > 0 ? "$count ${_t('records_available')}" : _t('no_records_yet'),
                            style: TextStyle(
                              color: count > 0 ? Colors.grey[700] : Colors.grey[400],
                              fontSize: 13,
                              fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // [NEW] BAKIM GEÇMİŞİ ÖZET KARTI
  Widget _buildMaintenanceHistorySummaryCard(Car car) {
    Map<String, dynamic>? lastRecord;
    if (car.history.isNotEmpty) {
      lastRecord = car.history.last;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark) BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMaintenanceHistoryDialog(car),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('maintenance_history'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_t('last_maintenance'), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    Text(
                      lastRecord != null 
                          ? "${_formatDate(lastRecord['date'])} - ${lastRecord['km']} KM"
                          : _t('no_records'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // [NEW] BAKIM GEÇMİŞİ LİSTE DIALOGU
  void _showMaintenanceHistoryDialog(Car car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : const Color(0xFFF5F7FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Header
             Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0,2))]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('maintenance_history'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blueGrey),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                           // Yeni bakım ekleme ekranına git
                           // Önce dialogu kapat
                           Navigator.pop(sheetContext);
                           
                           // Ekleme ekranını aç - Modal Bottom Sheet olarak
                           final result = await showModalBottomSheet(
                             context: context,
                             isScrollControlled: true,
                             backgroundColor: Colors.transparent,
                             builder: (context) => AddMaintenanceScreen(car: car, isSheet: true),
                           );

                           if (result != null && result is Map<String, dynamic>) {
                               final dateStr = result['date'];
                               final kmStr = result['km'];
                               
                               // Parse KM
                               int km = 0;
                               try {
                                 km = int.parse(kmStr.toString().replaceAll(RegExp(r'[^0-9]'), ''));
                               } catch (e) {
                                 debugPrint("KM Parse Error: $e");
                               }
                               
                               // Parse Date
                               DateTime date = DateTime.now();
                               try {
                                  final parts = dateStr.toString().split('/');
                                  if (parts.length == 3) {
                                      date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                                  }
                               } catch (e) {
                                  debugPrint("Date Parse Error: $e");
                               }

                               if (uid != null && car.id != null) {
                                 // [VALIDATION] Cannot be lower than current KM
                                 if (km < car.currentKm) {
                                   if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (dialogContext) => Dialog(
                                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                                          surfaceTintColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(15),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                                                ),
                                                const SizedBox(height: 15),
                                                Text(
                                                  _t('odometer_error'),
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  _t('odometer_error_msg'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                                ),
                                                const SizedBox(height: 25),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(dialogContext); // Kapat
                                                        },
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: Colors.grey,
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                        ),
                                                        child: Text(_t('cancel')),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () async {
                                                          Navigator.pop(dialogContext); // Dialogu kapat
                                                          
                                                          // TEKRAR AÇ (Verilerle birlikte)
                                                          final retryResult = await showModalBottomSheet(
                                                             context: context,
                                                             isScrollControlled: true,
                                                             backgroundColor: Colors.transparent,
                                                             builder: (context) => AddMaintenanceScreen(car: car, isSheet: true, initialData: result),
                                                          );
                                                          
                                                          if (retryResult != null && retryResult is Map<String, dynamic>) {
                                                              // Parsing...
                                                              final rDateStr = retryResult['date'];
                                                              final rKmStr = retryResult['km'];
                                                              int rKm = int.tryParse(rKmStr.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                                              
                                                              DateTime rDate = DateTime.now();
                                                              try {
                                                                  final rParts = rDateStr.toString().split('/');
                                                                  if (rParts.length == 3) rDate = DateTime(int.parse(rParts[2]), int.parse(rParts[1]), int.parse(rParts[0]));
                                                              } catch (_) {}

                                                              // Validation Again
                                                              if (rKm < car.currentKm) {
                                                                 // Fail again - just show snackbar this time to avoid infinite loop complexity in this block
                                                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yine hatalı KM girdiniz! İşlem iptal edildi."), backgroundColor: Colors.red));
                                                                 return;
                                                              }

                                                              await _firestoreService.addMaintenance(uid!, car.id!, retryResult, rKm, rDate, true);
                                                              if (rKm > car.currentKm) await _firestoreService.updateCarKm(uid!, car.id!, rKm);
                                                              setState(() {});
                                                          }
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF0059BC),
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                        ),
                                                        child: Text(_t('edit')),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                   }
                                   return;
                                 }

                                 await _firestoreService.addMaintenance(uid!, car.id!, result, km, date, true);
                                 
                                 // [FIX] Update Car KM if higher
                                 if (km > car.currentKm) {
                                    await _firestoreService.updateCarKm(uid!, car.id!, km);
                                 }
                                 
                                 setState(() {}); // UI Update

                                }
                           }
                        },
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0059BC), size: 28),
                        tooltip: "Yeni Bakım Ekle",
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            // List
            Expanded(
              child: car.history.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 15),
                      Text(_t('no_records_yet'), style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: car.history.length,
                itemBuilder: (context, index) {
                   final reversedIndex = car.history.length - 1 - index;
                   final record = car.history[reversedIndex];
                   
                   return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0,4))],
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200),
                      ),
                      child: ListTile(
                        onTap: () => _showMaintenanceDetail(car, record),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.build, color: Color(0xFF0059BC)),
                        ),
                        title: Text(_getLocalizedAction(record['action']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text("${_formatDate(record['date'])} • ${record['km'] ?? 0} KM", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            if (record['parts']?.toString().isNotEmpty ?? false)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_getLocalizedParts(record['parts']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteMaintenanceDialog(car, record),
                        ),
                      ),
                   );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SİLME ONAY PENCERELERİ ---

  // Araç Silme Onayı
  void _deleteCarDialog(Car car) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_car_title')),
        content: Text(
          _t('delete_car_confirm').replaceAll('{car}', car.name ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              if (uid != null && car.id != null) {
                await _firestoreService.deleteCar(uid!, car.id!);
                // Silme sonrası index yönetimi StreamBuilder tarafından,
                // veya state'teki index sınır kontrolü tarafından halledilir.
              }
                if (context.mounted) {
                  Navigator.pop(context);
                }
            },
            child: Text(_t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Bakım Silme Onayı
  void _deleteMaintenanceDialog(Car car, Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_maintenance_title')),
        content: Text(_t('delete_maintenance_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              if (uid != null && car.id != null) {
                await _firestoreService.removeMaintenance(uid!, car.id!, record);
                
                // [NEW] Recalculate Logic
                // We need to fetch the car or assume the local car object is updated? 
                // removeMaintenance does NOT update the local 'car' object passed here immediately unless we wait for Stream.
                // However, we can simulate the removal locally to calculate correct next dates.
                
                // Create a temporary car object with removed record to calculate
                Car tempCar = car;
                tempCar.history.remove(record); // Updates local reference if mutable list
                await _recalculateMaintenanceSchedule(tempCar);
              }
                if (context.mounted) {
                  Navigator.pop(context);
                }
            },
            child: Text(_t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- DİĞER FONKSİYONLAR ---

  DateTime _parseDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    try {
      List<String> parts = dateStr.split('.');
      if (parts.length != 3) return DateTime.now();
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (e) {
      return DateTime.now();
    }
  }

  void _showAddCarDialog() {
    // 1. Ask for Car Type First
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Araç Türü Seçiniz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () { 
                      Navigator.pop(context); // Close selection
                      _openAddCarForm(isZeroKm: true); 
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Color(0xFF0059BC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFF0059BC)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.new_releases, color: Color(0xFF0059BC), size: 30),
                          const SizedBox(height: 5),
                          Text(_t('condition_zero_km'), style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: GestureDetector(
                    onTap: () { 
                      Navigator.pop(context); 
                      _openAddCarForm(isZeroKm: false); 
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, color: Colors.grey[700], size: 30),
                          const SizedBox(height: 5),
                          Text(_t('condition_second_hand'), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _openAddCarForm({required bool isZeroKm}) {
    TextEditingController kmController = TextEditingController(text: isZeroKm ? "0" : "0");
    TextEditingController nextKmController = TextEditingController();
    TextEditingController nextDateController = TextEditingController();

    DateTime ownershipDate = DateTime.now();
    DateTime trafficReleaseDate = DateTime.now(); // Defaults to now, but for 2nd hand usually past.

    // State Variables
    bool isOver3Years = false;
    bool isCommercial = false; // false = Binek, true = Ticari
    bool didMaintenanceOnPurchase = false;
    DateTime? lastInspectionDate;
    
    // Manual Maintenance Variables
    DateTime? lastMaintenanceDate;

    TextEditingController inspectionDateController = TextEditingController();
    TextEditingController lastInspectionKmController = TextEditingController();
    
    TextEditingController lastMaintenanceDateController = TextEditingController();
    TextEditingController lastMaintenanceKmController = TextEditingController();
    
    // [NEW] Plaka ve Model Yılı
    TextEditingController modelYearController = TextEditingController(text: isZeroKm ? DateTime.now().year.toString() : "");
    
    // [NEW] 3 Parçalı Plaka
    int selectedPlateCity = 34; // Default İstanbul
    TextEditingController plateLetters = TextEditingController();
    // plateNumbers removed -> replaced by 4 digit wheels
    int plateDigitCount = 4; // Default
    List<int> plateNumberDigits = [0, 0, 0, 0];
    
    // [NEW] Marka ve Model Ayrımı
    String? selectedBrand;
    String? selectedSeries; 
    String? selectedModel; 
    String? selectedHardware;
    
    // [NEW] Selected Zero KM Image URL
    String? selectedZeroKmImageUrl;
    List<String> selectedZeroKmPhotos = [];
    Map<String, String> selectedZeroKmSpecs = {};
    
    // UI Display String
    String carSelectionDisplay = "Araç Seçiniz";
    
    // Loading State
    bool isLoading = false;

    // Otomatik Hesaplama Fonksiyonu
    void updateCalculations() {
      int startKm = int.tryParse(kmController.text) ?? 0;
      int nextKm;
      DateTime nextDate;
      
      // 1. 3 Yaş Kontrolü (Otomatik)
      // 3 * 365 = 1095 gün
      isOver3Years = DateTime.now().difference(trafficReleaseDate).inDays > 1095;

      // 2. Yeni Araç Mı? (Trafiğe çıkış tarihi < 1 yıl ve KM < 10k)
      bool isNewCar = isZeroKm || (DateTime.now().difference(trafficReleaseDate).inDays < 365 && startKm < 10000);

      if (didMaintenanceOnPurchase) {
          // A: Satın alırken bakım yapıldı
          nextKm = startKm + 10000;
          nextDate = DateTime(ownershipDate.year + 1, ownershipDate.month, ownershipDate.day);
      } else if (lastMaintenanceDate != null) {
          // B: Manuel son bakım girildi
          int lastMaintKm = int.tryParse(lastMaintenanceKmController.text) ?? 0;
          nextKm = lastMaintKm + 10000;
          nextDate = DateTime(lastMaintenanceDate!.year + 1, lastMaintenanceDate!.month, lastMaintenanceDate!.day);
      } else if (isNewCar) {
        // C: Yeni araç
        nextKm = 10000; // First maintenance usually earlier or at 10k/15k depending on brand, simplifying to 10k for now
        nextDate = DateTime(trafficReleaseDate.year + 1, trafficReleaseDate.month, trafficReleaseDate.day);
      } else {
        // D: Varsayılan (Eski araç, bilgi yok)
        nextKm = startKm + 10000;
        nextDate = DateTime(ownershipDate.year + 1, ownershipDate.month, ownershipDate.day);
      }

      nextKmController.text = nextKm.toString();
      nextDateController.text = "${nextDate.day}.${nextDate.month}.${nextDate.year}";
    }
    
    // İlk açılışta hesapla
    updateCalculations();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            
            // Tarih seçici yardımcı fonksiyonu
            Future<void> selectDate(bool isOwnership) async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: isOwnership ? ownershipDate : trafficReleaseDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Theme.of(context).primaryColor, 
                          onPrimary: Colors.white, 
                          onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    if (isOwnership) {
                        ownershipDate = picked;
                    } else {
                        trafficReleaseDate = picked;
                    }
                    updateCalculations();
                  });
                }
            }
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F7FA), // Light greyish blue bg
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              // [FIX] Add keyboard padding
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  // --- HEADER ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0,2))]
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(
                          isZeroKm ? _t('add_new_zero_car') : _t('add_new_second_hand_car'),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blueGrey),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        )
                      ],
                    ),
                  ),

                  // --- FORM BODY ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          // SECTİON 1: ARAÇ BİLGİLERİ
                          Text(_t('car_info_label'), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white, borderRadius: BorderRadius.circular(15)),
                            child: Column(
                              children: [
                                // [NEW] DETAYLI ARAÇ SEÇİMİ BUTTON
                                GestureDetector(
                                  onTap: () {
                                     showModalBottomSheet(
                                       context: context,
                                       isScrollControlled: true,
                                       backgroundColor: Theme.of(context).cardColor,
                                       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                       builder: (context) {
                                         return Padding(
                                           padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                           
                                           child: isZeroKm 
                                            ? ZeroKmCarSelector(
                                                onSelectionComplete: (brand, model, version, price, photos, specs) {
                                                   setState(() {
                                                     selectedBrand = brand;
                                                     selectedSeries = ""; // ZeroKM doesnt separate series cleanly yet
                                                     selectedModel = model;
                                                     selectedHardware = version;
                                                     selectedZeroKmImageUrl = photos.isNotEmpty ? photos.first : null;
                                                     selectedZeroKmPhotos = photos; // Save all photos
                                                     selectedZeroKmSpecs = specs;   // Save specs
                                                     
                                                     carSelectionDisplay = "$brand $model\n$version".trim();
                                                     modelYearController.text = DateTime.now().year.toString();
                                                   });
                                                },
                                              )
                                            : DetailedCarSelector(
                                             onSelectionComplete: (brand, series, model, hardware, year) {
                                                setState(() {
                                                  selectedBrand = brand;
                                                  selectedSeries = series;
                                                  selectedModel = model;
                                                  selectedHardware = hardware;
                                                  
                                                  String fullModel = "$series $model".trim();
                                                  carSelectionDisplay = "$brand $fullModel\n$hardware ${year != null ? '($year)' : ''}".trim();
                                                  
                                                  // Optional: If there is a year field, we could auto-fill it.
                                                  if (year != null) {
                                                     modelYearController.text = year.toString();
                                                  }
                                                });
                                             },
                                           ),
                                         );
                                       }
                                     );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
                                    ),
                                    child: Row(
                                       children: [
                                         const Icon(Icons.directions_car_filled, color: Color(0xFF0059BC)),
                                         const SizedBox(width: 15),
                                         Expanded(
                                           child: Text(
                                             carSelectionDisplay,
                                             style: TextStyle(
                                               color: selectedBrand == null ? Colors.grey : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                               fontSize: 15,
                                               fontWeight: selectedBrand == null ? FontWeight.normal : FontWeight.w600
                                             ),
                                           ),
                                         ),
                                         const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                       ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),

                                // MODEL YILI
                                TextField(
                                  controller: modelYearController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: _t('input_model_year'),
                                    hintText: _t('input_model_year_hint'),
                                    prefixIcon: const Icon(Icons.calendar_today, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  ),
                                ),
                                const SizedBox(height: 15),

                                // GÜNCEL KM
                                TextField(
                                  controller: kmController,
                                  keyboardType: TextInputType.number,
                                  enabled: !isZeroKm, // Disable for Zero KM? Or allow correction? 
                                  // User might buying "0 KM" but drove it home 50km. Let's allow edit.
                                   decoration: InputDecoration(
                                    labelText: _t('input_current_km'),
                                    suffixText: "KM",
                                    prefixIcon: const Icon(Icons.speed, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  ),
                                  onChanged: (val) => updateCalculations(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),

                          // SECTİON 2: PLAKA BİLGİSİ
                          const Text("PLAKA", style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Container(
                             padding: const EdgeInsets.all(15),
                             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                             child: Column(
                               children: [
                                  // RAKAM SAYISI SEÇİCİ
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Text(_t('input_plate_type'), style: const TextStyle(color: Colors.grey)),
                                      ),
                                      ...[2, 3, 4].map((count) {
                                        bool isSelected = plateDigitCount == count;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              plateDigitCount = count;
                                              List<int> newDigits = List.filled(count, 0);
                                              for(int i=0; i<count && i<plateNumberDigits.length; i++) {
                                                newDigits[i] = plateNumberDigits[i];
                                              }
                                              plateNumberDigits = newDigits;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFF0059BC) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100]),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(_t('plate_digit_count').replaceAll('{count}', count.toString()), style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontSize: 12)),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  // PLAKA INPUT ALANI
                                  Row(
                                    children: [
                                      // 1. İL KODU
                                      GestureDetector(
                                        onTap: () {
                                           showModalBottomSheet(
                                             context: context,
                                             builder: (BuildContext context) {
                                               return SizedBox(
                                                 height: 250,
                                                 child: CupertinoPicker(
                                                   scrollController: FixedExtentScrollController(initialItem: selectedPlateCity - 1),
                                                   itemExtent: 32.0,
                                                   onSelectedItemChanged: (int index) {
                                                     setState(() {
                                                       selectedPlateCity = index + 1;
                                                     });
                                                   },
                                                   children: List<Widget>.generate(81, (int index) {
                                                     return Center(child: Text((index + 1).toString().padLeft(2, '0')));
                                                   }),
                                                 ),
                                               );
                                             },
                                           ).then((_) => setState((){}));
                                        },
                                        child: Container(
                                          width: 60,
                                          height: 55,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0059BC), // TR Mavi
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text("TR", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                              Text(
                                                selectedPlateCity.toString().padLeft(2, '0'),
                                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // 2. HARFLER
                                      Expanded(
                                        child: Container(
                                          height: 55,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: TextField(
                                              controller: plateLetters,
                                              textAlign: TextAlign.center,
                                              textCapitalization: TextCapitalization.characters,
                                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                hintText: "ABC",
                                                hintStyle: TextStyle(color: Colors.grey, fontSize: 24),
                                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                                              ),
                                          ),
                                        ),
                                      ),
                                      // 3. RAKAMLAR
                                      GestureDetector(
                                        onTap: () {
                                           showModalBottomSheet(
                                             context: context,
                                             builder: (BuildContext context) {
                                               return SizedBox(
                                                 height: 250,
                                                 child: Row(
                                                   children: List.generate(plateNumberDigits.length, (digitIndex) {
                                                      return Expanded(
                                                        child: CupertinoPicker(
                                                          scrollController: FixedExtentScrollController(initialItem: plateNumberDigits[digitIndex]),
                                                          itemExtent: 32.0,
                                                          onSelectedItemChanged: (int val) {
                                                            setState(() => plateNumberDigits[digitIndex] = val);
                                                          },
                                                          children: List.generate(10, (idx) => Center(child: Text("$idx"))),
                                                        ),
                                                      );
                                                   }),
                                                 ),
                                               );
                                             },
                                           ).then((_) => setState((){}));
                                        },
                                        child: Container(
                                          height: 55,
                                           padding: const EdgeInsets.symmetric(horizontal: 10),
                                           decoration: BoxDecoration(
                                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                           ),
                                           alignment: Alignment.center,
                                           child: Row(
                                             mainAxisSize: MainAxisSize.min,
                                             children: plateNumberDigits.map((digit) {
                                                return Text(
                                                  "$digit",
                                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                                                );
                                             }).toList(),
                                           ),
                                        ),
                                      ),
                                    ],
                                  ),
                               ],
                             ),
                          ),
                          const SizedBox(height: 25),

                          // SECTİON 3: TARİH VE BAKIM
                          Text(_t('input_date_history_label'), style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Container(
                             padding: const EdgeInsets.all(15),
                             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                             child: Column(
                               children: [
                                  // TARİHLER ROW
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => selectDate(false),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(_t('input_first_registration'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                const SizedBox(height: 4),
                                                Text("${trafficReleaseDate.day}.${trafficReleaseDate.month}.${trafficReleaseDate.year}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => selectDate(true),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(_t('input_ownership_date'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                const SizedBox(height: 4),
                                                Text("${ownershipDate.day}.${ownershipDate.month}.${ownershipDate.year}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  SwitchListTile(
                                title: Text(_t('input_commercial_vehicle')),
                                subtitle: Text(
                                  _t('input_commercial_subtitle'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                value: isCommercial,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (val) => setState(() => isCommercial = val),
                              ),
                              /*
                              CheckboxListTile(
                                title: Text(_t('input_maintenance_on_purchase')),
                                value: maintenanceOnPurchase,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (val) => setState(() => maintenanceOnPurchase = val ?? false),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              */  Divider(color: Colors.grey.shade200),
                                  
                                  // SATIN ALIRKEN BAKIM
                                  CheckboxListTile(
                                    title: Text(_t('input_maintenance_on_purchase')),
                                    value: didMaintenanceOnPurchase,
                                    activeColor: const Color(0xFF0059BC),
                                    onChanged: (val) {
                                      setState(() {
                                        didMaintenanceOnPurchase = val ?? false;
                                        if(didMaintenanceOnPurchase) {
                                            lastMaintenanceDate = null;
                                            lastMaintenanceDateController.clear();
                                            lastMaintenanceKmController.clear();
                                        }
                                        updateCalculations();
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ),

                                  // MANUEL BAKIM GİRİŞİ
                                  if (!didMaintenanceOnPurchase && !widget.isReadOnly) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_t('input_last_maintenance_if_exists'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () async {
                                                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                                                        if (picked != null) {
                                                          setState(() {
                                                            lastMaintenanceDate = picked;
                                                            lastMaintenanceDateController.text = "${picked.day}.${picked.month}.${picked.year}";
                                                            updateCalculations();
                                                          });
                                                        }
                                                    },
                                                    child: AbsorbPointer(
                                                      child: TextField(
                                                        controller: lastMaintenanceDateController,
                                                        decoration: InputDecoration(
                                                          labelText: _t('input_inspection_date'),
                                                          isDense: true,
                                                          border: const OutlineInputBorder(),
                                                          suffixIcon: const Icon(Icons.date_range, size: 18),
                                                        ),
                                                        style: const TextStyle(fontSize: 13),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: TextField(
                                                    controller: lastMaintenanceKmController,
                                                    keyboardType: TextInputType.number,
                                                    decoration: InputDecoration(
                                                      labelText: _t('input_inspection_km'),
                                                      isDense: true,
                                                      border: const OutlineInputBorder(),
                                                      suffixText: "km",
                                                    ),
                                                    style: const TextStyle(fontSize: 13),
                                                    onChanged: (val) => updateCalculations(),
                                                  ),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      )
                                  ],
                               ],
                             ),
                          ),
                          const SizedBox(height: 25),    // SECTİON 4: MUAYENE VE GELECEK
                          if (isOver3Years) ...[
                             const Text("MUAYENE BİLGİSİ", style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 5),
                             Container(
                               padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                               child: Column(
                                 children: [
                                    Row(children: [const Icon(Icons.warning_amber, color: Colors.red, size: 16), const SizedBox(width: 5), Expanded(child: Text(_t('input_over_3_years_warning'), style: const TextStyle(color: Colors.red, fontSize: 12)))]),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                               final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                                               if (picked != null) setState(() { lastInspectionDate = picked; inspectionDateController.text = "${picked.day}.${picked.month}.${picked.year}"; });
                                            },
                                            child: AbsorbPointer(child: TextField(controller: inspectionDateController, decoration: InputDecoration(labelText: _t('input_inspection_date'), isDense: true, border: const OutlineInputBorder(), filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.white))),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: TextField(controller: lastInspectionKmController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _t('input_inspection_km'), isDense: true, border: const OutlineInputBorder(), filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.white))),
                                      ],
                                    ),
                                 ],
                               ),
                             ),
                             const SizedBox(height: 25),
                          ],

                           // 5. KAYDET BUTONU
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0059BC),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 5,
                              ),
                              onPressed: () async {
                                if (selectedBrand == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('warning_select_car_model'))));
                                  return;
                                }

                                // [NEW] 3+ Year Inspection Validation
                                if (isOver3Years && lastInspectionDate == null) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     const SnackBar(content: Text("3 yaş üstü araçlar için son muayene tarihi girilmesi önerilir."), duration: Duration(seconds: 4))
                                   );
                                   // We allow proceeding but warned.
                                }

                                // 3 Parçalı Plaka Birleştirme
                                if (plateLetters.text.isEmpty) {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('warning_enter_plate'))));
                                   return; 
                                }
                                String plateCode = "${selectedPlateCity < 10 ? '0$selectedPlateCity' : selectedPlateCity} ${plateLetters.text.toUpperCase()} ${plateNumberDigits.join()}";

                                // Plaka kontrolü (Only for TR or basic duplication check)
                                setState(() => isLoading = true);
                                try {
                                  // Fix: checkPlateExists returns Map?, so check if it is not null
                                  final existingData = await _firestoreService.checkPlateExists(plateCode);
                                  bool exists = existingData != null;
                                  
                                  if (exists) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('warning_plate_exists'))));
                                      setState(() => isLoading = false);
                                    }
                                    return;
                                  }

                                  Car fullCar = Car(
                                    name: "$selectedBrand $selectedModel",
                                    currentKm: int.tryParse(kmController.text) ?? 0,
                                    nextMaintenanceKm: int.tryParse(nextKmController.text) ?? 10000,
                                    plate: plateCode,
                                    modelYear: int.tryParse(modelYearController.text),
                                    brand: selectedBrand,
                                    model: selectedModel,
                                    hardware: selectedHardware,
                                    photos: (isZeroKm && selectedZeroKmPhotos.isNotEmpty) ? selectedZeroKmPhotos : [],
                                    technicalSpecs: (isZeroKm) ? selectedZeroKmSpecs : {},
                                    nextMaintenanceDate: _parseDate(nextDateController.text),
                                    trafficReleaseDate: trafficReleaseDate,
                                    ownershipDate: ownershipDate,
                                    nextInspectionDate: lastInspectionDate != null 
                                        ? (isOver3Years 
                                            ? DateTime(lastInspectionDate!.year + (isCommercial ? 1 : 2), lastInspectionDate!.month, lastInspectionDate!.day)
                                            : DateTime(trafficReleaseDate.year + 3, trafficReleaseDate.month, trafficReleaseDate.day))
                                        : DateTime(trafficReleaseDate.year + 3, trafficReleaseDate.month, trafficReleaseDate.day),
                                    history: didMaintenanceOnPurchase 
                                        ? [
                                            {
                                              'action': _t('maintenance_purchase_title'),
                                              'date': ownershipDate, 
                                              'km': int.tryParse(kmController.text) ?? 0,
                                              'cost': _t('unknown'),
                                              'service': _t('unknown'),
                                              'parts': _t('initial_maintenance_parts'),
                                            }
                                          ]
                                        : (lastMaintenanceDate != null)
                                            ? [
                                                {
                                                  'action': _t('legacy_maintenance_title'),
                                                  'date': lastMaintenanceDate,
                                                  'km': int.tryParse(lastMaintenanceKmController.text) ?? 0,
                                                  'cost': _t('unknown'),
                                                  'service': _t('manual_entry'),
                                                  'parts': _t('legacy_record'),
                                                }
                                              ]
                                            : [],
                                    inspectionHistory: (isOver3Years && lastInspectionDate != null)
                                        ? [
                                            {
                                              'date': lastInspectionDate,
                                              'km': int.tryParse(lastInspectionKmController.text) ?? 0,
                                              'result': _t('initial_inspection_result'),
                                              'type': 'initial',
                                            }
                                          ]
                                        : [],
                                    isCommercial: isCommercial,
                                  );

                                  if (uid != null) {
                                    await _firestoreService.addCar(uid!, fullCar);
                                  }
                                  
                                  setState(() => isLoading = false);
                                  if (context.mounted) Navigator.pop(context);
                                  
                                } catch (e) {
                                   setState(() => isLoading = false);
                                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                                }
                              },
                              child: isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(_t('btn_add_to_garage'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 40), // Bottom padding
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            );
          },
        );
      },
    );
  }



  void _updateKmDialog(Car car) {
    debugPrint("DEBUG: _updateKmDialog called for car ${car.name}");
    TextEditingController kmController = TextEditingController(
      text: car.currentKm.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white, // Fixes "pinkish" tint in Material 3
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F7FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.speed, color: Color(0xFF0059BC), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              _t('update_km'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            Text(
              _t('enter_current_km_msg'),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: kmController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFF333333)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              suffixText: "KM",
              suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_t('cancel'), style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    int? newKm = int.tryParse(kmController.text.replaceAll(RegExp(r'[^0-9]'), '')); // Sanitize input
                    
                    debugPrint("DEBUG: Attempting update. NewKM: $newKm, UID: $uid, CarID: ${car.id}");
                    
                    if (newKm == null) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(_t('error_invalid_number')), backgroundColor: Theme.of(context).colorScheme.error),
                       );
                       return;
                    }

                    // 1. Calculate Max History KM
                    int maxHistoryKm = 0;
                    if (car.history.isNotEmpty) {
                      for (var record in car.history) {
                        int rKm = int.tryParse(record['km']?.toString() ?? '0') ?? 0;
                        if (rKm > maxHistoryKm) maxHistoryKm = rKm;
                      }
                    }

                    // 2. Calculate Max Inspection KM
                    int maxInspectionKm = 0;
                    if (car.inspectionHistory.isNotEmpty) {
                       for (var record in car.inspectionHistory) {
                         int rKm = int.tryParse(record['km']?.toString() ?? '0') ?? 0;
                         if (rKm > maxInspectionKm) maxInspectionKm = rKm;
                       }
                    }

                    // 3. Determine Constraint
                    int minAllowedKm = (maxHistoryKm > maxInspectionKm) ? maxHistoryKm : maxInspectionKm;

                    // 4. Validate
                    if (newKm < minAllowedKm) {
                       if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_t('error_km_too_low_params').replaceAll('{new}', '$newKm').replaceAll('{old}', '$minAllowedKm')),
                              backgroundColor: Theme.of(context).colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                       }
                       return;
                    }
                    
                    if (uid != null && car.id != null) {
                      await _firestoreService.updateCarKm(uid!, car.id!, newKm);
                      if (context.mounted) Navigator.pop(context);
                    } else {
                       debugPrint("ERROR: Cannot update. Missing data or invalid input.");
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_t('error_update_failed_params').replaceAll('{details}', 'UID: $uid, ID: ${car.id}')), backgroundColor: Theme.of(context).colorScheme.error),
                        );
                       }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0059BC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(_t('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickMaintenanceDate(Car car) async {
    DateTime initialDate = car.nextMaintenanceDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0059BC),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && uid != null && car.id != null) {
      await _firestoreService.updateNextMaintenanceDate(uid!, car.id!, picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('msg_maintenance_date_updated')), backgroundColor: Colors.green),
        );
      }
    }
  }

  // --- RECALCULATE SCHEDULE LOGIC ---
  Future<void> _recalculateMaintenanceSchedule(Car car) async {
    if (uid == null || car.id == null) return;

    // 1. Sort history by date (newest first)
    List<Map<String, dynamic>> sortedHistory = List.from(car.history);
    sortedHistory.sort((a, b) {
      DateTime dA;
      if (a['date'] is Timestamp) dA = (a['date'] as Timestamp).toDate();
      else if (a['date'] is DateTime) dA = a['date'];
      else if (a['date'] is String) dA = DateTime.tryParse(a['date']) ?? DateTime.now();
      else dA = DateTime.now();

      DateTime dB;
      if (b['date'] is Timestamp) dB = (b['date'] as Timestamp).toDate();
      else if (b['date'] is DateTime) dB = b['date'];
      else if (b['date'] is String) dB = DateTime.tryParse(b['date']) ?? DateTime.now();
      else dB = DateTime.now();
      
      return dB.compareTo(dA); // Newest first
    });

    DateTime? lastDate;
    int lastKm = 0;

    // 2. Find latest valid periodic maintenance
    // If no periodic maintenance found, use the latest record of any type (fallback)
    // Or strictly search for 'periodic' if we want to be precise.
    // For now, let's assume valid records are ones that reset the clock.
    // Usually 'periodic maintenance', 'maintenance on purchase'.
    
    // Simplification: Use the very last record's data as base
    if (sortedHistory.isNotEmpty) {
       final latest = sortedHistory.first;
       if (latest['date'] is Timestamp) lastDate = (latest['date'] as Timestamp).toDate();
       else if (latest['date'] is DateTime) lastDate = latest['date'];
       else if (latest['date'] is String) lastDate = DateTime.tryParse(latest['date']);
       else lastDate = DateTime.now();
       lastKm = int.tryParse(latest['km']?.toString() ?? '0') ?? 0;
    } else {
       // Fallbacks
       lastDate = car.trafficReleaseDate;
       lastKm = 0; 
       // If maintenance on purchase was checked but history is empty (weird state), handle it?
       // Let's assume traffic release date is the baseline.
    }

    // 3. Calculate Next
    // Default Rule: +1 Year, +15000 KM (Standard for most cars) - or +10000 KM
    // Let's stick to 1 year / 10000km to be safe, or keep existing logic if we can infer.
    // Ideally we should store "maintenanceInterval" in Car object. Defaulting to 15k.
    
    // Check if we have a "nextMaintenanceKm" current value to infer interval? No, it might be wrong.
    // Hardcode 15000 KM / 1 Year
    int intervalKm = 15000;
    
    DateTime nextDate = (lastDate ?? DateTime.now()).add(const Duration(days: 365));
    int nextKm = lastKm + intervalKm;

    // 4. Update Firestore
    // We update the HEADER fields: nextMaintenanceDate, nextMaintenanceKm
    await _firestoreService.updateCarNextMaintenance(uid!, car.id!, nextDate, nextKm);
    
    // Update local state is handled by Stream usually, but we can force it if needed.
  }

  // --- RECALCULATE INSPECTION SCHEDULE ---
  Future<void> _recalculateInspectionSchedule(Car car) async {
    if (uid == null || car.id == null) return;
    
    // 1. Sort history
    List<Map<String, dynamic>> sortedHistory = List.from(car.inspectionHistory);
    sortedHistory.sort((a, b) {
       DateTime dA = (a['date'] is Timestamp) ? (a['date'] as Timestamp).toDate() : (a['date'] as DateTime);
       DateTime dB = (b['date'] is Timestamp) ? (b['date'] as Timestamp).toDate() : (b['date'] as DateTime);
       return dB.compareTo(dA);
    });

    DateTime? lastDate;
    
    if (sortedHistory.isNotEmpty) {
       final latest = sortedHistory.first;
       lastDate = (latest['date'] is Timestamp) ? (latest['date'] as Timestamp).toDate() : (latest['date'] as DateTime);
    } else {
       // Fallback: Traffic Release Date
       lastDate = null; // Don't use traffic release directly for "last inspection", calculation handles logic
    }
    
    // 2. Calculate Next Date
    DateTime? nextDate;
    
    // If we have a last inspection
    if (lastDate != null) {
       if (car.isCommercial) {
          nextDate = DateTime(lastDate.year + 1, lastDate.month, lastDate.day);
       } else {
          // Private Car
          // If over 3 years old -> 2 years
          // How do we know if it WAS over 3 years old at the time of inspection? 
          // Simplified: All subsequent inspections are 2 years for private cars (in TR).
          // Only the FIRST inspection is 3 years from traffic release.
          nextDate = DateTime(lastDate.year + 2, lastDate.month, lastDate.day);
       }
    } else {
       // No history -> Base on Traffic Release
       // Safely get date or default to now if null
       final trafficRelease = car.trafficReleaseDate ?? DateTime.now(); 
       
       if (car.isCommercial) {
          nextDate = DateTime(trafficRelease.year + 1, trafficRelease.month, trafficRelease.day);
       } else {
          // Private: 3 years from newly bought
          nextDate = DateTime(trafficRelease.year + 3, trafficRelease.month, trafficRelease.day);
       }
    }
    
    // 3. Update Firestore
    await _firestoreService.updateCarNextInspection(uid!, car.id!, nextDate);
  }

  // --- EDIT MAINTENANCE ---
  void _showEditMaintenanceDialog(Car car, Map<String, dynamic> oldRecord) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMaintenanceScreen(
        car: car, 
        isSheet: true, 
        initialData: oldRecord
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
       if (uid == null || car.id == null) return;
       
       // 1. Remove old - ensure Timestamp format if needed
       // Note: If oldRecord has DateTime but Firestore needs Timestamp, this might fail unless we convert.
       // But assuming the list came from Firestore or was consistently added as Timestamp (see below), it should work.
       // However, for safety, if keys match but types differ, we rely on equality.
       await _firestoreService.removeMaintenance(uid!, car.id!, oldRecord);
       
       // 2. Add new
       String kmStr = result['km']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0';
       int km = int.tryParse(kmStr) ?? 0;
       
       String dateStr = result['date'];
       DateTime date = DateTime.now();
       try {
           final parts = dateStr.toString().split('/');
           if (parts.length == 3) date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
       } catch (_) {}

       // Firestore Add converts to Timestamp internally
       await _firestoreService.addMaintenance(uid!, car.id!, result, km, date, true);
       
       // 3. Update Car KM if higher
       if (km > car.currentKm) {
          await _firestoreService.updateCarKm(uid!, car.id!, km);
       }

       // 4. Recalculate
       Car tempCar = car;
       tempCar.history.remove(oldRecord);
       Map<String, dynamic> newRec = Map.from(result);
       newRec['km'] = km;
       // Critical Fix: Store as Timestamp locally to match Firestore format for future edits/deletes in this session
       newRec['date'] = Timestamp.fromDate(date); 
       tempCar.history.add(newRec); 
       
       await _recalculateMaintenanceSchedule(tempCar);
       
       setState(() {});
       
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('msg_record_updated') ?? "Kayıt güncellendi"), backgroundColor: Colors.green));
       }
    }
  }

  // --- INSPECTION HISTORY DETAIL SCREEN ---
  void _showInspectionDetail(Car car, Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
             const SizedBox(height: 20),
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(_t('inspection_detail_title') ?? 'Muayene Detayı', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   if (!widget.isReadOnly)
                   Row(
                     children: [
                        /* Edit not fully implemented for Inspection yet, can use Delete & Re-add */
                         IconButton(
                           icon: const Icon(Icons.edit, color: Colors.blue),
                           onPressed: () {
                              Navigator.pop(context);
                              _showEditInspectionDialog(car, record);
                           }
                         ),
                         IconButton(
                           icon: const Icon(Icons.delete_outline, color: Colors.red),
                           onPressed: () {
                              Navigator.pop(context);
                              _deleteInspectionDialog(car, record);
                           }
                         )
                     ],
                   )
                ],
             ),
             const Divider(),
             const SizedBox(height: 10),
             _buildDetailRow(Icons.calendar_today, _t('date'), DateFormat('dd.MM.yyyy').format((record['date'] is Timestamp) ? (record['date'] as Timestamp).toDate() : record['date'])),
             _buildDetailRow(Icons.speed, _t('km_label'), "${record['km'] ?? 0} KM"),
             _buildDetailRow(Icons.assignment_turned_in, _t('result_label'), _getLocalizedInspectionResult(record['result'])),
             _buildDetailRow(Icons.note, _t('notes_label'), record['notes'] ?? '-'),
          ],
        ),
      ),
    );
  }
  
  // --- INSPECTION HISTORY LIST ---
  void _showInspectionHistoryDialog(Car car) {
     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
           height: MediaQuery.of(context).size.height * 0.8,
           decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
           ),
           padding: const EdgeInsets.all(20),
           child: Column(
              children: [
                 Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                 const SizedBox(height: 15),
                 Text(_t('inspection_history'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 15),
                 Expanded(
                    child: ListView.builder(
                       itemCount: car.inspectionHistory.length,
                       itemBuilder: (context, index) {
                          // Reverse order
                          final record = car.inspectionHistory[car.inspectionHistory.length - 1 - index];
                          DateTime d = (record['date'] is Timestamp) ? (record['date'] as Timestamp).toDate() : (record['date'] as DateTime);
                          
                          return ListTile(
                             leading: const Icon(Icons.verified_user, color: Colors.green),
                             title: Text(DateFormat('dd.MM.yyyy').format(d), style: const TextStyle(fontWeight: FontWeight.bold)),
                             subtitle: Text("${record['km']} KM • ${_getLocalizedInspectionResult(record['result'])}"),
                             onTap: () => _showInspectionDetail(car, record),
                             trailing: !widget.isReadOnly 
                                ? IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteInspectionDialog(car, record))
                                : null,
                          );
                       },
                    ),
                 )
              ]
           )
        )
     );
  }

  void _showMaintenanceDetail(Car car, Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Fix overflow issues
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, // Reasonable height
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white, // Fix pink background
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             // Drag Handle
            Center(
              child: Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         Expanded(
                           child: Text(
                            _getLocalizedAction(record['action']),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0059BC),
                            ),
                          ),
                         ),
                         // [NEW] Edit Button (Only if not read-only)
                         if (!widget.isReadOnly)
                         IconButton(
                           icon: const Icon(Icons.edit, color: Colors.blue),
                           onPressed: () {
                              Navigator.pop(context); // Close detail
                              _showEditMaintenanceDialog(car, record);
                           },
                         ),
                         
                         // Delete Button (Only if not read-only)
                         if (!widget.isReadOnly)
                         IconButton(
                           icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                           onPressed: () {
                              Navigator.pop(context); // Close detail
                              _deleteMaintenanceDialog(car, record);
                           },
                         ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    _buildDetailRow(Icons.calendar_today, _t('maintenance_date'), _formatDate(record['date'])),
                    _buildDetailRow(Icons.speed, _t('maintenance_km'), "${record['km'] ?? 0} KM"),
                    _buildDetailRow(Icons.store, _t('maintenance_service_shop'), record['service'] ?? ''),
                    _buildDetailRow(Icons.paid, _t('maintenance_cost'), record['cost'] ?? ''),
                    
                    // Oil Details (if available)
                    if (record['oilBrand'] != null && record['oilBrand'].toString().isNotEmpty) ...[
                       const SizedBox(height: 10),
                       Text(_t('oil_info_label'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                       const SizedBox(height: 5),
                       _buildDetailRow(Icons.branding_watermark, _t('brand_model_label'), record['oilBrand'] ?? '-'),
                       if (record['oilViscosity'] != null)
                         _buildDetailRow(Icons.water_drop, _t('viscosity_label'), record['oilViscosity'] ?? '-'),
                     ],

                    const SizedBox(height: 15),
                    Text(
                      _t('changed_parts_notes_label'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), // Theme aware
                      child: Text(
                        (record['parts'] != null && record['parts'].toString().isNotEmpty) 
                            ? _getLocalizedParts(record['parts']) 
                            : _t('no_notes_entered'),
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 30), // Safe area
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  // --- MUAYENE DURUMU WIDGET ---
  Widget _buildInspectionStatus(Car activeCar) {
    int remainingDays = 0;
    double progress = 0.0;
    String statusText = "";
    Color statusColor = Colors.green;

    if (activeCar.nextInspectionDate != null) {
      final now = DateTime.now();
      final difference = activeCar.nextInspectionDate!.difference(now);
      remainingDays = difference.inDays;

      // Basit bir progress mantığı: 2 yıl (730 gün) üzerinden hesaplayalım
      // Veya son muayeneden bu yana geçen zamana göre
      // Şimdilik kalan güne göre renk belirleyelim:
      if (remainingDays < 0) {
        statusText = _t('inspection_expired_msg');
        statusColor = Colors.red;
        progress = 1.0;
      } else if (remainingDays < 30) {
        statusText = _t('days_left_approaching').replaceAll('{days}', remainingDays.toString());
        statusColor = Colors.orange;
        progress = (30 - remainingDays) / 30.0; 
      } else {
        statusText = _t('days_left_simple').replaceAll('{days}', remainingDays.toString());
        statusColor = Colors.green;
        progress = 0.0; // Uzun süre var
      }
    } else {
      statusText = _t('no_inspection_info');
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('inspection_status'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              if(!widget.isReadOnly)
              GestureDetector(
                onTap: () => _showAddInspectionDialog(activeCar),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: Theme.of(context).primaryColor, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('expiration_date'), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              Text(
                activeCar.nextInspectionDate != null
                    ? DateFormat('dd/MM/yyyy').format(activeCar.nextInspectionDate!)
                    : "-",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : const Color(0xFF333333),
                ),
              ),
            ],
          ),
          if (activeCar.nextInspectionDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),

          // Muayene Geçmişi Başlığı (Ufak)
          if (activeCar.inspectionHistory.isNotEmpty) ...[
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_t('last_inspections'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                // [NEW] View All History Button
                GestureDetector(
                  onTap: () => _showInspectionHistoryDialog(activeCar),
                  child: Text(_t('see_all'), style: const TextStyle(color: Colors.blue, fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 10),
            ...activeCar.inspectionHistory.take(2).map((rec) {
              DateTime d = (rec['date'] is Timestamp) ? (rec['date'] as Timestamp).toDate() : (rec['date'] as DateTime);
              String dateStr = DateFormat('dd.MM.yyyy').format(d); // [FIX] Formatting

              String kmStr = rec['km'] != null ? "${rec['km']} KM" : "";

              return GestureDetector( // [NEW] Make clickable
                onTap: () => _showInspectionDetail(activeCar, rec),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (kmStr.isNotEmpty)
                        Text(kmStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_getLocalizedInspectionResult(rec['result']), style: const TextStyle(fontSize: 12)),
                      if (!widget.isReadOnly) // Check ReadOnly
                        GestureDetector(
                          onTap: () => _deleteInspectionDialog(activeCar, rec),
                          child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        )
                    ],
                  ),
                ),
              );
            }).toList()
          ]
        ],
      ),
    );
  }


      
  String _getLocalizedInspectionResult(String? result) {
      if (result == null) return "";
      switch (result) {
        case 'Passed': return _t('result_passed');
        case 'Flawed': return _t('result_flawed');
        case 'Failed': return _t('result_failed');
        default: return result;
      }
  }

  // --- EDIT INSPECTION DIALOG ---
  void _showEditInspectionDialog(Car car, Map<String, dynamic> oldRecord) {
    // Parse old data
    DateTime selectedDate = DateTime.now();
    if (oldRecord['date'] is Timestamp) {
      selectedDate = (oldRecord['date'] as Timestamp).toDate();
    } else if (oldRecord['date'] is DateTime) {
      selectedDate = oldRecord['date'];
    }
    
    TextEditingController kmController = TextEditingController(text: oldRecord['km']?.toString() ?? '');
    TextEditingController notesController = TextEditingController(text: oldRecord['notes']?.toString() ?? '');
    
    String result = oldRecord['result'] ?? _t('result_passed');
    int selectedResultIndex = 0;
    List<String> results = [_t('result_passed'), _t('result_flawed'), _t('result_failed')];
    if (results.contains(result)) {
       selectedResultIndex = results.indexOf(result);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
             return Container(
               height: MediaQuery.of(context).size.height * 0.85,
               decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
               ),
               padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
               child: Column(
                  children: [
                      Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Text(_t('edit'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      // Date Picker
                      ListTile(
                        title: Text(_t('inspection_date_label')),
                        subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                        onTap: () async {
                           DateTime? picked = await showDatePicker(
                             context: context,
                             initialDate: selectedDate,
                             firstDate: DateTime(2000),
                             lastDate: DateTime.now().add(const Duration(days: 365*5)),
                           );
                           if (picked != null) {
                             setState(() => selectedDate = picked);
                           }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: kmController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _t('inspection_km_label'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          suffixText: 'KM',
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(_t('inspection_result_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Row(
                         mainAxisAlignment: MainAxisAlignment.spaceAround,
                         children: List.generate(results.length, (index) {
                            return ChoiceChip(
                               label: Text(results[index]),
                               selected: selectedResultIndex == index,
                               onSelected: (selected) {
                                  if(selected) setState(() => selectedResultIndex = index);
                               },
                               selectedColor: index == 0 ? Colors.green.withOpacity(0.2) : (index == 1 ? Colors.orange.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                               labelStyle: TextStyle(
                                  color: selectedResultIndex == index 
                                    ? (index == 0 ? Colors.green : (index == 1 ? Colors.orange : Colors.red)) 
                                    : null
                               ),
                            );
                         }),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                         controller: notesController,
                         decoration: InputDecoration(
                            labelText: _t('notes_label'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                         ),
                         maxLines: 2,
                      ),
                      const Spacer(),
                      SizedBox(
                         width: double.infinity,
                         child: ElevatedButton(
                            onPressed: () async {
                               if (kmController.text.isEmpty) return;
                               
                               // Remove old
                               if (uid != null && car.id != null) {
                                  await _firestoreService.deleteInspection(uid!, car.id!, oldRecord);
                                  
                                  // Add new
                                  Map<String, dynamic> newRecord = {
                                     'date': Timestamp.fromDate(selectedDate),
                                     'km': int.tryParse(kmController.text) ?? 0,
                                     'result': results[selectedResultIndex],
                                     'notes': notesController.text,
                                  };
                                  
                                  // Local update for immediate UI
                                  car.inspectionHistory.remove(oldRecord);
                                  car.inspectionHistory.add(newRecord);
                                  
                                  await _firestoreService.addInspection(uid!, car.id!, newRecord);
                                  await _recalculateInspectionSchedule(car);
                                  
                                  if (mounted) {
                                     Navigator.pop(context);
                                     setState(() {});
                                  }
                               }
                            },
                            style: ElevatedButton.styleFrom(
                               backgroundColor: const Color(0xFF0059BC),
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(_t('save_btn')),
                         ),
                      )
                  ],
               ),
             );
          }
        );
      }
    );
  }

    // Existing _showAddInspectionDialog implementation below...
    void _showAddInspectionDialog(Car car) {
      DateTime selectedDate = DateTime.now();
      TextEditingController kmController = TextEditingController();
      TextEditingController notesController = TextEditingController();
      int selectedResultIndex = 0;
      List<String> results = [_t('result_passed'), _t('result_flawed'), _t('result_failed')];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
               
               // Tarih Seçici Helper
               Future<void> pickDate() async {
                 DateTime? picked = await showDatePicker(
                   context: context,
                   initialDate: selectedDate,
                   firstDate: DateTime(2000),
                   lastDate: DateTime.now(), // Gelecek tarihli muayene olmaz (randevu hariç, burası geçmiş kayıt)
                   locale: Locale(LanguageService().currentLanguage, LanguageService().currentLanguage.toUpperCase()),
                   builder: (context, child) {
                       return Theme(
                         data: Theme.of(context).copyWith(
                           colorScheme: const ColorScheme.light(
                             primary: Color(0xFF0059BC), 
                           ),
                         ),
                         child: child!,
                     );
                   }
                );
               if (picked != null) {
                 setState(() {
                   selectedDate = picked;
                 });
               }
             }

             return Container(
                height: MediaQuery.of(context).size.height * 0.75, // Daha geniş alan
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                ),
                padding: EdgeInsets.only(
                  top: 10, left: 20, right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // DRAG HANDLE
                      Center(
                        child: Container(
                          width: 40, height: 5,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // HEADER
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF0059BC).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.fact_check, color: Color(0xFF0059BC)),
                          ),
                          const SizedBox(width: 15),
                          Text(_t('add_inspection_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 15),

                      // 1. TARİH SEÇİMİ (MODERN KUTU)
                      Text(_t('inspection_date'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${selectedDate.day}.${selectedDate.month}.${selectedDate.year}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.calendar_today, color: Color(0xFF0059BC)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. KM GİRİŞİ
                      Text(_t('inspection_km_label'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: kmController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: "Örn: 120500", // Keep generic or localize if needed
                          suffixText: "KM",
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // 3. NOTLAR
                      Text(_t('inspection_notes_label'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          hintText: _t('inspection_notes_hint'),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. SONUÇ SEÇİMİ (CHIPS)
                      Text(_t('inspection_result_label'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(results.length, (index) {
                           bool isSelected = selectedResultIndex == index;
                           Color color = index == 0 ? Colors.green : (index == 1 ? Colors.orange : Colors.red);
                           return Expanded(
                             child: GestureDetector(
                               onTap: () => setState(() => selectedResultIndex = index),
                               child: AnimatedContainer(
                                 duration: const Duration(milliseconds: 200),
                                 margin: EdgeInsets.only(right: index < 2 ? 10 : 0),
                                 padding: const EdgeInsets.symmetric(vertical: 12),
                                 alignment: Alignment.center,
                                 decoration: BoxDecoration(
                                   color: isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(color: isSelected ? color : Colors.grey.shade300),
                                   boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                                 ),
                                 child: Text(
                                   results[index],
                                   style: TextStyle(
                                     color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]),
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ),
                             ),
                           );
                        }),
                      ),
                      const SizedBox(height: 30),

                      // KAYDET BUTONU
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () async {
                             int km = int.tryParse(kmController.text) ?? car.currentKm;
                             String result = results[selectedResultIndex];
                             
                             // Firestore Update Logic
                             if (uid != null && car.id != null) {
                               // Validasyonlar
                               if (km < car.currentKm) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('inspection_km_error'))));
                                  return;
                               }
                               
                               Navigator.pop(context); // Close sheet
                               
                               // 1. Add to History
                               Map<String, dynamic> inspectionRecord = {
                                 'date': Timestamp.fromDate(selectedDate),
                                 'km': km,
                                 'result': result,
                                 'notes': notesController.text, // Notları ekle
                                 'created_at': FieldValue.serverTimestamp(),
                               };
                               await _firestoreService.addInspectionRecord(uid!, car.id!, inspectionRecord);

                               // 2. Logic Check: Update Next Inspection Date
                               DateTime nextDate = DateTime(selectedDate.year + (car.isCommercial ? 1 : 2), selectedDate.month, selectedDate.day);
                               
                               if (result != "Kaldı") {
                                  await _firestoreService.updateCarInspectionDate(uid!, car.id!, nextDate);
                               }

                               // 3. Update Current KM if greater
                               if (km > car.currentKm) {
                                 await _firestoreService.updateCarKm(uid!, car.id!, km);
                               }

                               if (mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text(_t('msg_maintenance_date_updated')), backgroundColor: Colors.green),
                                 );
                               }
                             }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0059BC),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                            shadowColor: const Color(0xFF0059BC).withOpacity(0.4),
                          ),
                          child: Text(_t('save_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
             );
          },
        );
      }
    );
  }

  // --- MUAYENE SİLME ---
  void _deleteInspectionDialog(Car car, Map<String, dynamic> record) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_inspection_title')),
        content: Text(_t('delete_inspection_confirm')),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context),
             child: Text(_t('cancel')),
           ),
           TextButton(
             onPressed: () async {
               if (uid != null && car.id != null) {
                 await _firestoreService.deleteInspection(uid!, car.id!, record);
                 // [NEW] Recalculate
                 Car tempCar = car;
                 tempCar.inspectionHistory.remove(record);
                 await _recalculateInspectionSchedule(tempCar);
               }
               if (context.mounted) {
                 Navigator.pop(context);
               }
             },
             child: Text(_t('delete'), style: const TextStyle(color: Colors.red)),
           ),
        ],
      ),
     );
  }

  // --- EXPERTISE STATUS WIDGET ---
  Widget _buildExpertiseStatus(Car activeCar) {
    int changedCount = 0;
    int paintedCount = 0;
    // Standard keys to check (Ignoring localized junk)
    final validKeys = _getStandardPartKeys();

    if (activeCar.expertiseReport.isNotEmpty) {
      activeCar.expertiseReport.forEach((key, status) {
        if (!validKeys.contains(key)) return; // Skip invalid keys
        
        if (status == 'changed') changedCount++;
        if (status == 'painted' || status == 'local_paint') paintedCount++;
      });
    }

    String summary = _t('no_report');
    if (activeCar.expertiseReport.isNotEmpty) {
      bool isEmpty = changedCount == 0 && paintedCount == 0;
      if (isEmpty) {
         summary = _t('error_free_original');
      } else {
         summary = "$changedCount ${_t('parts_changed')}, $paintedCount ${_t('parts_painted')}";
      }
    }

    // Calulate Tramer
    double totalTramer = 0;
    if (activeCar.tramerRecords.isNotEmpty) {
      for (var r in activeCar.tramerRecords) {
         // Robust check for false
         var isInsVal = r['isInsurance'];
         bool isCebimden = (isInsVal == false || isInsVal.toString().toLowerCase() == 'false');
         
         if (!isCebimden) {
           double amt = 0;
           if (r['amount'] is num) {
             amt = (r['amount'] as num).toDouble();
           } else if (r['amount'] is String) {
             String s = r['amount'].toString().replaceAll(',', '.');
             amt = double.tryParse(s) ?? 0;
           }
           totalTramer += amt;
         }
       }
     }
     String tramerText = totalTramer > 0 ? "${NumberFormat('#,###', 'tr_TR').format(totalTramer)} ₺ ${_t('tramer_text')}" : _t('no_tramer_record');
 
     return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('expertise_tramer'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () {
                    // Open New Details Sheet
                     _showExpertiseAndTramerSheet(activeCar);
                }, 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0059BC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                       Text(_t('details'), style: const TextStyle(color: Color(0xFF0059BC), fontWeight: FontWeight.bold, fontSize: 12)),
                       const SizedBox(width: 4),
                       const Icon(Icons.arrow_forward_ios, color: Color(0xFF0059BC), size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(summary, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              Text(
                tramerText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: totalTramer > 0 ? Colors.redAccent : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : const Color(0xFF333333)),
                ),
              ),
            ],
          ),
          if (activeCar.expertiseReport.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "${_t('report_date')} ${activeCar.ownershipDate != null ? DateFormat('dd.MM.yyyy').format(activeCar.ownershipDate!) : '-'}", // Using ownership as proxy or add report date later
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  void _showExpertiseEditorDialog(Car car) {
    // Normalize report
    Map<String, String> currentReport = _normalizeExpertiseReport(car.expertiseReport);
    
    // Define parts list in specific order (Top-down, Left-Right generally)
    final List<String> partKeys = _getStandardPartKeys();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final double screenWidth = MediaQuery.of(context).size.width;
            
            // Full width, spacing 12
            final double spacing = 12.0; 
            // 2 items per row. Screen width - spacing * 3 (left, middle, right) / 2?
            // User requested NO side margins on the page bottom, but we likely need padding inside the sheet for the buttons?
            // "Kenarlarında boşluk kalmasın" (No space at edges) -> likely means the sheet itself touches edges.
            // Buttons inside usually have some padding. Let's maximize button width.
            
            // Let's assume some minimal internal padding for aesthetics so buttons don't touch screen edge physically.
            final double internalPadding = 12.0; 
            final double itemWidth = (screenWidth - (internalPadding * 2) - spacing) / 2;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85, // Take up significant height
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                   // Header
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                     child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_t('expert_report_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                     ),
                   ),
                   const Divider(height: 1),
                   
                   Expanded(
                     child: SingleChildScrollView(
                       padding: EdgeInsets.all(internalPadding),
                       child: Column(
                         children: [
                            // Info Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Text(
                                _t('expertise_edit_grid_hint') + " (Orijinal -> Boyalı -> Değişen -> Lokal Boyalı -> Plastik)",
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),

                            Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              alignment: WrapAlignment.start,
                              children: partKeys.map((key) {
                                  String status = currentReport[key] ?? 'original';
                                  String partName = _getPartName(key);
                                  String statusLabel = _getStatusLabel(status);
                                  
                                  Color themeColor;
                                  if (status == 'painted') themeColor = Colors.orange;
                                  else if (status == 'changed') themeColor = Colors.red;
                                  else if (status == 'local_paint') themeColor = Colors.orangeAccent;
                                  else if (status == 'plastic') themeColor = isDark ? Colors.grey[400]! : Colors.black87;
                                  else themeColor = isDark ? Colors.grey[500]! : Colors.black54;

                                  Color textColor = themeColor;
                                  Color borderColor = themeColor.withOpacity(0.5);
                                  Color bgColor = isDark ? Colors.grey[800]! : const Color(0xFFF9F9F9);
                                  
                                  if (status == 'original') {
                                    borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
                                    textColor = isDark ? Colors.grey[400]! : Colors.black87;
                                  } else {
                                    borderColor = themeColor;
                                    bgColor = isDark ? themeColor.withOpacity(0.1) : Colors.white;
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      setStateDialog(() {
                                        switch (status) {
                                          case 'original': status = 'painted'; break;
                                          case 'painted': status = 'changed'; break;
                                          case 'changed': status = 'local_paint'; break;
                                          case 'local_paint': status = 'plastic'; break;
                                          case 'plastic': status = 'original'; break;
                                          default: status = 'original';
                                        }
                                        currentReport[key] = status;
                                      });
                                    },
                                    child: Container(
                                      width: itemWidth,
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor, width: 1.5),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            partName, 
                                            textAlign: TextAlign.center, 
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, // Bold as per screenshot
                                              fontSize: 14, 
                                              color: textColor
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "($statusLabel)", 
                                            textAlign: TextAlign.center, 
                                            style: TextStyle(
                                              fontSize: 12, 
                                              color: textColor,
                                              fontWeight: FontWeight.w600
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                              }).toList(),
                            ),
                            const SizedBox(height: 80), // Space for fab/bottom button
                         ],
                       ),
                     ),
                   ),

                   // Bottom Button
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: isDark ? Colors.grey[900] : Colors.white,
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.05),
                           offset: const Offset(0, -4),
                           blurRadius: 10
                         )
                       ]
                     ),
                     child: SizedBox(
                       width: double.infinity,
                       child: ElevatedButton(
                         onPressed: () async {
                           car.expertiseReport = currentReport;
                           if (uid != null) {
                              await _firestoreService.updateCar(uid!, car);
                           }
                           if (context.mounted) Navigator.pop(context);
                           setState(() {});
                         },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF0059BC),
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                           elevation: 0,
                         ),
                         child: Text(_t('save_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       ),
                     ),
                   )
                ],
              ),
            );
          }
        );
      }
    );
  }
  Widget _buildMiniInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.blueGrey,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
  // --- EXPERTISE AND TRAMER DETAILS SHEET ---
  void _showExpertiseAndTramerSheet(Car car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return DefaultTabController(
              length: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      margin: const EdgeInsets.only(top: 15, bottom: 5),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_t('expertise_tramer'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tabs
                    TabBar(
                      labelColor: const Color(0xFF0059BC),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF0059BC),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: _t('expert_report_title')),
                        Tab(text: _t('tramer_repair_title')),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(child: _buildExpertiseTab(car)),
                          _buildTramerTab(car),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpertiseTab(Car car) {
     return Padding(
       padding: const EdgeInsets.all(20.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(_t('changed_painted_parts'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))), 
                TextButton(
                  onPressed: () => _showExpertiseEditorDialog(car),
                  child: Text(_t('edit_part_status'), style: const TextStyle(fontSize: 13)),
                )
              ],
            ),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_t('expertise_update_hint'), style: const TextStyle(color: Colors.blue, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Divider(),

            // List of Affected Parts
            if (car.expertiseReport.isEmpty)
               Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_t('no_expertise_data'))))
            else
               ..._getStandardPartKeys().map((key) { // Iterate STANDARDS, look up in report
                  String status = car.expertiseReport[key] ?? 'original';
                  if (status == 'original' || status == 'undefined') return const SizedBox.shrink(); // Hide clean parts
                  
                  Color color = Colors.orange;
                  String statusText = _t('part_painted');
                  if (status == 'changed') { color = Colors.red; statusText = _t('part_changed'); }
                  if (status == 'local_paint') { color = Colors.orangeAccent; statusText = _t('part_local_painted'); }
                  if (status == 'plastic') { color = Colors.black; statusText = _t('part_plastic'); }
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_getPartName(key), style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100], 
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.3)) 
                      ),
                      child: Text(statusText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  );
               }).toList(),
         ],
       ),
     );
  }

  Widget _buildTramerTab(Car car) {
    return Column(
      children: [
         // Add Tramer Button
         if (!widget.isReadOnly)
         Padding(
           padding: const EdgeInsets.all(20),
           child: ElevatedButton(
             onPressed: () => _showAddTramerDialog(car),
             style: ElevatedButton.styleFrom(
               backgroundColor: Theme.of(context).primaryColor,
               foregroundColor: Colors.white, // [FIX] Ensure text is visible
               minimumSize: const Size(double.infinity, 50),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             ),
             child: Text(_t('add_new_tramer_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
           ),
         ),
         
         // List
         Expanded(
           child: car.tramerRecords.isEmpty 
           ? Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
                   const SizedBox(height: 10),
                   Text(_t('no_tramer_saved'), style: const TextStyle(color: Colors.grey)),
                 ],
               )
             )
           : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: car.tramerRecords.length,
              itemBuilder: (context, index) {
                 final record = car.tramerRecords[index];
                 DateTime date = DateTime.now();
                 try {
                    if (record['date'] is Timestamp) date = (record['date'] as Timestamp).toDate();
                 } catch(_) {}
                 
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text(DateFormat('dd MMMM yyyy', LanguageService().currentLanguage == 'en' ? 'en_US' : 'tr_TR').format(date), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                             // Delete/Edit Menu
                             if (!widget.isReadOnly)
                             PopupMenuButton<String>(
                               padding: EdgeInsets.zero,
                               icon: const Icon(Icons.more_horiz),
                               onSelected: (value) async {
                                 if (value == 'edit') {
                                   _showAddTramerDialog(car, existingRecord: record, existingIndex: index);
                                 } else if (value == 'delete') {
                                   bool? confirm = await showDialog(
                                      context: context, 
                                      builder: (c) => AlertDialog(
                                        title: Text(_t('delete_record_title')),
                                        content: Text(_t('delete_tramer_confirm_msg')),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(_t('cancel'))),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(_t('delete'), style: const TextStyle(color: Colors.red))),
                                        ],
                                      )
                                   );
                                   if (confirm == true && uid != null) {
                                      await _firestoreService.deleteTramerRecord(uid!, car.id!, record);
                                   }
                                 }
                               },
                               itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        height: 35,
                                        child: Row(children: [const Icon(Icons.edit, color: Colors.blue, size: 20), const SizedBox(width: 8), Text(_t('edit'), style: const TextStyle(color: Colors.blue))]),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        height: 35,
                                        child: Row(children: [const Icon(Icons.delete, color: Colors.red, size: 20), const SizedBox(width: 8), Text(_t('delete'), style: const TextStyle(color: Colors.red))]),
                                      ),                            ],
                             )
                          ],
                        ),
                        // Split amount and menu to different rows or adjust layout
                        // Adjusting layout above: Date Left, Menu Right. Amount below?
                        // Let's keep original design but put amount below date
                         Row(
                          children: [
                             Builder(
                               builder: (context) {
                                 var isInsVal = record['isInsurance'];
                                 bool isCebimden = (isInsVal == false || isInsVal.toString() == 'false');
                                 
                                 return Row(
                                   children: [
                                      Text(
                                        "${NumberFormat('#,###', 'tr_TR').format(record['amount'])} ₺", 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 18, 
                                          decoration: isCebimden ? TextDecoration.lineThrough : null,
                                          color: isCebimden ? Colors.grey : Colors.red
                                        )
                                      ),
                                      if (isCebimden)
                                        Padding(
                                          padding: EdgeInsets.only(left: 6.0),
                                          child: Text("(${_t('out_of_pocket_type')})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ),
                                   ],
                                 );
                               }
                             ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_getLocalizedTramerDescription(record['description']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        if (record['parts'] != null && (record['parts'] as List).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Wrap(
                              spacing: 8,
                              children: (record['parts'] as List).map((p) => Chip(
                                label: Text(_getLocalizedTramerPart(p.toString()), style: TextStyle(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                                side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey.shade300),
                              )).toList(),
                            ),
                          ),
                     ],
                   ),
                 );
              }
            ),
         ),
         // [NEW] Total Tramer Footer
         Container(
           padding: const EdgeInsets.all(20),
           decoration: BoxDecoration(
             color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
           ),
           child: SafeArea(
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_t('total_tramer'), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text(_t('insurance_casco_label'), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      double total = 0;
                      for (var r in car.tramerRecords) {
                         // Robust check for false
                         var isInsVal = r['isInsurance'];
                         bool isCebimden = (isInsVal == false || isInsVal.toString().toLowerCase() == 'false');
                         
                         if (!isCebimden) {
                           double amt = 0;
                           if (r['amount'] is num) {
                             amt = (r['amount'] as num).toDouble();
                           } else if (r['amount'] is String) {
                             String s = r['amount'].toString().replaceAll(',', '.');
                             amt = double.tryParse(s) ?? 0;
                           }
                           total += amt;
                         }
                      }
                      return Text("${NumberFormat('#,###', 'tr_TR').format(total)} ₺", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0059BC)));
                    }
                  )
               ],
             ),
           ),
         )
      ],
    );
  }

  void _showAddTramerDialog(Car car, {Map<String, dynamic>? existingRecord, int? existingIndex}) {
     TextEditingController amountController = TextEditingController(text: existingRecord != null ? existingRecord['amount'].toString() : "");
     TextEditingController descController = TextEditingController(text: existingRecord != null ? existingRecord['description'] : "");
     TextEditingController locationController = TextEditingController(text: existingRecord != null ? existingRecord['location'] : "");
     
     DateTime selectedDate = existingRecord != null 
        ? ((existingRecord['date'] is Timestamp) ? (existingRecord['date'] as Timestamp).toDate() : DateTime.now()) 
        : DateTime.now();
        
     bool isInsurance = existingRecord != null ? (existingRecord['isInsurance'] ?? true) : true;
     
     // Selecting parts state - If editing, we should ideally load from record but record currently stores strings like "Kaput (Boyalı)".
     // Parsing that back is hard. 
     // BETTER APPROACH: Since Tramer record is a SNAPSHOT of change, maybe we don't allow editing parts? 
     // User requirement: "düzenleyebileyim".
     // If we just editing Amount/Desc/Location/PaymentType -> Easy.
     // If editing Parts -> Hard because we already updated the car's main expertise report.
     // Compromise: Allow editing Amount, Desc, Date, Location, PaymentType. 
     // FOR PARTS: Show "Parts cannot be edited here, please update via main report" or similar?
     // OR: Let them select parts, but realize it will update car expertise AGAIN.
     
     // Let's stick to standard behavior: Initialize with current Car expertise.
     Map<String, String> partStatuses = _normalizeExpertiseReport(car.expertiseReport); 
     Map<String, String> initialStatuses = Map.from(partStatuses); 

     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.transparent,
       builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateSheet) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              // [FIX] Padding applied to the wrapper around the container
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         children: [
                           Text(_t('new_tramer_record'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                           const Spacer(),
                           IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                         ],
                       ),
                       const SizedBox(height: 15),

                       // [NEW] Date Picker Row
                       GestureDetector(
                         onTap: () async {
                           DateTime? picked = await showDatePicker(
                             context: context,
                             initialDate: selectedDate,
                             firstDate: DateTime(1900),
                             lastDate: DateTime.now(),
                             locale: Locale(LanguageService().currentLanguage == 'en' ? 'en' : 'tr'),
                             builder: (context, child) {
                               return Theme(
                                 data: Theme.of(context).copyWith(
                                   colorScheme: ColorScheme.light(
                                     primary: const Color(0xFF0059BC), 
                                     onPrimary: Colors.white, 
                                     surface: isDark ? Colors.grey[900]! : Colors.white,
                                     onSurface: isDark ? Colors.white : Colors.black,
                                   ),
                                   dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
                                 ),
                                 child: child!,
                               );
                             }
                           );
                           if (picked != null && picked != selectedDate) {
                              setStateSheet(() {
                                 selectedDate = picked;
                              });
                           }
                         },
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                           decoration: BoxDecoration(
                             color: isDark ? Colors.grey[800] : Colors.grey[100],
                             borderRadius: BorderRadius.circular(10),
                             border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                           ),
                           child: Row(
                             children: [
                               const Icon(Icons.calendar_today, size: 20, color: Color(0xFF0059BC)),
                               const SizedBox(width: 10),
                               Text(
                                 DateFormat('dd MMMM yyyy', LanguageService().currentLanguage == 'en' ? 'en_US' : 'tr_TR').format(selectedDate),
                                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                               ),
                               const Spacer(),
                               const Icon(Icons.edit, size: 16, color: Colors.grey),
                             ],
                           ),
                         ),
                       ),
                       const SizedBox(height: 15),
                       
                       // [NEW] Payment Method Toggle
                       Container(
                         decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                         padding: const EdgeInsets.all(4),
                         child: Row(
                           children: [
                             Expanded(child: GestureDetector(
                               onTap: () => setStateSheet(() => isInsurance = true),
                               child: Container(
                                 padding: const EdgeInsets.symmetric(vertical: 10),
                                 decoration: BoxDecoration(color: isInsurance ? (isDark ? Colors.grey[700] : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: isInsurance ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : []),
                                 alignment: Alignment.center,
                                 child: Text(_t('insurance_casco_type'), style: const TextStyle(fontWeight: FontWeight.bold)),
                               ),
                             )),
                             Expanded(child: GestureDetector(
                               onTap: () => setStateSheet(() => isInsurance = false),
                               child: Container(
                                 padding: const EdgeInsets.symmetric(vertical: 10),
                                 decoration: BoxDecoration(color: !isInsurance ? (isDark ? Colors.grey[700] : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: !isInsurance ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : []),
                                 alignment: Alignment.center,
                                 child: Text(_t('out_of_pocket_type'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                               ),
                             )),
                           ],
                         ),
                       ),
                       if (!isInsurance)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 4),
                            child: Text(_t('out_of_pocket_info'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                       const SizedBox(height: 15),

                       Row(
                         children: [
                           Expanded(
                             child: TextField(
                               controller: amountController,
                               keyboardType: TextInputType.number,
                               decoration: InputDecoration(labelText: _t('amount_tl'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.currency_lira)),
                             ),
                           ),
                           const SizedBox(width: 10),
                           Expanded(
                             child: TextField(
                               controller: locationController,
                               decoration: InputDecoration(labelText: _t('repair_place_optional'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.store)),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 15),
                       
                       // [NEW] Quick Chips
                       SizedBox(
                         height: 35,
                         child: ListView(
                           scrollDirection: Axis.horizontal,
                           children: ['tag_accident', 'tag_collision', 'tag_scratch', 'tag_hail_damage', 'tag_parked_crash', 'tag_theft', 'tag_mini_repair'].map((key) {
                             String tag = _t(key);
                             final isSelected = descController.text.contains(tag);
                             return Padding(
                               padding: const EdgeInsets.only(right: 8.0),
                               child: FilterChip(
                                 label: Text(tag, style: TextStyle(fontSize: 11, color: isSelected ? Colors.blue[800] : Colors.black87)),
                                 selected: isSelected,
                                 showCheckmark: false,
                                 selectedColor: Colors.blue.withOpacity(0.15),
                                 backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                 side: BorderSide(color: isSelected ? Colors.blue : (isDark ? Colors.grey[700]! : Colors.grey.shade300)),
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                 onSelected: (bool selected) {
                                    String current = descController.text;
                                    String tagVal = _t(key); // Use localized value for text manipulation
                                    if (selected) {
                                      // Add
                                      if (current.isNotEmpty && !current.endsWith(' ')) current += ' ';
                                      current += tagVal;
                                    } else {
                                      // Remove
                                      current = current.replaceAll(tagVal, '').replaceAll('  ', ' ').trim();
                                    }
                                    
                                    descController.text = current;
                                    // Hack: Force rebuild to update chip state because descController listener isn't hooked to this builder
                                    setStateSheet(() {}); 
                                 },
                               ),
                             );
                           }).toList(),
                         ),
                       ),
                       const SizedBox(height: 8),

                       TextField(
                         controller: descController,
                         decoration: InputDecoration(labelText: _t('description_label'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.description)),
                       ),
                       const SizedBox(height: 20),
                       Text(_t('affected_parts_update_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       const SizedBox(height: 10),
                       Expanded(
                         child: SingleChildScrollView(
                           child: Wrap(
                             spacing: 8,
                             runSpacing: 8,
                             children: [
                               'hood', 'roof', 'trunk', 
                               'left_front_fender', 'right_front_fender', 'left_rear_fender', 'right_rear_fender',
                               'left_front_door', 'right_front_door', 'left_rear_door', 'right_rear_door',
                               'front_bumper', 'rear_bumper',
                               'left_rocker_panel', 'right_rocker_panel',
                               'left_a_pillar', 'right_a_pillar',
                               'left_b_pillar', 'right_b_pillar',
                               'left_c_pillar', 'right_c_pillar'
                             ].map((partKey) {
                               String status = partStatuses[partKey] ?? 'original';
                               
                               Color color = Colors.grey;
                               String text = _t('part_original');
                               
                               if (status == 'original') { color = Colors.grey; text = _t('part_original'); }
                               if (status == 'painted') { color = Colors.orange; text = _t('part_painted'); }
                               if (status == 'changed') { color = Colors.red; text = _t('part_changed'); }
                               if (status == 'local_paint') { color = Colors.orangeAccent; text = _t('part_local_painted'); }
                               if (status == 'plastic') { color = Colors.black; text = _t('part_plastic'); }

                               String initial = initialStatuses[partKey] ?? 'original';
                               bool isChanged = status != initial;
                               // If it has status but it's same as initial -> Dim it (Pre-existing)
                               // If it has status and it's changed -> Highlight it (New for Tramer)
                               
                               double opacity = (status != 'original' && !isChanged) ? 0.3 : 1.0; 
                               Color borderColor = isChanged ? color : ((status != 'original') ? color.withOpacity(0.3) : Colors.grey[300]!);
                               Color bgColor = (status == 'original') ? Colors.grey[100]! : color.withOpacity(isChanged ? 0.2 : 0.05);

                               return GestureDetector(
                                 onTap: () {
                                   setStateSheet(() {
                                      // Cycle status
                                      if (status == 'original') status = 'painted';
                                      else if (status == 'painted') status = 'changed';
                                      else if (status == 'changed') status = 'local_paint';
                                      else if (status == 'local_paint') status = 'plastic';
                                      else status = 'original';
                                      
                                      if (status == 'original') {
                                        partStatuses.remove(partKey);
                                      } else {
                                        partStatuses[partKey] = status;
                                      }
                                   });
                                 },
                                 child: Opacity(
                                   opacity: opacity,
                                   child: Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     decoration: BoxDecoration(
                                       color: bgColor,
                                       borderRadius: BorderRadius.circular(10),
                                       border: Border.all(color: borderColor, width: isChanged ? 2 : 1),
                                     ),
                                     child: Column(
                                       children: [
                                         Text(_getPartName(partKey), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                         const SizedBox(height: 2),
                                         Text(isChanged ? "${_t('label_new')}: $text" : (status != 'original' ? "${_t('label_current')}: $text" : text), 
                                           style: TextStyle(
                                           color: status == 'original' ? Colors.grey : color,
                                           fontSize: 10,
                                           fontWeight: FontWeight.bold
                                         )),
                                       ],
                                     ),
                                   ),
                                 ),
                               );
                             }).toList(),
                           ),
                         ),
                       ),
                       const SizedBox(height: 15),
                       Builder(
                         builder: (context) {
                           List<String> changes = [];
                           partStatuses.forEach((k, v) {
                              if (v != (initialStatuses[k] ?? 'original')) {
                                changes.add("${_getPartName(k)} -> ${_getStatusLabel(v)}");
                              }
                           });
                           
                           if (changes.isNotEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_t('tramer_changes_label'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    ...changes.map((c) => Text("• $c", style: const TextStyle(fontSize: 13, color: Colors.black87))).toList()
                                  ],
                                ),
                              );
                           }
                           return const SizedBox.shrink();
                         }
                       ),
                       const SizedBox(height: 10),
                       if (partStatuses.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Expanded(child: Text(_t('expertise_auto_update_warning'), style: const TextStyle(color: Colors.orange, fontSize: 12))),
                              ],
                            ),
                          ),
                       const SizedBox(height: 20),
                       ElevatedButton(
                         onPressed: () async {
                            if (amountController.text.isEmpty) return;
                            
                            String amountText = amountController.text.replaceAll(',', '.');
                            double amount = double.tryParse(amountText) ?? 0;
                            
                            // 1. Create Tramer Record
                             // Calculate Diff for Tramer Record
                             List<String> changedPartsForRecord = [];
                             partStatuses.forEach((key, status) {
                                if (status != (initialStatuses[key] ?? 'original')) {
                                   changedPartsForRecord.add("${_getPartName(key)} (${_getStatusLabel(status)})");
                                }
                             });

                             Map<String, dynamic> newRecord = {
                                'date': Timestamp.fromDate(selectedDate),
                                'amount': amount,
                                'description': descController.text,
                                'location': locationController.text, // [NEW]
                                'isInsurance': isInsurance, // [NEW]
                                'parts': changedPartsForRecord 
                             };
                             
                             if (uid != null && car.id != null) {
                                try {
                                   if (existingIndex != null && existingRecord != null) {
                                      // UPDATE EXISTING
                                      // Logic: remove old, add new (or update in place)
                                      // FirestoreService doesn't have updateAtIndex. We must replace the whole list or delete/add.
                                      // Safest: Modify local list, then updateCar (sets the whole object).
                                      
                                      List<Map<String, dynamic>> updatedRecords = List.from(car.tramerRecords);
                                      updatedRecords[existingIndex] = newRecord;
                                      car.tramerRecords = updatedRecords;
                                      
                                      await _firestoreService.updateCar(uid!, car);
                                   } else {
                                      // ADD NEW
                                      await _firestoreService.addTramerRecord(uid!, car.id!, newRecord);
                                       // Optimistic Update
                                      List<Map<String, dynamic>> updatedRecords = List.from(car.tramerRecords);
                                      updatedRecords.add(newRecord);
                                      car.tramerRecords = updatedRecords;
                                   }
                                   
                                   // 2. Update Expertise Report if parts selected
                                   if (partStatuses.isNotEmpty) {
                                      Map<String, String> currentReport = Map<String, String>.from(car.expertiseReport);
                                      currentReport = _normalizeExpertiseReport(currentReport);
                                      partStatuses.forEach((key, status) {
                                         currentReport[key] = status;
                                      });
                                      car.expertiseReport = currentReport;
                                      await _firestoreService.updateCar(uid!, car);
                                   }
                                } catch (e) {
                                   debugPrint("Error saving Tramer: $e");
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${_t('error_prefix')} $e")));
                                }
                             }
                             
                             if (context.mounted) Navigator.pop(context); 
                             setState(() { }); 
                         },
                         style: ElevatedButton.styleFrom(
                           minimumSize: const Size(double.infinity, 50), 
                           backgroundColor: Theme.of(context).primaryColor, 
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         ),
                         child: Text(_t('save_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       )
                    ],
                  ),
                ),
              );
            }
          );
       }
     );
  }

  // Normalizes keys to standard format (left_front instead of front_left, hood instead of bonnet)
  Map<String, String> _normalizeExpertiseReport(Map<String, String> report) {
     Map<String, String> normalized = {};
     
     final validKeys = _getStandardPartKeys();

     report.forEach((key, status) {
        String standardKey = key;
        
        // Map aliases to standard
        if (key == 'bonnet') standardKey = 'hood';
        if (key == 'front_left_fender') standardKey = 'left_front_fender';
        if (key == 'front_right_fender') standardKey = 'right_front_fender';
        if (key == 'rear_left_fender') standardKey = 'left_rear_fender';
        if (key == 'rear_right_fender') standardKey = 'right_rear_fender';
        
        if (key == 'front_left_door') standardKey = 'left_front_door';
        if (key == 'front_right_door') standardKey = 'right_front_door';
        if (key == 'rear_left_door') standardKey = 'left_rear_door';
        if (key == 'rear_right_door') standardKey = 'right_rear_door';
        
        // Add only if valid
        if (validKeys.contains(standardKey)) {
             normalized[standardKey] = status;
        }
     });
     
     return normalized;
  }
  
  // Single source of truth for ordered keys
  List<String> _getStandardPartKeys() {
    return [
      'hood', 'roof',
      'trunk', 'left_front_fender', // Standardized: left_front...
      'right_front_fender', 'left_rear_fender',
      'right_rear_fender', 'left_front_door',
      'right_front_door', 'left_rear_door',
      'right_rear_door', 'front_bumper', 
      'rear_bumper', 'left_rocker_panel',
      'right_rocker_panel', 'left_a_pillar',
      'right_a_pillar', 'left_b_pillar', 'right_b_pillar',
      'left_c_pillar', 'right_c_pillar'
    ];
  }



  String _getPartName(String key) {
    if (key == 'bonnet') key = 'hood';
    if (key == 'front_left_fender') key = 'left_front_fender';
    if (key == 'front_right_fender') key = 'right_front_fender';
    if (key == 'rear_left_fender') key = 'left_rear_fender';
    if (key == 'rear_right_fender') key = 'right_rear_fender';
    if (key == 'front_left_door') key = 'left_front_door';
    if (key == 'front_right_door') key = 'right_front_door';
    if (key == 'rear_left_door') key = 'left_rear_door';
    if (key == 'rear_right_door') key = 'right_rear_door';

    return _t('part_$key');
  }

  String _getStatusLabel(String? status) {
    if (status == 'painted') return _t('part_painted');
    if (status == 'changed') return _t('part_changed');
    if (status == 'local_paint') return _t('part_local_painted');
    if (status == 'plastic') return _t('part_plastic');
    return _t('part_original');
  }
  String _getLocalizedAction(String? action) {
    if (action == null || action.isEmpty) return _t('maintenance_default_title');
    // Check if it's already a key
    if (action.startsWith('maint_action_')) return _t(action);
    
    // Map legacy strings (Case Insensitive)
    switch (action.toLowerCase()) {
      case 'periyodik bakım':
      case 'periodic maintenance': 
      case 'periodik bakım': // Handle typo/variant from backend/legacy
        return _t('maint_action_periodic');
      case 'yağ değişimi': 
      case 'oil change':
        return _t('maint_action_oil_change');
      case 'fren bakımı': 
      case 'brake maintenance':
        return _t('maint_action_brake_maint');
      case 'lastik değişimi': 
      case 'tire change':
        return _t('maint_action_tire_change');
      case 'tamir': 
      case 'repair': 
        return _t('maint_action_repair'); 
    }
    return action;
  }

  String _getLocalizedParts(String? parts) {
    if (parts == null || parts.isEmpty) return '';
    // Split by comma
    List<String> items = parts.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    List<String> localizedItems = items.map((item) {
       if (item.startsWith('maint_part_')) return _t(item);
       
       // Map legacy
       switch(item) {
         case 'Motor Yağı': return _t('maint_part_motor_oil');
         case 'Yağ Filtresi': return _t('maint_part_oil_filter');
         case 'Hava Filtresi': return _t('maint_part_air_filter');
         case 'Polen Filtresi': return _t('maint_part_cabin_filter');
         case 'Yakıt Filtresi': return _t('maint_part_fuel_filter');
         case 'Fren Balatası': return _t('maint_part_brake_pad');
         case 'Fren Diski': return _t('maint_part_brake_disc');
         case 'Baskı Balata': return _t('maint_part_clutch');
         case 'Buji': return _t('maint_part_spark_plug');
         case 'Rot Ayarı': return _t('maint_part_alignment');
         case 'Silecek': return _t('maint_part_wiper');
         case 'Akü': return _t('maint_part_battery');
       }
       return item;
    }).toList();
    
    return localizedItems.join(', ');
  }

  String _getLocalizedTramerDescription(String? desc) {
    if (desc == null || desc.isEmpty) return _t('no_damage_description');
    
    // Tramer description is often just a set of tags separated by spaces "Kaza Çarpışma"
    // We try to tokenize and translate known tags.
    List<String> tokens = desc.split(' ');
    List<String> localizedTokens = tokens.map((token) {
       String t = token.trim();
       if (t.isEmpty) return '';
       
       // Check keys
       if (t == 'tag_accident' || t == 'Kaza') return _t('tag_accident');
       if (t == 'tag_collision' || t == 'Çarpışma') return _t('tag_collision');
       if (t == 'tag_scratch' || t == 'Sürtme') return _t('tag_scratch');
       if (t == 'tag_hail_damage' || t == 'Dolu Hasarı') return _t('tag_hail_damage');
       if (t == 'tag_parked_crash' || t == 'Park Halinde Çarpma') return _t('tag_parked_crash'); // Spaces inside might break split
       if (t == 'tag_theft' || t == 'Gasp/Hırsızlık') return _t('tag_theft');
       if (t == 'tag_mini_repair' || t == 'Mini Onarım') return _t('tag_mini_repair');
       
       // Handle multi-word legacy tags gracefully?
       // If token is just "Park", "Halinde", "Çarpma" -> logic breaks.
       // However, Tramer tags are stored as single strings usually? 
       // Only "Park Halinde Çarpma" and "Dolu Hasarı" and "Mini Onarım" have spaces.
       // A simple split(' ') destroys them.
       
       return token;
    }).toList();
    
    // Better approach: Replace known phrases in the full string
    String result = desc;
    result = result.replaceAll('tag_accident', _t('tag_accident')).replaceAll('Kaza', _t('tag_accident'));
    result = result.replaceAll('tag_collision', _t('tag_collision')).replaceAll('Çarpışma', _t('tag_collision'));
    result = result.replaceAll('tag_scratch', _t('tag_scratch')).replaceAll('Sürtme', _t('tag_scratch'));
    
    // Multi-word tags - be careful with order (longest first)
    result = result.replaceAll('tag_parked_crash', _t('tag_parked_crash')).replaceAll('Park Halinde Çarpma', _t('tag_parked_crash'));
    result = result.replaceAll('tag_hail_damage', _t('tag_hail_damage')).replaceAll('Dolu Hasarı', _t('tag_hail_damage'));
    result = result.replaceAll('tag_mini_repair', _t('tag_mini_repair')).replaceAll('Mini Onarım', _t('tag_mini_repair'));
    result = result.replaceAll('tag_theft', _t('tag_theft')).replaceAll('Gasp/Hırsızlık', _t('tag_theft'));

    return result;
  }

  String _getLocalizedTramerPart(String partStr) {
     // Format: "Kaput (Boyalı)" or "Hood (Painted)" or "Kaput: Boyalı"
     // We need to parse 
     // 1. Part Name
     // 2. Status
     
     // Regex to capture "Name (Status)"
     // Status mapping:
     // Boyalı -> _t('part_painted')
     // Değişen -> _t('part_changed')
     // Lokal Boyalı -> _t('part_local_painted')
     // Plastik -> _t('part_plastic')
     // Orjinal -> _t('part_original')
     // YENİ -> _t('label_new')
     // Mevcut -> _t('label_current')

     String result = partStr;
     
     // Translate Statuses inside parens
     result = result.replaceAll('(Boyalı)', '(${_t('part_painted')})');
     result = result.replaceAll('(Değişen)', '(${_t('part_changed')})');
     result = result.replaceAll('(Lokal Boyalı)', '(${_t('part_local_painted')})');
     result = result.replaceAll('(Plastik)', '(${_t('part_plastic')})');
     
     // Translate Prefixes
     result = result.replaceAll('YENİ:', '${_t('label_new')}:');
     result = result.replaceAll('Mevcut:', '${_t('label_current')}:');
     
     // Translate Part Names (Basic ones)
     // This is hard because we have many parts. 
     // Ideally we should have a _getLocalizedPartName(key) but here we have raw strings.
     // We can try to map known Turkish part names to keys.
     Map<String, String> partMap = {
       'Kaput': 'part_hood',
       'Tavan': 'part_roof',
       'Ön Tampon': 'part_front_bumper',
       'Arka Tampon': 'part_rear_bumper',
       'Sol Ön Çamurluk': 'part_left_front_fender',
       'Sağ Ön Çamurluk': 'part_right_front_fender',
       'Sol Ön Kapı': 'part_left_front_door',
       'Sağ Ön Kapı': 'part_right_front_door',
       'Sol Arka Kapı': 'part_left_rear_door',
       'Sağ Arka Kapı': 'part_right_rear_door',
       'Sol Arka Çamurluk': 'part_left_rear_fender',
       'Sağ Arka Çamurluk': 'part_right_rear_fender',
       'Bagaj': 'part_trunk',
     };
     
     partMap.forEach((trName, key) {
        if (result.contains(trName)) {
           result = result.replaceAll(trName, _t(key));
        }
     });

     return result;
  }
} // Restored brace

// --- BAKIM EKLEME SAYFASI (AYNI) ---
class AddMaintenanceScreen extends StatefulWidget {
  final Car car;
  final bool isSheet;
  final Map<String, dynamic>? initialData; // [NEW] Retry için veri taşıma
  const AddMaintenanceScreen({Key? key, required this.car, this.isSheet = false, this.initialData}) : super(key: key);

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {

  // Correct Localization Helper
  String _t(String key) {
     return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  final _actionController = TextEditingController();
  final _dateController = TextEditingController();
  final _kmController = TextEditingController();
  final _serviceController = TextEditingController();
  final _costController = TextEditingController();
  final _partsController = TextEditingController();

  // Controllers kept for compatibility with submit logic, but populated by dropdowns
  final _oilBrandController = TextEditingController();
  final _oilModelController = TextEditingController();
  final _oilViscosityController = TextEditingController();

  // Selection State
  String? _selectedOilBrand;
  String? _selectedOilModel;
  String? _selectedOilViscosity;

  final List<String> _actionSuggestions = [
    "maint_action_periodic",
    "maint_action_oil_change",
    "maint_action_brake_maint", 
    "maint_action_tire_change",
    "maint_action_repair"
  ];

  final List<String> _partSuggestions = [
    "maint_part_motor_oil",
    "maint_part_oil_filter",
    "maint_part_air_filter",
    "maint_part_cabin_filter",
    "maint_part_fuel_filter",
    "maint_part_brake_pad",
    "maint_part_brake_disc",
    "maint_part_clutch",
    "maint_part_spark_plug",
    "maint_part_alignment",
    "maint_part_wiper",
    "maint_part_battery",
  ];



  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.initialData != null) {
      // RETRY DURUMU: Verileri doldur
      final data = widget.initialData!;
      _actionController.text = data['action'] ?? '';
      _dateController.text = data['date'] ?? "${now.day}/${now.month}/${now.year}";
      _kmController.text = data['km']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      _serviceController.text = data['service'] ?? '';
      _costController.text = data['cost']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      _partsController.text = data['parts'] ?? '';
      
      // Oil Restoring (Safe)
      String? iBrand = data['oilBrand'];
      String? iModel = data['oilModel'];
      String? iViscosity = data['oilViscosity'];

      // Validate against catalog to prevent Dropdown crash
      if (iBrand != null && OilCatalog.getBrands().contains(iBrand)) {
          _selectedOilBrand = iBrand;
          _oilBrandController.text = iBrand;

          if (iModel != null && OilCatalog.getModels(iBrand).contains(iModel)) {
              _selectedOilModel = iModel;
              _oilModelController.text = iModel;

               if (iViscosity != null && OilCatalog.getViscosities(iBrand, iModel).contains(iViscosity)) {
                    _selectedOilViscosity = iViscosity;
                    _oilViscosityController.text = iViscosity;
               }
          }
      }
      
    } else {
      // SIFIR DURUM
       _dateController.text = "${now.day}/${now.month}/${now.year}";
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
         return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0059BC), 
              onPrimary: Colors.white, 
              onSurface: Colors.black, 
            ),
          ),
          child: child!,
        );
      }
    );

    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _setAction(String action) {
    _actionController.text = action;
  }

  void _addPartNote(String part) {
    List<String> currentParts = _partsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (currentParts.contains(part)) {
      currentParts.remove(part);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('msg_part_removed').replaceAll('{part}', part)),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      currentParts.add(part);
    }

    _partsController.text = currentParts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent = _buildBody(context);

    if (widget.isSheet) {
        return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[50], 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25))
            ),
            child: Column(
                children: [
                    Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(top: 10, bottom: 10), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                                Text(_t('new_maintenance_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                            ]
                        )
                    ),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(25), child: bodyContent))
                ]
            )
        );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('new_maintenance_title'), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E272E),
        elevation: 0,
      ),
      body: bodyContent,
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      // [FIX] Add keyboard padding to the bottom
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
            _buildActionInput(_t('maintenance_action'), _actionController, Icons.build),
            const SizedBox(height: 15),
            
            _buildDateInput(),
            const SizedBox(height: 15),

            _buildNumberInput(_t('maintenance_km'), _kmController, Icons.speed, "KM"),
            const SizedBox(height: 15),

            // OIL SELECTION (Restored)
            _buildOilSelectionInput(),
            const SizedBox(height: 15),

            _buildTextInput(_t('maintenance_service_shop'), _serviceController, Icons.store),
            const SizedBox(height: 15),

            _buildNumberInput(_t('maintenance_cost'), _costController, Icons.attach_money, "TL"),
            const SizedBox(height: 15),

            _buildPartsInput(),

            const SizedBox(height: 25),
            
            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveMaintenance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 5,
                  shadowColor: const Color(0xFF0059BC).withOpacity(0.4),
                ),
                child: Text(
                  _t('save_btn'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 30), // Bottom padding
        ],
      ),
    );
  }

  // --- HELPER METHODS ---

  void _saveMaintenance() {
    if (_actionController.text.isNotEmpty) {
      Navigator.pop(context, {
        'date': _dateController.text,
        'action': _actionController.text,
        'km': _kmController.text,
        'service': _serviceController.text,
        'cost': _costController.text,
        'parts': _partsController.text,
        'oilBrand': _oilBrandController.text,
        'oilModel': _oilModelController.text,
        'oilViscosity': _oilViscosityController.text,
      });
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(_t('maintenance_action_error')), backgroundColor: Theme.of(context).colorScheme.error),
       );
    }
  }

  Widget _buildActionInput(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _actionSuggestions.map((actionKey) {
              final actionLabel = _t(actionKey);
              final isSelected = controller.text == actionLabel;
              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: ActionChip(
                  label: Text(actionLabel),
                  backgroundColor: isSelected ? const Color(0xFF0059BC) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : const Color(0xFF1E272E)), fontWeight: FontWeight.w600),
                  onPressed: () => _setAction(actionLabel),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: _t('maintenance_custom_hint'),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            prefixIcon: Icon(icon, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildDateInput() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
                child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF0059BC)),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('maintenance_date'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(_dateController.text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E272E))),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput(String label, TextEditingController controller, IconData icon, String suffix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          decoration: InputDecoration(
            hintText: "0",
            suffixText: suffix,
            filled: true, 
            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100], 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            prefixIcon: Icon(icon, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: _t('hint_service_shop'),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPartsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('maintenance_parts_notes'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _partSuggestions.map((partKey) {
               final partLabel = _t(partKey);
               final currentText = _partsController.text.toLowerCase();
               final isSelected = currentText.contains(partLabel.toLowerCase());
               
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(partLabel),
                  selected: isSelected,
                  onSelected: (selected) => _addPartNote(partLabel),
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                  selectedColor: const Color(0xFF0059BC).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF0059BC) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? const Color(0xFF0059BC) : Colors.grey.shade300),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _partsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: _t('maintenance_parts_hint'), 
            filled: true, 
            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100], 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
          ),
        ),
      ],
    );
  }

  Widget _buildOilSelectionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_t('oil_selection_title'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
            if (_selectedOilBrand != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedOilBrand = null;
                    _selectedOilModel = null;
                    _selectedOilViscosity = null;
                    _oilBrandController.clear();
                    _oilModelController.clear();
                    _oilViscosityController.clear();
                  });
                },
                child: Text(_t('clear_btn'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
              )
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              // Brand Selector
              InputDecorator(
                decoration: InputDecoration(
                   border: InputBorder.none,
                   contentPadding: EdgeInsets.zero,
                   prefixIcon: _selectedOilBrand != null 
                     ? Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Image.network(
                           BrandData.getLogoUrl(_selectedOilBrand!),
                           width: 24, height: 24, fit: BoxFit.contain,
                           errorBuilder: (c,e,s) => const Icon(Icons.water_drop, color: Colors.orange),
                         ),
                       )
                     : const Icon(Icons.water_drop, color: Colors.orange),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOilBrand,
                    hint: Text(_t('select_oil_brand')),
                    isExpanded: true,
                    dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                    items: OilCatalog.getBrands().map((brand) {
                       return DropdownMenuItem(
                         value: brand,
                         child: Row(
                           children: [
                             Image.network(
                               BrandData.getLogoUrl(brand),
                               width: 24, height: 24, fit: BoxFit.contain,
                               errorBuilder: (c,e,s) => const Icon(Icons.water_drop, size: 20, color: Colors.grey),
                             ),
                             const SizedBox(width: 10),
                             Text(brand),
                           ],
                         ),
                       );
                    }).toList(),
                    onChanged: (String? val) {
                      setState(() {
                        _selectedOilBrand = val;
                        _selectedOilModel = null;
                        _selectedOilViscosity = null;
                        _oilBrandController.text = val ?? "";
                        _oilModelController.text = "";
                        _oilViscosityController.text = "";
                      });
                    },
                  ),
                ),
              ),
              const Divider(),
              
              // Model Selector
              InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  prefixIcon: const Icon(Icons.label, color: Colors.orange),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOilModel,
                    hint: Text(_t('select_model')),
                    disabledHint: Text(_t('hint_select_brand_first')),
                    isExpanded: true,
                    dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                    items: (_selectedOilBrand != null)
                      ? OilCatalog.getModels(_selectedOilBrand!).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList()
                      : [],
                    onChanged: (_selectedOilBrand == null) ? null : (String? val) {
                        setState(() {
                          _selectedOilModel = val;
                          _selectedOilViscosity = null;
                          _oilModelController.text = val ?? "";
                          _oilViscosityController.text = "";
                        });
                    },
                  ),
                ),
              ),
              const Divider(),

              // Viscosity Selector
              InputDecorator(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.opacity, color: Colors.orange),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOilViscosity,
                    onChanged: (_selectedOilModel == null) ? null : (String? val) {
                        if (val != null) setState(() => _selectedOilViscosity = val);
                        _oilViscosityController.text = val ?? "";
                    },
                    hint: Text(_t('select_viscosity')),
                    isExpanded: true,
                    dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                    items: (_selectedOilBrand != null && _selectedOilModel != null)
                      ? OilCatalog.getViscosities(_selectedOilBrand!, _selectedOilModel!).map((v) => DropdownMenuItem(value: v, child: Text(v))).toList()
                      : [],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


}
