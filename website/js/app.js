const FORBIDDEN_SETTINGS = new Set([
  "ApplyLaunchAccount",
  "LaunchAccountFileName",
  "LaunchLoggedOut",
  "MacAddressPrevious",
  "MacAddressCurrent",
  "MacAddressAdapterName"
]);

const FORBIDDEN_KEY_PARTS = [
  "cookie", "password", "passwd", "token", "secret", "session",
  "profilebackupsacc", "rbxsecurity", "roblosecurity"
];

function $(id) { return document.getElementById(id); }

function showMsg(el, text, kind) {
  if (!el) return;
  el.textContent = text || "";
  el.className = "msg" + (kind ? " " + kind : "");
}

function configured() {
  const c = window.HEXXSTRAP || {};
  return Boolean(c.SUPABASE_URL && c.SUPABASE_ANON_KEY);
}

function getClient() {
  if (!configured()) throw new Error("Add your Supabase URL and anon key in js/config.js");
  return window.supabase.createClient(window.HEXXSTRAP.SUPABASE_URL, window.HEXXSTRAP.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true }
  });
}

function stripForbidden(obj) {
  if (obj == null || typeof obj !== "object" || Array.isArray(obj)) return obj;
  const out = {};
  for (const [key, value] of Object.entries(obj)) {
    const lower = key.toLowerCase();
    if (FORBIDDEN_SETTINGS.has(key)) continue;
    if (FORBIDDEN_KEY_PARTS.some((p) => lower.includes(p))) continue;
    out[key] = typeof value === "object" && value && !Array.isArray(value)
      ? stripForbidden(value)
      : value;
  }
  return out;
}

function normalizeConfig(raw) {
  const src = raw && typeof raw === "object" ? raw : {};
  const extra = { ...(src.extra && typeof src.extra === "object" ? src.extra : {}) };
  for (const [k, v] of Object.entries(src)) {
    if (["settings", "fastFlags", "fast_flags", "robloxGlobal", "roblox_global", "nvidiaFlags", "nvidia_flags", "extra", "updatedAt", "updated_at"].includes(k))
      continue;
    extra[k] = v;
  }
  return {
    settings: stripForbidden(src.settings || {}),
    fastFlags: src.fastFlags || src.fast_flags || {},
    robloxGlobal: src.robloxGlobal || src.roblox_global || {},
    nvidiaFlags: src.nvidiaFlags || src.nvidia_flags || {},
    extra
  };
}

function toApiShape(row) {
  if (!row) {
    return { settings: {}, fastFlags: {}, robloxGlobal: {}, nvidiaFlags: {}, extra: {}, updatedAt: null };
  }
  return {
    settings: row.settings || {},
    fastFlags: row.fast_flags || {},
    robloxGlobal: row.roblox_global || {},
    nvidiaFlags: row.nvidia_flags || {},
    extra: row.extra || {},
    updatedAt: row.updated_at || null
  };
}

function formatWhen(iso) {
  if (!iso) return "Never saved";
  try { return new Date(iso).toLocaleString(); }
  catch { return iso; }
}

async function currentUser() {
  const sb = getClient();
  const { data } = await sb.auth.getUser();
  return data.user || null;
}

async function navAuth() {
  const slot = $("nav-auth");
  if (!slot) return;
  try {
    const user = await currentUser();
    if (user) {
      slot.innerHTML = '<a class="n" href="me.html">My FastFlags</a><a class="n" href="#" id="logout-link">Log out</a>';
      $("logout-link")?.addEventListener("click", async (e) => {
        e.preventDefault();
        await getClient().auth.signOut();
        location.href = "index.html";
      });
    } else {
      slot.innerHTML = '<a class="n" href="login.html">Log in</a><a class="n" href="register.html">Register</a>';
    }
  } catch {
    slot.innerHTML = '<a class="n" href="login.html">Log in</a>';
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll('a[href="docs.html"], a[href="home.html"]').forEach((a) => a.remove());
  navAuth();
});
