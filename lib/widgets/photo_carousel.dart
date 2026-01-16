import 'dart:convert';
import 'package:flutter/material.dart';

class PhotoCarousel extends StatefulWidget {
  final List<String> photos;
  final VoidCallback onTap;

  const PhotoCarousel({
    Key? key,
    required this.photos,
    required this.onTap,
  }) : super(key: key);

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0059BC), Color(0xFF003C8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Icon(Icons.directions_car, size: 120, color: Colors.white.withOpacity(0.15)),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final String photoData = widget.photos[index];
              // Simple heuristic: URLs usually start with http/https
              final bool isUrl = photoData.startsWith('http');
              
              if (isUrl) {
                return Image.network(
                  photoData,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                );
              } else {
                 try {
                    // Try validating base64 length/padding before decoding to avoid some errors
                    if (photoData.length % 4 != 0) {
                       // Invalid length for base64
                       return Container(color: Colors.grey[200]);
                    }
                    return Image.memory(
                      base64Decode(photoData),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0059BC)),
                    );
                 } catch (e) {
                   // Fallback for invalid base64 or other errors
                   return Container(
                     color: Colors.grey[200], 
                     child: const Icon(Icons.error_outline, color: Colors.grey)
                   );
                 }
              }
            },
          ),
          // Dark Gradient Overlay for Text Visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5],
              ),
            ),
          ),
          
          // Page Indicator
          if (widget.photos.length > 1)
            Positioned(
              bottom: 20, // Adjust based on where card starts, card starts at 0.28 height
              // Actually this carousel fills the top 0.4 height.
              // So bottom 20 is fine.
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photos.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == index ? 8 : 6,
                    height: _currentIndex == index ? 8 : 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? Colors.white : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
