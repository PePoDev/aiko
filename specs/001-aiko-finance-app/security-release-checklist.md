# Security Release Checklist

- Use anon keys only in the Flutter app; never ship service-role keys.
- Serve self-hosted Supabase only over HTTPS in production.
- Rotate JWT, anon, service-role, SMTP, storage, and database credentials before release.
- Verify RLS is enabled on every user-owned table.
- Verify storage policies restrict receipt, document, and export paths by authenticated user.
- Configure encrypted PostgreSQL backups and perform a restore drill.
- Configure database migrations through CI/CD with review gates.
- Enable monitoring for auth failures, policy errors, storage errors, and database latency.
- Review `.env`, CI logs, crash logs, and mobile build outputs for leaked secrets.
- Require PIN/biometric app-lock support for sensitive screens.
- Keep tax, investment, AI, export, and calculator disclaimers visible at decision points.
