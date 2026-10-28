import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../models/order.dart';
import '../orders/orders_provider.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref
        .watch(ordersProvider)
        .where((o) => o.id == orderId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Order confirmation')),
      body: SafeArea(
        child: order == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text('This order could not be found.'),
                ),
              )
            : _Body(order: order),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final d = order.delivery;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Center(
          child: Icon(
            Icons.check_circle_outline,
            size: 56,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Demo order placed',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Reference ${order.id}',
          textAlign: TextAlign.center,
          style: secondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(
            'This is a simulated order. The restaurant was not notified, no '
            'courier was assigned and no money was charged.',
            style: textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Delivering to', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(d.name),
        Text(d.phone),
        Text('${d.address}, ${d.subCity}'),
        if (d.landmark != null) Text('Landmark: ${d.landmark}'),
        const SizedBox(height: AppSpacing.lg),
        Text('Payment', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('${order.payment.label} (demo)'),
        const SizedBox(height: AppSpacing.lg),
        Text('From ${order.restaurantName}', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final i in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${i.quantity} × ${i.name}'
                    '${i.spiceLabel == null ? '' : ' (${i.spiceLabel})'}',
                  ),
                ),
                Text(formatEtb(i.lineTotalSantim)),
              ],
            ),
          ),
        const Divider(height: AppSpacing.xl),
        _Row(label: 'Subtotal', value: formatEtb(order.subtotalSantim)),
        _Row(label: 'Delivery fee', value: formatEtb(order.deliveryFeeSantim)),
        const SizedBox(height: AppSpacing.xs),
        _Row(label: 'Total', value: formatEtb(order.totalSantim), bold: true),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Tracking is simulated. Open the order to step through its status.',
          textAlign: TextAlign.center,
          style: secondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.orderDetailPath(order.id)),
          child: const Text('Track this order (simulated)'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Back to Home'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false});

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
