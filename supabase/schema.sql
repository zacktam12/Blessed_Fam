-- BlessedFam Supabase schema
-- Roles: admin, member (stored in public.users.role)

create table if not exists public.users (
  id uuid primary key default auth.uid(),
  name text,
  email text unique,
  role text not null default 'member' check (role in ('admin','member')),
  profile_picture_url text,
  created_at timestamptz not null default now()
);

alter table public.users enable row level security;

-- Helper: check if current auth user is admin
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'admin'
  );
$$;

do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'users' and policyname = 'Users can read own profile'
  ) then
    drop policy "Users can read own profile" on public.users;
  end if;
end $$;
create policy "Users can read own profile" on public.users
  for select using (auth.uid() = id or public.is_admin());

do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'users' and policyname = 'Users can update own profile'
  ) then
    drop policy "Users can update own profile" on public.users;
  end if;
end $$;
create policy "Users can update own profile" on public.users
  for update using (auth.uid() = id);

-- Auto-create a row in public.users whenever a new auth user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users(id, name, email, role)
  values (new.id, null, new.email, 'member')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Sessions catalog
create table if not exists public.sessions (
  id bigint generated always as identity primary key,
  name text not null,
  weight int not null,
  track_time boolean not null default true,
  start_time time
);

-- Attendance
create table if not exists public.attendance (
  id bigint generated always as identity primary key,
  user_id uuid references public.users(id) on delete cascade,
  session_id bigint references public.sessions(id) on delete cascade,
  date date not null,
  arrival_time timestamptz,
  status text not null check (status in ('present','absent')),
  unique(user_id, session_id, date)
);

alter table public.attendance enable row level security;

do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'attendance' and policyname = 'Members can read own attendance'
  ) then
    drop policy "Members can read own attendance" on public.attendance;
  end if;
end $$;
create policy "Members can read own attendance" on public.attendance
  for select using (auth.uid() = user_id or public.is_admin());

-- Performance weekly snapshot
create table if not exists public.performance (
  id bigint generated always as identity primary key,
  user_id uuid references public.users(id) on delete cascade,
  week_start_date date not null,
  total_score int not null,
  rank int,
  unique(user_id, week_start_date)
);

-- Announcements
create table if not exists public.announcements (
  id bigint generated always as identity primary key,
  title text not null,
  message text not null,
  created_at timestamptz not null default now(),
  posted_by uuid references public.users(id)
);

alter table public.announcements enable row level security;

-- Everyone can read announcements
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'announcements' and policyname = 'Anyone can read announcements'
  ) then
    drop policy "Anyone can read announcements" on public.announcements;
  end if;
end $$;
create policy "Anyone can read announcements" on public.announcements
  for select using (true);

-- Only admins can insert announcements
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'announcements' and policyname = 'Admins can insert announcements'
  ) then
    drop policy "Admins can insert announcements" on public.announcements;
  end if;
end $$;
create policy "Admins can insert announcements" on public.announcements
  for insert with check (public.is_admin());

-- Only admins can update announcements
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'announcements' and policyname = 'Admins can update announcements'
  ) then
    drop policy "Admins can update announcements" on public.announcements;
  end if;
end $$;
create policy "Admins can update announcements" on public.announcements
  for update using (public.is_admin());

-- Only admins can delete announcements
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'announcements' and policyname = 'Admins can delete announcements'
  ) then
    drop policy "Admins can delete announcements" on public.announcements;
  end if;
end $$;
create policy "Admins can delete announcements" on public.announcements
  for delete using (public.is_admin());

-- RPC: admin check-in using server time
create or replace function public.check_in(
  p_user uuid,
  p_session_id bigint,
  p_date date,
  p_status text default 'present'
) returns public.attendance as $$
declare
  v_track boolean;
begin
  select track_time into v_track from public.sessions where id = p_session_id;

  insert into public.attendance(user_id, session_id, date, arrival_time, status)
  values (
    p_user,
    p_session_id,
    p_date,
    case when v_track then now() else null end,
    coalesce(p_status, 'present')
  )
  on conflict (user_id, session_id, date) do update
    set arrival_time = excluded.arrival_time,
        status = excluded.status
  returning *;
end;
$$ language plpgsql security definer;

-- Seed default sessions if empty
insert into public.sessions (name, weight, track_time)
select * from (values
  ('Family Attendance', 4, true),
  ('Morning Prayer', 3, true),
  ('Bible Study', 2, true),
  ('Saturday/Sunday Service', 1, false)
) as v(name, weight, track_time)
where not exists (select 1 from public.sessions);

-- Set default start times where applicable
update public.sessions set start_time = '06:00' where name = 'Morning Prayer' and start_time is null;
update public.sessions set start_time = '18:00' where name = 'Bible Study' and start_time is null;
update public.sessions set start_time = '19:00' where name = 'Family Attendance' and start_time is null;

-- Function: compute weekly performance and ranks
create or replace function public.compute_weekly_performance(p_week_start date)
returns void as $$
begin
  -- remove existing snapshot for the week
  delete from public.performance where week_start_date = p_week_start;

  -- compute end of week (Sun)
  -- ISO week: start Monday; but we take provided start as week anchor
  with att as (
    select a.user_id,
           a.session_id,
           a.date,
           a.arrival_time,
           s.weight,
           s.track_time,
           s.start_time
    from public.attendance a
    join public.sessions s on s.id = a.session_id
    where a.date >= p_week_start and a.date < p_week_start + interval '7 days' and a.status = 'present'
  ), scored as (
    select user_id,
      sum(
        weight
        + case when track_time and start_time is not null and arrival_time is not null then
            case when arrival_time::time <= start_time then 1
                 when arrival_time::time > (start_time + time '00:15') then -1
                 else 0 end
          else 0 end
      ) as total
    from att
    group by user_id
  ), ranked as (
    select user_id, total as total_score,
           dense_rank() over (order by total desc) as rnk
    from scored
  )
  insert into public.performance(user_id, week_start_date, total_score, rank)
  select user_id, p_week_start, total_score, rnk from ranked;
end;
$$ language plpgsql security definer;

-- Device tokens for push notifications
create table if not exists public.device_tokens (
  user_id uuid references public.users(id) on delete cascade,
  token text primary key,
  platform text,
  created_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;
create policy "Users manage own tokens" on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


