import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog_providers.dart';
import '../../shared/widgets/catalog_rows.dart';
import '../../shared/widgets/nav_tile.dart';
import '../../shared/widgets/state_views.dart';
import '../addresses/addresses_provider.dart';
import '../favorites/favorites_provider.dart';
import '../orders/orders_provider.dart';

/// Profile hub. There are no accounts yet; everything here is local to this
/// phone.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(homeDataProvider);
    final favoriteIds = ref.watch(favoritesProvider);
    final orderCount = ref.watch(ordersProvider).length;
    final addressCount = ref.watch(addressesProvider).addresses.length;
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
              NavTile(
                icon: Icons.receipt_long_outlined,
                title: 'Order history',
                subtitle: orderCount == 0
                    ? 'No demo orders yet'
                    : '$orderCount demo '
                          '${orderCount == 1 ? 'order' : 'orders'} saved '
                          'on this phone',
                onTap: () => context.push(AppRoutes.orders),
              ),
              const SizedBox(height: AppSpacing.sm),
              NavTile(
                icon: Icons.location_on_outlined,
                title: 'Saved addresses',
                subtitle: addressCount == 0
                    ? 'No saved addresses'
                    : '$addressCount saved '
                          '${addressCount == 1 ? 'address' : 'addresses'}',
                onTap: () => context.push(AppRoutes.addresses),
              ),
              const SizedBox(height: AppSpacing.sm),
              NavTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'About, photo credits, clear local data',
                onTap: () => context.push(AppRoutes.settings),
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
