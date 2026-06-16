-- Public bucket for the tiny static pages we need to serve as real web pages.
-- Edge Functions can't serve HTML (the platform forces text/plain + a sandbox
-- CSP), so the LINE "connect" page lives here instead. Only non-sensitive
-- static assets belong in this bucket; it is world-readable.

insert into storage.buckets (id, name, public)
values ('public-web', 'public-web', true)
on conflict (id) do nothing;
