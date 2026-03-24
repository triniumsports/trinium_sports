/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const SUPABASE_URL = Deno.env.get("PROJECT_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return json(200, { ok: true });

  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json(401, { error: "Missing Authorization header" });

    const authClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const { data: userData, error: userErr } = await authClient.auth.getUser();
    if (userErr || !userData?.user) return json(401, { error: "Invalid JWT" });

    const userId = userData.user.id;

    const payload = await req.json();
    const bucket = String(payload.bucket || "avatars");
    const path = String(payload.path || "");
    const contentType = String(payload.contentType || "image/jpeg");
    const base64 = String(payload.base64 || "");

    if (!path) return json(400, { error: "Missing path" });
    if (!base64) return json(400, { error: "Missing base64" });

    if (!path.startsWith(`${userId}/`)) {
      return json(403, { error: "Path must start with userId/" });
    }

    const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const { error: uploadErr } = await admin.storage
      .from(bucket)
      .upload(path, bytes, { contentType, upsert: true });

    if (uploadErr) return json(500, { error: "Upload failed", details: uploadErr.message });

    const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${path}`;

    return json(200, { ok: true, bucket, path, publicUrl });
  } catch (e) {
    return json(500, { error: "Unexpected error", details: String(e) });
  }
});
