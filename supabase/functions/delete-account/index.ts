// Delete Account — Supabase Edge Function
// Schedules deletion of the caller's account after a 3-day grace period and
// emails them. The actual hard delete (finance data + auth.users login) is done
// later by the `purge-deleted-accounts` job. Signing back in before the grace
// period ends clears the schedule and cancels the deletion (handled client-side
// in AuthRepository).
//
// We don't purge here so the user has a safety window: a misclick or a
// compromised session that requests deletion can be undone by simply logging in
// again within 3 days. This function only sets `deletion_scheduled_at` and
// sends the heads-up email.
//
// Security model: validate the caller's JWT with a publishable-key client,
// derive the userId from the *token* (never from the request body), then use a
// separate secret-key admin client to set the schedule for exactly that user.
// Keys are read from the new JWT-signing-key env vars (SUPABASE_PUBLISHABLE_KEYS
// / SUPABASE_SECRET_KEYS, JSON maps) with a fallback to the deprecated legacy
// SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { sendEmail } from "../_shared/email.ts";

const GRACE_PERIOD_DAYS = 3;

// Resolves an API key from the new JWT-signing-key env vars (a JSON map keyed
// by name, e.g. {"default":"sb_secret_..."}), falling back to the deprecated
// legacy plain-string key during the migration window. `mapVar` is
// SUPABASE_SECRET_KEYS / SUPABASE_PUBLISHABLE_KEYS; `legacyVar` is the old
// SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY.
function resolveApiKey(mapVar: string, legacyVar: string): string | null {
  const raw = Deno.env.get(mapVar);
  if (raw) {
    try {
      const map = JSON.parse(raw) as Record<string, string>;
      const key = map["default"] ?? Object.values(map)[0];
      if (typeof key === "string" && key.length > 0) return key;
    } catch {
      // Not JSON — treat the value itself as the key.
      return raw;
    }
  }
  return Deno.env.get(legacyVar) ?? null;
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, content-type",
    },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed", code: "METHOD_NOT_ALLOWED" });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!jwt) {
    return jsonResponse(401, { error: "Missing bearer token", code: "NO_TOKEN" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  // New JWT-signing API keys (SUPABASE_*_KEYS) with legacy-key fallback.
  const publishableKey = resolveApiKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
  const secretKey = resolveApiKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !publishableKey || !secretKey) {
    return jsonResponse(500, { error: "Server is not configured", code: "MISCONFIGURED" });
  }

  // 1) Verify the JWT and derive the user id from the token, not the body.
  const authClient = createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return jsonResponse(401, { error: "Invalid token", code: "BAD_TOKEN" });
  }
  const userId = userData.user.id;
  const userEmail = userData.user.email ?? null;

  // 2) Secret-key (RLS-bypassing) client schedules the deletion for that user.
  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false },
  });

  const scheduledAt = new Date(Date.now() + GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000);
  const { error: scheduleErr } = await admin
    .from("profiles")
    .update({ deletion_scheduled_at: scheduledAt.toISOString() })
    .eq("id", userId);
  if (scheduleErr) {
    return jsonResponse(500, {
      error: `Failed to schedule deletion: ${scheduleErr.message}`,
      code: "SCHEDULE_FAILED",
    });
  }

  // 3) Email the heads-up. Best-effort — a mail outage must not undo the
  // schedule the user just asked for.
  let emailed = false;
  if (userEmail) {
    const when = scheduledAt.toUTCString();
    emailed = await sendEmail({
      to: userEmail,
      subject: "Your Aiko account is scheduled for deletion",
      text: [
        "Hi,",
        "",
        `We received a request to delete your Aiko account. It is scheduled to be permanently deleted on ${when} (in ${GRACE_PERIOD_DAYS} days).`,
        "",
        "Changed your mind? Just log back in to the Aiko app before then and the deletion will be cancelled automatically.",
        "",
        "If you did not request this, log in now to cancel it and consider changing your password.",
        "",
        "— Aiko",
      ].join("\n"),
    });
  }

  return jsonResponse(200, {
    scheduled: true,
    scheduledAt: scheduledAt.toISOString(),
    graceDays: GRACE_PERIOD_DAYS,
    emailed,
  });
});
