-- The app identifies catalog items by a stable text slug (for example "tibs").
-- sort_order keeps the menu in a fixed order.
alter table public.restaurants
  add column slug text unique,
  add column sort_order int not null default 0;
alter table public.dishes
  add column slug text unique,
  add column rating numeric(2, 1) check (rating between 0 and 5),
  add column sort_order int not null default 0;