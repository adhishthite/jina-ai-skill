#!/usr/bin/env bash
# jina-search.sh — Web search via Jina Search API (or Tavily when SEARCH_PROVIDER=tavily)
#
# SECURITY MANIFEST:
#   Environment variables accessed: JINA_API_KEY, TAVILY_API_KEY, SEARCH_PROVIDER
#   External endpoints called: https://s.jina.ai/ (jina) or https://api.tavily.com/search (tavily)
#   Local files read: none
#   Local files written: none
#   Data sent: Search query provided as argument + API key via header/body
#   Data received: Markdown/JSON search results via stdout
#
# Usage: jina-search.sh "<query>" [--json]
# Set SEARCH_PROVIDER=tavily to use Tavily instead of Jina.

set -euo pipefail

SEARCH_PROVIDER="${SEARCH_PROVIDER:-jina}"

# Dispatch to Tavily if selected
if [[ "$SEARCH_PROVIDER" == "tavily" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  exec "$SCRIPT_DIR/tavily-search.sh" "$@"
fi

if [[ -z "${JINA_API_KEY:-}" ]]; then
  echo "Error: JINA_API_KEY environment variable is not set." >&2
  echo "Get your key at https://jina.ai/" >&2
  exit 1
fi

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: $(basename "$0") \"<query>\" [--json]"
  echo ""
  echo "Search the web and return LLM-friendly results."
  echo ""
  echo "Options:"
  echo "  --json    Return JSON output"
  echo "  -h        Show this help"
  echo ""
  echo "Search operators (append to query):"
  echo "  site:example.com    Limit to domain"
  echo "  filetype:pdf        Filter by file type"
  echo "  intitle:keyword     Must appear in title"
  exit 0
fi

QUERY="$1"
ACCEPT="text/plain"

if [[ "${2:-}" == "--json" ]]; then
  ACCEPT="application/json"
fi

# URL-encode the query safely to prevent shell injection
ENCODED_QUERY=$(printf '%s' "$QUERY" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=""))')

response=$(curl -s -w "\n%{http_code}" "https://s.jina.ai/${ENCODED_QUERY}" \
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
