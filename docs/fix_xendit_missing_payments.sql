-- Jalankan di Supabase SQL Editor untuk memperbaiki:
-- Pembayaran via Xendit (payment gateway) tidak muncul di laporan pendapatan.
--
-- Root cause: create-xendit-invoice memakai
--   upsert(..., { onConflict: "order_id" })
-- tapi payments.order_id cuma punya index biasa (idx_payments_order_id),
-- bukan unique constraint. Postgres menolak upsert itu ("no unique or
-- exclusion constraint matching ON CONFLICT"), dan karena error-nya tidak
-- pernah dicek, row payment untuk transaksi Xendit tidak pernah tersimpan.
-- Order tetap kelihatan "paid" (di-update oleh xendit-webhook lewat
-- orders.payment_status), tapi laporan pendapatan (admin_provider.dart)
-- baca dari tabel payments saja, jadi transaksi gateway hilang dari laporan.
--
-- File ini: 1) cek & gabungkan duplikat order_id di payments (kalau ada),
-- 2) tambah unique constraint supaya upsert ke depan berfungsi normal,
-- 3) backfill payments yang hilang untuk order lama yang sudah paid.

begin;

-- 1) Pastikan tidak ada duplikat order_id sebelum bikin unique constraint.
--    Kalau ada order dengan >1 payment row, simpan yang paid duluan/terbaru,
--    hapus sisanya (menghindari kegagalan constraint creation di langkah 2).
with ranked_payments as (
  select
    id,
    row_number() over (
      partition by order_id
      order by
        (status = 'paid') desc,
        coalesce(paid_at, updated_at, created_at) desc
    ) as rn
  from payments
)
delete from payments p
using ranked_payments rp
where p.id = rp.id
  and rp.rn > 1;

-- 2) Tambah unique constraint di order_id supaya
--    upsert(..., { onConflict: "order_id" }) di create-xendit-invoice
--    benar-benar berfungsi (sebelumnya gagal diam-diam).
alter table payments
  add constraint payments_order_id_key unique (order_id);

-- 3) Backfill: order yang statusnya sudah paid tapi tidak punya payments
--    row sama sekali (korban bug di atas). Method diasumsikan 'xendit'
--    karena jalur manual (manual_qris/manual_transfer) selalu insert
--    langsung dan tidak kena bug upsert ini.
insert into payments (
  order_id, customer_id, method, provider, amount,
  status, paid_at, created_at, updated_at
)
select
  o.id,
  o.customer_id,
  'xendit',
  'xendit',
  o.total_amount,
  'paid',
  coalesce(o.updated_at, o.created_at, now()),
  o.created_at,
  o.updated_at
from orders o
where o.payment_status = 'paid'
  and not exists (
    select 1 from payments p where p.order_id = o.id
  );

commit;

-- Cek hasil backfill:
-- select count(*) from orders o
-- where o.payment_status = 'paid'
--   and not exists (select 1 from payments p where p.order_id = o.id);
-- -- harus 0 setelah script ini dijalankan
