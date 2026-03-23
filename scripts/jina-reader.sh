#!/usr/bin/env bash
# jina-reader.sh — Read any URL via Jina Reader API or Tavily Extract API
#
# SECURITY MANIFEST:
#   Environment variables accessed: JINA_API_KEY, TAVILY_API_KEY, READER_PROVIDER
#   External endpoints called: https://r.jina.ai/ (jina), https://api.tavily.com/extract (tavily)
#   Local files read: none
#   Local files written: none
#   Data sent: URL provided as argument + API key via header/body
#   Data received: Markdown/JSON content via stdout
#
# Usage: jina-reader.sh <url> [--json]
# Set READER_PROVIDER=tavily to use Tavily Extract instead of Jina Reader.

set -euo pipefail

READER_PROVIDER="${READER_PROVIDER:-jina}"

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: $(basename "$0") <url> [--json]"
  echo ""
  echo "Read any URL (web page or PDF) and return clean markdown."
  echo ""
  echo "Options:"
  echo "  --json    Return JSON output (includes url, title, content)"
  echo "  -h        Show this help"
  echo ""
  echo "Environment:"
  echo "  READER_PROVIDER  Provider to use: jina (default) or tavily"
  echo "  JINA_API_KEY     Required when READER_PROVIDER=jina"
  echo "  TAVILY_API_KEY   Required when READER_PROVIDER=tavily"
  exit 0
fi

URL="$1"
USE_JSON=false
if [[ "${2:-}" == "--json" ]]; then
  USE_JSON=true
fi

if [[ "$READER_PROVIDER" == "tavily" ]]; then
  if [[ -z "${TAVILY_API_KEY:-}" ]]; then
    echo "Error: TAVILY_API_KEY environment variable is not set." >&2
    echo "Get your key at https://app.tavily.com" >&2
    exit 1
  fi

  # Build JSON payload for Tavily Extract API
  payload=$(printf '{"urls":["%s"]}' "$URL")

  response=$(curl -s -w "\n%{http_code}" "https://api.tavily.com/extract" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TAVILY_API_KEY" \
    -d "$payload")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 400 ]]; then
    echo "Error: HTTP $http_code" >&2
    echo "$body" >&2
    exit 1
  fi

  if [[ "$USE_JSON" == true ]]; then
    echo "$body"
  else
    # Extract raw_content from the first result using python3
    printf '%s' "$body" | python3 -c '
import sys, json
data = json.load(sys.stdin)
results = data.get("results", [])
if results:
    print(results[0].get("raw_content", ""))
else:
    failed = data.get("failed_results", [])
    if failed:
        print("Error: extraction failed for URL: " + failed[0].get("url", ""), file=sys.stderr)
        sys.exit(1)
    print("Error: no results returned", file=sys.stderr)
    sys.exit(1)
'
  fi
else
  # Jina Reader (default)
  if [[ -z "${JINA_API_KEY:-}" ]]; then
    echo "Error: JINA_API_KEY environment variable is not set." >&2
    echo "Get your key at https://jina.ai/" >&2
    exit 1
  fi

  ACCEPT="text/plain"
  if [[ "$USE_JSON" == true ]]; then
    ACCEPT="application/json"
  fi

  # Sanitize URL: percent-encode to prevent shell injection via $() or backticks
  SAFE_URL=$(printf '%s' "$URL" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=":/?#[]@!$&'\''()*+,;=-._~%"))')

  response=$(curl -s -w "\n%{http_code}" "https://r.jina.ai/${SAFE_URL}" \
    -H "Authorization: Bearer $JINA_API_KEY" \
    -H "Accept: $ACCEPT")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 400 ]]; then
    echo "Error: HTTP $http_code" >&2
    echo "$body" >&2
    exit 1
  fi

  echo "$body"
fi
