import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/saved_address.dart';
import '../../shared/widgets/state_views.dart';
import 'addresses_active.dart';
import 'addresses_logic.dart';
import 'addresses_provider.dart';
import 'addresses_remote_logic.dart';

class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  bool _copying = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete(SavedAddress a) async {
    final actions = ref.read(addressActionsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('"${a.label}" will be removed.'),
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
    if (confirmed != true) return;
    final error = await actions.delete(a.id);
    if (error != null && mounted) _snack(error);
  }

  Future<void> _select(SavedAddress a) async {
    final error = await ref.read(addressActionsProvider).select(a.id);
    if (error != null && mounted) _snack(error);
  }

  Future<void> _copy() async {
    if (_copying) return;
    final notifier = ref.read(remoteAddressesProvider.notifier);
    final local = ref.read(addressesProvider).addresses;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copy phone addresses to your account?'),
        content: Text(
          '${local.length} ${local.length == 1 ? 'address' : 'addresses'} '
          'saved on this phone will be copied to your account on the Amole '
          'test server. Addresses already in your account are skipped. The '
          'copies on this phone are not changed or deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Copy addresses'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _copying = true);
    final report = await notifier.copyLocal(local);
    if (!mounted) return;
    setState(() => _copying = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CopyResultDialog(report: report),
    );
  }

  Widget _copyCard(int count, TextStyle? secondary) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
            'You have $count ${count == 1 ? 'address' : 'addresses'} saved '
            'on this phone. Copying is optional and never happens '
            'automatically.',
            style: secondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _copying ? null : _copy,
            child: Text(
              _copying ? 'Copying...' : 'Copy my phone addresses to my account',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(activeAddressesProvider);
    final status = ref.watch(addressesStatusProvider);
    final account = ref.watch(addressModeProvider) == AddressMode.account;
    final localAddresses = ref.watch(addressesProvider).addresses;
    final notifier = ref.read(addressActionsProvider);
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    final selectedId = book.selected?.id;
    final ready = status == AddressesStatus.ready;
    final full = book.addresses.length >= maxSavedAddresses;
    final showCopy = account && ready && localAddresses.isNotEmpty;
    final info = account
        ? 'Saved in your account on the local test server. These are separate '
              'from the addresses saved on this phone. Delete them any time.'
        : 'Saved on this phone only. Addresses are not encrypted and are not '
              'linked to an account, because there are no accounts yet. They '
              'fill in checkout and your delivery location. Delete them any '
              'time.';

    final Widget body;
    if (status == AddressesStatus.loading) {
      body = const CenteredLoading();
    } else if (status == AddressesStatus.error) {
      body = ErrorRetryView(
        message: 'Could not load your addresses. Please try again.',
        onRetry: () => ref.invalidate(remoteAddressesProvider),
      );
    } else if (book.addresses.isEmpty) {
      body = Center(
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
              Text('No saved addresses yet', style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                account
                    ? 'Add an address to your account to fill in checkout '
                          'faster.'
                    : 'Add an address to fill in checkout faster. It is '
                          'saved on this phone only.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (showCopy) ...[
                const SizedBox(height: AppSpacing.lg),
                _copyCard(localAddresses.length, secondary),
              ],
            ],
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(info, style: secondary),
          const SizedBox(height: AppSpacing.md),
          if (showCopy) _copyCard(localAddresses.length, secondary),
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
                  onTap: () => _select(a),
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
                        if (a.landmark != null) Text('Landmark: ${a.landmark}'),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (a.id != selectedId)
                              TextButton(
                                onPressed: () => _select(a),
                                child: const Text('Use this address'),
                              ),
                            IconButton(
                              tooltip: 'Edit ${a.label}',
                              onPressed: () =>
                                  context.push(AppRoutes.addressEditPath(a.id)),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete ${a.label}',
                              onPressed: () => _confirmDelete(a),
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
      );
    }

    // The notifier variable keeps the actions provider alive for this screen.
    assert(notifier.hashCode >= 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      body: SafeArea(child: body),
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
                onPressed: (full || !ready)
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

class _CopyResultDialog extends StatelessWidget {
  const _CopyResultDialog({required this.report});

  final CopyReport report;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Copy finished'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Copied: ${report.copied}'),
          Text('Already in your account (skipped): ${report.duplicates}'),
          if (report.overLimit > 0)
            Text(
              'Not copied, account limit of $maxSavedAddresses reached: '
              '${report.overLimit}',
            ),
          if (report.failed > 0) Text('Failed: ${report.failed}'),
          if (report.firstError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(report.firstError!),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Text('Your addresses on this phone were not changed.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
