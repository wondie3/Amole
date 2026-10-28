import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money.dart';
import '../../models/order.dart';
import 'orders_provider.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref
        .watch(ordersProvider)
        .where((o) => o.id == orderId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
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
    final hasContact = d.name.isNotEmpty || d.phone.isNotEmpty;
    final place = d.address.isEmpty
        ? (d.subCity.isEmpty ? 'Area not recorded' : d.subCity)
        : '${d.address}, ${d.subCity}';
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(order.restaurantName, style: textTheme.headlineSmall),
        Text('Reference ${order.id}', style: secondary),
        Text(formatOrderDate(order.createdAt), style: secondary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${order.status.label}${order.simulated ? ' · Simulated' : ''}',
          style: textTheme.labelLarge?.copyWith(color: AppColors.orangeDeep),
        ),
        if (order.simulated) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(
              'This was a simulated order. The restaurant was not notified, '
              'no courier was assigned and no money was charged.',
              style: textTheme.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Delivery', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        if (d.name.isNotEmpty) Text(d.name),
        if (d.phone.isNotEmpty) Text(d.phone),
        Text(place),
        if (d.landmark != null) Text('Landmark: ${d.landmark}'),
        if (!hasContact)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Contact details are not saved on this phone.',
              style: secondary,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Payment', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('${order.payment.label} (demo)'),
        const SizedBox(height: AppSpacing.lg),
        Text('Items', style: textTheme.titleMedium),
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
                const SizedBox(width: AppSpacing.md),
                Text(formatEtb(i.lineTotalSantim)),
              ],
            ),
          ),
        const Divider(height: AppSpacing.xl),
        _Row(label: 'Subtotal', value: formatEtb(order.subtotalSantim)),
        _Row(label: 'Delivery fee', value: formatEtb(order.deliveryFeeSantim)),
        const SizedBox(height: AppSpacing.xs),
        _Row(label: 'Total', value: formatEtb(order.totalSantim), bold: true),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sample data: prices and the delivery fee are not real charges.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
