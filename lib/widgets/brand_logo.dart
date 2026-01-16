import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BrandLogo extends StatelessWidget {
  final String logoUrl;
  final double size;

  const BrandLogo({
    required this.logoUrl,
    required this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isEmpty) return _buildFallback();

    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      memCacheWidth: (size * 3).toInt(), // Optimization: Resize in memory (3x for high DPI)
      httpHeaders: const {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://www.autotrader.co.uk/",
        "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
      },
      placeholder: (context, url) => SizedBox(
        width: size * 0.5,
        height: size * 0.5,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) {
        // debugPrint("BrandLogo Error ($url): $error");
        return _buildFallback();
      },
      fadeInDuration: const Duration(milliseconds: 200),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(20),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.directions_car, size: size * 0.6, color: Colors.grey),
    );
  }
}
