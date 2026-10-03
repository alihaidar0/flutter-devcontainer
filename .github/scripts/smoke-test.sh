#!/usr/bin/env bash
# =============================================================
#  smoke-test.sh — verify a freshly built image.
#
#  Usage (from the repository root): .github/scripts/smoke-test.sh <image>
#
#  Shared by ci.yml (pull requests) and docker.yml (publishing) so the image
#  that is released passes exactly the checks the pull request did.
#  Expected versions are read from docker/Dockerfile.dev, so a bump needs no
#  change here.
# =============================================================
set -euo pipefail

image="${1:?usage: smoke-test.sh <image>}"
dockerfile="docker/Dockerfile.dev"

pin() { grep -oE "$1=[0-9][0-9.]*" "${dockerfile}" | head -1 | cut -d= -f2; }

expect_firebase="$(pin FIREBASE_TOOLS_VERSION)"
expect_pnpm="$(pin PNPM_VERSION)"
expect_starship="$(pin STARSHIP_VERSION)"
expect_node="$(pin NODE_VERSION)"
expect_basic_ftp="$(jq -r '.overrides["basic-ftp"]' docker/firebase-tools-overrides.json)"
expect_android_api="$(grep -oE 'platforms;android-[0-9]+' "${dockerfile}" | head -1 | grep -oE '[0-9]+$')"
for v in "${expect_firebase}" "${expect_pnpm}" "${expect_starship}" "${expect_node}" "${expect_basic_ftp}" "${expect_android_api}"; do
  test -n "${v}" || { echo "::error::Could not read a pinned version from ${dockerfile}"; exit 1; }
done

echo "::group::Toolchain"
docker run --rm \
  -e EXPECT_FIREBASE="${expect_firebase}" \
  -e EXPECT_PNPM="${expect_pnpm}" \
  -e EXPECT_STARSHIP="${expect_starship}" \
  -e EXPECT_NODE="${expect_node}" \
  -e EXPECT_BASIC_FTP="${expect_basic_ftp}" \
  -e EXPECT_ANDROID_API="${expect_android_api}" \
  "${image}" bash -c '
    set -euo pipefail
    # UID/GID 1000 matches the first user on a Linux host, so bind mounts are writable.
    test "$(id -un)" = "developer"
    test "$(id -u)" = "1000"
    test "$(id -g)" = "1000"
    test "${HOME}" = "/home/developer"
    # The base image account was renamed, not duplicated.
    ! getent passwd node > /dev/null
    # Consuming projects run `sudo` non-interactively (chown, apt).
    sudo -n true

    # Directories that projects mount named volumes over must already exist and
    # belong to the developer user, otherwise Docker creates them root-owned.
    for dir in "${GRADLE_USER_HOME}" "${PUB_CACHE}" "${HOME}/.shell_history" "${HOME}/Android"; do
      test "$(stat -c %u "${dir}")" = "1000"
      test -w "${dir}"
    done

    # Git must accept the bind-mounted workspace without a startup step.
    git config --system --get-all safe.directory | grep -Fx /workspace > /dev/null

    flutter --version
    dart --version
    java -version
    node --version | grep "^v${EXPECT_NODE}\." > /dev/null
    test "$(firebase --version)" = "${EXPECT_FIREBASE}"
    # firebase-tools lives in its own prefix so the security overrides apply;
    # prove the patched dependency is the one that was installed.
    readlink -f "$(command -v firebase)" | grep -F /opt/firebase-tools/ > /dev/null
    test "$(node -p "require(\"/opt/firebase-tools/node_modules/basic-ftp/package.json\").version")" = "${EXPECT_BASIC_FTP}"
    corepack --version
    test "${COREPACK_ENABLE_DOWNLOAD_PROMPT}" = "0"
    # pnpm must resolve from the cache baked in at build time: with the network
    # disabled Corepack cannot download anything, so this fails if the cache is
    # missing or unreadable for the developer user.
    test "$(COREPACK_ENABLE_NETWORK=0 pnpm --version)" = "${EXPECT_PNPM}"
    flutterfire --version
    gh --version
    starship --version | grep -F "starship ${EXPECT_STARSHIP}" > /dev/null
    test -f "${ANDROID_SDK_ROOT}/platform-tools/adb"
    # Google only ships x86_64 platform-tools for Linux, so adb cannot run on arm64.
    if [ "$(uname -m)" = "x86_64" ]; then adb version; fi
    test -d "${ANDROID_SDK_ROOT}/platforms/android-${EXPECT_ANDROID_API}"
    # CHROME_EXECUTABLE is image-level ENV (no shell profile needed) and must run.
    test -x "${CHROME_EXECUTABLE}"
    "${CHROME_EXECUTABLE}" --version
    # chromedriver must come from the same release as the browser: web
    # integration tests (`flutter drive -d web-server`) fail on a version mismatch.
    chrome_major="$("${CHROME_EXECUTABLE}" --version | grep -oE "[0-9]+" | head -1)"
    chromedriver --version | grep -E "^ChromeDriver ${chrome_major}\." > /dev/null
    # Tools a Flutter workflow relies on every day: coverage reports and a pager.
    genhtml --version
    less --version | head -1
    # Desktop platforms are switched off, so `flutter doctor` must not mention them.
    ! flutter doctor -v 2>&1 | grep -E "Linux toolchain|Windows Version|Xcode" > /dev/null
    flutter doctor
  '
echo "::endgroup::"

echo "::group::Shell aliases"
docker run --rm "${image}" bash -ic 'type fget frunw ftest fanalyze adbrestart gs'
echo "::endgroup::"

# Debian's /etc/profile resets PATH for login shells; /etc/profile.d restores it.
echo "::group::Toolchain on PATH in a login shell"
docker run --rm "${image}" bash -lc '
  for tool in flutter dart java node pnpm firebase sdkmanager adb; do
    command -v "${tool}" > /dev/null || { echo "missing from PATH: ${tool}" >&2; exit 1; }
  done
'
echo "::endgroup::"

echo "::group::Dev Container metadata label"
flutter_root="$(docker run --rm "${image}" printenv FLUTTER_ROOT)"
docker inspect --format '{{ index .Config.Labels "devcontainer.metadata" }}' "${image}" \
  | jq -e --arg root "${flutter_root}" '
      type == "array"
      and any(.[]; .remoteUser == "developer")
      and any(.[]; .customizations.vscode.extensions | index("Dart-Code.flutter"))
      and any(.[]; .customizations.vscode.settings["dart.flutterSdkPath"] == $root)
    ' > /dev/null
echo "devcontainer.metadata is valid"
echo "::endgroup::"
