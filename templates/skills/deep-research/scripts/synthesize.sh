#!/usr/bin/env bash
# synthesize.sh — Call external LLM API to synthesize research materials
# Usage: synthesize.sh <provider> "<topic>" <sources_file>
#   provider: gemini | openai
#   topic: research topic
#   sources_file: JSON file path containing collected source materials

set -euo pipefail

PROVIDER="${1:-}"
TOPIC="${2:-}"
SOURCES_FILE="${3:-}"

if [[ -z "$PROVIDER" || -z "$TOPIC" || -z "$SOURCES_FILE" ]]; then
  echo "Usage: synthesize.sh <provider> <topic> <sources_file>" >&2
  exit 1
fi

if [[ ! -f "$SOURCES_FILE" ]]; then
  echo "Error: sources file not found: $SOURCES_FILE" >&2
  exit 1
fi

SOURCES=$(cat "$SOURCES_FILE")

# Build system prompt
SYSTEM_PROMPT="You are a deep research analyst. Synthesize the provided source materials into a comprehensive research report on the given topic. Follow these rules:
1. Every claim must cite a source with [Source Name](URL)
2. Cross-reference facts across sources; mark single-source claims with ⚠️
3. Prefer recent sources (last 12 months)
4. Acknowledge information gaps honestly
5. Write in the same language as the topic (Chinese topic → Chinese report, English → English)
6. Structure: Executive Summary → Key Findings (3-5 sections) → Conclusions → Sources List"

USER_PROMPT="Research topic: ${TOPIC}

Source materials:
${SOURCES}

Please synthesize these materials into a comprehensive deep research report."

case "$PROVIDER" in
  gemini)
    if [[ -z "${GEMINI_API_KEY:-}" ]]; then
      echo "Error: GEMINI_API_KEY not set" >&2
      exit 2
    fi
    
    # Gemini API call
    PAYLOAD=$(jq -n \
      --arg sys "$SYSTEM_PROMPT" \
      --arg user "$USER_PROMPT" \
      '{
        "system_instruction": {"parts": [{"text": $sys}]},
        "contents": [{"role": "user", "parts": [{"text": $user}]}],
        "generationConfig": {
          "temperature": 0.3,
          "maxOutputTokens": 65536
        }
      }')
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview:generateContent?key=${GEMINI_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      --max-time 120)
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [[ "$HTTP_CODE" != "200" ]]; then
      echo "Error: Gemini API returned HTTP $HTTP_CODE" >&2
      echo "$BODY" >&2
      exit 3
    fi
    
    # Extract text from Gemini response
    echo "$BODY" | jq -r '.candidates[0].content.parts[0].text // "Error: empty response"'
    ;;
    
  openai)
    if [[ -z "${AZURE_OPENAI_API_KEY:-}" || -z "${AZURE_OPENAI_ENDPOINT:-}" || -z "${AZURE_OPENAI_DEPLOYMENT:-}" ]]; then
      echo "Error: Azure OpenAI env vars not set (AZURE_OPENAI_API_KEY, AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_DEPLOYMENT)" >&2
      exit 2
    fi
    
    # Azure OpenAI API call (o3 model)
    API_URL="${AZURE_OPENAI_ENDPOINT}openai/deployments/${AZURE_OPENAI_DEPLOYMENT}/chat/completions?api-version=${AZURE_OPENAI_API_VERSION:-2024-12-01-preview}"
    
    # o3 is a reasoning model: no system message, no temperature, use max_completion_tokens
    PAYLOAD=$(jq -n \
      --arg user "${SYSTEM_PROMPT}\n\n${USER_PROMPT}" \
      '{
        "messages": [
          {"role": "user", "content": $user}
        ],
        "max_completion_tokens": 32768
      }')
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
      "$API_URL" \
      -H "Content-Type: application/json" \
      -H "api-key: ${AZURE_OPENAI_API_KEY}" \
      -d "$PAYLOAD" \
      --max-time 120)
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [[ "$HTTP_CODE" != "200" ]]; then
      echo "Error: Azure OpenAI API returned HTTP $HTTP_CODE" >&2
      echo "$BODY" >&2
      exit 3
    fi
    
    echo "$BODY" | jq -r '.choices[0].message.content // "Error: empty response"'
    ;;
    
  gemini-dr-start)
    # Start a Gemini DR interaction and return the interaction ID immediately.
    # Usage: synthesize.sh gemini-dr-start "<topic>" [sources_file]
    # Outputs interaction ID to stdout. Use gemini-dr-check to poll.
    if [[ -z "${GEMINI_API_KEY:-}" ]]; then
      echo "Error: GEMINI_API_KEY not set" >&2
      exit 2
    fi

    START_RESP=$(curl -s \
      "https://generativelanguage.googleapis.com/v1beta/interactions" \
      -H "Content-Type: application/json" \
      -H "x-goog-api-key: ${GEMINI_API_KEY}" \
      -d "$(jq -n --arg input "$USER_PROMPT" '{
        "input": $input,
        "agent": "deep-research-pro-preview-12-2025",
        "background": true
      }')" \
      --max-time 30)

    INTERACTION_ID=$(echo "$START_RESP" | jq -r '.id // empty')
    if [[ -z "$INTERACTION_ID" ]]; then
      echo "Error: Failed to start Gemini DR interaction" >&2
      echo "$START_RESP" >&2
      exit 3
    fi

    # Output only the interaction ID (for caller to capture)
    echo "$INTERACTION_ID"
    ;;

  gemini-dr-check)
    # Check status of a Gemini DR interaction.
    # Usage: synthesize.sh gemini-dr-check "<interaction_id>" [dummy_sources]
    # Exit codes: 0=complete (report on stdout), 10=still running, 11=stale (no progress), 3=failed
    # Stderr outputs: status=<status> updated=<ISO timestamp>
    if [[ -z "${GEMINI_API_KEY:-}" ]]; then
      echo "Error: GEMINI_API_KEY not set" >&2
      exit 2
    fi
    # interaction ID is passed as $TOPIC (2nd positional arg)
    INTERACTION_ID="$TOPIC"
    if [[ -z "$INTERACTION_ID" ]]; then
      echo "Error: interaction ID required" >&2
      exit 1
    fi

    POLL_RESP=$(curl -s \
      "https://generativelanguage.googleapis.com/v1beta/interactions/${INTERACTION_ID}" \
      -H "x-goog-api-key: ${GEMINI_API_KEY}" \
      --max-time 15)

    STATUS=$(echo "$POLL_RESP" | jq -r '.status // "unknown"')
    UPDATED=$(echo "$POLL_RESP" | jq -r '.updated // "unknown"')
    echo "status=$STATUS updated=$UPDATED" >&2

    if [[ "$STATUS" == "completed" || "$STATUS" == "complete" ]]; then
      echo "$POLL_RESP" | jq -r '.outputs[0].text // "Error: empty output"'
      exit 0
    elif [[ "$STATUS" == "failed" || "$STATUS" == "error" ]]; then
      echo "Error: Gemini DR failed" >&2
      echo "$POLL_RESP" >&2
      exit 3
    else
      # Check for stale interaction: if updated timestamp equals created timestamp
      # or hasn't changed, the caller should detect by comparing across polls.
      # Output status + updated for caller to track.
      echo "${STATUS}|${UPDATED}"
      exit 10
    fi
    ;;

  gemini-dr)
    # Legacy: synchronous start + poll (kept for backward compat, but prefer gemini-dr-start + gemini-dr-check)
    if [[ -z "${GEMINI_API_KEY:-}" ]]; then
      echo "Error: GEMINI_API_KEY not set" >&2
      exit 2
    fi

    START_RESP=$(curl -s \
      "https://generativelanguage.googleapis.com/v1beta/interactions" \
      -H "Content-Type: application/json" \
      -H "x-goog-api-key: ${GEMINI_API_KEY}" \
      -d "$(jq -n --arg input "$USER_PROMPT" '{
        "input": $input,
        "agent": "deep-research-pro-preview-12-2025",
        "background": true
      }')" \
      --max-time 30)

    INTERACTION_ID=$(echo "$START_RESP" | jq -r '.id // empty')
    if [[ -z "$INTERACTION_ID" ]]; then
      echo "Error: Failed to start Gemini DR interaction" >&2
      echo "$START_RESP" >&2
      exit 3
    fi

    echo "Gemini DR started: $INTERACTION_ID (polling...)" >&2

    for i in $(seq 1 120); do
      sleep 30
      POLL_RESP=$(curl -s \
        "https://generativelanguage.googleapis.com/v1beta/interactions/${INTERACTION_ID}" \
        -H "x-goog-api-key: ${GEMINI_API_KEY}" \
        --max-time 15)

      STATUS=$(echo "$POLL_RESP" | jq -r '.status // "unknown"')
      echo "  Poll $i: status=$STATUS" >&2

      if [[ "$STATUS" == "completed" || "$STATUS" == "complete" ]]; then
        echo "$POLL_RESP" | jq -r '.outputs[0].text // "Error: empty output"'
        exit 0
      elif [[ "$STATUS" == "failed" || "$STATUS" == "error" ]]; then
        echo "Error: Gemini DR failed" >&2
        echo "$POLL_RESP" >&2
        exit 3
      fi
    done

    echo "Error: Gemini DR timed out after 60 minutes" >&2
    exit 3
    ;;

  *)
    echo "Error: unknown provider '$PROVIDER'. Use 'gemini' or 'openai'" >&2
    exit 1
    ;;
esac
