#!/usr/bin/env python3
"""Report pinned versions in docker/Dockerfile.dev that are behind upstream.

Run by .github/workflows/dependency-drift.yml. Stdlib only.

Sources (all official release channels):
  firebase-tools / pnpm   npm registry dist-tags
  Flutter                 Google's release manifest (newest stable) vs the newest flutter-X.Y.Z.R tag on Docker Hub
  Starship                GitHub releases API
  Android cmdline-tools   developer.android.com/studio (the documented download page)
  node base image         Docker Hub registry (digest of the pinned tag)

pnpm is compared inside its pinned major line; a newer major is listed
separately because it needs a deliberate migration. Node is frozen on purpose
(only its image digest is compared, never its major version).

Usage: check_drift.py REPORT_FILE
Writes a markdown report to REPORT_FILE and "drift=true|false" to $GITHUB_OUTPUT.
Always exits 0 unless the Dockerfile itself cannot be parsed; a source that
cannot be reached is reported as "unknown" and never counts as drift.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request

DOCKERFILE = "docker/Dockerfile.dev"
IMAGE = "alihaidar199527/flutter-devcontainer"
ALLOWLIST = ".github/npm-audit-allowlist.txt"
TIMEOUT = 30


def fetch(url, headers=None, method="GET"):
    request = urllib.request.Request(url, headers=headers or {}, method=method)
    token = os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        request.add_header("Authorization", f"Bearer {token}")
    return urllib.request.urlopen(request, timeout=TIMEOUT)


def fetch_json(url, headers=None):
    with fetch(url, headers) as response:
        return json.load(response)


def pin(text, key):
    match = re.search(rf"{key}=([^\s\\]+)", text)
    if not match:
        sys.exit(f"Could not read {key} from {DOCKERFILE}")
    return match.group(1)


def major(version):
    return version.split(".")[0]


def npm_dist_tags(package):
    return fetch_json(f"https://registry.npmjs.org/-/package/{package}/dist-tags")


def read_allowlist(path):
    """Advisory IDs accepted in .github/npm-audit-allowlist.txt, with their package hint."""
    entries = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#"):
                ident, _, reason = line.partition(" ")
                entries.append((ident, reason.split(":", 1)[0].strip()))
    return entries


def advisory_patch(ident):
    """First patched version(s) of an advisory, or "none" while no fix is published."""
    data = fetch_json(
        f"https://api.github.com/advisories/{ident}", headers={"Accept": "application/vnd.github+json"}
    )
    patched = {v.get("first_patched_version") for v in data.get("vulnerabilities", [])}
    patched.discard(None)
    return ", ".join(sorted(patched)) if patched else "none"


def latest_flutter():
    """Version of the current stable Flutter release, from the official release manifest."""
    data = fetch_json("https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json")
    current = data["current_release"]["stable"]
    versions = [r["version"] for r in data["releases"] if r["hash"] == current and r["channel"] == "stable"]
    if not versions:
        raise ValueError("current stable release not found in the release manifest")
    return versions[0]


def published_flutter():
    """Flutter version of the newest flutter-X.Y.Z.R tag published on Docker Hub."""
    url = f"https://hub.docker.com/v2/repositories/{IMAGE}/tags?page_size=100&name=flutter-"
    found = []
    while url:
        page = fetch_json(url)
        for tag in page["results"]:
            match = re.fullmatch(r"flutter-(\d+)\.(\d+)\.(\d+)\.\d+", tag["name"])
            if match:
                found.append(tuple(int(part) for part in match.groups()))
        url = page.get("next")
    if not found:
        raise ValueError("no flutter-X.Y.Z.R tag published yet")
    return ".".join(str(part) for part in max(found))


def latest_starship():
    return fetch_json("https://api.github.com/repos/starship/starship/releases/latest")["tag_name"].lstrip("v")


def latest_cmdline_build():
    with fetch("https://developer.android.com/studio") as response:
        html = response.read().decode("utf-8", "ignore")
    builds = {int(b) for b in re.findall(r"commandlinetools-linux-(\d+)_latest\.zip", html)}
    if not builds:
        raise ValueError("no cmdline-tools download link found on the page")
    return str(max(builds))


def node_tag_digest(tag):
    token = fetch_json(
        "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/node:pull"
    )["token"]
    accept = ", ".join(
        [
            "application/vnd.oci.image.index.v1+json",
            "application/vnd.docker.distribution.manifest.list.v2+json",
        ]
    )
    with fetch(
        f"https://registry-1.docker.io/v2/library/node/manifests/{tag}",
        headers={"Authorization": f"Bearer {token}", "Accept": accept},
        method="HEAD",
    ) as response:
        return response.headers["Docker-Content-Digest"]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    report_path = sys.argv[1]

    with open(DOCKERFILE, encoding="utf-8") as handle:
        dockerfile = handle.read()

    rows = []  # (component, pinned, latest, status)
    notes = []

    def record(component, pinned, resolver, compare=None):
        try:
            latest = resolver()
        except (urllib.error.URLError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
            rows.append((component, pinned, "unknown", f"could not check ({type(error).__name__})"))
            return
        behind = compare(pinned, latest) if compare else pinned != latest
        rows.append((component, pinned, latest, "behind" if behind else "current"))

    firebase = pin(dockerfile, "FIREBASE_TOOLS_VERSION")
    record("firebase-tools", firebase, lambda: npm_dist_tags("firebase-tools")["latest"])

    pnpm = pin(dockerfile, "PNPM_VERSION")
    record("pnpm", pnpm, lambda: npm_dist_tags("pnpm")[f"latest-{major(pnpm)}"])
    try:
        newest_pnpm = npm_dist_tags("pnpm")["latest"]
        if major(newest_pnpm) != major(pnpm):
            notes.append(
                f"pnpm {newest_pnpm} is a new major version (pinned line: {major(pnpm)}.x). "
                "Review its release notes before migrating; this is not counted as drift."
            )
    except (urllib.error.URLError, OSError, KeyError, json.JSONDecodeError):
        pass

    # Flutter floats (no pin): the row shows whether the newest published image is behind the
    # newest stable release. The next image build picks the newest stable up.
    try:
        published = published_flutter()
    except (urllib.error.URLError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        rows.append(("Flutter (published image)", "unknown", "unknown", f"could not check ({type(error).__name__})"))
    else:
        record("Flutter (published image)", published, latest_flutter)
        if rows[-1][3] == "behind":
            notes.append(
                "Flutter is not pinned: the next image build uses the newest stable. To publish it without "
                "another image change, run the Docker workflow on `main` (Actions → Docker → Run workflow)."
            )

    record("Starship", pin(dockerfile, "STARSHIP_VERSION"), latest_starship)
    record("Android cmdline-tools build", pin(dockerfile, "CMDLINE_TOOLS_BUILD"), latest_cmdline_build)

    # The Debian variant (for example "trixie-slim") is read from the FROM line.
    variant = re.search(r"^FROM node:\$\{NODE_VERSION\}-([a-z0-9-]+)@", dockerfile, re.M)
    if not variant:
        sys.exit(f"Could not read the node image variant from {DOCKERFILE}")
    node_tag = f"{pin(dockerfile, 'NODE_VERSION')}-{variant.group(1)}"
    node_digest = pin(dockerfile, "NODE_IMAGE_DIGEST")
    record(f"node:{node_tag} digest", node_digest[:19], lambda: node_tag_digest(node_tag)[:19],
           compare=lambda pinned, latest: pinned != latest)

    # A fix for an accepted advisory is a reason to drop the exception (and to
    # add an override or bump the tool), so it is reported like any other drift.
    try:
        allowlist = read_allowlist(ALLOWLIST)
    except OSError:
        allowlist = []
    for ident, package in allowlist:
        record(
            f"{ident} ({package}) accepted advisory",
            "no patch",
            lambda ident=ident: advisory_patch(ident),
            compare=lambda pinned, latest: latest not in ("none", "unknown"),
        )

    drift = any(status == "behind" for *_, status in rows)

    lines = [
        "Pinned versions in `docker/Dockerfile.dev` compared with their official release channels.",
        "",
        "| Component | Pinned | Latest | Status |",
        "| --- | --- | --- | --- |",
    ]
    lines += [f"| {c} | `{p}` | `{l}` | {s} |" for c, p, l, s in rows]
    if notes:
        lines += ["", *[f"- {note}" for note in notes]]
    lines += [
        "",
        "Bump each pin together with its checksum (where one exists) and the matching",
        "`README.md` entries, then refresh the \"Last verified\" date in the Dockerfile.",
        "This issue is maintained by the `dependency-drift` workflow and closes itself",
        "once every pin is current.",
    ]
    with open(report_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")

    print("\n".join(lines))
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"drift={'true' if drift else 'false'}\n")


if __name__ == "__main__":
    main()
