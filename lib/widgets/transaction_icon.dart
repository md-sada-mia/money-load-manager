import 'package:flutter/material.dart';
import '../utils/logo_helper.dart';

class TransactionIcon extends StatelessWidget {
  final String type;
  final double size;
  final Color? color; // Optional override

  const TransactionIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // For now, we prefer asset images from LogoHelper
    final assetPath = LogoHelper.getLogoPath(type);
    final fallbackColor = color ?? LogoHelper.getColor(type);

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
           return Icon(Icons.receipt, size: size, color: fallbackColor);
        },
      );
    } else {
      return Icon(
        Icons.category, // Default icon
        size: size, 
        color: fallbackColor
      );
    }
  }
}
