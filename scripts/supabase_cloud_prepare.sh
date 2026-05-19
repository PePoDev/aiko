#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SUPABASE_PROJECT_REF:-}" ]; then
  echo "Set SUPABASE_PROJECT_REF to your Supabase Cloud project ref."
  exit 1
fi

npx supabase link --project-ref "$SUPABASE_PROJECT_REF"
npx supabase db push
