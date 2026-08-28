-- Order code sebelumnya "PL-YYYYMMDD-XXXX" dengan XXXX random dari jam
-- device customer, jadi nggak berurutan meski pesanan masuk berturut-turut.
-- Diganti jadi nomor urut per hari ("PL-YYYYMMDD-001", "PL-YYYYMMDD-002", ...)
-- yang di-generate di database (trigger, security definer) supaya atomik
-- dan nggak bentrok walau ada 2 order masuk bersamaan.
-- Jalankan di Supabase SQL Editor.

create table if not exists order_code_sequences (
  date_key text primary key,
  last_seq integer not null default 0
);

alter table order_code_sequences enable row level security;

create or replace function generate_order_code() returns trigger
  security definer
  set search_path = public
  language plpgsql as $$
declare
  v_date_key text := to_char(now(), 'YYYYMMDD');
  next_seq integer;
begin
  if new.order_code is not null then
    return new;
  end if;

  insert into order_code_sequences (date_key, last_seq)
  values (v_date_key, 1)
  on conflict (date_key) do update set last_seq = order_code_sequences.last_seq + 1
  returning last_seq into next_seq;

  new.order_code := 'PL-' || v_date_key || '-' || lpad(next_seq::text, 3, '0');
  return new;
end;
$$;

drop trigger if exists trg_generate_order_code on orders;
create trigger trg_generate_order_code
  before insert on orders
  for each row execute function generate_order_code();
