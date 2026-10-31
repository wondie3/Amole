import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/saved_address.dart';
import '../checkout/checkout_logic.dart';
import 'addresses_active.dart';
import 'addresses_logic.dart';

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

/// Add (addressId == null) or edit an address. Goes to the account when
/// signed in with a backend, otherwise to this phone.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.addressId});

  final String? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _label = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _landmark = TextEditingController();
  String? _subCity;
  SavedAddress? _existing;
  bool _missing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final id = widget.addressId;
    if (id == null) return;
    final existing = ref
        .read(activeAddressesProvider)
        .addresses
        .where((a) => a.id == id)
        .firstOrNull;
    if (existing == null) {
      _missing = true;
      return;
    }
    _existing = existing;
    _label.text = existing.label;
    _name.text = existing.name;
    _phone.text = existing.phone;
    _address.text = existing.address;
    _landmark.text = existing.landmark ?? '';
    _subCity = existing.subCity;
  }

  @override
  void dispose() {
    _label.dispose();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final existing = _existing;
    final landmark = _landmark.text.trim();
    final address = SavedAddress(
      id:
          existing?.id ??
          'addr-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      label: _label.text.trim(),
      name: _name.text.trim(),
      phone: normalizePhone(_phone.text) ?? _phone.text.trim(),
      subCity: _subCity ?? '',
      address: _address.text.trim(),
      landmark: landmark.isEmpty ? null : landmark,
    );
    setState(() => _saving = true);
    final actions = ref.read(addressActionsProvider);
    final error = await (existing == null
        ? actions.add(address)
        : actions.update(address));
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.addressId == null ? 'Add address' : 'Edit address';
    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('This address could not be found.'),
            ),
          ),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final account = ref.watch(addressModeProvider) == AddressMode.account;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account
                      ? 'Saved in your account on the local test server, and '
                            'separate from the addresses on this phone. You '
                            'can delete it any time.'
                      : 'Saved on this phone only, without encryption, and '
                            'not linked to an account. You can delete it any '
                            'time.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const Key('address_label'),
                  controller: _label,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validateLabel,
                  decoration: _decoration(
                    'Address name',
                    hint: 'Home, Work...',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('address_name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validateName,
                  decoration: _decoration('Contact name'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('address_phone'),
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
                const SizedBox(height: AppSpacing.lg),
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
                  key: const Key('address_street'),
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
                  key: const Key('address_landmark'),
                  controller: _landmark,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validateLandmark,
                  decoration: _decoration('Landmark (optional)'),
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
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save address'),
          ),
        ),
      ),
    );
  }
}
