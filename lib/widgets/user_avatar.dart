import 'dart:convert';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? fallbackContent; // Widget to show if no image (default: Icon)
  final Color? backgroundColor;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    this.radius = 20,
    this.fallbackContent,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (imageUrl!.startsWith('http')) {
        imageProvider = NetworkImage(imageUrl!);
      } else {
        try {
          // Assume Base64
          imageProvider = MemoryImage(base64Decode(imageUrl!));
        } catch (e) {
          debugPrint("UserAvatar Error decoding base64: $e");
          // Fallback will be used if provider is null or errors (though CircleAvatar doesn't catch provider errors easily)
        }
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade200,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? (fallbackContent ?? Icon(Icons.person, color: Colors.grey.shade500, size: radius))
          : null,
    );
  }
}
