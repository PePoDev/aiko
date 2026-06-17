-- The home dashboard is now static (fixed widget set and order), so per-user
-- layout customization is gone. Drop the backing table; cascade removes its
-- RLS policy too.
drop table if exists public.dashboard_widget_preferences cascade;
