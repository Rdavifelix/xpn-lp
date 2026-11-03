#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

find supabase/functions -mindepth 2 -name index.ts -print0 \
  | xargs -0 deno check --quiet --node-modules-dir=none
