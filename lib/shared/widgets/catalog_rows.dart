import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';
import 'amole_image.dart';
import 'pressable.dart';

/// Temporary branded tile colors until licensed restaurant photos exist.
/// Same order as the Home restaurant cards so a restaurant keeps its color.
const List<Color> restaurantTints = [
  Color(0xFF263D32),
  Color(0xFFB8481C),
  Color(0xFF4A5D3A),
  Color(0xFF7A4B2A),
  Color(0xFF5B3A4A),
];

const double _thumbSize = 96;

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(AppRadii.md),
  border: Border.all(color: AppColors.outline),
);

class RestaurantInitialTile extends StatelessWidget {
  const RestaurantInitialTile({
    super.key,
    required this.name,
    required this.tintIndex,
    this.width,
    this.height,
  });

  final String name;
  final int tintIndex;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall
        ?.copyWith(color: AppColors.cream, fontWeight: FontWeight.w800);
    return Container(
      width: width,
      height: height,
      color: restaurantTints[tintIndex % restaurantTints.length],
      alignment: Alignment.center,
      child: ExcludeSemantics(
        child: Text(name.isEmpty ? '?' : name.substring(0, 1), style: style),
      ),
    );
  }
}

class DishRow extends StatelessWidget {
  const DishRow({
    super.key,
    required this.dish,
    this.restaurantName,
    this.onTap,
  });

  final Dish dish;
  final String? restaurantName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: _thumbSize,
            height: _thumbSize,
            child: AmoleImage(asset: dish.imageAsset, semanticLabel: dish.name),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dish.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  if (restaurantName != null)
                    Text(
                      restaurantName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${formatEtb(dish.priceSantim)}  ·  ★ ${dish.rating}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap!, child: row);
  }
}

class RestaurantRow extends StatelessWidget {
  const RestaurantRow({
    super.key,
    required this.restaurant,
    required this.tintIndex,
    required this.onTap,
  });

  final Restaurant restaurant;
  final int tintIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = restaurant;
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: _cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            RestaurantInitialTile(
              name: r.name,
              tintIndex: tintIndex,
              width: _thumbSize,
              height: _thumbSize,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      r.cuisine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '★ ${r.rating}  ·  ${r.etaMinMinutes}-${r.etaMaxMinutes} min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge,
                    ),
                    Text(
                      'Delivery ${formatEtb(r.deliveryFeeSantim)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
