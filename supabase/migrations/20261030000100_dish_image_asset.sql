-- Bundled photo name for each dish (the app ships the photos for now).
alter table public.dishes add column image_asset text;
-- Column-level read access is not used on dishes; the existing select grant
-- on the table already covers new columns.