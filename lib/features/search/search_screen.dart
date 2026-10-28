import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog_providers.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';
import '../../shared/widgets/catalog_rows.dart';
import '../../shared/widgets/state_views.dart';
import 'search_logic.dart';
import 'search_providers.dart';

OutlineInputBorder _border(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadii.md),
  borderSide: BorderSide(color: color),
);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearText() {
    _controller.clear();
    ref.read(searchStateProvider.notifier).setText('');
  }

  void _resetAll() {
    _controller.clear();
    ref.read(searchStateProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeDataProvider);
    return SafeArea(
      child: catalog.when(
        loading: () => const CenteredLoading(),
        error: (error, stack) => ErrorRetryView(
          message: 'Could not load the menu. Please try again.',
          onRetry: () => ref.invalidate(homeDataProvider),
        ),
        data: (d) => _buildContent(context, d),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeData d) {
    final state = ref.watch(searchStateProvider);
    final results = ref.watch(searchResultsProvider).value;
    final notifier = ref.read(searchStateProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final names = {for (final r in d.restaurants) r.id: r.name};
    final isDishes = state.mode == SearchMode.dishes;
    final dishes = results?.dishes ?? const <Dish>[];
    final restaurants = results?.restaurants ?? const <Restaurant>[];
    final count = isDishes ? dishes.length : restaurants.length;

    final rows = <Widget>[];
    if (isDishes) {
      for (final dish in dishes) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: DishRow(
              dish: dish,
              restaurantName: names[dish.restaurantId],
              onTap: () => context.push(AppRoutes.dishPath(dish.id)),
            ),
          ),
        );
      }
    } else {
      for (final r in restaurants) {
        final index = d.restaurants.indexOf(r);
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: RestaurantRow(
              restaurant: r,
              tintIndex: index < 0 ? 0 : index,
              onTap: () => context.push(AppRoutes.restaurantPath(r.id)),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text('Search', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: notifier.setText,
          decoration: InputDecoration(
            hintText: 'Search dishes or restaurants',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: state.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: _clearText,
                  ),
            filled: true,
            fillColor: AppColors.surface,
            border: _border(AppColors.outline),
            enabledBorder: _border(AppColors.outline),
            focusedBorder: _border(AppColors.forest),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.categories.length,
            separatorBuilder: (context, i) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final c = d.categories[i];
              final isSelected = c.id == state.categoryId;
              return ChoiceChip(
                label: Text(c.label),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: AppColors.forest,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.outline),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.cream : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => notifier.setCategory(c.id),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<SearchMode>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.forest,
            selectedForegroundColor: AppColors.cream,
          ),
          segments: const [
            ButtonSegment<SearchMode>(
              value: SearchMode.dishes,
              label: Text('Dishes'),
              icon: Icon(Icons.restaurant_menu),
            ),
            ButtonSegment<SearchMode>(
              value: SearchMode.restaurants,
              label: Text('Restaurants'),
              icon: Icon(Icons.storefront_outlined),
            ),
          ],
          selected: {state.mode},
          onSelectionChanged: (s) => notifier.setMode(s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                '$count ${count == 1 ? 'result' : 'results'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            PopupMenuButton<SortOption>(
              tooltip: 'Sort results',
              initialValue: state.sort,
              onSelected: notifier.setSort,
              itemBuilder: (context) => [
                for (final o in sortOptionsFor(state.mode))
                  PopupMenuItem<SortOption>(value: o, child: Text(o.label)),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Text(state.sort.label, style: textTheme.labelLarge),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (count == 0)
          _EmptyState(filtered: state.isFiltered, onClear: _resetAll)
        else
          ...rows,
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sample data: dishes, prices and ratings are not real.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onClear});

  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filtered
                ? 'Nothing matches your search or filter.'
                : 'Nothing to show yet.',
            textAlign: TextAlign.center,
          ),
          if (filtered)
            TextButton(
              onPressed: onClear,
              child: const Text('Clear search and filters'),
            ),
        ],
      ),
    );
  }
}
