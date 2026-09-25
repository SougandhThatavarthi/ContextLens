#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
JS="$ROOT/context_lens.js"

show_error() {
  /usr/bin/osascript -e 'on run argv' \
    -e 'display alert "Context Lens" message (item 1 of argv) as critical buttons {"OK"} default button "OK"' \
    -e 'end run' "$1" >/dev/null 2>&1 || true
}

INPUT="$(cat)"
INPUT="${INPUT//$'\r'/}"
INPUT="$(printf '%s' "$INPUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

if [[ -z "$INPUT" ]]; then
  show_error "Select a word or phrase first."
  exit 0
fi

if [[ ! -f "$JS" ]]; then
  show_error "Context Lens helper is incomplete. Re-run the installer."
  exit 1
fi

/usr/bin/osascript -l JavaScript "$JS" "$INPUT"
