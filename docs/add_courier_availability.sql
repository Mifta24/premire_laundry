-- Tambah kolom status ketersediaan kurir.
-- Jalankan di Supabase SQL Editor.
-- Dipakai oleh halaman Akun Kurir untuk toggle "Aktif Menerima Tugas",
-- supaya admin bisa membedakan kurir yang sedang aktif vs tidak saat assign tugas.

alter table profiles
  add column if not exists is_available boolean not null default true;
