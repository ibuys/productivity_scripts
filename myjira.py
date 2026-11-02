#!/usr/bin/env python3
"""
myjira - list open Jira issues assigned to you.

Jira Cloud only. Uses /rest/api/3/search/jql (the old /rest/api/3/search
endpoint was removed by Atlassian; see notes at the bottom of this file).

Setup:
    export JIRA_SITE=yourcompany.atlassian.net
    export JIRA_EMAIL=you@yourcompany.com
    export JIRA_TOKEN=$(pass jira/api-token)   # or however you store it

Create the token at https://id.atlassian.com/manage-profile/security/api-tokens

Usage:
    myjira.py                       # table
    myjira.py --format markdown     # wiki-friendly checkboxes
    myjira.py --format json         # raw-ish, for piping to jq
    myjira.py --jql 'assignee = currentUser() AND sprint in openSprints()'
"""

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_JQL = (
    "assignee = currentUser() "
    "AND statusCategory != Done "
    "ORDER BY priority DESC, updated ASC"
)

# The new endpoint returns ONLY `id` unless you ask for fields explicitly.
FIELDS = [
    "summary",
    "status",
    "priority",
    "issuetype",
    "project",
    "duedate",
    "updated",
]

PAGE_SIZE = 100


def env(name):
    val = os.environ.get(name)
    if not val:
        sys.exit(f"{name} is not set. See the docstring at the top of this file.")
    return val


def auth_header(email, token):
    raw = f"{email}:{token}".encode("utf-8")
    return "Basic " + base64.b64encode(raw).decode("ascii")


def search(site, email, token, jql, limit=None):
    """Yield issue dicts, following nextPageToken until exhausted."""
    base = f"https://{site}/rest/api/3/search/jql"
    headers = {
        "Authorization": auth_header(email, token),
        "Accept": "application/json",
    }
    next_token = None
    seen = 0

    while True:
        params = {
            "jql": jql,
            "maxResults": PAGE_SIZE,
            "fields": ",".join(FIELDS),
        }
        if next_token:
            params["nextPageToken"] = next_token

        url = f"{base}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers=headers)

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = json.load(resp)
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            sys.exit(f"Jira returned HTTP {e.code}: {body}")
        except urllib.error.URLError as e:
            sys.exit(f"Could not reach {site}: {e.reason}")

        for issue in payload.get("issues", []):
            yield issue
            seen += 1
            if limit and seen >= limit:
                return

        next_token = payload.get("nextPageToken")
        if payload.get("isLast") or not next_token:
            return


def flatten(issue):
    f = issue.get("fields", {})

    def name_of(key):
        obj = f.get(key)
        return obj.get("name") if isinstance(obj, dict) else None

    return {
        "key": issue.get("key", "?"),
        "summary": (f.get("summary") or "").strip(),
        "status": name_of("status") or "-",
        "priority": name_of("priority") or "-",
        "type": name_of("issuetype") or "-",
        "project": (f.get("project") or {}).get("key", "-"),
        "due": f.get("duedate") or "",
        "updated": (f.get("updated") or "")[:10],
    }


def render_table(rows, site):
    if not rows:
        print("Nothing assigned and open. Enjoy it while it lasts.")
        return
    kw = max(len(r["key"]) for r in rows)
    sw = max(len(r["status"]) for r in rows)
    pw = max(len(r["priority"]) for r in rows)
    for r in rows:
        summary = r["summary"]
        if len(summary) > 70:
            summary = summary[:67] + "..."
        due = f"  due {r['due']}" if r["due"] else ""
        print(
            f"{r['key']:<{kw}}  {r['status']:<{sw}}  "
            f"{r['priority']:<{pw}}  {summary}{due}"
        )
    print(f"\n{len(rows)} issue(s).")


def render_markdown(rows, site):
    for r in rows:
        url = f"https://{site}/browse/{r['key']}"
        due = f" (due {r['due']})" if r["due"] else ""
        print(f"- [ ] [{r['key']}]({url}) {r['summary']}{due} `{r['status']}`")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--jql", default=DEFAULT_JQL, help="override the JQL query")
    ap.add_argument(
        "--format",
        choices=["table", "markdown", "json"],
        default="table",
    )
    ap.add_argument("--limit", type=int, default=None, help="stop after N issues")
    args = ap.parse_args()

    site = env("JIRA_SITE").replace("https://", "").rstrip("/")
    email = env("JIRA_EMAIL")
    token = env("JIRA_TOKEN")

    rows = [flatten(i) for i in search(site, email, token, args.jql, args.limit)]

    if args.format == "json":
        json.dump(rows, sys.stdout, indent=2)
        print()
    elif args.format == "markdown":
        render_markdown(rows, site)
    else:
        render_markdown(rows, site)


if __name__ == "__main__":
    main()
