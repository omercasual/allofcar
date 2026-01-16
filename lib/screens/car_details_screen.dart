import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/car_model.dart';
import '../services/firestore_service.dart';
import 'gallery_screen.dart';
import '../utils/app_localizations.dart';
import '../services/language_service.dart';

class CarDetailsScreen extends StatefulWidget {
  final Car car;

  const CarDetailsScreen({Key? key, required this.car}) : super(key: key);

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "-";
    return "${date.day}.${date.month}.${date.year}";
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Limit size
        imageQuality: 70, // Compress
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final String base64Image = base64Encode(bytes);
        
        setState(() {
          widget.car.photos.add(base64Image);
        });

        // Update Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestoreService.updateCar(user.uid, widget.car);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fotoğraf eklenirken hata: $e")),
      );
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      widget.car.photos.removeAt(index);
      if (_currentImageIndex >= widget.car.photos.length) {
        _currentImageIndex = 0;
      }
    });
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreService.updateCar(user.uid, widget.car);
    }
  }

  Widget _buildPhotoSlider() {
    if (widget.car.photos.isEmpty) {
      return Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0059BC), const Color(0xFF003C8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 80, color: Colors.white24),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_a_photo, color: Color(0xFF0059BC)),
              label: Text(_t('add_photo_btn'), style: const TextStyle(color: Color(0xFF0059BC))),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            )
          ],
        ),
      );
    }

    return Container(
      height: 250,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.car.photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GalleryScreen(
                        car: widget.car,
                        onUpdate: () => setState(() {}),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                  child: Image.memory(
                    base64Decode(widget.car.photos[index]),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              );
            },
          ),
          // Gradient Overlay Top
           Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(0)), // Only top visual
              ),
            ),
          ),
          // Delete Button
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white, size: 28),
              onPressed: () => _removeImage(_currentImageIndex),
              tooltip: _t('delete_photo_tooltip'),
            ),
          ),
          // Add Button (Floating on image)
          Positioned(
            top: 40,
            right: 50,
            child: IconButton(
              icon: const Icon(Icons.add_a_photo, color: Colors.white, size: 28),
              onPressed: _pickImage,
              tooltip: _t('add_photo_btn'),
            ),
          ),
          // Indicator
          Positioned(
            bottom: 15,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.car.photos.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentImageIndex == index ? 12 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0059BC).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0059BC), size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true, // For transparent app bar effect over images
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 5)]),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Text(
          widget.car.name,
           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold,  shadows: [Shadow(color: Colors.black45, blurRadius: 5)]),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. CAROUSEL SECTION
            _buildPhotoSlider(),
            
            // 2. MAIN HEADER (Name etc.)
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      widget.car.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // CUSTOM LICENSE PLATE
                    Container(
                      width: 180,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white, // Plate usually white
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Blue Strip (TR)
                          Container(
                            width: 35,
                            decoration: const BoxDecoration(
                              color: Color(0xFF003399),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: const [
                                Text(
                                  "TR",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                SizedBox(height: 3),
                              ],
                            ),
                          ),
                          // Plate Number
                          Expanded(
                            child: Center(
                              child: Text(
                                (widget.car.plate ?? "-").toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontFamily: "RobotoMono", // Monospace-ish look
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // KM Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.speed, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "${widget.car.currentKm} KM",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 3. DETAILS LIST
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.calendar_today,

                    title: _t('first_registration_date'),
                    value: _formatDate(widget.car.trafficReleaseDate),
                    subtitle: _t('immutable_label'),
                  ),
                  _buildInfoTile(
                    icon: Icons.branding_watermark,
                    title: _t('brand'),
                    value: widget.car.brand ?? "-",
                  ),
                  _buildInfoTile(
                    icon: Icons.directions_car,
                    title: _t('model'),
                    value: widget.car.model ?? "-",
                  ),
                  _buildInfoTile(
                    icon: Icons.confirmation_number,
                    title: _t('plate'),
                    value: widget.car.plate ?? "-",
                    subtitle: _t('immutable_label'),
                  ),
                  _buildInfoTile(
                    icon: Icons.calendar_view_day,
                    title: _t('model_year'),
                    value: widget.car.modelYear?.toString() ?? "-",
                    subtitle: _t('immutable_label'),
                  ),
                   _buildInfoTile(
                    icon: Icons.vpn_key,
                    title: _t('ownership_date'),
                    value: _formatDate(widget.car.ownershipDate),
                    subtitle: _t('immutable_label'),
                  ),
                   _buildInfoTile(
                    icon: Icons.speed,
                    title: _t('current_km_label'),
                    value: "${widget.car.currentKm} KM",
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
