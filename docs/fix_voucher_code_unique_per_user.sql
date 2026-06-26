-- Vouchers.code awalnya unique secara global, jadi satu kode cuma bisa
-- dipakai 1 baris di seluruh tabel. Untuk promo broadcast (kode yang sama
-- dibagikan ke banyak customer sekaligus, mis. "PREMIER20" untuk semua user
-- baru), constraint-nya perlu dilonggarkan jadi unique per (code, user_id) -
-- satu user tetap cuma bisa punya 1 baris dengan kode itu, tapi user lain
-- boleh punya baris terpisah dengan kode yang sama.
-- Jalankan di Supabase SQL Editor.

alter table vouchers drop constraint if exists vouchers_code_key;

alter table vouchers
  add constraint vouchers_code_user_id_key unique (code, user_id);
