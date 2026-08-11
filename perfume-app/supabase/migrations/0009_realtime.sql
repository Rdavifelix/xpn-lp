-- Enable Realtime (logical replication) for the tables the social feed
-- subscribes to (src/features/feed/hooks/useRealtimeFeed.ts). Supabase
-- projects ship an empty `supabase_realtime` publication by default —
-- tables only broadcast postgres_changes once added to it explicitly.
alter publication supabase_realtime add table public.wears;
alter publication supabase_realtime add table public.comments;
alter publication supabase_realtime add table public.likes;
