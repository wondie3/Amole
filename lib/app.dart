import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_overlay.dart';

class AmoleApp extends ConsumerWidget {
  const AmoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Amole',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final appWithSplash =
            SplashOverlay(child: child ?? const SizedBox.shrink());
        return ColoredBox(
          color: const Color(0xFF14211A),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRect(child: appWithSplash),
            ),
          ),
        );
      },
    );
  }
}
