-- Fix status order tidak ikut berubah saat kurir update task.
-- Jalankan di Supabase SQL Editor.

drop policy if exists "orders: courier can update assigned" on orders;
create policy "orders: courier can update assigned"
  on orders for update
  using (
    get_my_role() = 'courier'
    and exists (
      select 1
      from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  )
  with check (
    get_my_role() = 'courier'
    and exists (
      select 1
      from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Repair data yang sudah terlanjur mismatch karena update order sebelumnya ditolak RLS.
update orders
set status = 'waiting_pickup',
    updated_at = now()
where status = 'created'
  and exists (
    select 1
    from courier_tasks
    where courier_tasks.order_id = orders.id
      and courier_tasks.task_type = 'pickup'
      and courier_tasks.status = 'on_the_way'
  );

update orders
set status = 'picked_up',
    updated_at = now()
where status = 'waiting_pickup'
  and exists (
    select 1
    from courier_tasks
    where courier_tasks.order_id = orders.id
      and courier_tasks.task_type = 'pickup'
      and courier_tasks.status = 'picked_up'
  );

update orders
set status = 'out_for_delivery',
    updated_at = now()
where status = 'ready_to_deliver'
  and exists (
    select 1
    from courier_tasks
    where courier_tasks.order_id = orders.id
      and courier_tasks.task_type = 'delivery'
      and courier_tasks.status = 'on_the_way'
  );

update orders
set status = 'completed',
    updated_at = now()
where status = 'out_for_delivery'
  and exists (
    select 1
    from courier_tasks
    where courier_tasks.order_id = orders.id
      and courier_tasks.task_type = 'delivery'
      and courier_tasks.status = 'delivered'
  );
