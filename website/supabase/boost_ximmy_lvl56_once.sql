-- ONE-TIME ONLY: set level 56 by EMAIL (not username — usernames can be changed).
-- Paste into Supabase → SQL Editor → Run. Do not run again unless you mean to.

do $$
declare
  target uuid;
begin
  select id into target
  from auth.users
  where lower(email) = lower('gotemrepsss@gmail.com')
  limit 1;

  if target is null then
    raise exception 'No auth user found for that email';
  end if;

  perform set_config('hexxstrap.runtime_ok', '1', true);

  update public.profiles
  set
    account_level = 56,
    runtime_seconds = greatest(coalesce(runtime_seconds, 0), 56::bigint * 216000)
  where id = target;
end $$;

-- Confirm:
select p.username, u.email, p.account_level, p.runtime_seconds
from public.profiles p
join auth.users u on u.id = p.id
where lower(u.email) = lower('gotemrepsss@gmail.com');
