#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M2_DIR="$HOME/.m2"

[[ -d "$M2_DIR" ]]             || mkdir -p "$M2_DIR"
[[ -d "$M2_DIR/repository" ]]  || mkdir -p "$M2_DIR/repository"
[[ -f "$M2_DIR/settings.xml" ]] || cp "$SCRIPT_DIR/settings.xml" "$M2_DIR/settings.xml"

echo "Maven home configured at $M2_DIR"
