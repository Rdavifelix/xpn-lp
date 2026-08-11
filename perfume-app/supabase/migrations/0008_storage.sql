-- Storage buckets for avatars, wear photos, and (admin-managed) fragrance
-- catalog images. src/lib/storage/uploadImage.ts uploads to a path of the
-- form "<uid>/<timestamp>.<ext>" for avatars/wear-photos, which is what the
-- "own folder" policies below check against.

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('wear-photos', 'wear-photos', true),
  ('fragrance-images', 'fragrance-images', true)
on conflict (id) do nothing;

-- Public read on all three — profile photos, wear posts and the catalog
-- are all meant to be visible without a signed URL round-trip.
create policy "Avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Wear photos are publicly readable"
  on storage.objects for select
  using (bucket_id = 'wear-photos');

create policy "Fragrance images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'fragrance-images');

-- Uploads/edits/deletes are restricted to the user's own folder, i.e. the
-- first path segment must equal their auth uid.
create policy "Users can upload their own avatar"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update their own avatar"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can delete their own avatar"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can upload their own wear photos"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'wear-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update their own wear photos"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'wear-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can delete their own wear photos"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'wear-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- fragrance-images has no client-facing write policy: catalog imagery is
-- seeded/managed via the service_role key (migrations/admin tooling only).
