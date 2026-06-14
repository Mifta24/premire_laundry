-- Fix riwayat status dobel yang terjadi karena trigger otomatis dan insert manual.
-- Jalankan di Supabase SQL Editor setelah app/edge function memakai trigger sebagai
-- satu-satunya sumber order_status_histories.

delete from order_status_histories duplicate
using order_status_histories keeper
where duplicate.id <> keeper.id
  and duplicate.order_id = keeper.order_id
  and duplicate.status = keeper.status
  and coalesce(duplicate.changed_by, '00000000-0000-0000-0000-000000000000'::uuid)
      = coalesce(keeper.changed_by, '00000000-0000-0000-0000-000000000000'::uuid)
  and duplicate.note is null
  and keeper.note is not null
  and abs(extract(epoch from (duplicate.created_at - keeper.created_at))) <= 10;

-- Kalau masih ada duplikat identik tanpa note yang tercipta berdekatan,
-- simpan row paling awal dan hapus sisanya.
with ranked as (
  select
    id,
    lag(created_at) over (
      partition by order_id, status, changed_by, note
      order by created_at, id
    ) as previous_created_at
  from order_status_histories
)
delete from order_status_histories h
using ranked r
where h.id = r.id
  and r.previous_created_at is not null
  and abs(extract(epoch from (h.created_at - r.previous_created_at))) <= 10;
