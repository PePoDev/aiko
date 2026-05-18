insert into storage.buckets (id, name, public)
values
  ('receipts', 'receipts', false),
  ('documents', 'documents', false),
  ('exports', 'exports', false)
on conflict (id) do nothing;

create policy "users read own storage objects" on storage.objects
  for select using (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users insert own storage objects" on storage.objects
  for insert with check (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users update own storage objects" on storage.objects
  for update using (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users delete own storage objects" on storage.objects
  for delete using (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
