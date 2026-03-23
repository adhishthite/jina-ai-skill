#!/usr/bin/env bash
# tavily-search.sh — Web search via Tavily Search API
#
# SECURITY MANIFEST:
#   Environment variables accessed: TAVILY_API_KEY (only)
#   External endpoints called: https://api.tavily.com/search (only)
#   Local files read: none
#   Local files written: none
#   Data sent: Search query provided as argument + TAVILY_API_KEY in request body
#   Data received: JSON search results via stdout
#
# Usage: tavily-search.sh "<query>" [--json]

set -euo pipefail

if [[ -z "${TAVILY_API_KEY:-}" ]]; then
  echo "Error: TAVILY_API_KEY environment variable is not set." >&2
  echo "Get your key at https://app.tavily.com" >&2
  exit 1
fi

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: $(basename "$0") \"<query>\" [--json]"
  echo ""
  echo "Search the web using Tavily and return LLM-friendly results."
  echo ""
  echo "Options:"
  echo "  --json    Return raw JSON output"
  echo "  -h        Show this help"
  exit 0
fi

QUERY="$1"
OUTPUT_JSON=false

if [[ "${2:-}" == "--json" ]]; then
  OUTPUT_JSON=true
fi

# Escape the query for JSON
JSON_QUERY=$(printf '%s' "$QUERY" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

response=$(curl -s -w "\n%{http_code}" "https://api.tavily.com/search" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${TAVILY_API_KEY}\",
    \"query\": ${JSON_QUERY},
    \"search_depth\": \"advanced\",
    \"max_results\": 10
  }")

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | sed '$d')

if [[ "$http_code" -ge 400 ]]; then
  echo "Error: HTTP $http_code" >&2
  echo "$body" >&2
  exit 1
fi

if [[ "$OUTPUT_JSON" == "true" ]]; then
  echo "$body"
else
  # Format results as LLM-friendly markdown
  echo "$body" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('results', [])
    if not results:
        print('No results found.')
        sys.exit(0)
    for i, r in enumerate(results, 1):
        title = r.get('title', 'Untitled')
        url = r.get('url', '')
        content = r.get('content', '')
        print(f'## {i}. {title}')
        print(f'URL: {url}')
        print()
        print(content)
        print()
        print('---')
        print()
except (json.JSONDecodeError, KeyError) as e:
    print(f'Error parsing response: {e}', file=sys.stderr)
    sys.exit(1)
"
fi
