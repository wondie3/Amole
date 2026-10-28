import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/catalog_providers.dart';
import '../../models/cart_line.dart';
import '../../models/dish.dart';
import '../../shared/widgets/amole_image.dart';
import '../../shared/widgets/favorite_button.dart';
import '../../shared/widgets/state_views.dart';
import '../cart/cart_logic.dart';
import '../cart/cart_provider.dart';

class DishDetailScreen extends ConsumerStatefulWidget {
  const DishDetailScreen({super.key, required this.dishId});

  final String dishId;

  @override
  ConsumerState<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends ConsumerState<DishDetailScreen> {
  int _quantity = 1;
  SpiceLevel _spice = SpiceLevel.medium;

  Widget _plain(Widget body) => Scaffold(
    appBar: AppBar(title: const Text('Dish')),
    body: SafeArea(child: body),
  );

  void _addToCart(Dish dish) {
    final capped = ref
        .read(cartProvider.notifier)
        .add(
          CartLine(
            dishId: dish.id,
            quantity: _quantity,
            spice: dish.hasSpiceOptions ? _spice : null,
          ),
        );
    final limit = capped ? ' Limit of $maxQuantity per item reached.' : '';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Added $_quantity × ${dish.name} to your cart.$limit '
            'Viewing the cart arrives in Milestone 5.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeDataProvider);
    return catalog.when(
      loading: () => _plain(const CenteredLoading()),
      error: (error, stack) => _plain(
        ErrorRetryView(
          message: 'Could not load this dish. Please try again.',
          onRetry: () => ref.invalidate(homeDataProvider),
        ),
      ),
      data: (d) {
        final dish = d.dishes.where((x) => x.id == widget.dishId).firstOrNull;
        if (dish == null) {
          return _plain(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('This dish could not be found.'),
              ),
            ),
          );
        }
        final restaurantName =
            d.restaurants
                .where((r) => r.id == dish.restaurantId)
                .map((r) => r.name)
                .firstOrNull ??
            '';
        return _buildDish(context, dish, restaurantName);
      },
    );
  }

  Widget _buildDish(BuildContext context, Dish dish, String restaurantName) {
    final textTheme = Theme.of(context).textTheme;
    final total = dish.priceSantim * _quantity;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dish'),
        actions: [FavoriteButton(dishId: dish.id)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: AmoleImage(
                asset: dish.imageAsset,
                semanticLabel: dish.name,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(dish.name, style: textTheme.headlineSmall),
          Text(
            restaurantName,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatEtb(dish.priceSantim)}  ·  ★ ${dish.rating}',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sample dish. Price and rating are not real.',
            style: textTheme.labelMedium?.copyWith(color: AppColors.orangeDeep),
          ),
          if (dish.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(dish.description, style: textTheme.bodyLarge),
          ],
          if (dish.hasSpiceOptions) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Spice level', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final s in SpiceLevel.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _spice == s,
                    showCheckmark: false,
                    selectedColor: AppColors.forest,
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.outline),
                    labelStyle: TextStyle(
                      color: _spice == s
                          ? AppColors.cream
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _spice = s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Text('Quantity', style: textTheme.titleMedium),
              const Spacer(),
              IconButton.outlined(
                tooltip: 'Decrease quantity',
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Increase quantity',
                onPressed: _quantity < maxQuantity
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: FilledButton(
            onPressed: () => _addToCart(dish),
            child: Text('Add to cart · ${formatEtb(total)}'),
          ),
        ),
      ),
    );
  }
}
