-- Promo broadcast: satu kode yang sama dipakai banyak user (mis. PREMIER20),
-- beda dari tabel vouchers yang satu baris = satu voucher milik satu user.
-- Jalankan di Supabase SQL Editor.

create table if not exists promo_codes (
  id                uuid primary key default gen_random_uuid(),
  code              text unique not null,
  discount_percent  numeric not null,
  max_discount      numeric,
  new_user_only     boolean not null default true,
  is_active         boolean not null default true,
  expired_at        timestamptz,
  created_at        timestamptz default now()
);

-- Jejak siapa yang sudah memakai kode promo apa, supaya satu user cuma bisa
-- pakai satu kode promo sekali (constraint unique di bawah).
create table if not exists promo_code_redemptions (
  id              uuid primary key default gen_random_uuid(),
  promo_code_id   uuid not null references promo_codes(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  order_id        uuid references orders(id),
  redeemed_at     timestamptz default now(),
  unique (promo_code_id, user_id)
);

create index if not exists idx_promo_code_redemptions_user
  on promo_code_redemptions(user_id);

alter table promo_codes enable row level security;
alter table promo_code_redemptions enable row level security;

drop policy if exists "promo_codes: authenticated can read" on promo_codes;
create policy "promo_codes: authenticated can read"
  on promo_codes for select using (auth.uid() is not null);

drop policy if exists "promo_codes: admin can insert" on promo_codes;
create policy "promo_codes: admin can insert"
  on promo_codes for insert with check (get_my_role() = 'admin');

drop policy if exists "promo_codes: admin can update" on promo_codes;
create policy "promo_codes: admin can update"
  on promo_codes for update using (get_my_role() = 'admin');

drop policy if exists "promo_code_redemptions: user can read own" on promo_code_redemptions;
create policy "promo_code_redemptions: user can read own"
  on promo_code_redemptions for select using (user_id = auth.uid());

drop policy if exists "promo_code_redemptions: user can insert own" on promo_code_redemptions;
create policy "promo_code_redemptions: user can insert own"
  on promo_code_redemptions for insert with check (user_id = auth.uid());

drop policy if exists "promo_code_redemptions: user can delete own" on promo_code_redemptions;
create policy "promo_code_redemptions: user can delete own"
  on promo_code_redemptions for delete using (user_id = auth.uid());

drop policy if exists "promo_code_redemptions: admin can read all" on promo_code_redemptions;
create policy "promo_code_redemptions: admin can read all"
  on promo_code_redemptions for select using (get_my_role() = 'admin');
