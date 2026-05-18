#!/bin/sh
set -eu

psql -v ON_ERROR_STOP=1 <<'SQL'
create schema if not exists _aiko_migrations;
create table if not exists _aiko_migrations.schema_migrations (
  version text primary key,
  applied_at timestamptz not null default now()
);
SQL

for file in /workspace/supabase/migrations/*.sql; do
  version="$(basename "$file")"
  applied="$(psql -Atc "select 1 from _aiko_migrations.schema_migrations where version = '$version'")"
  if [ "$applied" = "1" ]; then
    echo "Skipping already applied migration: $version"
    continue
  fi

  echo "Applying migration: $version"
  psql -v ON_ERROR_STOP=1 -f "$file"
  psql -v ON_ERROR_STOP=1 -c "insert into _aiko_migrations.schema_migrations(version) values ('$version')"
done

if [ -f /workspace/supabase/seed.sql ]; then
  echo "Applying idempotent seed data"
  psql -v ON_ERROR_STOP=1 -f /workspace/supabase/seed.sql
fi
