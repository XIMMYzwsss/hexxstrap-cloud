-- HexXstrap levels v2: fractional levels + activity XP.
-- Paste ALL of this into Supabase → SQL Editor → Run.

-- Allow fractional progress (0.001 = 0.1% of a level, …)
alter table public.profiles
  alter column account_level type numeric(12,4)
  using account_level::numeric(12,4);

alter table public.profiles
  alter column account_level set default 0;

alter table public.profiles
  add column if not exists last_settings_xp_at timestamptz;

alter table public.profiles
  add column if not exists last_launch_xp_at timestamptz;

-- Protect new cooldown columns from client faking
create or replace function public.protect_hexxstrap_runtime_cols()
returns trigger
language plpgsql
as $$
begin
  if current_setting('hexxstrap.runtime_ok', true) is distinct from '1' then
    new.runtime_seconds := old.runtime_seconds;
    new.account_level := old.account_level;
    new.last_heartbeat_at := old.last_heartbeat_at;
    new.last_settings_xp_at := old.last_settings_xp_at;
    new.last_launch_xp_at := old.last_launch_xp_at;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_runtime on public.profiles;
create trigger trg_protect_runtime
  before update on public.profiles
  for each row execute function public.protect_hexxstrap_runtime_cols();

-- Passive XP: add fractional levels from time (still ~2.5 days = +1.0). Does NOT overwrite activity XP.
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
  lvl numeric(12,4);
  add_lvl numeric(12,4);
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select extract(epoch from (now() - last_heartbeat_at))
    into elapsed
  from public.profiles
  where id = uid;

  if elapsed is null then
    elapsed := 300;
  end if;

  add_secs := greatest(0, least(floor(elapsed)::bigint, 360));
  add_lvl := round((add_secs::numeric / 216000::numeric), 4);

  perform set_config('hexxstrap.runtime_ok', '1', true);

  update public.profiles
  set
    runtime_seconds = coalesce(runtime_seconds, 0) + add_secs,
    account_level = round(coalesce(account_level, 0) + add_lvl, 4),
    last_heartbeat_at = now()
  where id = uid
  returning runtime_seconds, account_level into rs, lvl;

  return json_build_object('runtime_seconds', rs, 'account_level', lvl, 'added_seconds', add_secs, 'added_level', add_lvl);
end;
$$;

grant execute on function public.report_hexxstrap_runtime() to authenticated;

-- Settings / feature toggle XP: +0.1% of a level (0.001) with 2 minute server cooldown
create or replace function public.report_hexxstrap_settings_xp()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  since_secs double precision;
  lvl numeric(12,4);
  awarded boolean := false;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select extract(epoch from (now() - last_settings_xp_at))
    into since_secs
  from public.profiles
  where id = uid;

  if since_secs is null or since_secs >= 120 then
    perform set_config('hexxstrap.runtime_ok', '1', true);
    update public.profiles
    set
      account_level = round(coalesce(account_level, 0) + 0.001, 4),
      last_settings_xp_at = now()
    where id = uid
    returning account_level into lvl;
    awarded := true;
  else
    select account_level into lvl from public.profiles where id = uid;
  end if;

  return json_build_object(
    'account_level', coalesce(lvl, 0),
    'awarded', awarded,
    'amount', 0.001,
    'cooldown_seconds', 120
  );
end;
$$;

grant execute on function public.report_hexxstrap_settings_xp() to authenticated;

-- Roblox launch via HexXstrap: +0.2% of a level (0.002), 30s anti-spam
create or replace function public.report_hexxstrap_launch_xp()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  since_secs double precision;
  lvl numeric(12,4);
  awarded boolean := false;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select extract(epoch from (now() - last_launch_xp_at))
    into since_secs
  from public.profiles
  where id = uid;

  if since_secs is null or since_secs >= 30 then
    perform set_config('hexxstrap.runtime_ok', '1', true);
    update public.profiles
    set
      account_level = round(coalesce(account_level, 0) + 0.002, 4),
      last_launch_xp_at = now()
    where id = uid
    returning account_level into lvl;
    awarded := true;
  else
    select account_level into lvl from public.profiles where id = uid;
  end if;

  return json_build_object(
    'account_level', coalesce(lvl, 0),
    'awarded', awarded,
    'amount', 0.002
  );
end;
$$;

grant execute on function public.report_hexxstrap_launch_xp() to authenticated;
