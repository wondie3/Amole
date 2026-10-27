import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Asset image with a fade-in and a visible fallback if loading fails.
class AmoleImage extends StatelessWidget {
  const AmoleImage({
    super.key,
    required this.asset,
    this.semanticLabel,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final String? semanticLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: semanticLabel,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image failed to load: $asset ($error)');
        return const ColoredBox(
          color: AppColors.outline,
          child: Center(
            child: Icon(Icons.restaurant, color: AppColors.textSecondary),
          ),
        );
      },
    );
  }
}
