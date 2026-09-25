#!/bin/bash
set -euo pipefail
MODEL="${CONTEXT_LENS_MODEL:-qwen3:4b}"
MAX_TOKENS="${CONTEXT_LENS_MAX_TOKENS:-90}"
TIMEOUT="${CONTEXT_LENS_TIMEOUT:-20}"
OLLAMA_URL="http://127.0.0.1:11434"
show_error() { /usr/bin/osascript -e "display dialog \"Context Lens: $1\" buttons {\"OK\"} default button \"OK\" with title \"Context Lens\""; }
INPUT="$(cat)"; INPUT="${INPUT//$'\r'/}"; INPUT="$(printf '%s' "$INPUT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
[[ -z "$INPUT" ]] && { show_error "no text was selected."; exit 0; }
if ! curl -fsS --max-time 1 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
  [[ -d "/Applications/Ollama.app" ]] || { show_error "Ollama is not installed. Install Ollama, then try again."; exit 1; }
  /usr/bin/open -g -a "Ollama" >/dev/null 2>&1 || true
  ready=0
  for _ in $(seq 1 20); do
    if curl -fsS --max-time 1 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then ready=1; break; fi
    sleep 0.5
  done
  [[ "$ready" -eq 1 ]] || { show_error "Ollama did not start in time. Open Ollama once manually and try again."; exit 1; }
fi
if ! curl -fsS --max-time 3 "$OLLAMA_URL/api/show" -H 'Content-Type: application/json' -d "{\"name\":\"$MODEL\"}" >/dev/null 2>&1; then
  command -v ollama >/dev/null 2>&1 || { show_error "The model $MODEL is not installed."; exit 1; }
  ollama pull "$MODEL" >/dev/null 2>&1 || { show_error "The model $MODEL is not installed and could not be downloaded."; exit 1; }
fi
command -v python3 >/dev/null 2>&1 || { show_error "Context Lens needs Python 3 on this Mac."; exit 1; }
PAYLOAD="$(CONTEXT_TEXT="$INPUT" CONTEXT_MODEL="$MODEL" CONTEXT_MAX="$MAX_TOKENS" python3 - <<'PY'
import json, os
text=os.environ['CONTEXT_TEXT']; model=os.environ['CONTEXT_MODEL']; max_tokens=int(os.environ['CONTEXT_MAX'])
prompt=f'''You are a reading assistant.\n\nThe reader selected this text from a book:\n"""\n{text}\n"""\n\nExplain what the selected word or phrase means in THIS context. If the supplied text is only one word, give its most likely meaning. If it contains a sentence or paragraph, use that context.\n\nReturn exactly 2 or 3 short lines:\nMeaning: one short sentence.\nSimple: one very simple restatement.\nSynonyms: up to 3 short synonyms, only when useful.\n\nDo not add introductions, caveats, etymology, or long examples.'''
print(json.dumps({'model':model,'prompt':prompt,'stream':False,'think':False,'options':{'temperature':0.2,'num_predict':max_tokens}},ensure_ascii=False))
PY
)"
RESPONSE="$(curl -fsS --max-time "$TIMEOUT" -H 'Content-Type: application/json' -d "$PAYLOAD" "$OLLAMA_URL/api/generate" || true)"
[[ -n "$RESPONSE" ]] || { show_error "Context Lens could not get a response from Ollama."; exit 1; }
ANSWER="$(RESPONSE="$RESPONSE" python3 - <<'PY'
import json, os
try: print((json.loads(os.environ['RESPONSE']).get('response') or '').strip())
except Exception: print('')
PY
)"
[[ -n "$ANSWER" ]] || { show_error "Context Lens received an empty answer from Ollama."; exit 1; }
/usr/bin/osascript - "$ANSWER" <<'OSA'
on run argv
    set answerText to item 1 of argv
    display dialog answerText buttons {"OK"} default button "OK" with title "Context Lens"
end run
OSA
