#!/usr/bin/env bash
# Builds the Windows release: one NeonRequiem.exe with the game data embedded, zipped.
# Needs the Godot 4.7.2 export templates (Editor → Manage Export Templates, or extract
# windows_release_x86_64.exe and version.txt into the templates folder).
# Usage: GODOT=/path/to/Godot_v4.7 tools/export_windows.sh   → export/NeonRequiem-windows.zip
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
export GODOT_SILENCE_ROOT_WARNING=1
OUT=export/windows
mkdir -p "$OUT"
rm -f "$OUT/NeonRequiem.exe" export/NeonRequiem-windows.zip
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/NeonRequiem.exe"
test -s "$OUT/NeonRequiem.exe"
python3 - "$OUT" <<'PY'
import os, sys, zipfile
out = sys.argv[1]
with zipfile.ZipFile("export/NeonRequiem-windows.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(out)):
        z.write(os.path.join(out, name), os.path.join("NeonRequiem", name))
PY
ls -la "$OUT" export/NeonRequiem-windows.zip
