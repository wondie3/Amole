import '../models/dish.dart';
import '../models/food_category.dart';
import '../models/photo_credit.dart';
import '../models/restaurant.dart';

/// Sample data for development. Restaurant names are fictional placeholders
/// and nothing here is connected to a real restaurant, price or order.
abstract final class SampleData {
  static const String bannerAsset = 'assets/images/promo/shared_table.jpg';

  static const List<FoodCategory> categories = [
    FoodCategory(id: 'all', label: 'All'),
    FoodCategory(id: 'stew', label: 'Wat'),
    FoodCategory(id: 'grill', label: 'Tibs & grill'),
    FoodCategory(id: 'fasting', label: 'Fasting'),
    FoodCategory(id: 'breakfast', label: 'Breakfast'),
  ];

  static const List<Restaurant> restaurants = [
    Restaurant(
      id: 'gursha_corner',
      name: 'Gursha Corner',
      cuisine: 'Everyday injera meals',
      rating: 4.5,
      etaMinMinutes: 25,
      etaMaxMinutes: 35,
      deliveryFeeSantim: 4000,
    ),
    Restaurant(
      id: 'meskel_kitchen',
      name: 'Meskel Kitchen',
      cuisine: 'Traditional wat',
      rating: 4.6,
      etaMinMinutes: 30,
      etaMaxMinutes: 40,
      deliveryFeeSantim: 5000,
    ),
    Restaurant(
      id: 'sheger_grill',
      name: 'Sheger Grill',
      cuisine: 'Tibs and kitfo',
      rating: 4.4,
      etaMinMinutes: 20,
      etaMaxMinutes: 30,
      deliveryFeeSantim: 4500,
    ),
    Restaurant(
      id: 'enat_injera_house',
      name: 'Enat Injera House',
      cuisine: 'Home-style and fasting',
      rating: 4.7,
      etaMinMinutes: 35,
      etaMaxMinutes: 45,
      deliveryFeeSantim: 3500,
    ),
    Restaurant(
      id: 'buna_bet_bistro',
      name: 'Buna Bet Bistro',
      cuisine: 'Coffee and breakfast',
      rating: 4.3,
      etaMinMinutes: 15,
      etaMaxMinutes: 25,
      deliveryFeeSantim: 3000,
    ),
  ];

  // Descriptions are general and should be reviewed against local serving.
  static const List<Dish> dishes = [
    Dish(
      id: 'wat_platter',
      name: 'Doro wat',
      restaurantId: 'meskel_kitchen',
      categoryId: 'stew',
      priceSantim: 25000,
      rating: 4.6,
      imageAsset: 'assets/images/foods/doro_wat.jpg',
      description:
          'Slow-simmered chicken in a rich, spicy berbere sauce, traditionally '
          'served with a boiled egg on injera.',
      hasSpiceOptions: true,
    ),
    Dish(
      id: 'fasting_platter',
      name: 'Shiro',
      restaurantId: 'enat_injera_house',
      categoryId: 'fasting',
      priceSantim: 19000,
      rating: 4.7,
      imageAsset: 'assets/images/foods/shiro.jpg',
      description:
          'A smooth, savory stew of ground chickpeas with onion, garlic and '
          'spices, served with injera. A staple on fasting days.',
    ),
    Dish(
      id: 'tibs',
      name: 'Tibs',
      restaurantId: 'sheger_grill',
      categoryId: 'grill',
      priceSantim: 32000,
      rating: 4.4,
      imageAsset: 'assets/images/foods/tibs.jpg',
      description:
          'Sauteed cubes of meat with onion, pepper and spices, served with '
          'injera.',
      hasSpiceOptions: true,
    ),
    Dish(
      id: 'kitfo',
      name: 'Kitfo',
      restaurantId: 'sheger_grill',
      categoryId: 'grill',
      priceSantim: 36000,
      rating: 4.5,
      imageAsset: 'assets/images/foods/kitfo.jpg',
      description:
          'Finely minced beef seasoned with spiced clarified butter and '
          'mitmita, served with ayib (fresh cheese) and injera.',
    ),
    Dish(
      id: 'firfir',
      name: 'Firfir',
      restaurantId: 'buna_bet_bistro',
      categoryId: 'breakfast',
      priceSantim: 14000,
      rating: 4.2,
      imageAsset: 'assets/images/foods/firfir.jpg',
      description:
          'Shredded injera tossed in a spiced berbere sauce, a popular '
          'breakfast dish.',
      hasSpiceOptions: true,
    ),
  ];

  /// Mirrors assets/images/ATTRIBUTIONS.md. Keep the two in sync; a unit
  /// test fails if a dish or the banner uses a photo with no credit here.
  static const List<PhotoCredit> photoCredits = [
    PhotoCredit(
      asset: 'assets/images/foods/doro_wat.jpg',
      subject: 'Doro wat',
      author: 'Miguel Discar',
      license: 'CC BY-SA 2.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/2.0/',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:A_formal_serving_of_wat_atop_injera_in_Brussels,_Belgium.jpg',
    ),
    PhotoCredit(
      asset: 'assets/images/foods/shiro.jpg',
      subject: 'Shiro',
      author: 'Florian Fell',
      license: 'CC BY-SA 3.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/3.0/',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Fastenessen_fasting_meal.JPG',
    ),
    PhotoCredit(
      asset: 'assets/images/foods/tibs.jpg',
      subject: 'Tibs',
      author: 'Sofia.jahn',
      license: 'CC BY-SA 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Tibs_1.jpg',
    ),
    PhotoCredit(
      asset: 'assets/images/foods/kitfo.jpg',
      subject: 'Kitfo',
      author: 'Lelaw Wendimu',
      license: 'CC BY-SA 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      sourceUrl:
          'https://commons.wikimedia.org/wiki/File:Kitfo,_Ayib_and_Injera.jpg',
    ),
    PhotoCredit(
      asset: 'assets/images/foods/firfir.jpg',
      subject: 'Firfir',
      author: 'Temesgen Woldezion (edited by Merhawie Woldezion)',
      license: 'CC BY-SA 2.5',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/2.5/',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Taita_fit-fit.jpg',
    ),
    PhotoCredit(
      asset: 'assets/images/promo/shared_table.jpg',
      subject: 'Injera spread',
      author: 'Jeff Gunn',
      license: 'CC BY 2.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/2.0/',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Queen_of_Sheba.jpg',
    ),
  ];
}
