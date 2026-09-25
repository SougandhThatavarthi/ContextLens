# Context Lens 0.3

Local macOS reading assistant using Ollama + Qwen3.

## 0.3 changes
- Disables Qwen3 thinking for fast contextual lookups.
- Starts the Ollama macOS app automatically when needed.
- Keeps the Ollama service available for subsequent lookups.
- Ensures qwen3:4b is installed during setup.

## Install
1. Unzip.
2. In Terminal, `cd` into the ContextLens-v0.2 folder.
3. Run `./install.sh`.
4. Go to System Settings -> Keyboard -> Keyboard Shortcuts -> Services.
5. Find Context Lens and assign a shortcut such as Control-Option-Command-M.
6. In Preview, select text and use the shortcut.

You do not need to run `ollama run qwen3:4b` manually.

## Current limitation
The basic macOS Service receives selected text but not reliably the surrounding PDF sentences. For now, select the target word plus its sentence or a short passage. The next version should use a native helper/accessibility layer to extract 1-2 surrounding sentences automatically.
