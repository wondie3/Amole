import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.person_outline,
      title: 'Profile is on its way',
      message: 'Account, addresses and order history will live here.',
      milestone: 7,
    );
  }
}
