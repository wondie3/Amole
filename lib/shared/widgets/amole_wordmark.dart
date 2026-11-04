import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// TEMPORARY text-based wordmark. This is not a designed logo asset; a
/// professional logo should replace it before release.
class AmoleWordmark extends StatelessWidget {
  const AmoleWordmark({
    super.key,
    this.fontSize = 40,
    this.color = AppColors.forest,
  });

  final double fontSize;

  /// Color of the letters. The dot is always the brand orange.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dot = fontSize * 0.18;
    return Semantics(
      label: 'Amole',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Amole',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1,
                color: color,
              ),
            ),
            SizedBox(width: fontSize * 0.06),
            Padding(
              padding: EdgeInsets.only(bottom: fontSize * 0.08),
              child: Container(
                width: dot,
                height: dot,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
