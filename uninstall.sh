#!/bin/bash
set -euo pipefail
SERVICE="$HOME/Library/Services/Context Lens Test.workflow"
RES="$SERVICE/Contents/Resources"
if [[ -d "$RES" ]]; then
  rm -f "$RES/context_lens.sh" "$RES/context_lens.js"
  echo "Removed Context Lens files from the existing Quick Action."
else
  echo "Context Lens Test workflow not found."
fi
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
