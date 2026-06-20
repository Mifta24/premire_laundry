-- Perbaikan: akun yang berhasil daftar (ada di auth.users) tapi tidak
-- punya baris di tabel profiles, sehingga nama & nomor HP tampil kosong
-- di aplikasi dan tetap kosong saat dibuka di form edit profil.
-- Jalankan di Supabase SQL Editor.

-- 1) Pastikan trigger handle_new_user terpasang dengan versi terbaru
--    (idempotent — aman dijalankan ulang). Lihat docs/setup.sql untuk versi acuan.
create or replace function handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into profiles (user_id, name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'role', 'customer')
  )
  on conflict (user_id) do update
    set name = excluded.name,
        phone = excluded.phone,
        role = excluded.role;

  insert into loyalty_points (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- 2) Backfill: buat baris profiles untuk akun yang sudah ada di auth.users
--    tapi belum punya profiles (termasuk akun yang baru saja diisi nama
--    & no HP saat registrasi, tapi triggernya belum sempat jalan).
insert into profiles (user_id, name, phone, role)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'name', split_part(u.email, '@', 1)),
  u.raw_user_meta_data->>'phone',
  coalesce(u.raw_user_meta_data->>'role', 'customer')
from auth.users u
left join profiles p on p.user_id = u.id
where p.user_id is null;

insert into loyalty_points (user_id)
select u.id
from auth.users u
left join loyalty_points lp on lp.user_id = u.id
where lp.user_id is null;
