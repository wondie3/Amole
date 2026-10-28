import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money.dart';
import '../../models/order.dart';
import '../../shared/widgets/pressable.dart';
import 'orders_provider.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final notifier = ref.read(ordersProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear order history?'),
        content: Text(
          'This removes all $count demo ${count == 1 ? 'order' : 'orders'} '
          'saved on this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.clearHistory();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order history'),
        actions: [
          if (orders.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref, orders.length),
              child: const Text('Clear history'),
            ),
        ],
      ),
      body: SafeArea(
        child: orders.isEmpty
            ? const _EmptyHistory()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'Demo orders saved on this phone only. No real orders '
                    'were placed.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final o in orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _OrderCard(order: o),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

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
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.orange,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('No orders yet', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Demo orders you place will be listed here.',
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    return Pressable(
      onTap: () => context.push(AppRoutes.orderDetailPath(order.id)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium,
            ),
            Text(formatOrderDate(order.createdAt), style: secondary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}'
              ' · ${formatEtb(order.totalSantim)}',
              style: textTheme.labelLarge,
            ),
            Text('Reference ${order.id}', style: secondary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${order.status.label}${order.simulated ? ' · Simulated' : ''}',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.orangeDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
