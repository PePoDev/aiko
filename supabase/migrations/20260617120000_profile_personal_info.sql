-- Profile personal-info expansion (full name, gender, date of birth, phone
-- number) plus avatar storage support: an `avatars` Supabase Storage bucket
-- keyed by the user's UUID at the first path segment. The bucket is public
-- so the avatar can be rendered with a stable URL across devices without
-- short-lived signed URLs; RLS restricts writes/updates/deletes to the
-- owning user.

alter table public.profiles
  add column if not exists full_name text,
  add column if not exists gender text not null default 'preferNotToSay',
  add column if not exists date_of_birth date,
  add column if not exists phone_number text,
  add column if not exists avatar_path text,
  add column if not exists avatar_url text;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Anyone with the URL can read an avatar; uploads / replacements / deletes
-- are scoped to the user's own folder so a different auth.uid() can never
-- touch someone else's photo.
create policy "avatars are publicly readable"
  on storage.objects
  for select using (bucket_id = 'avatars');

create policy "users upload their own avatar"
  on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users update their own avatar"
  on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users delete their own avatar"
  on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
