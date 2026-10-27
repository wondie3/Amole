import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog_providers.dart';
import '../../data/sample_data.dart';
import '../../shared/widgets/amole_wordmark.dart';
import 'home_providers.dart';
import 'home_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return SafeArea(
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load the menu. Please try again.'),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => ref.invalidate(homeDataProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (d) => _HomeContent(data: d),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context);
    final selected = ref.watch(selectedCategoryProvider);
    final restaurantNames = {for (final r in data.restaurants) r.id: r.name};
    final dishes = selected == 'all'
        ? data.dishes
        : data.dishes.where((d) => d.categoryId == selected).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AmoleWordmark(fontSize: 30),
          const SizedBox(height: AppSpacing.md),
          _LocationPill(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Choosing a delivery location arrives with addresses '
                  '(Milestone 7).',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Selam! What are you craving?', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          _SearchField(onTap: () => context.go(AppRoutes.search)),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.categories.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final c = data.categories[i];
                final isSelected = c.id == selected;
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
                  onSelected: (_) =>
                      ref.read(selectedCategoryProvider.notifier).select(c.id),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const PromoBanner(asset: SampleData.bannerAsset),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Popular dishes'),
          const SizedBox(height: AppSpacing.md),
          if (dishes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.outline),
              ),
              child: Text(
                'No dishes in this category yet.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            SizedBox(
              height: DishCard.imageHeight + scale.scale(100),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dishes.length,
                separatorBuilder: (context, i) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, i) => DishCard(
                  dish: dishes[i],
                  restaurantName: restaurantNames[dishes[i].restaurantId] ?? '',
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Featured restaurants'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Fictional restaurants. Photos will be added later.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: RestaurantCard.tileHeight + scale.scale(110),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.restaurants.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) =>
                  RestaurantCard(restaurant: data.restaurants[i], index: i),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push(AppRoutes.credits),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Photo credits'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: AppColors.orange, size: 20),
                  SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Bole, Addis Ababa (sample)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.outline),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Search dishes or restaurants',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
