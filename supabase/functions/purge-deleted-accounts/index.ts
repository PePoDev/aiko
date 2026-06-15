// Purge Deleted Accounts — Supabase Edge Function (scheduled)
// Hard-deletes accounts whose 3-day deletion grace period has elapsed. Invoked
// by pg_cron over pg_net (see migration 20260615040001), NOT by end users — it
// is guarded by a shared secret rather than a user JWT.
//
// For each due profile (`deletion_scheduled_at <= now()`): delete the profile
// row (cascades all finance data via `on delete cascade`), then delete the
// auth.users login. Note `profiles.id` is NOT FK'd to `auth.users`, so the
// profile must be deleted explicitly — deleting the auth user alone would orphan
// the data.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Mirror of delete-account's key resolution: new JWT-signing secret-key map,
// legacy service-role fallback.
function resolveSecretKey(): string | null {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (raw) {
    try {
      const map = JSON.parse(raw) as Record<string, string>;
      const key = map["default"] ?? Object.values(map)[0];
      if (typeof key === "string" && key.length > 0) return key;
    } catch {
      return raw;
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed", code: "METHOD_NOT_ALLOWED" });
  }

  // Shared-secret gate: only the scheduled pg_cron caller knows PURGE_CRON_SECRET.
  const cronSecret = Deno.env.get("PURGE_CRON_SECRET");
  const authHeader = req.headers.get("authorization") ?? "";
  const presented = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!cronSecret || presented !== cronSecret) {
    return jsonResponse(401, { error: "Unauthorized", code: "UNAUTHORIZED" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKey = resolveSecretKey();
  if (!supabaseUrl || !secretKey) {
    return jsonResponse(500, { error: "Server is not configured", code: "MISCONFIGURED" });
  }

  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false },
  });

  const nowIso = new Date().toISOString();
  const { data: dueRows, error: selectErr } = await admin
    .from("profiles")
    .select("id")
    .lte("deletion_scheduled_at", nowIso);
  if (selectErr) {
    return jsonResponse(500, { error: `Query failed: ${selectErr.message}`, code: "QUERY_FAILED" });
  }

  const ids = (dueRows ?? []).map((r) => (r as { id: string }).id);
  let purged = 0;
  const failures: { id: string; error: string }[] = [];

  for (const id of ids) {
    // Re-check inside the loop is unnecessary; the row was due at query time and
    // cancel-on-login would have cleared the column before this run.
    const { error: profileErr } = await admin.from("profiles").delete().eq("id", id);
    if (profileErr) {
      failures.push({ id, error: `profile: ${profileErr.message}` });
      continue;
    }
    const { error: authErr } = await admin.auth.admin.deleteUser(id);
    if (authErr) {
      // Data is already gone; surface the auth-delete failure for retry/visibility.
      failures.push({ id, error: `auth: ${authErr.message}` });
      continue;
    }
    purged++;
  }

  return jsonResponse(200, { purged, due: ids.length, failures });
});
