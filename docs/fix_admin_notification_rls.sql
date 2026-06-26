-- Fix: customer membuat order baru tidak pernah menotif admin.
-- Jalankan di Supabase SQL Editor.
-- _notifyAdminsNewOrder (customer_provider.dart) query "profiles" where role
-- = 'admin' untuk dapat user_id semua admin. Tapi policy profiles yang ada
-- cuma izinkan user baca profile sendiri, atau admin baca semua -- customer
-- tidak punya akses baca profile admin sama sekali. Query itu balik list
-- kosong tanpa error (RLS cuma filter row, bukan throw), jadi notifikasi
-- "Pesanan Baru" ke admin diam-diam tidak pernah terkirim.

drop policy if exists "profiles: authenticated can read admins" on profiles;

create policy "profiles: authenticated can read admins"
  on profiles for select
  using (role = 'admin' and auth.role() = 'authenticated');
