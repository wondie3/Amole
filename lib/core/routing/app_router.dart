import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/addresses/address_book_screen.dart';
import '../../features/addresses/address_form_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/order_confirmation_screen.dart';
import '../../features/credits/credits_screen.dart';
import '../../features/dish/dish_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/orders/order_history_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/restaurants/restaurant_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';

abstract final class AppRoutes {
  static const String home = '/home';
  static const String search = '/search';
  static const String cart = '/cart';
  static const String profile = '/profile';
  static const String credits = '/credits';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String settings = '/settings';
  static const String addresses = '/addresses';
  static const String addressNew = '/addresses/new';
  static const String addressEditPattern = '/addresses/:id/edit';
  static const String restaurantPattern = '/restaurants/:id';
  static const String dishPattern = '/dishes/:id';
  static const String orderDetailPattern = '/orders/:id';
  static const String orderConfirmationPattern = '/orders/:id/confirmation';

  static String restaurantPath(String id) =>
      '/restaurants/${Uri.encodeComponent(id)}';

  static String dishPath(String id) => '/dishes/${Uri.encodeComponent(id)}';

  static String orderDetailPath(String id) =>
      '/orders/${Uri.encodeComponent(id)}';

  static String orderConfirmationPath(String id) =>
      '/orders/${Uri.encodeComponent(id)}/confirmation';

  static String addressEditPath(String id) =>
      '/addresses/${Uri.encodeComponent(id)}/edit';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.cart,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.credits,
        builder: (context, state) => const CreditsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        builder: (context, state) => const AddressBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.addressNew,
        builder: (context, state) => const AddressFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.addressEditPattern,
        builder: (context, state) =>
            AddressFormScreen(addressId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.restaurantPattern,
        builder: (context, state) =>
            RestaurantScreen(restaurantId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.dishPattern,
        builder: (context, state) =>
            DishDetailScreen(dishId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderDetailPattern,
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.orderConfirmationPattern,
        builder: (context, state) =>
            OrderConfirmationScreen(orderId: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
});
