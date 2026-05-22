alter table public.notification_preferences
  add column if not exists source_module text not null default 'reports';

alter table public.attachments
  add column if not exists is_sensitive boolean not null default false,
  add column if not exists export_policy text not null default 'include';
