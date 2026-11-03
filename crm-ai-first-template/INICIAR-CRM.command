#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v npm >/dev/null || { echo "Instale Node.js 22 para iniciar."; exit 1; }
[[ -f .env ]] || { echo "Faça a instalação seguindo LEIA-ME-PRIMEIRO.md."; exit 1; }
exec npm run dev -- --host 127.0.0.1
