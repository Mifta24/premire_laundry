-- Fix bug-bug seputar pembatalan pesanan:
-- 1. Tugas kurir yang masih aktif (assigned/on_the_way) tidak ikut dibatalkan
--    saat order-nya dibatalkan, sehingga kurir bisa lanjut update status tugas
--    dan tanpa sengaja "menghidupkan ulang" order yang sudah cancelled.
-- 2. Voucher yang sudah dipakai (status 'used') tidak dikembalikan ke 'active'
--    saat order yang memakainya dibatalkan, sehingga voucher hilang permanen.
-- 3. Customer bisa mengubah status order miliknya ke status apa pun lewat
--    API/SDK langsung (RLS hanya cek kepemilikan, tidak cek transisi status).
-- Jalankan di Supabase SQL Editor.

create or replace function handle_order_cancelled()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    update courier_tasks
    set status = 'cancelled', updated_at = now()
    where order_id = new.id
      and status in ('assigned', 'on_the_way');

    update vouchers
    set status = 'active', used_order_id = null, used_at = null
    where used_order_id = new.id
      and status = 'used';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_handle_order_cancelled on orders;
create trigger trg_handle_order_cancelled
  after update on orders
  for each row execute function handle_order_cancelled();

-- Customer hanya boleh mengubah status order miliknya sendiri menjadi
-- 'cancelled', dan hanya selama order masih berstatus 'created'.
-- Admin & courier tidak terkena batasan ini (alur mereka sudah diatur
-- lewat policy/trigger lain).
create or replace function enforce_customer_order_status_transition()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if get_my_role() = 'customer' and new.status is distinct from old.status then
    if new.status <> 'cancelled'
       or old.status <> 'created'
       or old.payment_status <> 'pending' then
      raise exception
        'Pelanggan hanya bisa membatalkan pesanan yang masih berstatus "created" dan belum ada pembayaran berjalan';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_customer_order_status on orders;
create trigger trg_enforce_customer_order_status
  before update on orders
  for each row execute function enforce_customer_order_status_transition();

-- Repair data: kembalikan voucher yang sudah dipakai oleh order yang
-- ternyata sudah dibatalkan sebelum fix ini ada, dan batalkan task kurir
-- yang masih aktif untuk order yang sudah cancelled.
update vouchers
set status = 'active', used_order_id = null, used_at = null
where status = 'used'
  and used_order_id in (select id from orders where status = 'cancelled');

update courier_tasks
set status = 'cancelled', updated_at = now()
where status in ('assigned', 'on_the_way')
  and order_id in (select id from orders where status = 'cancelled');
