#!/usr/bin/env python3
"""
jina-reader.py — Read any URL via Jina Reader API or Tavily Extract API.

SECURITY MANIFEST:
    Environment variables accessed: JINA_API_KEY, TAVILY_API_KEY, READER_PROVIDER
    External endpoints called: https://r.jina.ai/ (jina), https://api.tavily.com/extract (tavily)
    Local files read: none
    Local files written: none
    Data sent: URL provided as argument + API key via header/body
    Data received: Markdown/JSON content via stdout

Usage:
    python3 jina-reader.py <url> [--json]

Set READER_PROVIDER=tavily to use Tavily Extract instead of Jina Reader.
No external dependencies (uses urllib from stdlib).
"""

import json
import os
import sys
import urllib.request
import urllib.error


def jina_read(url, use_json):
    """Read a URL using Jina Reader API."""
    api_key = os.environ.get("JINA_API_KEY")
    if not api_key:
        print("Error: JINA_API_KEY environment variable is not set.", file=sys.stderr)
        print("Get your key at https://jina.ai/", file=sys.stderr)
        sys.exit(1)

    accept = "application/json" if use_json else "text/plain"

    req = urllib.request.Request(
        f"https://r.jina.ai/{url}",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": accept,
            "User-Agent": "Mozilla/5.0 (compatible; JinaReader/1.0)",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            content = resp.read().decode("utf-8")
            print(content)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"Error: HTTP {e.code}", file=sys.stderr)
        print(body, file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Error: {e.reason}", file=sys.stderr)
        sys.exit(1)


def tavily_extract(url, use_json):
    """Read a URL using Tavily Extract API."""
    api_key = os.environ.get("TAVILY_API_KEY")
    if not api_key:
        print("Error: TAVILY_API_KEY environment variable is not set.", file=sys.stderr)
        print("Get your key at https://app.tavily.com", file=sys.stderr)
        sys.exit(1)

    payload = json.dumps({"urls": [url]}).encode("utf-8")

    req = urllib.request.Request(
        "https://api.tavily.com/extract",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"Error: HTTP {e.code}", file=sys.stderr)
        print(body, file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Error: {e.reason}", file=sys.stderr)
        sys.exit(1)

    if use_json:
        print(json.dumps(data, indent=2))
    else:
        results = data.get("results", [])
        if results:
            print(results[0].get("raw_content", ""))
        else:
            failed = data.get("failed_results", [])
            if failed:
                print(f"Error: extraction failed for URL: {failed[0].get('url', '')}", file=sys.stderr)
            else:
                print("Error: no results returned", file=sys.stderr)
            sys.exit(1)


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print("Usage: python3 jina-reader.py <url> [--json]")
        print()
        print("Read any URL (web page or PDF) and return clean markdown.")
        print()
        print("Options:")
        print("  --json    Return JSON output (includes url, title, content)")
        print("  -h        Show this help")
        print()
        print("Environment:")
        print("  READER_PROVIDER  Provider to use: jina (default) or tavily")
        print("  JINA_API_KEY     Required when READER_PROVIDER=jina")
        print("  TAVILY_API_KEY   Required when READER_PROVIDER=tavily")
        sys.exit(0)

    url = sys.argv[1]
    use_json = "--json" in sys.argv[2:]
    provider = os.environ.get("READER_PROVIDER", "jina").lower()

    if provider == "tavily":
        tavily_extract(url, use_json)
    else:
        jina_read(url, use_json)


if __name__ == "__main__":
    main()
