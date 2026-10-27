import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/catalog_providers.dart';
import '../../models/dish.dart';
import '../../models/food_category.dart';
import '../../models/restaurant.dart';
import '../../shared/widgets/catalog_rows.dart';
import '../../shared/widgets/state_views.dart';

class RestaurantScreen extends ConsumerWidget {
  const RestaurantScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(homeDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant')),
      body: SafeArea(
        child: catalog.when(
          loading: () => const CenteredLoading(),
          error: (error, stack) => ErrorRetryView(
            message: 'Could not load this restaurant. Please try again.',
            onRetry: () => ref.invalidate(homeDataProvider),
          ),
          data: (d) {
            final index = d.restaurants.indexWhere((r) => r.id == restaurantId);
            if (index < 0) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text('This restaurant could not be found.'),
                ),
              );
            }
            final restaurant = d.restaurants[index];
            final menu = d.dishes
                .where((x) => x.restaurantId == restaurant.id)
                .toList();
            return _RestaurantBody(
              restaurant: restaurant,
              tintIndex: index,
              menu: menu,
              categories: d.categories,
            );
          },
        ),
      ),
    );
  }
}

class _RestaurantBody extends StatelessWidget {
  const _RestaurantBody({
    required this.restaurant,
    required this.tintIndex,
    required this.menu,
    required this.categories,
  });

  final Restaurant restaurant;
  final int tintIndex;
  final List<Dish> menu;
  final List<FoodCategory> categories;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = restaurant;

    final sections = <Widget>[];
    for (final c in categories) {
      if (c.id == 'all') continue;
      final items = menu.where((d) => d.categoryId == c.id).toList();
      if (items.isEmpty) continue;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(c.label, style: textTheme.titleMedium),
        ),
      );
      for (final d in items) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: DishRow(dish: d),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: RestaurantInitialTile(
            name: r.name,
            tintIndex: tintIndex,
            height: 140,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(r.name, style: textTheme.headlineSmall),
        Text(
          r.cuisine,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            Text('★ ${r.rating}', style: textTheme.labelLarge),
            Text(
              '${r.etaMinMinutes}-${r.etaMaxMinutes} min',
              style: textTheme.labelLarge,
            ),
            Text(
              'Delivery ${formatEtb(r.deliveryFeeSantim)}',
              style: textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sample restaurant. Not a real business.',
          style: textTheme.labelMedium?.copyWith(color: AppColors.orangeDeep),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Menu',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (menu.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              'Menu coming soon. This sample restaurant has no dishes yet.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...sections,
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Adding dishes to a cart arrives in Milestones 4 and 5.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
