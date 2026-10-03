#!/usr/bin/env python3
"""Fail when `npm audit` reports a high or critical advisory that is not allowlisted.

Usage: audit_gate.py AUDIT_JSON ALLOWLIST

AUDIT_JSON  output of `npm audit --json`
ALLOWLIST   .github/npm-audit-allowlist.txt (GitHub advisory ID, then the reason)

Exit status 1 when a non-allowlisted advisory at GATED severity is present.
Moderate and low findings are listed for information and never fail the check.
Allowlist entries that no longer match anything are reported so they get removed.
A markdown summary is written to stdout.
"""
import json
import re
import sys

GATED = {"high", "critical"}


def read_allowlist(path):
    allowed = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            advisory, _, reason = line.partition(" ")
            allowed[advisory] = reason.strip()
    return allowed


def advisory_id(entry):
    match = re.search(r"GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}", entry.get("url", ""))
    return match.group(0) if match else str(entry.get("source"))


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as handle:
        audit = json.load(handle)
    allowed = read_allowlist(sys.argv[2])

    # Every advisory appears once, as a dict, under the package it is filed
    # against; packages that merely depend on it list the package name instead.
    advisories = {}
    for package, vulnerability in audit.get("vulnerabilities", {}).items():
        for entry in vulnerability.get("via", []):
            if isinstance(entry, dict):
                advisories[advisory_id(entry)] = (package, entry["severity"], entry["title"])

    blocking, accepted, informational = [], [], []
    for ident, (package, severity, title) in sorted(advisories.items()):
        row = (ident, package, severity, title)
        if severity in GATED and ident in allowed:
            accepted.append(row)
        elif severity in GATED:
            blocking.append(row)
        else:
            informational.append(row)

    seen = {row[0] for row in accepted}
    stale = sorted(set(allowed) - seen)

    def table(title, rows):
        if not rows:
            return []
        out = [f"### {title}", "", "| Advisory | Package | Severity | Summary |", "| --- | --- | --- | --- |"]
        out += [f"| {i} | `{p}` | {s} | {t} |" for i, p, s, t in rows]
        return out + [""]

    lines = []
    lines += table("Blocking (high or critical, not allowlisted)", blocking)
    lines += table("Accepted (allowlisted, see .github/npm-audit-allowlist.txt)", accepted)
    lines += table("Informational (below the gate)", informational)
    if stale:
        lines += ["### Stale allowlist entries", ""]
        lines += [f"- {ident} no longer appears in the audit; remove it from the allowlist." for ident in stale]
        lines.append("")
    if not advisories:
        lines.append("No advisories reported.")
    print("\n".join(lines))

    if blocking:
        print(f"{len(blocking)} high/critical advisory(ies) are not allowlisted.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
