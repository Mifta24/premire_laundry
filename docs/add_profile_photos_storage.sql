-- Foto profil untuk customer/kurir/admin.
-- Jalankan di Supabase SQL Editor SETELAH membuat bucket secara manual:
--   Dashboard -> Storage -> New bucket -> name: "profile-photos" -> Public bucket: ON
-- (sama seperti cara bucket "qris-assets" dibuat).
--
-- App meng-upload ke path "{user_id}/avatar.jpg" lalu memakai getPublicUrl(),
-- jadi bucket WAJIB public agar foto bisa ditampilkan tanpa signed URL.

drop policy if exists "profile-photos: user can upload own" on storage.objects;
create policy "profile-photos: user can upload own"
  on storage.objects for insert
  with check (
    bucket_id = 'profile-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "profile-photos: user can update own" on storage.objects;
create policy "profile-photos: user can update own"
  on storage.objects for update
  using (
    bucket_id = 'profile-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "profile-photos: authenticated can read" on storage.objects;
create policy "profile-photos: authenticated can read"
  on storage.objects for select
  using (
    bucket_id = 'profile-photos'
    and auth.role() = 'authenticated'
  );
