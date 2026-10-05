#!/usr/bin/env bash
# Writes the shields.io endpoint JSON for the readiness badge in the README.
#
# Usage: scripts/badge.sh SCORE [FILE]     (FILE default: rollcall.json)
#
# SCORE is the rollcall Action's `score` output (the readiness score out of 100). The
# workflow's `badge` job commits FILE to the orphan `badges` branch, and the README's badge is
#   https://img.shields.io/endpoint?url=<raw URL of badges/rollcall.json>
# Colour: 80 and up brightgreen, 60 green, 40 yellow, 20 orange, below red.
# Exits 2 if SCORE is not a whole number from 0 to 100.
set -euo pipefail

score="${1:-}"
out="${2:-rollcall.json}"
if ! [[ "$score" =~ ^[0-9]{1,3}$ ]] || ((10#$score > 100)); then
    echo "badge: SCORE must be a whole number from 0 to 100, got '$score'" >&2
    exit 2
fi
score=$((10#$score))
if ((score >= 80)); then
    color=brightgreen
elif ((score >= 60)); then
    color=green
elif ((score >= 40)); then
    color=yellow
elif ((score >= 20)); then
    color=orange
else
    color=red
fi
printf '{"schemaVersion":1,"label":"CRA readiness","message":"%d/100","color":"%s"}\n' \
    "$score" "$color" >"$out"
cat "$out"
