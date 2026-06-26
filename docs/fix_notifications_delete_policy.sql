-- Tambah policy hapus notifikasi sendiri.
-- Jalankan di Supabase SQL Editor (tabel notifications sudah ada dari
-- add_notifications_table.sql, ini cuma nambah policy delete-nya).

drop policy if exists "notifications: user can delete own" on notifications;

create policy "notifications: user can delete own"
  on notifications for delete using (user_id = auth.uid());
