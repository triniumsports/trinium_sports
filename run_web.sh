#!/usr/bin/env bash
set -e

# Flutter path (codespaces)
export PATH="/workspaces/flutter/bin:$PATH"
hash -r

cd /workspaces/trinium_sports

# Segurança: remove teste padrão (não usamos agora)
rm -f test/widget_test.dart || true

# Valida e compila sempre do zero (evita "APP antigo")
flutter analyze
flutter clean
rm -rf build

# Build web (modo padrão)
flutter build web

# Serve build estático (mais estável no Codespaces)
cd build/web
python3 -m http.server 8080
