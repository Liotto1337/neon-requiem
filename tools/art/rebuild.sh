#!/usr/bin/env bash
# Redraws the code-drawn art, imports it and rebuilds the TileSet and location scenes.
# Usage: GODOT=/path/to/Godot_v4.7 tools/art/rebuild.sh [tiles creatures icons fx heroes]
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
export GODOT_SILENCE_ROOT_WARNING=1
python3 tools/art/build_art.py "$@"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . res://tools/BuildWorld.tscn
echo "art: imported, world rebuilt"
