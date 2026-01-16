import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/car_model.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'turkish_license_plate.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class PagedCarCard extends StatefulWidget {
  final Car car;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEditKm;

  const PagedCarCard({
    Key? key,
    required this.car,
    required this.onTap,
    this.onDelete,
    this.onEditKm,
  }) : super(key: key);

  @override
  State<PagedCarCard> createState() => _PagedCarCardState();
}

class _PagedCarCardState extends State<PagedCarCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Use pickMultiImage to allow selecting multiple photos
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
    
    if (images.isNotEmpty) {
      List<String> newPhotos = [];
      for (var image in images) {
        final bytes = await image.readAsBytes();
        newPhotos.add(base64Encode(bytes));
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && widget.car.id != null) {
        setState(() {
          widget.car.photos.addAll(newPhotos); // Add to existing photos
        });

        try {
          await _firestoreService.updateCar(user.uid, widget.car);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${newPhotos.length} fotoğraf eklendi.")),
            );
          }
        } catch (e) {
          debugPrint("Fotoğraflar kaydedilirken hata: $e");
        }
      }
    }
  }

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Collect pages
    List<Widget> pages = [
      _buildMainPage(isDark),
      if (widget.car.technicalSpecs.isNotEmpty) _buildSpecsPage(isDark),
      if (widget.car.technicalSpecs.length > 6) _buildDimensionsPage(isDark),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. MAIN CARD (White in Light, CardColor in Dark)
          Card(
            elevation: 8,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            color: Theme.of(context).cardColor,
            child: Container(
              height: 320, // Standardized height
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16), // Reduced top padding
              child: Stack(
                children: [
                  PageView(
                    physics: const NeverScrollableScrollPhysics(), // Disable swipe
                    controller: _pageController,
                    onPageChanged: (int page) => setState(() => _currentPage = page),
                    children: pages,
                  ),
                  
                  // Indicators (Dots) inside the card bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(pages.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentPage == index ? Theme.of(context).primaryColor : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Navigation Arrows
                  if (_currentPage > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.chevron_left, color: isDark ? Colors.grey.shade600 : Colors.grey.shade300, size: 28),
                        onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                    ),
                  if (_currentPage < pages.length - 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey.shade300, size: 28),
                        onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. KM DISPLAY (Floating at bottom, ensuring clickability)
          if (_currentPage == 0)
            Positioned(
              bottom: 15,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Current KM Display (Visual only)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     decoration: BoxDecoration(
                       color: isDark ? Theme.of(context).primaryColor.withOpacity(0.15) : const Color(0xFFE3F2FD), 
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                     ),
                     child: Text(
                       "${widget.car.currentKm} KM",
                       style: TextStyle(
                         color: isDark ? Colors.white : const Color(0xFF1565C0),
                         fontWeight: FontWeight.bold,
                         fontSize: 14,
                       ),
                     ),
                   ),
                   const SizedBox(height: 8),
                   // Update Button (Action)
                   ElevatedButton.icon(
                      onPressed: () {
                         debugPrint("DEBUG: KM Update Button Tapped");
                         widget.onEditKm?.call();
                      },
                      icon: const Icon(Icons.speed, size: 18), // Updated icon
                      label: Text(_t('update_km'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                        elevation: 4,
                        shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Theme.of(context).primaryColor, width: 1.5), // Thicker border
                        ),
                      ),
                   ),
                ],
              ),
            ),

            // 2. FOTOĞRAF EKLE BUTTON (Overlapping top)
            Positioned(
              top: -15,
              left: 0,
              right: 0,
              height: 60, // Constrain height to prevent blocking touches below
              child: Center(
                child: Material( // Wrap with Material to properly handle InkWell separate from Card
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap, // Link to details
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.drive_file_rename_outline, size: 16, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            _t('edit'),
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7) ?? Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildMainPage(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start, // Push content up
      children: [
        const SizedBox(height: 20), // Top spacer
        
        // Brand/Model Name (Centered, Multi-line)
        InkWell(
          onTap: widget.onTap,
          child: Text(
            widget.car.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Subtitle (Optional, if exists like "M-Technic" in image)
        if (widget.car.hardware?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.car.hardware!,
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 13),
            ),
          ),


        const SizedBox(height: 10),

        // License Plate (Centered)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.car.plate != null && widget.car.plate!.isNotEmpty)
              TurkishLicensePlate(plate: widget.car.plate!),
          ],
        ),
        
        const SizedBox(height: 10),

        // KM DISPLAY (Centered with pencil icon)
        // KM DISPLAY (Centered with pencil icon)
        const SizedBox(height: 70), // Reserve space for the floating KM button
      ],
    );
  }

  Widget _buildSpecsPage(bool isDark) {
    Map<String, String> specs = widget.car.technicalSpecs;
    List<MapEntry<String, String>> entries = specs.entries
        .where((e) => ["Motor Hacmi", "Maksimum Güç", "Maksimum Tork", "0-100 Hızlanma", "Maksimum Hız"].any((k) => e.key.contains(k)))
        .toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Text("Motor & Performans", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A), fontSize: 18, fontWeight: FontWeight.bold)),
         const SizedBox(height: 10),
         Expanded(
           child: GridView.builder(
             padding: const EdgeInsets.symmetric(horizontal: 10),
             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 2,
               childAspectRatio: 3,
             ),
             itemCount: entries.length,
             itemBuilder: (context, index) {
               return Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(entries[index].key, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 11), textAlign: TextAlign.center),
                   Text(entries[index].value, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF333333), fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                 ],
               );
             },
           ),
         )
      ],
    );
  }

  Widget _buildDimensionsPage(bool isDark) {
    Map<String, String> specs = widget.car.technicalSpecs;
    List<MapEntry<String, String>> entries = specs.entries
        .where((e) => ["Tüketim", "Uzunluk", "Genişlik", "Bagaj", "Yakıt Deposu"].any((k) => e.key.contains(k)))
        .toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Text("Boyutlar & Tüketim", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A), fontSize: 18, fontWeight: FontWeight.bold)),
         const SizedBox(height: 10),
         Expanded(
           child: GridView.builder(
             padding: const EdgeInsets.symmetric(horizontal: 10),
             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 2,
               childAspectRatio: 3,
             ),
             itemCount: entries.length,
             itemBuilder: (context, index) {
               return Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(entries[index].key, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 11), textAlign: TextAlign.center),
                   Text(entries[index].value, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF333333), fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                 ],
               );
             },
           ),
         )
      ],
    );
  }
}
