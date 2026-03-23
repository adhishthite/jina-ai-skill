#!/usr/bin/env bash
# tavily-extract.sh — Convenience wrapper that delegates to jina-reader.sh with READER_PROVIDER=tavily
#
# SECURITY MANIFEST:
#   Environment variables accessed: TAVILY_API_KEY (via jina-reader.sh)
#   External endpoints called: https://api.tavily.com/extract (via jina-reader.sh)
#   Local files read: none
#   Local files written: none
#   Data sent: URL provided as argument + API key via header/body
#   Data received: Markdown/JSON content via stdout
#
# Usage: tavily-extract.sh <url> [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
READER_PROVIDER=tavily exec "$SCRIPT_DIR/jina-reader.sh" "$@"
