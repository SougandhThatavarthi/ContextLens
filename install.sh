#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MODEL="qwen3:4b"

[[ "$(uname -s)" == "Darwin" ]] || { echo "Context Lens is for macOS."; exit 1; }
[[ -d "/Applications/Ollama.app" || -n "$(command -v ollama 2>/dev/null || true)" ]] || {
  echo "Ollama is not installed. Install Ollama first."; exit 1;
}

SERVICE_DIR=""
for candidate in "$HOME/Library/Services/Context Lens Test.workflow" "$HOME/Library/Services/Context Lens.workflow"; do
  if [[ -d "$candidate/Contents/Resources" ]]; then SERVICE_DIR="$candidate"; break; fi
done

if [[ -z "$SERVICE_DIR" ]]; then
  cat <<MSG
No existing Context Lens Automator Quick Action was found.

Use the working Quick Action you already created:
  Name: Context Lens Test
  Receives: text
  Input: to stdin

Then run this installer again.
MSG
  exit 1
fi

RESOURCE_DIR="$SERVICE_DIR/Contents/Resources"
cp "$ROOT/context_lens.sh" "$RESOURCE_DIR/context_lens.sh"
cp "$ROOT/context_lens.js" "$RESOURCE_DIR/context_lens.js"
chmod +x "$RESOURCE_DIR/context_lens.sh"

# Best-effort refresh of Services registration.
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

cat <<MSG

Context Lens v0.2 installed.
Quick Action: $SERVICE_DIR
Model: $MODEL

Qwen is not downloaded by this installer on every run.
The Quick Action starts Ollama automatically when needed and reuses the model already on the Mac.

Test: in Preview, select ONE word and choose Services -> Context Lens Test.
MSG
