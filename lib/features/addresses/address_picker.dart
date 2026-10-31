import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'addresses_active.dart';
import 'addresses_logic.dart';

/// Bottom sheet for choosing the delivery address shown on Home. When signed
/// in with no account addresses, it opens the address form instead.
Future<void> showAddressPicker(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(addressModeProvider) == AddressMode.account &&
      container.read(addressesStatusProvider) == AddressesStatus.ready &&
      container.read(activeAddressesProvider).addresses.isEmpty) {
    context.push(AppRoutes.addressNew);
    return Future<void>.value();
  }

  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (ctx, ref, child) {
          final book = ref.watch(activeAddressesProvider);
          final status = ref.watch(addressesStatusProvider);
          final account = ref.watch(addressModeProvider) == AddressMode.account;
          final ready = status == AddressesStatus.ready;
          final selectedId = book.selected?.id;
          final textTheme = Theme.of(ctx).textTheme;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery address', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  account
                      ? 'Saved in your account (local test backend).'
                      : 'Saved on this phone only.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (status == AddressesStatus.loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (status == AddressesStatus.error) ...[
                  const Text('Could not load your addresses.'),
                  TextButton(
                    onPressed: () => ref.invalidate(remoteAddressesProvider),
                    child: const Text('Retry'),
                  ),
                ],
                if (ready && book.addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No saved addresses yet.'),
                  ),
                if (ready)
                  for (final a in book.addresses)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        a.id == selectedId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: a.id == selectedId ? AppColors.forest : null,
                      ),
                      title: Text(a.label),
                      subtitle: Text('${a.address}, ${a.subCity}'),
                      onTap: () async {
                        final error = await ref
                            .read(addressActionsProvider)
                            .select(a.id);
                        if (error != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                          return;
                        }
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                    ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add),
                  title: const Text('Add new address'),
                  enabled: ready && book.addresses.length < maxSavedAddresses,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(AppRoutes.addressNew);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_location_alt_outlined),
                  title: const Text('Manage addresses'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(AppRoutes.addresses);
                  },
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
