#!/bin/bash
# Imports the stems STRATA actually uses from the Unity project into the app
# bundle as Apple Lossless (.m4a), so ~175 MB of 16-bit AIFF does not get
# duplicated in git. Run once on a Mac before building:
#
#     ./Scripts/import-audio.sh
#
# Uses afconvert, which ships with macOS. Re-running only converts files that
# are missing or older than their source.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
UNITY_SOUNDS="$HERE/../ - Unity project/strata unity files/Assets/Sounds"
OUT="$HERE/STRATA/Resources/Audio"

if [ ! -d "$UNITY_SOUNDS" ]; then
  echo "Cannot find the Unity Sounds folder at: $UNITY_SOUNDS" >&2
  exit 1
fi
if ! command -v afconvert >/dev/null; then
  echo "afconvert not found — this script needs macOS." >&2
  exit 1
fi
mkdir -p "$OUT"

# source path (relative to Sounds)                      -> bundle name
FILES=(
  "5.1/backing noise.aif|backing noise"
  "5.1/backing extra melody.aif|backing extra melody"
  "Songs/terroir part a.aif|terroir part a"
  "Songs/terroir part b.aif|terroir part b"
  "4.29/spawn into terroir/spawn into terroir full.aif|spawn into terroir full"
)

for entry in "${FILES[@]}"; do
  src="$UNITY_SOUNDS/${entry%%|*}"
  name="${entry##*|}"
  dst="$OUT/$name.m4a"
  if [ ! -f "$src" ]; then
    echo "missing source: $src" >&2
    continue
  fi
  if [ -f "$dst" ] && [ ! "$src" -nt "$dst" ]; then
    echo "up to date: $name.m4a"
    continue
  fi
  echo "converting: $name"
  afconvert -f m4af -d alac "$src" "$dst"
done

echo "Done. Stems are in $OUT"
