-- Ensures 0.1% progress (0.001 level) is not rounded away on the server.
-- Paste into Supabase SQL Editor → Run.

alter table public.profiles
  alter column account_level type numeric(12,4)
  using round(account_level::numeric, 4);
