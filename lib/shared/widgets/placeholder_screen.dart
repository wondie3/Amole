import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Honest placeholder for a feature that is not built yet. It states what is
/// coming and when, and contains no buttons that do nothing.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.milestone,
    this.header,
  });

  final IconData icon;
  final String title;
  final String message;
  final int milestone;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header != null) ...[
                header!,
                const SizedBox(height: AppSpacing.xxl),
              ],
              Icon(icon, size: 48, color: AppColors.orange),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Planned for Milestone $milestone. Not functional yet.',
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.orangeDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
