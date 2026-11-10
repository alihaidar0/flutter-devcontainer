#!/usr/bin/env bash
# =============================================================
#  dockerhub-readme.sh — the part of README.md that goes to Docker Hub.
#
#  Docker Hub keeps at most 25,000 bytes of a repository's description, and
#  README.md is about twice that, so the synced page used to end mid-sentence.
#  Docker Hub gets the sections a user of the image needs; the maintainer
#  sections (the repository layout, the automation, updating the image, the
#  repository setup) stay on GitHub, linked at the end. Links to a heading of
#  README.md become absolute links to the GitHub README, so they keep working
#  on Docker Hub, including those to a section that is left out.
#
#  Usage: dockerhub-readme.sh [OUTPUT]   (default: stdout)
#  Fails when the result is larger than LIMIT bytes (default 24500, a margin
#  below Docker Hub's 25000), so CI stops a README change before the page is cut.
#  Run from anywhere inside the repository.
# =============================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

limit="${LIMIT:-24500}"
output="${1:-/dev/stdout}"
repo_url="https://github.com/alihaidar0/flutter-devcontainer"

# The maintainer sections, as their exact level-2 headings in README.md.
skip='^## (Contents|Repository Structure|GitHub Automation|How the Build Works|Updating the Image|Repository setup and recovery|Contributing)$'

content="$(
  awk -v skip="${skip}" '
    /^## / { skipping = ($0 ~ skip) }
    !skipping
  ' README.md | sed -E "s#\]\(\#([A-Za-z0-9_-]+)\)#](${repo_url}\#\1)#g"
  printf '\n---\n\nThe full documentation (the build pipeline, updating the image, the repository setup) is in the [GitHub README](%s#readme).\n' "${repo_url}"
)"

size="$(printf '%s\n' "${content}" | wc -c | tr -d ' ')"
if [ "${size}" -gt "${limit}" ]; then
  echo "::error::The Docker Hub part of README.md is ${size} bytes (limit ${limit}; Docker Hub keeps 25000). Shorten the user-facing sections, or add a maintainer section to the list in .github/scripts/dockerhub-readme.sh."
  exit 1
fi
printf '%s\n' "${content}" > "${output}"
