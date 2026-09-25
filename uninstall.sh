#!/bin/bash
set -euo pipefail
rm -rf "$HOME/Library/Services/Context Lens.workflow"; /System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
echo "Context Lens Quick Action removed. Ollama and local models were left untouched."
