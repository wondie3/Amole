import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.search,
      title: 'Search is on its way',
      message: 'Find dishes and restaurants with working filters.',
      milestone: 3,
    );
  }
}
