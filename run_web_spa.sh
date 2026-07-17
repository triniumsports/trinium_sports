#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f "build/web/index.html" ]; then
  echo "ERRO: build/web/index.html não encontrado."
  echo "Execute primeiro o build do Flutter."
  exit 1
fi

fuser -k 8081/tcp 2>/dev/null || true
python3 tools/serve_spa.py
