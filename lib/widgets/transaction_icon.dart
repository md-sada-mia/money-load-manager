import 'package:flutter/material.dart';
import '../models/models.dart';

class TransactionIcon extends StatelessWidget {
  final TransactionType type;
  final double size;
  final Color? color;
  final bool useContainer;
  final double containerSize;

  const TransactionIcon({
    super.key,
    required this.type,
    this.size = 24.0,
    this.color,
    this.useContainer = false,
    this.containerSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;
    
    if (type.assetPath != null) {
      iconWidget = Image.asset(
        type.assetPath!,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to Icon if asset fails to load
          return Icon(
            type.icon,
            color: color ?? type.color,
            size: size,
          );
        },
      );
    } else {
      iconWidget = Icon(
        type.icon,
        color: color ?? type.color,
        size: size,
      );
    }

    if (useContainer) {
      return Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: (color ?? type.color).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(child: iconWidget),
      );
    }

    return iconWidget;
  }
}
