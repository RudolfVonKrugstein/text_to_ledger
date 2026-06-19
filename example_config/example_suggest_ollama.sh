#!/usr/bin/env bash
#
# Example suggester script for text_to_ledger.
#
# Invoked with two environment variables:
#   T2L_PROMPT_FILE     — file containing the prompt
#   T2L_SUGGESTION_FILE — path to write the suggestion to
#
# Configure in your YAML config like:
#   suggester:
#     command: ["bash", "example_config/example_suggest_ollama.sh"]
#
# Uses ollama's HTTP API (/api/generate) rather than `ollama run` to sidestep
# the CLI's interactive-mode hang on stdin EOF, and passes "think": false to
# disable thinking-mode for reasoning models like qwen3.

set -euo pipefail

MODEL="${OLLAMA_MODEL:-qwen3.5:4b}"
HOST="${OLLAMA_HOST:-http://localhost:11434}"

echo "asking ${MODEL} via ${HOST} ..." >&2

jq -n --arg model "$MODEL" --rawfile prompt "$T2L_PROMPT_FILE" \
  '{model: $model, prompt: $prompt, stream: false, think: false}' \
  | curl -sS -X POST "${HOST}/api/generate" \
      -H 'Content-Type: application/json' \
      --data-binary @- \
  | jq -r '.response' > "$T2L_SUGGESTION_FILE"

echo "suggestion written to $T2L_SUGGESTION_FILE" >&2
