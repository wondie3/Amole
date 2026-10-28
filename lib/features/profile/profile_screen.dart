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
import '../orders/orders_provider.dart';

/// Profile hub. Account features (sign-in, addresses) are not built yet.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(homeDataProvider);
    final favoriteIds = ref.watch(favoritesProvider);
    final orderCount = ref.watch(ordersProvider).length;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    return SafeArea(
      child: catalog.when(
        loading: () => const CenteredLoading(),
        error: (error, stack) => ErrorRetryView(
          message: 'Could not load your profile. Please try again.',
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
                'Sign-in is not available yet. Accounts need a secure '
                'backend, so Amole does not collect passwords or pretend to '
                'sign you in. Nothing is linked to an account.',
                style: secondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Material(
                color: AppColors.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  side: const BorderSide(color: AppColors.outline),
                ),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Order history'),
                  subtitle: Text(
                    orderCount == 0
                        ? 'No demo orders yet'
                        : '$orderCount demo '
                              '${orderCount == 1 ? 'order' : 'orders'} saved '
                              'on this phone',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.orders),
                ),
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
