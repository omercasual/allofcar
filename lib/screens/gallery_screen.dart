import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/car_model.dart';
import '../services/firestore_service.dart';

class GalleryScreen extends StatefulWidget {
  final Car car;
  final VoidCallback? onUpdate; // Callback to refresh parent state

  const GalleryScreen({Key? key, required this.car, this.onUpdate}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  Future<void> _setCoverPhoto() async {
    if (_currentIndex == 0) return; // Already cover

    setState(() {
      _isLoading = true;
    });

    try {
      final String selectedPhoto = widget.car.photos[_currentIndex];
      
      // Move to index 0 locally
      setState(() {
        widget.car.photos.removeAt(_currentIndex);
        widget.car.photos.insert(0, selectedPhoto);
        _currentIndex = 0;
        _pageController.jumpToPage(0);
      });

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestoreService.updateCar(user.uid, widget.car);
        widget.onUpdate?.call();
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kapak fotoğrafı güncellendi!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePhoto() async {
    setState(() => _isLoading = true);
    
    try {
      setState(() {
        widget.car.photos.removeAt(_currentIndex);
        if (_currentIndex >= widget.car.photos.length) {
          _currentIndex = widget.car.photos.length - 1;
        }
        if (_currentIndex < 0) _currentIndex = 0;
      });

       // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestoreService.updateCar(user.uid, widget.car);
        widget.onUpdate?.call();
      }

      if (widget.car.photos.isEmpty && mounted) {
        Navigator.pop(context); // Close if no photos left
      }
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.car.photos.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.car.photos.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) {
                if (val == 'cover') _setCoverPhoto();
                if (val == 'delete') _deletePhoto();
              },
              itemBuilder: (context) => [
                if (_currentIndex != 0)
                  const PopupMenuItem(
                    value: 'cover',
                    child: Row(
                      children: [
                        Icon(Icons.photo_album, size: 20, color: Colors.black87),
                        SizedBox(width: 10),
                        Text("Kapak Fotoğrafı Yap"),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 10),
                      Text("Sil", style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.car.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Center(
                  child: Image.memory(
                    base64Decode(widget.car.photos[index]),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Thumbnail Strip
          SafeArea(
            child: Container(
              height: 60,
              margin: const EdgeInsets.only(bottom: 20),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.car.photos.length,
                itemBuilder: (context, index) {
                  bool isSelected = _currentIndex == index;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 50,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          base64Decode(widget.car.photos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          if (_currentIndex == 0)
            Positioned(
              top: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Text(
                  "Kapak Fotoğrafı",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
