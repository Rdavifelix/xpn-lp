-- RPCs the client calls directly (see src/features/*/api). All run as
-- SECURITY INVOKER (the Postgres default) unless noted, so normal RLS
-- still applies to the calling user — these are conveniences for
-- shaping/joining data, not privilege escalations.

-- get_feed: the social feed, newest first, with author + fragrance already
-- joined and a per-viewer liked_by_me flag. Because this runs as the
-- caller, it can only ever return wears the "Wears are visible per their
-- visibility setting" RLS policy already allows that user to see — a
-- private/followers-only post from someone you don't follow simply won't
-- appear, with no special-casing needed here.
create or replace function public.get_feed(p_limit int default 20, p_before timestamptz default null)
returns table (
  id                     uuid,
  user_id                uuid,
  fragrance_id           uuid,
  worn_at                timestamptz,
  photo_url              text,
  caption                text,
  occasion_id            uuid,
  mood                   text,
  weather                jsonb,
  likes_count            integer,
  comments_count         integer,
  author_username        citext,
  author_display_name    text,
  author_avatar_url      text,
  fragrance_name         text,
  fragrance_brand_name   text,
  fragrance_image_url    text,
  liked_by_me            boolean
)
language sql
stable
set search_path = public
as $$
  select
    w.id, w.user_id, w.fragrance_id, w.worn_at, w.photo_url, w.caption,
    w.occasion_id, w.mood, w.weather, w.likes_count, w.comments_count,
    p.username, p.display_name, p.avatar_url,
    f.name, b.name, f.image_url,
    exists (select 1 from public.likes l where l.wear_id = w.id and l.user_id = auth.uid())
  from public.wears w
  join public.profiles p on p.id = w.user_id
  join public.fragrances f on f.id = w.fragrance_id
  join public.brands b on b.id = f.brand_id
  where p_before is null or w.worn_at < p_before
  order by w.worn_at desc
  limit greatest(least(coalesce(p_limit, 20), 100), 1);
$$;

-- toggle_like: flips the current user's like on a wear, returns the new
-- state. Relies entirely on the likes RLS policies for authorization.
create or replace function public.toggle_like(p_wear_id uuid)
returns boolean
language plpgsql
set search_path = public
as $$
declare
  already_liked boolean;
begin
  select exists (
    select 1 from public.likes where wear_id = p_wear_id and user_id = auth.uid()
  ) into already_liked;

  if already_liked then
    delete from public.likes where wear_id = p_wear_id and user_id = auth.uid();
    return false;
  else
    insert into public.likes (wear_id, user_id) values (p_wear_id, auth.uid());
    return true;
  end if;
end;
$$;

-- search_fragrances: fuzzy match on fragrance name or brand name using
-- pg_trgm similarity, so "chanel no5" / typos still surface results.
create or replace function public.search_fragrances(p_query text, p_limit int default 20)
returns setof public.fragrances
language sql
stable
-- extensions is included because similarity()/gin_trgm_ops live in the
-- extensions schema (see 0001_extensions.sql), not public.
set search_path = public, extensions
as $$
  select f.*
  from public.fragrances f
  join public.brands b on b.id = f.brand_id
  where p_query is null or p_query = ''
     or f.name ilike '%' || p_query || '%'
     or b.name ilike '%' || p_query || '%'
     or similarity(f.name, p_query) > 0.2
     or similarity(b.name, p_query) > 0.2
  order by greatest(similarity(f.name, coalesce(p_query, '')), similarity(b.name, coalesce(p_query, ''))) desc,
           f.wears_count desc
  limit greatest(least(coalesce(p_limit, 20), 100), 1);
$$;

-- friends_who_own: "which of your friends own this" on the fragrance
-- detail page. SECURITY DEFINER because it must read other users'
-- collection_items (owner-only under RLS) — but it only ever does so
-- scoped to (a) people auth.uid() follows and (b) status = 'owned' for one
-- specific fragrance, and returns profile rows, never raw collection rows
-- (so ratings/personal notes never leak through this path).
create or replace function public.friends_who_own(p_fragrance_id uuid)
returns setof public.profiles
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.profiles p
  join public.collection_items c on c.user_id = p.id
  join public.follows f on f.following_id = p.id
  where f.follower_id = auth.uid()
    and c.fragrance_id = p_fragrance_id
    and c.status = 'owned';
$$;

grant execute on function public.get_feed(int, timestamptz) to authenticated;
grant execute on function public.toggle_like(uuid) to authenticated;
grant execute on function public.search_fragrances(text, int) to authenticated;
grant execute on function public.friends_who_own(uuid) to authenticated;
