import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money.dart';
import '../../models/order.dart';
import 'order_status_logic.dart';
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

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String keepLabel,
  required String yesLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(keepLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yesLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});

  final Order order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(ordersProvider.notifier);
    final ok = await _confirm(
      context,
      title: 'Cancel this order?',
      message:
          'This demo order will be marked as cancelled. Nothing is refunded '
          'because no money was charged.',
      keepLabel: 'Keep order',
      yesLabel: 'Yes, cancel order',
    );
    if (ok) notifier.cancel(order.id);
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(ordersProvider.notifier);
    final ok = await _confirm(
      context,
      title: 'Request cancellation?',
      message:
          'Your request goes to the restaurant, which decides whether to '
          'accept it. If it declines, your order stays as it is. Nothing was '
          'charged. (Simulated: no restaurant is involved.)',
      keepLabel: 'Keep order',
      yesLabel: 'Send request',
    );
    if (ok) notifier.requestCancellation(order.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final d = order.delivery;
    final hasContact = d.name.isNotEmpty || d.phone.isNotEmpty;
    final place = d.address.isEmpty
        ? (d.subCity.isEmpty ? 'Area not recorded' : d.subCity)
        : '${d.address}, ${d.subCity}';
    final next = nextStatus(order.status);
    final window = estimatedWindow(order);
    final request = order.cancellationRequest;
    final showActions =
        next != null ||
        canCancel(order.status) ||
        canRequestCancellation(order);

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
              'Simulated tracking. Statuses and restaurant decisions change '
              'only when you press a "Simulate" button. No restaurant or '
              'courier is involved, nothing was charged and there is no live '
              'location.',
              style: textTheme.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Status', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _Timeline(status: order.status),
        if (order.status != OrderStatus.cancelled &&
            order.status != OrderStatus.delivered) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            window == null
                ? 'Estimated delivery was not recorded for this order.'
                : 'Estimated delivery (simulated): '
                      '${formatClock(window.from)} - ${formatClock(window.to)}',
            style: secondary,
          ),
        ],
        if (showActions) ...[
          const SizedBox(height: AppSpacing.md),
          if (next != null)
            OutlinedButton(
              onPressed: () =>
                  ref.read(ordersProvider.notifier).advance(order.id),
              child: Text('Simulate next step: ${next.label}'),
            ),
          if (canCancel(order.status))
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => _cancel(context, ref),
              child: const Text('Cancel order'),
            ),
          if (canRequestCancellation(order))
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => _request(context, ref),
              child: const Text('Request cancellation'),
            ),
        ],
        if (request != null) ...[
          const SizedBox(height: AppSpacing.md),
          _RequestCard(order: order, request: request),
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

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.order, required this.request});

  final Order order;
  final CancellationRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(ordersProvider.notifier);
    final String title;
    final List<Widget> body;
    switch (request.status) {
      case CancellationRequestStatus.pending:
        title = 'Cancellation requested';
        body = [
          const Text(
            'Waiting for the restaurant to decide. Your order carries on '
            'until then.',
          ),
          if (!canAcceptCancellation(order))
            const Text(
              'The order has left the restaurant, so support would handle '
              'this.',
            ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => notifier.withdrawCancellation(order.id),
            child: const Text('Withdraw request'),
          ),
          if (canAcceptCancellation(order))
            OutlinedButton(
              onPressed: () =>
                  notifier.simulateDecision(order.id, accept: true),
              child: const Text('Simulate: restaurant accepts'),
            ),
          OutlinedButton(
            onPressed: () => notifier.simulateDecision(order.id, accept: false),
            child: const Text('Simulate: restaurant declines'),
          ),
        ];
      case CancellationRequestStatus.accepted:
        title = 'Cancellation accepted';
        body = const [
          Text('The restaurant accepted your request. Nothing was charged.'),
        ];
      case CancellationRequestStatus.declined:
        title = 'Cancellation declined';
        body = [
          const Text('Your order continues as before.'),
          if (request.decisionReason != null)
            Text('Reason: ${request.decisionReason}'),
        ];
    }
    return Container(
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
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ...body,
        ],
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return const _TimelineRow(
        label: 'Cancelled',
        state: _StepState.current,
        cancelled: true,
      );
    }
    final current = progression.indexOf(status);
    return Column(
      children: [
        for (var i = 0; i < progression.length; i++)
          _TimelineRow(
            label: progression[i].label,
            state: i < current
                ? _StepState.done
                : (i == current ? _StepState.current : _StepState.upcoming),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.state,
    this.cancelled = false,
  });

  final String label;
  final _StepState state;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final IconData icon;
    final Color color;
    if (cancelled) {
      icon = Icons.cancel_outlined;
      color = AppColors.error;
    } else {
      switch (state) {
        case _StepState.done:
          icon = Icons.check_circle;
          color = AppColors.forest;
        case _StepState.current:
          icon = Icons.radio_button_checked;
          color = AppColors.orangeDeep;
        case _StepState.upcoming:
          icon = Icons.radio_button_unchecked;
          color = AppColors.textSecondary;
      }
    }
    final word = switch (state) {
      _StepState.done => 'completed',
      _StepState.current => 'current',
      _StepState.upcoming => 'not reached yet',
    };
    return Semantics(
      label: '$label, $word',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: state == _StepState.current
                      ? textTheme.titleMedium
                      : textTheme.bodyLarge?.copyWith(
                          color: state == _StepState.upcoming
                              ? AppColors.textSecondary
                              : null,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
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
