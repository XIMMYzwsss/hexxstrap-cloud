-- Fix XP amounts: +0.1% per settings change, +0.2% per Roblox launch.
-- Also widen account_level precision so 0.001 is not rounded away.
-- Paste into Supabase SQL Editor → Run.

alter table public.profiles
  alter column account_level type numeric(12,4)
  using account_level::numeric(12,4);

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
