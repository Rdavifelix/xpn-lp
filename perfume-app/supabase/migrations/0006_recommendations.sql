-- Data backing the smart recommendation engine (src/features/recommendations):
-- a calendar of commemorative dates/holidays that map to an occasion, and a
-- cache of each user's computed "scent for today".

create table public.occasion_calendar (
  id             uuid primary key default gen_random_uuid(),
  slug           text not null unique,
  name           text not null,
  -- Fixed-date holidays set month/day directly (e.g. Valentine's Day = 2/14).
  -- Movable-feast holidays (Easter, Mother's Day, ...) leave these null and
  -- set is_movable = true — their actual date for a given year is computed
  -- client-side (src/features/recommendations/occasions.ts) since that math
  -- doesn't belong in SQL.
  month          smallint check (month between 1 and 12),
  day            smallint check (day between 1 and 31),
  is_movable     boolean not null default false,
  -- null = applies globally; set for country-specific observances.
  country_code   text,
  occasion_id    uuid not null references public.occasions (id) on delete cascade,
  -- How many days beforehand the recommendation engine should start
  -- factoring this occasion in (a lead-up window rather than a single day).
  lead_days      smallint not null default 3,
  constraint occasion_calendar_date_shape check (
    (is_movable and month is null and day is null)
    or (not is_movable and month is not null and day is not null)
  )
);

create table public.daily_recommendations (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  for_date    date not null,
  fragrance_id uuid not null references public.fragrances (id) on delete cascade,
  score       numeric(6, 2) not null,
  -- Structured explanation (RecommendationReason in database.types.ts) so
  -- the "Your scent for today" card can show *why* without recomputing.
  reason      jsonb not null,
  created_at  timestamptz not null default now(),
  unique (user_id, for_date)
);

create index daily_recommendations_user_date_idx on public.daily_recommendations (user_id, for_date desc);

alter table public.occasion_calendar enable row level security;
alter table public.daily_recommendations enable row level security;

create policy "Occasion calendar is publicly readable"
  on public.occasion_calendar for select
  to authenticated
  using (true);

create policy "Users can view their own daily recommendations"
  on public.daily_recommendations for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can save their own daily recommendation"
  on public.daily_recommendations for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own daily recommendation"
  on public.daily_recommendations for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
