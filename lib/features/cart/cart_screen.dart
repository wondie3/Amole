import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.shopping_bag_outlined,
      title: 'Cart is on its way',
      message: 'Your selected dishes and totals will be shown here.',
      milestone: 5,
    );
  }
}
