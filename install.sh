#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"; SCRIPT_PATH="$ROOT/context_lens.sh"; SERVICE_DIR="$HOME/Library/Services/Context Lens.workflow"; CONTENTS="$SERVICE_DIR/Contents"; MODEL="${CONTEXT_LENS_MODEL:-qwen3:4b}"
[[ "$(uname -s)" == "Darwin" ]] || { echo "This installer is for macOS."; exit 1; }
if ! command -v ollama >/dev/null 2>&1 && [[ ! -d "/Applications/Ollama.app" ]]; then echo "Ollama is not installed."; exit 1; fi
if ! curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  [[ -d "/Applications/Ollama.app" ]] && /usr/bin/open -g -a "Ollama" >/dev/null 2>&1 || true
  ready=0
  for _ in $(seq 1 20); do if curl -fsS --max-time 1 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then ready=1; break; fi; sleep 0.5; done
  [[ "$ready" -eq 1 ]] || { echo "Ollama did not start."; exit 1; }
fi
if command -v ollama >/dev/null 2>&1; then echo "Ensuring local model is installed: $MODEL"; ollama pull "$MODEL"; fi
rm -rf "$SERVICE_DIR"; mkdir -p "$CONTENTS/Resources"; cp "$SCRIPT_PATH" "$CONTENTS/Resources/context_lens.sh"; chmod +x "$CONTENTS/Resources/context_lens.sh"
cat > "$CONTENTS/Info.plist" <<'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.contextlens.quickaction</string>
<key>CFBundleName</key><string>Context Lens</string><key>CFBundleDisplayName</key><string>Context Lens</string>
<key>CFBundlePackageType</key><string>BNDL</string><key>CFBundleVersion</key><string>0.3</string><key>CFBundleShortVersionString</key><string>0.3</string>
<key>NSServices</key><array><dict>
<key>NSMenuItem</key><dict><key>default</key><string>Context Lens</string></dict>
<key>NSMessage</key><string>runWorkflowAsService</string>
<key>NSSendTypes</key><array><string>public.text</string></array>
<key>NSReturnTypes</key><array><string>public.text</string></array>
</dict></array>
</dict></plist>
PLISTEOF
cat > "$CONTENTS/document.wflow" <<'WFLOWEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>AMApplicationBuild</key><string>Automator</string><key>AMDocumentVersion</key><string>2</string>
<key>actions</key><array><dict>
<key>actionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string><key>actionName</key><string>Run Shell Script</string>
<key>actionParameters</key><dict><key>COMMAND_STRING</key><string>"$HOME/Library/Services/Context Lens.workflow/Contents/Resources/context_lens.sh"</string><key>inputMethod</key><string>1</string><key>shell</key><string>/bin/bash</string><key>source</key><string></string></dict>
<key>isViewVisible</key><true/><key>location</key><string>410.000000:300.000000</string></dict></array>
<key>connectors</key><array/><key>variables</key><dict><key>input</key><dict><key>variableType</key><string>AMSelectVariableType</string><key>value</key><string>Automator</string></dict></dict>
<key>inputSettings</key><dict><key>AMInputHandlingType</key><integer>1</integer><key>AMInputHandlingText</key><string>0</string></dict>
<key>workflowMetaData</key><dict><key>serviceInputTypeIdentifier</key><string>public.text</string><key>serviceOutputTypeIdentifier</key><string>public.text</string><key>serviceInputApplicationMode</key><integer>0</integer><key>serviceApplicationMode</key><integer>0</integer></dict>
</dict></plist>
WFLOWEOF
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
echo "Context Lens 0.3 installed. Ollama will start automatically when the shortcut is used."
echo "Model: $MODEL"
echo "Set a shortcut in System Settings -> Keyboard -> Keyboard Shortcuts -> Services -> Context Lens."
