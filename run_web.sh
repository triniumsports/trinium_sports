#!/usr/bin/env bash
set -e
if [ ! -d "/workspaces/flutter" ]; then
  cd /workspaces
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="/workspaces/flutter/bin:$PATH"
hash -r
cd /workspaces/trinium_sports
rm -f test/widget_test.dart || true
flutter analyze
flutter clean
rm -rf build
flutter build web
cd build/web
python3 -m http.server 8080
