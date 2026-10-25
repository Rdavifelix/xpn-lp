-- Profiles: one row per auth.users, holding everything public about a user.
-- fragrances(id) is referenced by signature_fragrance_id but fragrances
-- doesn't exist yet, so that FK is added at the end of 0003_catalog.sql.

create table public.profiles (
  id                       uuid primary key references auth.users (id) on delete cascade,
  username                 citext not null unique,
  display_name             text,
  avatar_url               text,
  bio                      text,
  city                     text,
  country                  text,
  latitude                 double precision,
  longitude                double precision,
  signature_fragrance_id   uuid,
  followers_count          integer not null default 0,
  following_count          integer not null default 0,
  wears_count              integer not null default 0,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  constraint username_length check (char_length(username) between 3 and 30),
  constraint username_format check (username ~ '^[a-zA-Z0-9_.]+$')
);

comment on table public.profiles is 'Public profile data for each authenticated user.';

-- Shared trigger function: keeps updated_at current on any row update.
-- Reused by every table below that has an updated_at column.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile row the moment someone signs up via Supabase Auth,
-- so the app never has to juggle "user exists but profile doesn't" states.
-- The username is derived from the email as a placeholder; onboarding
-- (see src/features/auth) lets the user claim a real one, enforced unique
-- by the constraint above with an on-conflict suffix to avoid collisions.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username text;
  final_username text;
  suffix int := 0;
begin
  base_username := lower(regexp_replace(split_part(new.email, '@', 1), '[^a-zA-Z0-9_.]', '', 'g'));
  if base_username is null or base_username = '' then
    base_username := 'user';
  end if;
  base_username := left(base_username, 24);

  final_username := base_username;
  while exists (select 1 from public.profiles where username = final_username) loop
    suffix := suffix + 1;
    final_username := left(base_username, 24 - length(suffix::text) - 1) || '_' || suffix::text;
  end loop;

  insert into public.profiles (id, username, display_name)
  values (new.id, final_username, split_part(new.email, '@', 1));

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

-- Profiles are public (like Instagram/Gym Rats) — anyone signed in can view
-- anyone's profile. Only the owner can modify their own row.
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- No insert policy: rows are created exclusively by handle_new_user() via
-- the security-definer trigger above, never directly by client code.
