# Context Lens v0.2

A macOS Quick Action that explains a selected word using nearby text from the PDF in Preview and a local Ollama model.

## Current flow

Select one word in Preview -> Services -> Context Lens Test -> local Qwen -> compact explanation.

## Requirements

- macOS
- Preview with a text-selectable PDF
- Ollama for Mac
- `qwen3:4b` installed in Ollama
- A working Automator Quick Action named `Context Lens Test` that receives `text` and passes input to stdin

## Install

From this folder:

```bash
./install.sh
```

The installer copies the updated helper files into the existing Quick Action. It does not re-download Qwen on each run.

## What changed in v0.2

- Fixes the `undefined` model-name bug by using `qwen3:4b` directly in JXA.
- Starts Ollama automatically when the Quick Action is invoked.
- Reuses an existing model; only pulls it if it is genuinely missing.
- Uses PDFKit to find the selected word in nearby page text.
- Sends the selected word plus the surrounding sentence to Qwen.
- Requests a maximum two-line answer with thinking disabled.
- Defensively strips thinking markers and prompt leakage.

## Known limitation

Preview does not expose a stable current-page API through its normal scripting interface, so the helper prefers the visible page when it can infer it from the window title and otherwise searches nearby/whole-document pages. Repeated occurrences of the same word can therefore still select the wrong occurrence. This is the next area to improve.
