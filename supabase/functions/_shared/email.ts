// Minimal transactional email sender over SMTP — reuses the same SMTP server
// the project configures for Supabase Auth. Credentials are read from function
// secrets (never the client):
//
//   supabase secrets set SMTP_HOST=smtp.example.com SMTP_PORT=465 \
//     SMTP_USERNAME=apikey SMTP_PASSWORD=... \
//     SMTP_FROM="Aiko <noreply@yourdomain.com>"
//
// Sending is best-effort: if SMTP isn't configured the caller should still
// succeed at its primary job (e.g. scheduling a deletion) — `sendEmail` returns
// false instead of throwing so a mail outage never blocks the user action.

import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

export interface EmailMessage {
  to: string;
  subject: string;
  text: string;
  html?: string;
}

export function smtpConfigured(): boolean {
  return Boolean(
    Deno.env.get("SMTP_HOST") &&
      Deno.env.get("SMTP_USERNAME") &&
      Deno.env.get("SMTP_PASSWORD") &&
      Deno.env.get("SMTP_FROM"),
  );
}

export async function sendEmail(message: EmailMessage): Promise<boolean> {
  if (!smtpConfigured()) {
    console.warn("[email] SMTP not configured — skipping send to", message.to);
    return false;
  }

  const host = Deno.env.get("SMTP_HOST")!;
  const port = Number(Deno.env.get("SMTP_PORT") ?? "465");
  const username = Deno.env.get("SMTP_USERNAME")!;
  const password = Deno.env.get("SMTP_PASSWORD")!;
  const from = Deno.env.get("SMTP_FROM")!;

  const client = new SMTPClient({
    connection: {
      hostname: host,
      port,
      // 465 = implicit TLS; 587/25 = STARTTLS (tls: false lets denomailer upgrade).
      tls: port === 465,
      auth: { username, password },
    },
  });

  try {
    await client.send({
      from,
      to: message.to,
      subject: message.subject,
      content: message.text,
      html: message.html,
    });
    return true;
  } catch (e) {
    console.error("[email] send failed:", (e as Error).message);
    return false;
  } finally {
    try {
      await client.close();
    } catch {
      // noop
    }
  }
}
