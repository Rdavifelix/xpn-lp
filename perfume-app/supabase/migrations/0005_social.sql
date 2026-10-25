-- The social graph and feed core: follows, wears ("what I'm wearing
-- today" posts), likes, comments.

create table public.follows (
  follower_id   uuid not null references public.profiles (id) on delete cascade,
  following_id  uuid not null references public.profiles (id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self_follow check (follower_id <> following_id)
);

create index follows_following_id_idx on public.follows (following_id);

create table public.wears (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  fragrance_id     uuid not null references public.fragrances (id) on delete cascade,
  worn_at          timestamptz not null default now(),
  photo_url        text,
  caption          text,
  occasion_id      uuid references public.occasions (id) on delete set null,
  mood             text,
  -- Snapshot of the weather at post time — see WeatherSnapshot in
  -- database.types.ts. Kept denormalized (rather than re-fetched later) so
  -- an old post still shows the weather it was actually worn in.
  weather          jsonb,
  likes_count      integer not null default 0,
  comments_count   integer not null default 0,
  visibility       text not null default 'public' check (visibility in ('public', 'followers')),
  created_at       timestamptz not null default now()
);

create index wears_feed_idx on public.wears (worn_at desc);
create index wears_user_id_idx on public.wears (user_id, worn_at desc);
create index wears_fragrance_id_idx on public.wears (fragrance_id);

create table public.likes (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  wear_id     uuid not null references public.wears (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, wear_id)
);

create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  wear_id     uuid not null references public.wears (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  body        text not null check (char_length(body) between 1 and 500),
  created_at  timestamptz not null default now()
);

create index comments_wear_id_idx on public.comments (wear_id, created_at);

-- Visibility helper -------------------------------------------------------
-- A wear is visible to: its author, anyone (if public), or followers of the
-- author (if visibility = 'followers'). Used directly in the wears select
-- policy and reused by likes/comments so a comment never leaks the
-- existence of a wear its author restricted to followers.
create or replace function public.can_view_wear(p_wear_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.wears w
    where w.id = p_wear_id
      and (
        w.visibility = 'public'
        or w.user_id = auth.uid()
        or exists (
          select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = w.user_id
        )
      )
  );
$$;

-- Counters ------------------------------------------------------------------
create or replace function public.adjust_profile_follow_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (tg_op = 'INSERT') then
    update public.profiles set following_count = following_count + 1 where id = new.follower_id;
    update public.profiles set followers_count = followers_count + 1 where id = new.following_id;
  elsif (tg_op = 'DELETE') then
    update public.profiles set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
    update public.profiles set followers_count = greatest(followers_count - 1, 0) where id = old.following_id;
  end if;
  return null;
end;
$$;

create trigger follows_adjust_counts
  after insert or delete on public.follows
  for each row execute function public.adjust_profile_follow_counts();

create or replace function public.adjust_wear_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (tg_op = 'INSERT') then
    update public.profiles set wears_count = wears_count + 1 where id = new.user_id;
    update public.fragrances set wears_count = wears_count + 1 where id = new.fragrance_id;
  elsif (tg_op = 'DELETE') then
    update public.profiles set wears_count = greatest(wears_count - 1, 0) where id = old.user_id;
    update public.fragrances set wears_count = greatest(wears_count - 1, 0) where id = old.fragrance_id;
  end if;
  return null;
end;
$$;

create trigger wears_adjust_counts
  after insert or delete on public.wears
  for each row execute function public.adjust_wear_counts();

create or replace function public.adjust_wear_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (tg_op = 'INSERT') then
    update public.wears set likes_count = likes_count + 1 where id = new.wear_id;
  elsif (tg_op = 'DELETE') then
    update public.wears set likes_count = greatest(likes_count - 1, 0) where id = old.wear_id;
  end if;
  return null;
end;
$$;

create trigger likes_adjust_count
  after insert or delete on public.likes
  for each row execute function public.adjust_wear_like_count();

create or replace function public.adjust_wear_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (tg_op = 'INSERT') then
    update public.wears set comments_count = comments_count + 1 where id = new.wear_id;
  elsif (tg_op = 'DELETE') then
    update public.wears set comments_count = greatest(comments_count - 1, 0) where id = old.wear_id;
  end if;
  return null;
end;
$$;

create trigger comments_adjust_count
  after insert or delete on public.comments
  for each row execute function public.adjust_wear_comment_count();

-- RLS -------------------------------------------------------------------
alter table public.follows enable row level security;
alter table public.wears enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;

-- Follow graph is public (needed to render follower/following lists, and
-- for "N friends own this" elsewhere) — only the follower can create/undo it.
create policy "Follow graph is publicly readable"
  on public.follows for select
  to authenticated
  using (true);

create policy "Users can follow others"
  on public.follows for insert
  to authenticated
  with check (auth.uid() = follower_id);

create policy "Users can unfollow"
  on public.follows for delete
  to authenticated
  using (auth.uid() = follower_id);

create policy "Wears are visible per their visibility setting"
  on public.wears for select
  to authenticated
  using (
    visibility = 'public'
    or user_id = auth.uid()
    or exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = wears.user_id
    )
  );

create policy "Users can post their own wears"
  on public.wears for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can edit their own wears"
  on public.wears for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own wears"
  on public.wears for delete
  to authenticated
  using (auth.uid() = user_id);

create policy "Likes are visible on wears the viewer can see"
  on public.likes for select
  to authenticated
  using (public.can_view_wear(wear_id));

create policy "Users can like wears they can see"
  on public.likes for insert
  to authenticated
  with check (auth.uid() = user_id and public.can_view_wear(wear_id));

create policy "Users can unlike their own like"
  on public.likes for delete
  to authenticated
  using (auth.uid() = user_id);

create policy "Comments are visible on wears the viewer can see"
  on public.comments for select
  to authenticated
  using (public.can_view_wear(wear_id));

create policy "Users can comment on wears they can see"
  on public.comments for insert
  to authenticated
  with check (auth.uid() = user_id and public.can_view_wear(wear_id));

create policy "Users can delete their own comments"
  on public.comments for delete
  to authenticated
  using (auth.uid() = user_id);
