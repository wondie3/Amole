import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/saved_address.dart';
import 'addresses_logic.dart';
import 'addresses_provider.dart';

class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SavedAddress a,
  ) async {
    final notifier = ref.read(addressesProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('"${a.label}" will be removed from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.delete(a.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressesProvider);
    final notifier = ref.read(addressesProvider.notifier);
    final selectedId = book.selected?.id;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    final full = book.addresses.length >= maxSavedAddresses;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      body: SafeArea(
        child: book.addresses.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 48,
                        color: AppColors.orange,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'No saved addresses yet',
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Add an address to fill in checkout faster. It is '
                        'saved on this phone only.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'Saved on this phone only. Addresses are not encrypted '
                    'and are not linked to an account, because there are no '
                    'accounts yet. They fill in checkout and your delivery '
                    'location. Delete them any time.',
                    style: secondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final a in book.addresses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Material(
                        color: AppColors.surface,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          side: BorderSide(
                            color: a.id == selectedId
                                ? AppColors.forest
                                : AppColors.outline,
                            width: a.id == selectedId ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => notifier.select(a.id),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleMedium,
                                      ),
                                    ),
                                    if (a.id == selectedId)
                                      Text(
                                        'Selected',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: AppColors.forest,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text('${a.name} · ${a.phone}'),
                                Text('${a.address}, ${a.subCity}'),
                                if (a.landmark != null)
                                  Text('Landmark: ${a.landmark}'),
                                const SizedBox(height: AppSpacing.xs),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (a.id != selectedId)
                                      TextButton(
                                        onPressed: () => notifier.select(a.id),
                                        child: const Text('Use this address'),
                                      ),
                                    IconButton(
                                      tooltip: 'Edit ${a.label}',
                                      onPressed: () => context.push(
                                        AppRoutes.addressEditPath(a.id),
                                      ),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete ${a.label}',
                                      onPressed: () =>
                                          _confirmDelete(context, ref, a),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: full
                    ? null
                    : () => context.push(AppRoutes.addressNew),
                child: const Text('Add address'),
              ),
              if (full)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'You can save up to $maxSavedAddresses addresses. Delete '
                    'one to add another.',
                    style: secondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
