-- HexXstrap Cloud — run this in Supabase: SQL Editor → New query → Run
-- Then Authentication → URL Configuration:
--   Site URL = your GitHub Pages URL
--   Redirect URLs = that URL and that URL + /reset.html

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  avatar_url text,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-zA-Z0-9_]{3,24}$')
);

create table if not exists public.configs (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  settings jsonb not null default '{}'::jsonb,
  fast_flags jsonb not null default '{}'::jsonb,
  roblox_global jsonb not null default '{}'::jsonb,
  nvidia_flags jsonb not null default '{}'::jsonb,
  extra jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create unique index if not exists profiles_username_lower_idx on public.profiles (lower(username));
create index if not exists profiles_public_idx on public.profiles (is_public, updated_at desc);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uname text;
begin
  uname := coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(replace(new.id::text, '-', ''), 1, 8));
  uname := regexp_replace(uname, '[^a-zA-Z0-9_]', '', 'g');
  if length(uname) < 3 then
    uname := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  insert into public.profiles (id, username)
  values (new.id, uname);

  insert into public.configs (user_id)
  values (new.id);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.touch_profile_updated()
returns trigger
language plpgsql
as $$
begin
  update public.profiles
     set updated_at = now()
   where id = new.user_id;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists configs_touch on public.configs;
create trigger configs_touch
  before update on public.configs
  for each row execute function public.touch_profile_updated();

alter table public.profiles enable row level security;
alter table public.configs enable row level security;

drop policy if exists "public profiles readable" on public.profiles;
create policy "public profiles readable"
  on public.profiles for select
  using (is_public = true or auth.uid() = id);

drop policy if exists "own profile update" on public.profiles;
create policy "own profile update"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "public configs readable" on public.configs;
create policy "public configs readable"
  on public.configs for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = configs.user_id
        and (p.is_public = true or auth.uid() = p.id)
    )
  );

drop policy if exists "own config upsert" on public.configs;
create policy "own config upsert"
  on public.configs for insert
  with check (auth.uid() = user_id);

drop policy if exists "own config update" on public.configs;
create policy "own config update"
  on public.configs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
