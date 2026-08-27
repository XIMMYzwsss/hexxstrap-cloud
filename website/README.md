# HexXstrap Cloud (GitHub Pages)

GitHub’s free website host (**GitHub Pages**) can only serve files. It cannot store accounts or settings by itself.

This folder is the website. A free **Supabase** project is the backend (accounts, password reset, JSON settings).

HexXstrap.exe is **not** wired up yet. After the site is live, we can make the app login and sync.

## 1. Create the GitHub website

1. Create a new GitHub repository (example name: `hexxstrap-cloud`).
2. Upload **everything inside this `website` folder** to the **root** of that repo (`index.html` should be at the top, not inside another `website` folder).
3. On GitHub: **Settings → Pages**
   - Source: **Deploy from a branch**
   - Branch: `main` (or `master`), folder: `/ (root)`
4. After a minute the site is:
   `https://YOURNAME.github.io/hexxstrap-cloud/`

If the repo is named `YOURNAME.github.io`, the site is `https://YOURNAME.github.io/`.

## 2. Create the free backend

1. Sign up at [https://supabase.com](https://supabase.com) (free plan).
2. **New project** → wait until it finishes.
3. Left sidebar **SQL Editor** → New query → paste all of `supabase/schema.sql` → **Run**.
4. **Authentication → Providers → Email**: enabled.
   - For easier testing, turn **Confirm email** off.
5. **Authentication → URL Configuration**
   - Site URL: your GitHub Pages URL (with trailing slash is fine)
   - Redirect URLs: add
     - `https://YOURNAME.github.io/hexxstrap-cloud/`
     - `https://YOURNAME.github.io/hexxstrap-cloud/reset.html`
6. **Project Settings → API**
   - Copy **Project URL**
   - Copy **anon public** key

## 3. Plug keys into the site

Edit `js/config.js`:

```js
window.HEXXSTRAP = {
  SUPABASE_URL: "https://xxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOi..."
};
```

Commit and push. The anon key is meant to be public (row security in the database protects data). Do **not** put the `service_role` key in this site.

## 4. Try it

- Register with email, password, username
- Save a JSON blob on **My settings**
- Search the username on **Explore**
- Open **Forgot password** (needs the redirect URLs above)

## What is stored

- `settings` — full HexXstrap settings object
- `fastFlags` — full FastFlag map
- `robloxGlobal` — GBS / global Roblox settings
- `nvidiaFlags` — extra NVIDIA flags
- extra unknown keys — kept in `extra`

Never stored: Roblox cookies, Accounts tab logins, MAC addresses, passwords/tokens.

## Pages

| File | Purpose |
|---|---|
| `index.html` | Home |
| `register.html` / `login.html` | Account |
| `forgot.html` / `reset.html` | Password reset |
| `me.html` | Save / load your config |
| `explore.html` | Search users |
| `user.html?u=name` | Public profile |
| `docs.html` | API notes for HexXstrap later |
