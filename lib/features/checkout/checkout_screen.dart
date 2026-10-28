import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/catalog_providers.dart';
import '../../models/cart_line.dart';
import '../../models/order.dart';
import '../../shared/widgets/state_views.dart';
import '../cart/cart_logic.dart';
import '../cart/cart_provider.dart';
import '../orders/orders_provider.dart';
import '../addresses/addresses_provider.dart';
import 'checkout_logic.dart';

OutlineInputBorder _border(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadii.md),
  borderSide: BorderSide(color: color),
);

InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  filled: true,
  fillColor: AppColors.surface,
  border: _border(AppColors.outline),
  enabledBorder: _border(AppColors.outline),
  focusedBorder: _border(AppColors.forest),
  errorBorder: _border(AppColors.error),
  focusedErrorBorder: _border(AppColors.error),
);

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _landmark = TextEditingController();
  String? _subCity;
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(addressesProvider).selected;
    if (saved != null) {
      _name.text = saved.name;
      _phone.text = saved.phone;
      _address.text = saved.address;
      _landmark.text = saved.landmark ?? '';
      _subCity = saved.subCity;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Widget _plain(Widget body) => Scaffold(
    appBar: AppBar(title: const Text('Checkout')),
    body: SafeArea(child: body),
  );

  void _submit(HomeData data) {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final landmark = _landmark.text.trim();
    final result = ref
        .read(ordersProvider.notifier)
        .placeOrder(
          data: data,
          delivery: DeliveryDetails(
            name: _name.text.trim(),
            phone: normalizePhone(_phone.text) ?? _phone.text.trim(),
            subCity: _subCity ?? '',
            address: _address.text.trim(),
            landmark: landmark.isEmpty ? null : landmark,
          ),
          payment: _payment,
        );

    final order = result.order;
    if (order == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not place the order.')),
      );
      return;
    }
    context.pushReplacement(AppRoutes.orderConfirmationPath(order.id));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeDataProvider);
    final lines = ref.watch(cartProvider);
    return catalog.when(
      loading: () => _plain(const CenteredLoading()),
      error: (error, stack) => _plain(
        ErrorRetryView(
          message: 'Could not load checkout. Please try again.',
          onRetry: () => ref.invalidate(homeDataProvider),
        ),
      ),
      data: (d) {
        if (lines.isEmpty && !_submitting) {
          return _plain(
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Your cart is empty.'),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: const Text('Browse dishes'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _buildForm(context, d, lines);
      },
    );
  }

  Widget _buildForm(BuildContext context, HomeData d, List<CartLine> lines) {
    final textTheme = Theme.of(context).textTheme;
    final dishesById = {for (final x in d.dishes) x.id: x};
    final restaurantsById = {for (final r in d.restaurants) r.id: r};
    final totals = computeTotals(lines, dishesById, restaurantsById);
    final restaurantId = cartRestaurantId(lines, dishesById);
    final restaurantName = restaurantId == null
        ? null
        : restaurantsById[restaurantId]?.name;
    final hasUnavailable = lines.any((l) => !dishesById.containsKey(l.dishId));
    final sectionStyle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text(
                    'Demo checkout. No real order is placed and no payment is '
                    'taken. Details are saved only if you add them under Saved addresses.',
                    style: textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Contact', style: sectionStyle),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('checkout_name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validateName,
                  decoration: _decoration('Full name'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('checkout_phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validatePhone,
                  decoration: _decoration(
                    'Mobile number',
                    hint: '0911 22 33 44',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Delivery address', style: sectionStyle),
                const SizedBox(height: AppSpacing.md),
                Text('Sub-city', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                FormField<String>(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (_) => validateSubCity(_subCity),
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final s in addisSubCities)
                            ChoiceChip(
                              label: Text(s),
                              selected: _subCity == s,
                              showCheckmark: false,
                              selectedColor: AppColors.forest,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.outline),
                              labelStyle: TextStyle(
                                color: _subCity == s
                                    ? AppColors.cream
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) {
                                setState(() => _subCity = s);
                                field.didChange(s);
                              },
                            ),
                        ],
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            field.errorText ?? '',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('checkout_address'),
                  controller: _address,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validateAddress,
                  decoration: _decoration(
                    'Street or area',
                    hint: 'e.g. near Edna Mall',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('checkout_landmark'),
                  controller: _landmark,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validateLandmark,
                  decoration: _decoration('Landmark (optional)'),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Payment', style: sectionStyle),
                const SizedBox(height: AppSpacing.md),
                for (final m in PaymentMethod.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PaymentTile(
                      method: m,
                      selected: _payment == m,
                      onTap: m.available
                          ? () => setState(() => _payment = m)
                          : null,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text('Order summary', style: sectionStyle),
                if (restaurantName != null)
                  Text(
                    'From $restaurantName',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Column(
                    children: [
                      for (final l in lines)
                        _SummaryRow(
                          label: dishesById[l.dishId] == null
                              ? 'Unavailable item'
                              : '${l.quantity} × ${dishesById[l.dishId]!.name}'
                                    '${l.spice == null ? '' : ' (${l.spice!.label})'}',
                          value: dishesById[l.dishId] == null
                              ? '-'
                              : formatEtb(
                                  dishesById[l.dishId]!.priceSantim *
                                      l.quantity,
                                ),
                        ),
                      const Divider(height: AppSpacing.xl),
                      _SummaryRow(
                        label: 'Subtotal',
                        value: formatEtb(totals.subtotalSantim),
                      ),
                      _SummaryRow(
                        label: 'Delivery fee',
                        value: formatEtb(totals.deliveryFeeSantim),
                      ),
                      const Divider(height: AppSpacing.xl),
                      _SummaryRow(
                        label: 'Total',
                        value: formatEtb(totals.totalSantim),
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sample data: prices and the delivery fee are not real '
                  'charges.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (hasUnavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Some items are no longer available. Remove them in '
                      'your cart to continue.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
            onPressed: (_submitting || hasUnavailable)
                ? null
                : () => _submit(d),
            child: Text('Place demo order · ${formatEtb(totals.totalSantim)}'),
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(
          color: selected ? AppColors.forest : AppColors.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        leading: Icon(
          method.available ? Icons.payments_outlined : Icons.phone_android,
        ),
        title: Text(method.label),
        subtitle: Text(
          method.available ? 'Pay the courier in cash (demo)' : method.note,
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.forest)
            : null,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: AppSpacing.md),
          Text(value, style: style),
        ],
      ),
    );
  }
}
