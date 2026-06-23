-- Tambah tabel notifications.
-- Jalankan di Supabase SQL Editor.
-- Selama ini notifikasi cuma dikirim lewat FCM push (send-notification),
-- jadi kalau device offline / token invalid, riwayatnya hilang dan tidak ada
-- in-app notification list. Tabel ini jadi riwayat notifikasi per user yang
-- diisi oleh edge function send-notification setiap kali push dikirim.

create table if not exists notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null,
  body        text not null,
  type        text,
  data        jsonb,
  is_read     boolean not null default false,
  created_at  timestamptz default now()
);

create index if not exists idx_notifications_user_id on notifications(user_id);

alter table notifications enable row level security;

drop policy if exists "notifications: user can read own" on notifications;
drop policy if exists "notifications: user can update own" on notifications;
drop policy if exists "notifications: admin can read all" on notifications;

create policy "notifications: user can read own"
  on notifications for select using (user_id = auth.uid());

-- Update dibatasi cuma untuk tandai sudah dibaca, bukan ganti isi notifikasi.
create policy "notifications: user can update own"
  on notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "notifications: admin can read all"
  on notifications for select using (get_my_role() = 'admin');

-- Insert hanya lewat service role key (edge function send-notification),
-- jadi tidak perlu insert policy untuk role authenticated.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table notifications;
  end if;
end $$;
