-- Sample catalog for LOCAL development. Restaurants are fictional and prices
-- and ratings are not real. Fixed UUIDs and slugs let the app and database
-- agree on ids.
insert into public.restaurants (id, slug, sort_order, name, cuisine, rating, eta_min_minutes, eta_max_minutes, delivery_fee_santim) values
  ('10000000-0000-0000-0000-000000000001', 'gursha_corner', 1, 'Gursha Corner', 'Everyday injera meals', 4.5, 25, 35, 4000),
  ('10000000-0000-0000-0000-000000000002', 'meskel_kitchen', 2, 'Meskel Kitchen', 'Traditional wat', 4.6, 30, 40, 5000),
  ('10000000-0000-0000-0000-000000000003', 'sheger_grill', 3, 'Sheger Grill', 'Tibs and kitfo', 4.4, 20, 30, 4500),
  ('10000000-0000-0000-0000-000000000004', 'enat_injera_house', 4, 'Enat Injera House', 'Home-style and fasting', 4.7, 35, 45, 3500),
  ('10000000-0000-0000-0000-000000000005', 'buna_bet_bistro', 5, 'Buna Bet Bistro', 'Coffee and breakfast', 4.3, 15, 25, 3000)
on conflict (id) do nothing;

insert into public.dishes (id, slug, sort_order, restaurant_id, category, name, description, price_santim, rating, has_spice_options, image_asset) values
  ('20000000-0000-0000-0000-000000000001', 'wat_platter', 1, '10000000-0000-0000-0000-000000000002', 'stew', 'Doro wat',
   'Slow-simmered chicken in a rich, spicy berbere sauce, traditionally served with a boiled egg on injera.', 25000, 4.6, true, 'assets/images/foods/doro_wat.jpg'),
  ('20000000-0000-0000-0000-000000000002', 'fasting_platter', 2, '10000000-0000-0000-0000-000000000004', 'fasting', 'Shiro',
   'A smooth, savory stew of ground chickpeas with onion, garlic and spices, served with injera. A staple on fasting days.', 19000, 4.7, false, 'assets/images/foods/shiro.jpg'),
  ('20000000-0000-0000-0000-000000000003', 'tibs', 3, '10000000-0000-0000-0000-000000000003', 'grill', 'Tibs',
   'Sauteed cubes of meat with onion, pepper and spices, served with injera.', 32000, 4.4, true, 'assets/images/foods/tibs.jpg'),
  ('20000000-0000-0000-0000-000000000004', 'kitfo', 4, '10000000-0000-0000-0000-000000000003', 'grill', 'Kitfo',
   'Finely minced beef seasoned with spiced clarified butter and mitmita, served with ayib (fresh cheese) and injera.', 36000, 4.5, false, 'assets/images/foods/kitfo.jpg'),
  ('20000000-0000-0000-0000-000000000005', 'firfir', 5, '10000000-0000-0000-0000-000000000005', 'breakfast', 'Firfir',
   'Shredded injera tossed in a spiced berbere sauce, a popular breakfast dish.', 14000, 4.2, true, 'assets/images/foods/firfir.jpg')
on conflict (id) do nothing;