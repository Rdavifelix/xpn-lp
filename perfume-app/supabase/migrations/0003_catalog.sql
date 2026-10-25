-- The fragrance catalog: brands, notes/ingredients, accords, occasions, and
-- the fragrances themselves with their many-to-many relations to notes,
-- accords, seasons and occasions. This is reference data — readable by
-- everyone, writable only by service_role (migrations/seed/admin tooling),
-- never directly by app users.

create table public.brands (
  id             uuid primary key default gen_random_uuid(),
  name           text not null unique,
  country        text,
  founded_year   int,
  logo_url       text,
  created_at     timestamptz not null default now()
);

create table public.notes (
  id             uuid primary key default gen_random_uuid(),
  name           text not null unique,
  -- Matches the accord family vocabulary (theme/colors.ts ACCORD_FAMILY_COLORS)
  -- so a note's chip can be tinted consistently with the accord chart.
  note_family    text not null check (note_family in (
                   'citrus', 'floral', 'woody', 'oriental', 'fresh', 'gourmand',
                   'spicy', 'green', 'aquatic', 'musk', 'leather', 'resin'
                 )),
  description    text,
  created_at     timestamptz not null default now()
);

create table public.accords (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique,
  label      text not null,
  hex_color  text not null check (hex_color ~ '^#[0-9A-Fa-f]{6}$')
);

create table public.occasions (
  id     uuid primary key default gen_random_uuid(),
  slug   text not null unique,
  label  text not null,
  icon   text
);

create table public.fragrances (
  id              uuid primary key default gen_random_uuid(),
  brand_id        uuid not null references public.brands (id) on delete restrict,
  name            text not null,
  release_year    int,
  gender          text not null check (gender in ('masculine', 'feminine', 'unisex')),
  concentration   text not null check (concentration in ('edc', 'edt', 'edp', 'parfum', 'extrait', 'oil')),
  description     text,
  image_url       text,
  longevity       smallint check (longevity between 1 and 5),
  sillage         smallint check (sillage between 1 and 5),
  -- Denormalized aggregates, kept current by the trigger in 0004_collection.sql
  -- (recomputed from collection_items.rating) and 0005_social.sql
  -- (wears_count from wears) — avoids an expensive aggregate query on every
  -- fragrance detail page view.
  avg_rating      numeric(3, 2) not null default 0,
  ratings_count   integer not null default 0,
  wears_count     integer not null default 0,
  created_at      timestamptz not null default now(),
  unique (brand_id, name, release_year)
);

alter table public.profiles
  add constraint profiles_signature_fragrance_fkey
  foreign key (signature_fragrance_id) references public.fragrances (id) on delete set null;

create table public.fragrance_notes (
  fragrance_id   uuid not null references public.fragrances (id) on delete cascade,
  note_id        uuid not null references public.notes (id) on delete cascade,
  pyramid_level  text not null check (pyramid_level in ('top', 'middle', 'base')),
  -- Display order within a tier (e.g. bergamot before pink pepper in "top").
  position       smallint not null default 0,
  primary key (fragrance_id, note_id, pyramid_level)
);

create table public.fragrance_accords (
  fragrance_id  uuid not null references public.fragrances (id) on delete cascade,
  accord_id     uuid not null references public.accords (id) on delete cascade,
  intensity     smallint not null check (intensity between 0 and 100),
  primary key (fragrance_id, accord_id)
);

-- Season suitability score (0-100), one row per season. Feeds directly into
-- the recommendation scoring function's seasonFit term.
create table public.fragrance_seasons (
  fragrance_id  uuid not null references public.fragrances (id) on delete cascade,
  season        text not null check (season in ('spring', 'summer', 'fall', 'winter')),
  score         smallint not null check (score between 0 and 100),
  primary key (fragrance_id, season)
);

create table public.fragrance_occasions (
  fragrance_id  uuid not null references public.fragrances (id) on delete cascade,
  occasion_id   uuid not null references public.occasions (id) on delete cascade,
  score         smallint not null check (score between 0 and 100),
  primary key (fragrance_id, occasion_id)
);

-- Search & browse indexes -----------------------------------------------
create index brands_name_trgm_idx on public.brands using gin (name extensions.gin_trgm_ops);
create index fragrances_name_trgm_idx on public.fragrances using gin (name extensions.gin_trgm_ops);
create index fragrances_brand_id_idx on public.fragrances (brand_id);
create index fragrance_notes_note_id_idx on public.fragrance_notes (note_id);
create index fragrance_accords_accord_id_idx on public.fragrance_accords (accord_id);
create index fragrance_occasions_occasion_id_idx on public.fragrance_occasions (occasion_id);

-- RLS: catalog is read-only reference data ---------------------------------
alter table public.brands enable row level security;
alter table public.notes enable row level security;
alter table public.accords enable row level security;
alter table public.occasions enable row level security;
alter table public.fragrances enable row level security;
alter table public.fragrance_notes enable row level security;
alter table public.fragrance_accords enable row level security;
alter table public.fragrance_seasons enable row level security;
alter table public.fragrance_occasions enable row level security;

create policy "Brands are publicly readable" on public.brands for select to authenticated using (true);
create policy "Notes are publicly readable" on public.notes for select to authenticated using (true);
create policy "Accords are publicly readable" on public.accords for select to authenticated using (true);
create policy "Occasions are publicly readable" on public.occasions for select to authenticated using (true);
create policy "Fragrances are publicly readable" on public.fragrances for select to authenticated using (true);
create policy "Fragrance notes are publicly readable" on public.fragrance_notes for select to authenticated using (true);
create policy "Fragrance accords are publicly readable" on public.fragrance_accords for select to authenticated using (true);
create policy "Fragrance seasons are publicly readable" on public.fragrance_seasons for select to authenticated using (true);
create policy "Fragrance occasions are publicly readable" on public.fragrance_occasions for select to authenticated using (true);

-- Deliberately no insert/update/delete policies: catalog data is managed
-- via migrations/seed data and, later, admin tooling using the
-- service_role key, which bypasses RLS entirely.
