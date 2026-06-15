-- Fix upload bukti pembayaran manual:
-- Jalankan di Supabase SQL Editor agar customer dapat upload file ke folder
-- miliknya sendiri: payment-proofs/{auth.uid()}/{order_id}/proof_*.jpg.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "payment-proofs: customer can upload" on storage.objects;
create policy "payment-proofs: customer can upload"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and auth.uid() is not null
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "payment-proofs: customer can read own" on storage.objects;
create policy "payment-proofs: customer can read own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and auth.uid() is not null
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "payment-proofs: admin can read all" on storage.objects;
create policy "payment-proofs: admin can read all"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and get_my_role() = 'admin'
  );
