#!/usr/bin/env bash
# tavily-deepsearch.sh — Deep research via Tavily Search API
#
# SECURITY MANIFEST:
#   Environment variables accessed: TAVILY_API_KEY (only)
#   External endpoints called: https://api.tavily.com/search (only)
#   Local files read: none
#   Local files written: none
#   Data sent: Research question provided as argument + TAVILY_API_KEY in request body
#   Data received: JSON search results with raw content via stdout
#
# Usage: tavily-deepsearch.sh "<question>"
#
# This performs an advanced Tavily search with include_raw_content=true
# to retrieve full page content for deep research synthesis.

set -euo pipefail

if [[ -z "${TAVILY_API_KEY:-}" ]]; then
  echo "Error: TAVILY_API_KEY environment variable is not set." >&2
  echo "Get your key at https://app.tavily.com" >&2
  exit 1
fi

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: $(basename "$0") \"<question>\""
  echo ""
  echo "Run a deep research query using Tavily Search with full content retrieval."
  echo "Returns detailed results with raw page content for synthesis."
  echo ""
  echo "Note: Results include full page content and may be large."
  exit 0
fi

QUESTION="$1"

# Escape the question for JSON
JSON_QUESTION=$(printf '%s' "$QUESTION" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

response=$(curl -s -w "\n%{http_code}" "https://api.tavily.com/search" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${TAVILY_API_KEY}\",
    \"query\": ${JSON_QUESTION},
    \"search_depth\": \"advanced\",
    \"max_results\": 5,
    \"include_raw_content\": true
  }")

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | sed '$d')

if [[ "$http_code" -ge 400 ]]; then
  echo "Error: HTTP $http_code" >&2
  echo "$body" >&2
  exit 1
fi

# Format results as detailed markdown for LLM synthesis
echo "$body" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('results', [])
    if not results:
        print('No results found.')
        sys.exit(0)
    print('# Deep Research Results')
    print()
    for i, r in enumerate(results, 1):
        title = r.get('title', 'Untitled')
        url = r.get('url', '')
        content = r.get('content', '')
        raw = r.get('raw_content', '')
        score = r.get('score', 0)
        print(f'## {i}. {title}')
        print(f'URL: {url}')
        print(f'Relevance: {score:.2f}')
        print()
        print('### Summary')
        print(content)
        print()
        if raw:
            # Truncate very long raw content to keep output manageable
            max_chars = 5000
            if len(raw) > max_chars:
                raw = raw[:max_chars] + '... [truncated]'
            print('### Full Content')
            print(raw)
            print()
        print('---')
        print()
except (json.JSONDecodeError, KeyError) as e:
    print(f'Error parsing response: {e}', file=sys.stderr)
    sys.exit(1)
"
