-- A user's personal relationship to a fragrance: owned/wishlist/tried,
-- their private rating & notes, bottle size, purchase info.

create table public.collection_items (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  fragrance_id     uuid not null references public.fragrances (id) on delete cascade,
  status           text not null default 'owned' check (status in ('owned', 'wishlist', 'tried')),
  -- 0-10 scale at half-star precision (rendered as 0-5 stars by RatingStars).
  rating           smallint check (rating between 0 and 10),
  personal_notes   text,
  bottle_size_ml   smallint check (bottle_size_ml > 0),
  remaining_pct    smallint not null default 100 check (remaining_pct between 0 and 100),
  purchase_date    date,
  purchase_price   numeric(10, 2),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (user_id, fragrance_id)
);

comment on table public.collection_items is 'A user''s owned/wishlist/tried fragrances, with personal rating and notes.';

create index collection_items_user_id_idx on public.collection_items (user_id, status);
create index collection_items_fragrance_id_idx on public.collection_items (fragrance_id);

create trigger collection_items_set_updated_at
  before update on public.collection_items
  for each row execute function public.set_updated_at();

-- Keep fragrances.avg_rating / ratings_count in sync with personal ratings
-- left in collection_items, so the fragrance detail page can show a
-- community average without an aggregate query on every read.
create or replace function public.refresh_fragrance_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_fragrance_id uuid;
begin
  target_fragrance_id := coalesce(new.fragrance_id, old.fragrance_id);

  update public.fragrances f
  set avg_rating = coalesce((
        select round(avg(c.rating)::numeric, 2)
        from public.collection_items c
        where c.fragrance_id = target_fragrance_id and c.rating is not null
      ), 0),
      ratings_count = (
        select count(*)
        from public.collection_items c
        where c.fragrance_id = target_fragrance_id and c.rating is not null
      )
  where f.id = target_fragrance_id;

  return null;
end;
$$;

create trigger collection_items_refresh_fragrance_rating
  after insert or update of rating or delete on public.collection_items
  for each row execute function public.refresh_fragrance_rating();

alter table public.collection_items enable row level security;

-- Fully private: only the owner can see or touch their collection. (Other
-- users only ever see aggregated effects of it — avg_rating on fragrances,
-- and the "friends who own this" RPC which itself runs as the caller and
-- is scoped to fragrance_id + status='owned', not raw row access.)
create policy "Users can view their own collection"
  on public.collection_items for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can add to their own collection"
  on public.collection_items for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own collection items"
  on public.collection_items for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can remove their own collection items"
  on public.collection_items for delete
  to authenticated
  using (auth.uid() = user_id);
