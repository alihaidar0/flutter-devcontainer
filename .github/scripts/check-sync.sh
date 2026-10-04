#!/usr/bin/env bash
# =============================================================
#  check-sync.sh — keep README.md and the implementation in step.
#
#  Fails when:
#    * a version pinned in docker/Dockerfile.dev is not mentioned in README.md,
#    * the Node major differs between the Dockerfile, ci.yml and docker.yml,
#    * an alias defined in scripts/shell_setup.sh is missing from the README
#      "Shell Aliases" tables, or the README documents an alias that no longer
#      exists.
#
#  Run from anywhere inside the repository.
# =============================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

dockerfile="docker/Dockerfile.dev"
readme="README.md"
aliases_script="scripts/shell_setup.sh"
status=0

fail() { echo "::error::$*"; status=1; }

pin() { grep -oE "$1=[0-9][0-9.]*" "${dockerfile}" | head -1 | cut -d= -f2; }

# ── Versions ─────────────────────────────────────────────────
check_in_readme() {
  local name="$1" value="$2"
  if [ -z "${value}" ]; then
    fail "Could not read ${name} from ${dockerfile}"
  elif ! grep -qF -- "${value}" "${readme}"; then
    fail "${readme} does not mention ${name} ${value} — update the version tables."
  fi
}

check_in_readme FIREBASE_TOOLS_VERSION "$(pin FIREBASE_TOOLS_VERSION)"
check_in_readme PNPM_VERSION "$(pin PNPM_VERSION)"
check_in_readme FLUTTER_VERSION "$(pin FLUTTER_VERSION)"
check_in_readme STARSHIP_VERSION "$(pin STARSHIP_VERSION)"
check_in_readme CMDLINE_TOOLS_BUILD "$(pin CMDLINE_TOOLS_BUILD)"

android_api="$(grep -oE 'platforms;android-[0-9]+' "${dockerfile}" | head -1 | grep -oE '[0-9]+$')"
check_in_readme "Android API" "API ${android_api}"
build_tools="$(grep -oE 'build-tools;[0-9.]+' "${dockerfile}" | head -1 | cut -d';' -f2)"
check_in_readme "Android build-tools" "${build_tools}"

# ── Node major must agree everywhere (it is frozen on purpose) ──
node_major="$(pin NODE_VERSION)"
for file in .github/workflows/ci.yml .github/workflows/docker.yml; do
  grep -qE "NODE_VERSION=${node_major}\$" "${file}" \
    || fail "${file} does not build with NODE_VERSION=${node_major} (Dockerfile default)."
done
grep -qE "Node\.js ${node_major} LTS" "${readme}" \
  || fail "${readme} does not describe Node.js ${node_major} LTS."

# The Debian variant of the base image (for example "trixie-slim") is documented too.
variant="$(grep -oE '^FROM node:\$\{NODE_VERSION\}-[a-z0-9-]+' "${dockerfile}" | head -1 | sed -E 's/.*\}-//')"
if [ -z "${variant}" ]; then
  fail "Could not read the node image variant from ${dockerfile}"
elif ! grep -qF -- "${variant}" "${readme}"; then
  fail "${readme} does not mention the base image variant ${variant}."
fi

# ── Aliases ──────────────────────────────────────────────────
script_aliases="$(grep -oE '^alias [A-Za-z0-9_]+' "${aliases_script}" | cut -d' ' -f2 | sort -u)"

# First column of the tables between "## Shell Aliases" and "## Updating the Image".
readme_aliases="$(
  awk '
    /^## Shell Aliases/ { in_section = 1; next }
    /^## /              { in_section = 0 }
    in_section && /^\| `/ {
      split($0, cols, "|")
      gsub(/[ `]/, "", cols[2])
      print cols[2]
    }
  ' "${readme}" | sort -u
)"

while IFS= read -r name; do
  [ -z "${name}" ] && continue
  grep -qxF -- "${name}" <<< "${readme_aliases}" \
    || fail "Alias '${name}' is defined in ${aliases_script} but missing from the README tables."
done <<< "${script_aliases}"

while IFS= read -r name; do
  [ -z "${name}" ] && continue
  grep -qxF -- "${name}" <<< "${script_aliases}" \
    || fail "Alias '${name}' is documented in the README but not defined in ${aliases_script}."
done <<< "${readme_aliases}"

if [ "${status}" -eq 0 ]; then
  echo "README and implementation are in sync."
fi
exit "${status}"
