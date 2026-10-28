import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'addresses_logic.dart';
import 'addresses_provider.dart';

/// Bottom sheet for choosing the delivery address shown on Home.
Future<void> showAddressPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (ctx, ref, child) {
          final book = ref.watch(addressesProvider);
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
                  'Saved on this phone only.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (book.addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No saved addresses yet.'),
                  ),
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
                    onTap: () {
                      ref.read(addressesProvider.notifier).select(a.id);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add),
                  title: const Text('Add new address'),
                  enabled: book.addresses.length < maxSavedAddresses,
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
