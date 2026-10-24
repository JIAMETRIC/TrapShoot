#!/bin/bash
# Turn a range video or audio recording into a detector fixture: mono 48 kHz AAC plus a JSON skeleton to fill in.
# Needs ffmpeg (brew install ffmpeg / winget install ffmpeg). Works on macOS, Linux and Git Bash on Windows.
#
# Usage: Tools/detector-fixtures/make-fixture.sh <input video or audio> <fixture name> [receiver] [start] [duration]
#   start and duration are ffmpeg time specs (e.g. 00:01:30 90) to trim to the targets.
# Example: Tools/detector-fixtures/make-fixture.sh ~/Videos/range-s3.mp4 2026-09-12-s3 "DJI Mic Mini 2" 00:00:12 110
set -euo pipefail
IN="${1:?input file}"; NAME="${2:?fixture name, e.g. 2026-09-12-s3}"; RECEIVER="${3:-iPhone microphone}"
START="${4:-}"; DURATION="${5:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found; install it first" >&2; exit 1; }
[ -f "$IN" ] || { echo "no such file: $IN" >&2; exit 1; }
case "$NAME" in *[!A-Za-z0-9._-]*) echo "fixture name may contain letters, digits, . _ - only" >&2; exit 1;; esac

AUDIO="$HERE/$NAME.m4a"; JSON="$HERE/$NAME.json"
[ -e "$JSON" ] && { echo "$JSON exists; choose another name or delete it first" >&2; exit 1; }

trim=()
[ -n "$START" ] && trim+=(-ss "$START")
[ -n "$DURATION" ] && trim+=(-t "$DURATION")
# -ac 1: the detector follows one channel anyway; -ar 48000: the iPhone's rate; 160k AAC keeps the shot transients.
ffmpeg -hide_banner -loglevel error -y ${trim[@]+"${trim[@]}"} -i "$IN" -vn -ac 1 -ar 48000 -c:a aac -b:a 160k "$AUDIO"
secs=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO" 2>/dev/null || echo "?")

cat > "$JSON" <<EOF
{
  "name": "$NAME, $RECEIVER",
  "audio": "$NAME.m4a",
  "receiver": "$RECEIVER",
  "notes": "FILL IN: conditions, other shooters, anything the detector must ignore. Source: $(basename "$IN"), ${secs}s",
  "settings": {},
  "toleranceMs": 7,
  "targets": [
    { "firstMs": 0, "secondMs": null }
  ]
}
EOF
echo "wrote $AUDIO (${secs}s) and $JSON"
echo "Now fill in targets[]: firstMs = 1st shot - call onset, secondMs = 2nd shot - call onset or null (Tools/detector-fixtures/README.md)."
