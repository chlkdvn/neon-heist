#!/usr/bin/env bash
# NEON HEIST — Sunset City launcher.
# Finds the local Godot 4.7.2 binary, falls back to godot4/godot on PATH.
set -euo pipefail

GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="${GODOT_BIN:-}"

if [[ -z "$GODOT_BIN" ]]; then
  candidates=(
    "/home/divine/Downloads/Godot_v4.7.2-stable_linux.x86_64 (1)/Godot_v4.7.2-stable_linux.x86_64"
    "/home/divine/Downloads/Godot_v4.7.2-stable_linux.x86_64"
  )
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then GODOT_BIN="$c"; break; fi
  done
fi
if [[ -z "$GODOT_BIN" ]]; then
  for c in godot4 godot; do
    if command -v "$c" >/dev/null 2>&1; then GODOT_BIN="$(command -v "$c")"; break; fi
  done
fi

if [[ -z "$GODOT_BIN" ]]; then
  echo "NEON HEIST: Godot 4.7+ was not found." >&2
  echo "Set GODOT_BIN=/path/to/godot and run this script again." >&2
  exit 1
fi

cd "$GAME_DIR"
exec "$GODOT_BIN" --path "$GAME_DIR" --resolution 1280x720 "$@"
