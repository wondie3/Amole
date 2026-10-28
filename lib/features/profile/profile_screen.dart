import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog_providers.dart';
import '../../shared/widgets/catalog_rows.dart';
import '../../shared/widgets/state_views.dart';
import '../favorites/favorites_provider.dart';

/// Temporary Profile: shows saved favorites. Account features arrive in
/// Milestone 7.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(homeDataProvider);
    final favoriteIds = ref.watch(favoritesProvider);
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    return SafeArea(
      child: catalog.when(
        loading: () => const CenteredLoading(),
        error: (error, stack) => ErrorRetryView(
          message: 'Could not load your favorites. Please try again.',
          onRetry: () => ref.invalidate(homeDataProvider),
        ),
        data: (d) {
          final names = {for (final r in d.restaurants) r.id: r.name};
          final favorites = d.dishes
              .where((x) => favoriteIds.contains(x.id))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Profile', style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign-in, addresses and order history arrive in Milestone 7. '
                'Nothing is linked to an account yet.',
                style: secondary,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Favorites',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('Saved on this phone only.', style: secondary),
              const SizedBox(height: AppSpacing.md),
              if (favorites.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    'No favorites yet. Open a dish and tap the heart to save '
                    'it here.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                for (final dish in favorites)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: DishRow(
                      dish: dish,
                      restaurantName: names[dish.restaurantId],
                      onTap: () => context.push(AppRoutes.dishPath(dish.id)),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
