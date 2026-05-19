#!/usr/bin/env bash
set -euo pipefail

npx supabase start
npx supabase db reset
flutter pub get
flutter test
