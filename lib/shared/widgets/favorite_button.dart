import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/favorites/favorites_provider.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.dishId});

  final String dishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoritesProvider.select((s) => s.contains(dishId)),
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IconButton(
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(dishId),
      icon: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          key: ValueKey<bool>(isFavorite),
          color: isFavorite ? AppColors.orangeDeep : null,
        ),
      ),
    );
  }
}
