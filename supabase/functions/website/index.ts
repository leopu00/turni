import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const BUCKET = "web";

function mime(path: string) {
  const ext = path.slice(path.lastIndexOf("."));
  return ({
    ".html": "text/html; charset=utf-8",
    ".js": "application/javascript",
    ".css": "text/css",
    ".json": "application/json",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
    ".webp": "image/webp",
    ".wasm": "application/wasm",
    ".map": "application/octet-stream",
  } as Record<string, string>)[ext] ?? "application/octet-stream";
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  let path = url.pathname;
  if (path === "/") path = "/index.html";

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  async function fetchFile(p: string) {
    const key = p.startsWith("/") ? p.slice(1) : p; // Storage keys senza slash iniziale
    const { data } = supabase.storage.from(BUCKET).getPublicUrl(key);
    const r = await fetch(data.publicUrl);
    if (!r.ok) return null;
    const body = await r.arrayBuffer();
    return new Response(body, {
      status: 200,
      headers: {
        "Content-Type": mime(p),
        "Cache-Control": p.endsWith(".html")
          ? "no-cache"
          : "public, max-age=31536000, immutable",
      },
    });
  }

  const asset = await fetchFile(path);
  if (asset) return asset;

  // SPA fallback
  const spa = await fetchFile("index.html");
  if (spa) return new Response(await spa.arrayBuffer(), {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-cache" },
  });

  return new Response("Not found", { status: 404 });
});
