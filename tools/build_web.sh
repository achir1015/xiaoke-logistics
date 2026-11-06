#!/usr/bin/env bash
# 建置線上版：bash tools/build_web.sh → ../build/logistics-web/ 與 ../build/xiaoke-logistics-web.zip
set -euo pipefail
cd "$(dirname "$0")/.."
GD="${GODOT:-/e/從零建置 Godot 賽車遊戲/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
OUT=../build/logistics-web
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -maxdepth 1 -name 'index*' -delete
"$GD" --headless --path . --export-release "Web" "$OUT/index.html"
cp docs/version.json "$OUT/version.json"
python -I tools/patch_manifest.py "$OUT"
( cd "$OUT" && rm -f ../xiaoke-logistics-web.zip && "/c/Program Files/7-Zip/7z.exe" a -tzip ../xiaoke-logistics-web.zip ./* >/dev/null 2>&1 || powershell -NoProfile -Command "Compress-Archive -Path * -DestinationPath ../xiaoke-logistics-web.zip -Force" )
ls -la "$OUT" ../build/xiaoke-logistics-web.zip
