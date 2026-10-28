import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/catalog_providers.dart';
import '../../models/cart_line.dart';
import '../../models/dish.dart';
import '../../shared/widgets/amole_image.dart';
import '../../shared/widgets/state_views.dart';
import 'cart_logic.dart';
import 'cart_provider.dart';

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(AppRadii.md),
  border: Border.all(color: AppColors.outline),
);

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(homeDataProvider);
    return SafeArea(
      child: catalog.when(
        loading: () => const CenteredLoading(),
        error: (error, stack) => ErrorRetryView(
          message: 'Could not load your cart. Please try again.',
          onRetry: () => ref.invalidate(homeDataProvider),
        ),
        data: (d) => _CartBody(data: d),
      ),
    );
  }
}

class _CartBody extends ConsumerWidget {
  const _CartBody({required this.data});

  final HomeData data;

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final notifier = ref.read(cartProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cart?'),
        content: Text(
          'This removes all $count ${count == 1 ? 'item' : 'items'} from '
          'your cart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear cart'),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    if (lines.isEmpty) return const _EmptyCart();

    final notifier = ref.read(cartProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final dishesById = {for (final x in data.dishes) x.id: x};
    final restaurantsById = {for (final r in data.restaurants) r.id: r};
    final totals = computeTotals(lines, dishesById, restaurantsById);
    final restaurantId = cartRestaurantId(lines, dishesById);
    final restaurantName = restaurantId == null
        ? null
        : restaurantsById[restaurantId]?.name;
    final itemCount = cartItemCount(lines);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(child: Text('Cart', style: textTheme.headlineSmall)),
            TextButton.icon(
              onPressed: () => _confirmClear(context, ref, itemCount),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear cart'),
            ),
          ],
        ),
        if (restaurantName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'From $restaurantName',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _CartLineCard(
              line: line,
              dish: dishesById[line.dishId],
              onChange: (delta) => notifier.changeQuantity(line.key, delta),
              onRemove: () => notifier.remove(line.key),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              _TotalRow(
                label: 'Subtotal',
                value: formatEtb(totals.subtotalSantim),
              ),
              const SizedBox(height: AppSpacing.sm),
              _TotalRow(
                label: 'Delivery fee',
                value: formatEtb(totals.deliveryFeeSantim),
              ),
              const Divider(height: AppSpacing.xl),
              _TotalRow(
                label: 'Total',
                value: formatEtb(totals.totalSantim),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sample data: prices and the delivery fee are not real charges.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        const FilledButton(
          onPressed: null,
          child: Text('Checkout arrives in Milestone 6'),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: AppColors.orange,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Your cart is empty', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add a dish and it will show up here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Browse dishes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final base = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    final style = bold ? base?.copyWith(fontWeight: FontWeight.w800) : base;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.dish,
    required this.onChange,
    required this.onRemove,
  });

  final CartLine line;
  final Dish? dish;
  final void Function(int delta) onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = dish;

    if (d == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const Expanded(child: Text('This item is no longer available.')),
            TextButton(onPressed: onRemove, child: const Text('Remove')),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: AmoleImage(asset: d.imageAsset, semanticLabel: d.name),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    if (line.spice != null)
                      Text(
                        'Spice: ${line.spice!.label}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      '${formatEtb(d.priceSantim)} each',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    tooltip: 'Decrease quantity of ${d.name}',
                    onPressed: line.quantity > 1 ? () => onChange(-1) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${line.quantity}',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Increase quantity of ${d.name}',
                    onPressed: line.quantity < maxQuantity
                        ? () => onChange(1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatEtb(d.priceSantim * line.quantity),
                    style: textTheme.titleMedium,
                  ),
                  IconButton(
                    tooltip: 'Remove ${d.name} from cart',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
