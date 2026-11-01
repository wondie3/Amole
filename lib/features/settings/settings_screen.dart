import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/storage_scope.dart';
import '../../shared/widgets/nav_tile.dart';
import '../addresses/addresses_provider.dart';
import '../cart/cart_provider.dart';
import '../favorites/favorites_provider.dart';
import '../orders/orders_provider.dart';
import 'local_data.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final account = ref.read(storageScopeProvider) != null;
    final favorites = ref.read(favoritesProvider).length;
    final cartItems = ref.read(cartCountProvider);
    final orders = ref.read(ordersProvider).length;
    final addresses = ref.read(addressesProvider).addresses.length;
    final clear = ref.read(clearLocalDataProvider);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all local data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account
                  ? 'This permanently removes from this phone, for the '
                        'account you are signed in to:'
                  : 'This permanently removes from this phone:',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('• $favorites favorite ${favorites == 1 ? 'dish' : 'dishes'}'),
            Text(
              '• $cartItems ${cartItems == 1 ? 'item' : 'items'} in your cart',
            ),
            Text('• $orders demo ${orders == 1 ? 'order' : 'orders'}'),
            if (!account)
              Text(
                '• $addresses saved '
                '${addresses == 1 ? 'address' : 'addresses'}',
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              account
                  ? 'This cannot be undone. Data saved on this phone for '
                        'guest use or for other accounts, and addresses '
                        'saved in your account, are not affected.'
                  : 'This cannot be undone. Data saved for accounts on this '
                        'phone, and addresses saved in an account, are not '
                        'affected.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear local data'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Local data cleared.')),
      );
    } catch (error) {
      debugPrint('Could not clear local data: $error');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not clear local data. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final account = ref.watch(storageScopeProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Favorites, your cart, demo orders and saved addresses are '
              'stored only on this phone, without encryption.',
              style: secondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              account
                  ? 'You are signed in: the favorites, cart and demo orders '
                        'shown belong to your account on this phone. Your '
                        'guest data is kept separately and returns when you '
                        'sign out.'
                  : 'You are not signed in: this is the guest demo data. '
                        'Each account you sign in to gets its own, starting '
                        'empty.',
              style: secondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            NavTile(
              icon: Icons.location_on_outlined,
              title: 'Saved addresses',
              onTap: () => context.push(AppRoutes.addresses),
            ),
            const SizedBox(height: AppSpacing.sm),
            NavTile(
              icon: Icons.photo_library_outlined,
              title: 'Photo credits',
              onTap: () => context.push(AppRoutes.credits),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'About Amole',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Prototype build. Good food, delivered.', style: secondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Amole is a food-delivery app in development. Restaurants, '
              'prices, ratings and orders are sample data. No real orders, '
              'payments or deliveries happen. Sample photos are shared under '
              'Creative Commons licenses, listed under Photo credits.',
              style: secondary,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(64, 48),
              ),
              onPressed: () => _confirmClear(context, ref),
              child: const Text('Clear local data'),
            ),
          ],
        ),
      ),
    );
  }
}
