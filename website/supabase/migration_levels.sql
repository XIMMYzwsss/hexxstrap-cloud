-- Run in Supabase SQL Editor (new query). Account levels + anti-cheat runtime.

alter table public.profiles
  add column if not exists runtime_seconds bigint not null default 0;

alter table public.profiles
  add column if not exists account_level int not null default 0;

alter table public.profiles
  add column if not exists last_heartbeat_at timestamptz;

-- Block clients from faking level / runtime via normal PATCH
create or replace function public.protect_hexxstrap_runtime_cols()
returns trigger
language plpgsql
as $$
begin
  if current_setting('hexxstrap.runtime_ok', true) is distinct from '1' then
    new.runtime_seconds := old.runtime_seconds;
    new.account_level := old.account_level;
    new.last_heartbeat_at := old.last_heartbeat_at;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_runtime on public.profiles;
create trigger trg_protect_runtime
  before update on public.profiles
  for each row execute function public.protect_hexxstrap_runtime_cols();

-- 1 level per 2.5 days of HexXstrap running (216000 seconds).
-- Clients call this about every 5 minutes; server only adds time since last beat (max 6 min).
create or replace function public.report_hexxstrap_runtime()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  elapsed double precision;
  add_secs bigint;
  rs bigint;
  lvl int;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select extract(epoch from (now() - last_heartbeat_at))
    into elapsed
  from public.profiles
  where id = uid;

  if elapsed is null then
    elapsed := 300; -- first heartbeat: up to 5 minutes
  end if;

  add_secs := greatest(0, least(floor(elapsed)::bigint, 360));

  perform set_config('hexxstrap.runtime_ok', '1', true);

  update public.profiles
  set
    runtime_seconds = coalesce(runtime_seconds, 0) + add_secs,
    account_level = ((coalesce(runtime_seconds, 0) + add_secs) / 216000)::int,
    last_heartbeat_at = now()
  where id = uid
  returning runtime_seconds, account_level into rs, lvl;

  return json_build_object('runtime_seconds', rs, 'account_level', lvl, 'added', add_secs);
end;
$$;

grant execute on function public.report_hexxstrap_runtime() to authenticated;
