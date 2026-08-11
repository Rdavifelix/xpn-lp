-- Extensions used across the schema:
--   pgcrypto  -> gen_random_uuid() for primary keys
--   citext    -> case-insensitive usernames (so "Jane" and "jane" collide)
--   pg_trgm   -> trigram indexes powering fuzzy search (fragrance/brand name)
create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;
create extension if not exists pg_trgm with schema extensions;
