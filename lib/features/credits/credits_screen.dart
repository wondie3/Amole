import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/sample_data.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo credits')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Sample photos from Wikimedia Commons. Each photo was resized '
              'for use in Amole and is shared under the license shown.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final c in SampleData.photoCredits)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.subject, style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Photo by ${c.author}'),
                      Text('License: ${c.license}'),
                      const SizedBox(height: AppSpacing.sm),
                      SelectableText(c.licenseUrl, style: textTheme.bodySmall),
                      SelectableText(c.sourceUrl, style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
