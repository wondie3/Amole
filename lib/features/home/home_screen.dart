import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/amole_wordmark.dart';
import '../../shared/widgets/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      icon: Icons.home_outlined,
      title: 'Home is on its way',
      message:
          'Delivery location, categories and restaurants will appear here.',
      milestone: 2,
      header: Column(
        children: [
          const AmoleWordmark(),
          const SizedBox(height: 6),
          Text(
            'Good food, delivered.',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
