# flutter-devcontainer

> Blank-canvas base Docker image for VS Code Dev Containers.
> One image, shared across all your Flutter projects.

Flutter (stable) · Dart · Android SDK 36 · Java 21 (Temurin) · Node.js 24 LTS · pnpm (Corepack) · Firebase CLI · FlutterFire CLI · GitHub CLI · Starship

[![Docker Build](https://github.com/alihaidar0/flutter-devcontainer/actions/workflows/docker.yml/badge.svg)](https://github.com/alihaidar0/flutter-devcontainer/actions/workflows/docker.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/alihaidar199527/flutter-devcontainer)](https://hub.docker.com/r/alihaidar199527/flutter-devcontainer)
[![Image Size](https://img.shields.io/docker/image-size/alihaidar199527/flutter-devcontainer/latest)](https://hub.docker.com/r/alihaidar199527/flutter-devcontainer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

```bash
docker pull alihaidar199527/flutter-devcontainer:latest
```

---

## Overview

Every Flutter project needs the same developer tooling: Flutter SDK, Android SDK, Dart, Java, Gradle, Firebase, and a productive terminal. Configuring all of this from scratch on every machine — or worse, on every project — wastes time and produces inconsistent environments.

This repository solves that problem with a single shared base image. Push a change here and all your Flutter projects get the upgrade on the next `docker pull` — without touching any project code.

**This repo has one job:** build and publish the base development Docker image to Docker Hub.

It contains no Flutter project files, no `pubspec.yaml`, no application code, and no app-level CI. Flutter packages, app configuration, and deployment workflows all belong in the project repositories that consume this image.

---

## Quick start

The fastest route is the [`flutter-template`](https://github.com/alihaidar0/flutter-template) repository, which already wires this image into a Dev Container. To use the image in your own project, point a Dev Container at it:

```jsonc
// .devcontainer/devcontainer.json
{
  "name": "Flutter",
  "image": "alihaidar199527/flutter-devcontainer:latest",
  "forwardPorts": [8080]
}
```

The image's metadata supplies the `developer` user, the Dart and Flutter extensions and the Flutter SDK path, so nothing else is required. Port 8080 is where `frunw` serves the web target. `latest` always moves to the newest build; a project that must keep building on the same image pins a permanent [tag](#tags) instead (`flutter-X.Y.Z.R` or a digest).

Without Dev Containers, run any tool straight from the image:

```bash
docker run --rm -it -v "$PWD:/workspace" alihaidar199527/flutter-devcontainer:latest bash
```

---

## Architecture

This image is one half of a two-repo system.

| Repo | Responsibility |
| --- | --- |
| `flutter-devcontainer` ← **you are here** | Build and publish the base dev image |
| `flutter-template` | GitHub Template — the starting point for every new Flutter project |

When you open a Flutter project that uses this image, the container starts via Docker Compose with your project folder mounted at `/workspace` and your Git identity and SSH keys available for pushing to GitHub.

The container user is `developer` with **UID/GID 1000** (the base image's `node` account, renamed), which matches the first user on most Linux hosts, so files created in `/workspace` belong to you on the host as well. On Docker Desktop (Windows/macOS) bind-mount ownership is translated by Docker and the UID does not matter. If your Linux user has a different UID, Dev Containers remaps `developer` to it automatically.

The image carries [Dev Container metadata](https://containers.dev/implementors/spec/#image-metadata) (`devcontainer.metadata` label), so a `devcontainer.json` or Compose service that uses it inherits `remoteUser: developer`, the Dart and Flutter VS Code extensions and `dart.flutterSdkPath` without repeating them.

Runtime defaults baked into the image, so consuming projects need no startup workarounds for them:

| Default | Effect |
| --- | --- |
| `git config --system safe.directory /workspace` | Git works in the bind-mounted workspace (no "dubious ownership" error), even when `~/.gitconfig` is mounted read-only |
| `~/.gradle`, `~/.pub-cache`, `~/Android`, `~/.shell_history` exist and belong to `developer` | A named volume mounted over them starts writable instead of root-owned |
| `CHROME_EXECUTABLE=/usr/local/bin/chrome-browser` | Chromium is found by every process, including IDE-launched ones |
| `/etc/profile.d/10-dev-toolchain.sh` | Flutter, Java, Node and the Android SDK tools stay on `PATH` in login shells too (`docker exec -l`, `su -l`, SSH), where Debian's `/etc/profile` would otherwise reset it |
| `ANDROID_HOME` (and the deprecated `ANDROID_SDK_ROOT`, same value) | Android tooling finds the SDK at `/home/developer/Android/sdk` |
| `COREPACK_ENABLE_DOWNLOAD_PROMPT=0` | Corepack never waits for an interactive confirmation |
| pnpm prepared for `developer` (Corepack cache) | `pnpm install` works offline when the project's `packageManager` matches the image's pnpm version |

Named volumes are initialised from the image only when they are first created. After pulling a new image, recreate volumes that cache image content (for example the Android SDK or pub cache) with `docker compose down -v` to pick the new content up.

---

## What's Inside

### Runtime & Language

| Tool | Version | Purpose |
| --- | --- | --- |
| **Flutter SDK** | stable channel | Flutter framework + Dart SDK |
| **Dart SDK** | bundled with Flutter | Language runtime (included in Flutter) |
| **Java (Eclipse Temurin)** | 21 | Required by Android build toolchain and Gradle |
| **Node.js** | 24 LTS (Debian 13 `trixie-slim`) | Required by Firebase CLI and FlutterFire CLI |
| **pnpm** | 12.9.1 (via Corepack) | Package manager for repo-level tooling (Husky, commitlint) in consuming projects |

### Android

| Tool | Version | Purpose |
| --- | --- | --- |
| **Android SDK** | API 36 | Latest Android platform |
| **Android Build Tools** | 36.0.0 | APK/AAB compilation |
| **Android Platform Tools** | latest | `adb`, `fastboot` |
| **Android Cmdline Tools** | latest (bootstrapped from build 15859902) | `sdkmanager`, `avdmanager` |
| **Gradle** | per project | No standalone Gradle is installed: each Flutter project's wrapper (`android/gradlew`) downloads the version Flutter chose into the persisted `~/.gradle` cache on the first build |

### Web & Testing

| Tool | Version | Purpose |
| --- | --- | --- |
| **Chromium** | Debian 13 build (amd64 and arm64) | `flutter test --platform chrome`, `flutter build web` checks, headless browser for web integration tests |
| **chromedriver** | matches Chromium | `flutter drive -d web-server` (web integration tests) |
| **lcov** | Debian 13 build | `genhtml` turns `flutter test --coverage` into an HTML report |

```bash
ftestc && genhtml coverage/lcov.info -o coverage/html     # HTML coverage report

chromedriver --port=4444 &                                # web integration tests
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart -d web-server --browser-name=chrome --headless
```

### Developer Tools

| Tool | Version | Purpose |
| --- | --- | --- |
| **Firebase CLI** | 15.32.1 | Firebase project management and deployment |
| **FlutterFire CLI** | latest | Configure Firebase in Flutter projects |
| **pnpm** | 12.9.1 | Fast, disk-efficient package manager, activated via Corepack at build time (cached for the `developer` user — no download on first use) |
| **GitHub CLI** | latest | `gh pr create`, `gh run watch`, `gh auth login` |
| **openssh-client** | — | `git push` via SSH from inside the container |
| **Starship** | 1.26.0 | Terminal prompt — git branch and status, Dart and Node versions |
| **Utilities** | — | curl, git, jq, less, nano, htop, tree, procps, bash-completion (git and `gh` tab completion) |

### What is NOT inside

These are intentionally absent. Add them to your `pubspec.yaml` per project:

```text
provider / riverpod / bloc    →  flutter pub add provider
go_router                     →  flutter pub add go_router
dio / http                    →  flutter pub add dio
hive / isar / drift           →  flutter pub add hive
firebase_core                 →  flutter pub add firebase_core
any_other_package             →  flutter pub add <package>
```

---

## Platform Support

| Platform | Build target | Status |
| --- | --- | --- |
| Android APK / AAB | `flutter build apk`, `flutter build appbundle` | ✅ Full support |
| Web | `flutter build web`, `flutter run -d web` | ✅ Full support |
| iOS | `flutter build ipa` | ❌ Requires macOS + Xcode — impossible in Linux containers |
| Linux Desktop | `flutter build linux` | ❌ Not included — a container cannot show a desktop window, so the toolchain is left out |
| macOS Desktop | `flutter build macos` | ❌ Requires macOS |
| Windows Desktop | `flutter build windows` | ❌ Requires Windows host |

The three desktop platforms are switched off in the image's Flutter configuration, so `flutter create` generates only the `android`, `ios` and `web` folders and `flutter doctor` reports no desktop toolchains as missing.

### iOS Note

Apple's build toolchain (`Xcode`, `codesign`, `xcodebuild`) only runs on macOS by Apple's own enforcement — this is not a tooling gap. iOS is handled at the CI layer:

- **CI:** Use a `macos-latest` GitHub Actions runner in your `flutter-template` CI workflow to build, sign, and upload to TestFlight automatically on every push to `main`.
- **When you get a Mac:** The same devcontainer works identically. For iOS, also install Xcode on the Mac host — `flutter doctor` detects it automatically. No image changes needed.
- **No Mac at all:** Rent one for $1–5/hour on [Codemagic](https://codemagic.io) or [MacInCloud](https://www.macincloud.com) for the one-time certificate and provisioning profile setup.

---

## Repository Structure

```text
flutter-devcontainer/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml                ← Structured bug report form
│   │   ├── feature_request.yml           ← Structured feature request form
│   │   └── config.yml                    ← Disables blank issues, links to flutter-template
│   ├── rulesets/
│   │   ├── main-protect.json             ← Importable ruleset: protects main
│   │   ├── develop-protect.json          ← Importable ruleset: protects develop
│   │   └── tags-protect.json             ← Importable ruleset: protects release tags
│   ├── scripts/
│   │   ├── audit_gate.py                 ← CI: fails on high/critical npm advisories that are not allowlisted
│   │   ├── check-sync.sh                 ← CI: README versions/aliases must match the implementation
│   │   ├── check_drift.py                ← Compares pinned versions with upstream (used by dependency-drift.yml)
│   │   └── smoke-test.sh                 ← Toolchain smoke test shared by ci.yml and docker.yml
│   ├── workflows/
│   │   ├── ci.yml                        ← PR validation: lint, format, docs sync, build + smoke test + scan, npm audit → "CI passed"
│   │   ├── dependency-drift.yml          ← Weekly: reports pinned tool versions that are behind upstream
│   │   ├── docker.yml                    ← Builds natively per arch, tests, pushes, signs (main, weekly, manual)
│   │   ├── dockerhub-description.yml     ← Syncs README.md to Docker Hub on push to main
│   │   ├── labels.yml                    ← Syncs labels.yml to GitHub labels
│   │   └── release.yml                   ← Publishes a GitHub Release when a promotion changes the image
│   ├── CODE_OF_CONDUCT.md                ← Contributor Covenant 2.1
│   ├── CODEOWNERS                        ← Auto-requests reviewer on every PR
│   ├── CONTRIBUTING.md                   ← Branching, commit and change guidelines
│   ├── grype.yaml                        ← Image-scan exceptions for components that cannot be fixed here, each with its reason
│   ├── npm-audit-allowlist.txt           ← Accepted high/critical advisories, each with its reason
│   ├── PULL_REQUEST_TEMPLATE.md          ← PR checklist (versions, platforms, scope)
│   ├── dependabot.yml                    ← Weekly grouped updates for GitHub Actions + Docker base image → develop
│   ├── renovate.json                     ← Weekly PRs for the pins Dependabot cannot see (firebase-tools, pnpm, node digest) → develop
│   ├── labels.yml                        ← Label definitions — name, color, description
│   └── release.yml                       ← Release-notes categories (by PR label)
├── docker/
│   ├── Dockerfile.dev                    ← The image recipe ← MAIN FILE
│   └── firebase-tools-overrides.json     ← npm overrides that patch firebase-tools' transitive dependencies
├── docs/
│   └── github-setup.md                   ← Repository settings, rulesets and branch workflow
├── scripts/
│   └── shell_setup.sh                    ← Installs Starship (pinned + verified) and bakes aliases into the image
├── .dockerignore                         ← Allowlist: only what the Dockerfile COPYs enters the build context
├── .editorconfig                         ← Consistent indentation/line endings across editors
├── .gitattributes                        ← Forces LF line endings in every checkout
├── .gitignore                            ← Ensures secrets are never committed
├── .hadolint.yaml                        ← Dockerfile lint rules used by CI
├── LICENSE                               ← MIT — free to use, your name stays on it
├── README.md                             ← This file — also synced to Docker Hub
├── SECURITY.md                           ← Vulnerability reporting policy
└── repomix.config.json                   ← Repomix config for generating a single-file repository snapshot
```

---

## GitHub Automation

### Workflow trigger summary

| File | Trigger | What happens |
| --- | --- | --- |
| `workflows/ci.yml` | PR targeting `develop` or `main` | Lint, format, docs sync, build + smoke test + vulnerability scan (`amd64` + `arm64`), `npm audit`, then the aggregate **CI passed** check |
| `workflows/ci.yml` | Manual dispatch | Same checks on the selected branch |
| `workflows/docker.yml` | Push to `main` (`docker/`, `scripts/` changed) | Builds each architecture natively, smoke-tests, pushes `:latest`, `:sha-xxx`, a date tag and a Flutter-version tag, and signs the image |
| `workflows/docker.yml` | Every Monday 05:00 UTC | Same pipeline, so the published image picks up the newest Flutter stable and base-image patches |
| `workflows/docker.yml` | Manual dispatch (from `main`) | Same pipeline, with force-rebuild and push toggle |
| `workflows/dependency-drift.yml` | Every Monday 06:00 UTC / manual | Opens, updates or closes one issue listing pinned tool versions that are behind upstream |
| `workflows/dockerhub-description.yml` | Push to `main` (`README.md` changed) | Updates Docker Hub description |
| `workflows/dockerhub-description.yml` | Manual dispatch (from `main`) | Forces immediate Docker Hub sync |
| `workflows/release.yml` | Push to `main` (`docker/`, `scripts/` changed) | Publishes a GitHub Release (`vYYYY.MM.DD`) with generated notes |
| `workflows/labels.yml` | Push to `main` (`.github/labels.yml` changed) | Syncs all labels to GitHub |
| `workflows/labels.yml` | Manual dispatch | Bootstrap all labels in one go |
| `dependabot.yml` | Every Monday 09:00 UTC | Scans GitHub Actions and the Docker base image, opens grouped PRs against `develop` |
| `renovate.json` | Before 09:00 UTC on Mondays | Renovate opens one PR per bump of firebase-tools, pnpm or the node base digest (Dockerfile and README together) against `develop` |

Every third-party action is pinned to a full commit SHA (with a `# vX.Y.Z` comment) and every workflow declares least-privilege `permissions:`. Repository settings, rulesets and the branch workflow are documented in [`docs/github-setup.md`](docs/github-setup.md).

### `workflows/ci.yml`

Runs on every pull request into `develop` or `main`:

- **Verify source branch** — a PR into `main` must come from `develop` of this repository.
- **Lint** — Hadolint (`.hadolint.yaml`), ShellCheck, a syntax check of the Python helper, and actionlint.
- **Format** — LF line endings, no trailing whitespace, final newline (the rules in `.editorconfig` that tooling can check reliably).
- **Docs sync** — `.github/scripts/check-sync.sh` fails when `README.md` and the implementation disagree: a version pinned in `Dockerfile.dev` that the README does not mention, a Node major that differs between the Dockerfile and the workflows, or an alias missing from (or extra in) the README tables.
- **Build & test** — builds the image natively on `linux/amd64` and `linux/arm64` (no push) and runs `.github/scripts/smoke-test.sh`: Firebase CLI, pnpm and Starship versions against the pins in `Dockerfile.dev` (pnpm is resolved with the network disabled, proving the build-time cache works), the container user (UID/GID 1000, passwordless `sudo`), writable cache directories, Git's trust of `/workspace`, Node 24, Android platform, Chrome/Chromium, `flutter doctor`, the shell aliases and the Dev Container metadata label. On `amd64` the image is then scanned with Grype; a **critical** vulnerability that already has a fix fails the check, unless `.github/grype.yaml` records why it is accepted (only for components that cannot be fixed from this repository, such as the Bouncy Castle library bundled inside Google's Android command-line tools; each entry names the exact version it covers, so it lapses when that component changes). Skipped when a PR touches neither `docker/`, `scripts/`, the smoke test nor the CI configuration.
- **npm audit** — audits the `firebase-tools` tree exactly as the image installs it (pinned version plus `docker/firebase-tools-overrides.json`). Any **high or critical** advisory fails the check unless `.github/npm-audit-allowlist.txt` records why it is accepted; moderate and low findings are listed for information. The result and the full report are written to the job summary.
- **CI passed** — the single aggregate check required by branch protection. It fails if any job failed or was cancelled; jobs skipped by design count as passed.

### `workflows/docker.yml`

Builds and publishes the multi-platform image (`linux/amd64` + `linux/arm64`) to Docker Hub. Each architecture is built **natively** on its own runner (no QEMU emulation), smoke-tested with the same script the pull requests use, and only then pushed by digest. A final job merges both digests into one manifest list, applies the tags and signs the result with a keyless [Sigstore](https://www.sigstore.dev/) signature (see [Verifying the image](#verifying-the-image)). Every build carries SBOM and maximum-detail provenance attestations, and the layer cache lives in `buildcache-<arch>` tags in the registry rather than in the size-limited GitHub Actions cache.

The push trigger is path-filtered so a README change never rebuilds the image. The workflow also runs every Monday, because Flutter tracks the stable channel and the base image receives security patches even when this repository does not change. Pull requests are validated by `ci.yml` instead. The jobs use the `docker-hub` environment, which holds the Docker Hub credentials and is restricted to `main`.

> **Note:** `IMAGE_NAME` is hardcoded (not read from a secret) so the image tag is always valid.

### `workflows/dependency-drift.yml`

Dependabot cannot see the tools pinned in `Dockerfile.dev`, so this workflow compares them with their official release channels every Monday and keeps **one** issue up to date. It covers firebase-tools, pnpm (within its pinned major line — a newer major is noted separately), Starship, the Android cmdline-tools build, the digest of the `node` base image, and every advisory accepted in `.github/npm-audit-allowlist.txt` (reported as soon as a patched release exists). The issue closes itself when every pin is current. Renovate normally opens the PR for firebase-tools, pnpm and the node digest; the issue is the safety net for those and the only prompt for Starship and the cmdline-tools build, whose downloads are checksum-verified and so need a deliberate bump. Bump what it lists as described in [Updating the Image](#updating-the-image).

### `workflows/dockerhub-description.yml`

Syncs `README.md` to the Docker Hub repository description page on every `README.md` change merged to `main`.

### `workflows/release.yml`

Publishes a GitHub Release when a `develop` → `main` promotion changes the image (same path filter as `docker.yml`), so a documentation-only promotion does not produce a release. Releases use calendar versions (`vYYYY.MM.DD`, then `vYYYY.MM.DD.1`, …) because the image has no semantic API — Flutter and the Android SDK float with upstream. Notes are generated from the merged pull requests and grouped by label (`.github/release.yml`).

### `workflows/labels.yml`

Keeps GitHub repository labels in sync with `.github/labels.yml`. Labels are version-controlled — add or rename a label in the file, push, and GitHub reflects the change automatically. Run manually to bootstrap on a new repo.

### `dependabot.yml`

Automatically monitors two ecosystems and opens grouped PRs when updates are found:

- **`github-actions`** — all action versions across every workflow file, grouped into one weekly PR
- **`docker`** — the Docker ecosystem scan of `docker/`, with every update to the `node` base image ignored because Node is intentionally frozen (today it finds nothing: Dependabot's parser skips a `FROM` line built from `ARG`s, which is why [Renovate](#renovatejson) refreshes the node digest)

All Dependabot PRs target **`develop`**, not `main` — they land on the integration branch first and are promoted to `main` (which triggers the publish workflow) once verified. A 7-day cooldown delays each upstream release before it is proposed. Node.js is intentionally frozen at version 24 (all update types ignored). Dependabot cannot read the version pins in `Dockerfile.dev`, so those are handled by [Renovate](#renovatejson) and the [dependency-drift workflow](#workflowsdependency-driftyml) — see [Updating the Image](#updating-the-image).

### `renovate.json`

Renovate (the [Renovate GitHub app](https://github.com/apps/renovate), configured in `.github/renovate.json`) covers what Dependabot cannot parse. Its regex rules read `ENV FIREBASE_TOOLS_VERSION`, `ENV PNPM_VERSION` and the digest of the pinned `node` tag in `docker/Dockerfile.dev`, and open one PR per bump against `develop`, at most once a week and only for releases at least 7 days old. Each PR also updates the matching `README.md` entries, so the **Docs sync** check passes without manual edits. Node's major and minor stay frozen: only the digest of the pinned tag may change. Starship and the Android cmdline-tools build are excluded because their downloads are checksum-verified, so a new version needs its checksum copied from the official source in the same edit.

Both ecosystems run every Monday at 09:00 UTC.

---

## How the Build Works

```text
Push to main (Dockerfile or scripts changed), every Monday, or manual run
  → Builds linux/amd64 and linux/arm64 in parallel, each on a native runner
  → Smoke-tests each build (same script as the pull requests)
  → Pushes each architecture by digest, with SBOM + provenance attestations
  → Merges the digests into one manifest list and tags it
    (:latest, :flutter-<version>.<revision>, plus :sha-<commit> on pushes)
  → Signs the manifest list with a keyless Sigstore signature
  → Job summary written to Actions log

PR targeting develop or main (ci.yml)
  → Lints, format-checks, checks README sync and audits on every PR
  → If Dockerfile, scripts or CI config changed: builds natively on
    linux/amd64 and linux/arm64, smoke-tests the toolchain and scans the
    amd64 image (no push)
  → "CI passed" goes green or red
  → Merge when green
```

The first build takes ~15–20 minutes (Flutter SDK + Android SDK are large). Subsequent builds are much faster thanks to the per-architecture layer cache in the registry. Each job carries an explicit `timeout-minutes` so a stuck runner fails fast instead of hanging.

---

## Platforms

| Platform | Architecture |
| --- | --- |
| Windows · Linux · GCP | `linux/amd64` |
| Apple Silicon Mac | `linux/arm64` |

Docker pulls the correct platform automatically.

---

## Tags

| Tag | Published when |
| --- | --- |
| `latest` | Every publish — always the newest build |
| `flutter-X.Y.Z.R` | Every publish — **immutable**: Flutter release `X.Y.Z` and image revision `R` (for example `flutter-3.47.6.1`). `R` starts at 1 for each Flutter release and every new build of that release takes the next free number (`.2`, `.3`, …). The tag to pin an app to; the dotted numeric form lets Dependabot in a consuming repository order and bump it |
| `sha-xxxxxxx` | Only when a push to `main` changes the image — **immutable** per commit. Weekly and manual rebuilds do not create or overwrite it |
| `buildcache-amd64`, `buildcache-arm64` | Internal layer cache for the publish workflow — not meant to be pulled |

Only `latest` moves. `flutter-X.Y.Z.R`, `sha-xxxxxxx` and the image digest never change, and no published tag is ever deleted or overwritten, so an app pinned to one of them pulls the same image today and a year from now. A revision that already exists is never reused: the publish workflow always picks the next free number. The digest (`alihaidar199527/flutter-devcontainer@sha256:…`) is the strictest pin and appears in every run summary.

**Choosing a tag:** use `latest` to always get the newest Flutter and tools; use `flutter-X.Y.Z.R` in projects that must keep building on a known image, and bump it deliberately (the revision increases when the same Flutter release is rebuilt with operating-system or tool updates). The build date is in the image's `org.opencontainers.image.created` label and on Docker Hub. Keep Docker Hub tag-retention or inactive-image clean-up disabled for this repository, otherwise old tags can expire outside this pipeline.

### Rolling back `latest`

If a build reaches `latest` and turns out to be bad, repoint `latest` to the last good permanent tag. No rebuild is needed: the tag is moved on the registry, the digest (and with it the signature and attestations) is unchanged, and both architectures are kept.

```bash
# 1. find the last good build and confirm what it points to
docker buildx imagetools inspect alihaidar199527/flutter-devcontainer:flutter-X.Y.Z.R

# 2. repoint latest to it (needs push access to the Docker Hub repository)
docker buildx imagetools create \
  -t alihaidar199527/flutter-devcontainer:latest \
  alihaidar199527/flutter-devcontainer:flutter-X.Y.Z.R
```

The next publish from `main` (including the Monday rebuild) moves `latest` forward again, so fix the cause on `develop` and promote it, or disable the **Docker** workflow until then. Projects pinned to a permanent tag or digest are not affected by any of this.

---

## Verifying the image

Published images are signed with [Cosign](https://github.com/sigstore/cosign) using GitHub's OIDC identity (keyless), and carry SBOM and provenance attestations. To check that an image was built by this repository's publish workflow on `main`:

```bash
cosign verify alihaidar199527/flutter-devcontainer:latest \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/alihaidar0/flutter-devcontainer/\.github/workflows/docker\.yml@refs/heads/main$'
```

Inspect the attestations with `docker buildx imagetools inspect alihaidar199527/flutter-devcontainer:latest --format '{{ json .Provenance }}'` (or `.SBOM`).

---

## Shell Aliases

All aliases are defined in `scripts/shell_setup.sh` and baked into the image.

### Flutter

| Alias | Expands to | Notes |
| --- | --- | --- |
| `fl` | `flutter` | Short flutter prefix |
| `fget` | `flutter pub get` | Install all dependencies |
| `fadd` | `flutter pub add` | Add a package |
| `frm` | `flutter pub remove` | Remove a package |
| `fupgrade` | `flutter pub upgrade` | Upgrade packages |
| `foutdated` | `flutter pub outdated` | Check for outdated packages |
| `frun` | `flutter run` | Run on connected device |
| `frunw` | `flutter run -d web-server ...` | Run web server (Docker-friendly, port 8080) |
| `frunc` | `flutter run -d chrome` | Run in Chrome |
| `fbuild` | `flutter build` | Build prefix |
| `fbuildapk` | `flutter build apk --release` | Release APK |
| `fbuildaab` | `flutter build appbundle --release` | Release App Bundle |
| `fbuildweb` | `flutter build web --release` | Release web build |
| `ftest` | `flutter test` | Run tests |
| `ftestc` | `flutter test --coverage` | Run tests with coverage |
| `fanalyze` | `flutter analyze` | Static analysis |
| `fformat` | `dart format .` | Format all Dart files |
| `fformatcheck` | `dart format --set-exit-if-changed .` | Format check (CI mode) |
| `fdoctor` | `flutter doctor -v` | Verbose environment check |
| `fclean` | `flutter clean` | Clean build cache |
| `fcreate` | `flutter create` | Create new project |
| `fdevices` | `flutter devices` | List connected devices |
| `fupgrade_sdk` | `flutter upgrade` | Upgrade Flutter SDK |

### Dart

| Alias | Expands to |
| --- | --- |
| `dpub` | `dart pub` |
| `dget` | `dart pub get` |
| `dformat` | `dart format .` |
| `danalyze` | `dart analyze` |
| `dtest` | `dart test` |
| `drun` | `dart run` |
| `dcompile` | `dart compile` |
| `dglobal` | `dart pub global` |

### Firebase

| Alias | Expands to |
| --- | --- |
| `fblogin` | `firebase login` |
| `fbdeploy` | `firebase deploy` |
| `fbserve` | `firebase serve` |
| `fbuse` | `firebase use` |
| `fblist` | `firebase projects:list` |
| `ffinit` | `flutterfire configure` |

### Android / ADB

| Alias | Expands to |
| --- | --- |
| `adbdevices` | `adb devices` |
| `adblog` | `adb logcat` |
| `adbinstall` | `adb install` |
| `adbrestart` | `adb kill-server && adb start-server` |

### Git

| Alias | Expands to |
| --- | --- |
| `gs` | `git status` |
| `ga` | `git add` |
| `gc` | `git commit -m` |
| `gp` | `git push` |
| `gpl` | `git pull` |
| `gl` | `git log --oneline --graph --decorate` |
| `gco` | `git checkout` |
| `gb` | `git branch` |
| `gd` | `git diff` |

### General

| Alias | Expands to |
| --- | --- |
| `ll` | `ls -alFh --color=auto` |
| `la` | `ls -A --color=auto` |
| `cls` | `clear` |

---

## Updating the Image

Renovate opens PRs for firebase-tools, pnpm and the node digest, and the weekly [dependency-drift](#workflowsdependency-driftyml) issue lists every pin below that has fallen behind. For a manual bump: open a topic branch off `develop`, change the pin (and its checksum where one exists), update this README in the same PR, refresh the "Last verified" date above the `ENV` block, and let CI validate. Merge to `develop`, then promote to `main` when ready to publish. The **Docs sync** check fails the PR if the README and the Dockerfile disagree.

### Upgrading Flutter

Flutter is installed via `git clone -b stable`, so it always tracks the latest stable release at build time, and the weekly publish run picks up a new stable release automatically. To get it sooner, trigger the **Docker** workflow from the **Actions** tab (use *Bypass layer cache* to force a fresh clone). The resulting image is tagged `flutter-X.Y.Z` so a project can pin to it.

### Upgrading Node.js

Node.js is intentionally frozen at 24 LTS via `ARG NODE_VERSION=24` in `docker/Dockerfile.dev`. Dependabot is configured to ignore all Node update types so it will not open PRs for Node upgrades, and Renovate is limited to refreshing the digest of the pinned tag. The base image is additionally pinned by digest (`ARG NODE_IMAGE_DIGEST`), so a build always starts from a known base; the drift workflow reports when the tag has moved to a newer digest.

To refresh the digest within Node 24 (OS security patches), copy the new index digest of `node:24-trixie-slim` from [hub.docker.com/_/node/tags](https://hub.docker.com/_/node/tags) into `NODE_IMAGE_DIGEST`.

To move to another Node major version, change **both** the tag and the digest, and keep `NODE_VERSION` in `ci.yml` and `docker.yml` in step:

```dockerfile
ARG NODE_VERSION=26
ARG NODE_IMAGE_DIGEST=sha256:<digest of node:26-trixie-slim>
```

Verify the tag exists at [hub.docker.com/_/node/tags](https://hub.docker.com/_/node/tags) first. Newer Node lines may no longer bundle Corepack, so check that `corepack enable` still works.

### Upgrading Firebase CLI

Firebase CLI is pinned via `ENV FIREBASE_TOOLS_VERSION` in `docker/Dockerfile.dev`. Check the latest version at [npmjs.com/package/firebase-tools](https://www.npmjs.com/package/firebase-tools) and update the env:

```dockerfile
ENV FIREBASE_TOOLS_VERSION=15.32.1 \
    PNPM_VERSION=12.9.1 \
```

firebase-tools is installed into its own prefix (`/opt/firebase-tools`, with `firebase` symlinked into `/usr/local/bin`) instead of with `npm install -g`, because only a local install honours npm `overrides`. `docker/firebase-tools-overrides.json` pins patched versions of transitive dependencies that upstream has not picked up yet (today `basic-ftp` and the `uuid` used by `gaxios`). After a version bump:

1. Read the **npm audit** job summary of the pull request. If an advisory is now fixed upstream, delete its override.
1. If a new high or critical advisory appears with a patched release, add an override for it, and check that the CLI still loads (`firebase --help`, `firebase deploy --help`).
1. If no patched release exists, add the advisory ID and the reason to `.github/npm-audit-allowlist.txt`. The weekly drift issue reports when a fix is published.

### Upgrading pnpm

pnpm is activated via Corepack and pinned via `ENV PNPM_VERSION` in `docker/Dockerfile.dev`. The image tracks the pnpm 12 line; when a newer major appears, the drift workflow mentions it separately because it needs its own review. Check the latest 12.x version at [npmjs.com/package/pnpm](https://www.npmjs.com/package/pnpm) and update the env:

```dockerfile
ENV PNPM_VERSION=12.9.1
```

> `corepack enable` runs as **root** (it writes shims to the root-owned `/usr/local/bin`), but `corepack prepare pnpm@${PNPM_VERSION} --activate` runs as the non-root `developer` user. Corepack caches the download for the user that runs it, so preparing pnpm as `developer` is what makes `pnpm` work offline for that user. From pnpm 12 the package is only a launcher that downloads its native binary on first use, so the build also runs `pnpm --version` once (as `developer`, with network access) to bake that binary into the cache and to assert the pinned version. CI proves this by resolving pnpm with `COREPACK_ENABLE_NETWORK=0`.

### Upgrading Android SDK

Update the package list of the `sdkmanager` call in the Android SDK layer of `docker/Dockerfile.dev`:

```dockerfile
"platform-tools" \
"platforms;android-37" \
"build-tools;37.0.0" \
"cmdline-tools;latest" \
```

Check new API levels at [developer.android.com/tools/releases/platforms](https://developer.android.com/tools/releases/platforms).

### Upgrading Android Cmdline Tools

The cmdline-tools zip is a bootstrap: its URL contains a build number (`15859902`). It is unpacked outside the SDK, its `sdkmanager` installs `cmdline-tools;latest` into the SDK, and the bootstrap is then deleted, so no superseded jars stay in the image. When Google publishes a new build, update both build args in `docker/Dockerfile.dev`:

```dockerfile
ARG CMDLINE_TOOLS_BUILD=<new build number>
ARG CMDLINE_TOOLS_SHA256=<SHA-256 shown next to that download>
```

Copy the build number and the SHA-256 together from the [Android Studio download page](https://developer.android.com/studio#command-tools) ("Command line tools only", Linux). A wrong build number 404s the build and a wrong checksum fails it on purpose.

### Upgrading Starship

Starship is installed from a pinned release tarball, not an install script. Update the three args above `COPY scripts/shell_setup.sh` in `docker/Dockerfile.dev`:

```dockerfile
ARG STARSHIP_VERSION=1.26.0
ARG STARSHIP_SHA256_AMD64=<contents of starship-x86_64-unknown-linux-musl.tar.gz.sha256>
ARG STARSHIP_SHA256_ARM64=<contents of starship-aarch64-unknown-linux-musl.tar.gz.sha256>
```

Both checksum files are published as assets of the [GitHub release](https://github.com/starship/starship/releases).

### Adding a system package

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    your-new-tool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

---

## Troubleshooting

### Build fails — authentication error

**Symptom:** `denied: requested access to the resource is denied`

1. Go to **Settings → Environments → `docker-hub`**
1. Confirm both `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are present as environment secrets
1. Confirm the token has **Read, Write & Delete** scope — Read-only tokens cannot push
1. If expired: Docker Hub → **Account Settings → Personal access tokens** → delete → create new → update the secret
1. Re-run from the **Actions** tab

### Permission denied on `/workspace` or in a named volume

Images published before the user-ID change ran `developer` as UID 1001. A named volume created with such an image stays owned by 1001, and a Linux host user with UID 1000 could not write the project files. Current images use UID/GID 1000.

1. Check the user inside the container: `id` must show `uid=1000(developer) gid=1000(developer)`. If it does not, pull the current image and rebuild the dev container.
1. Recreate volumes made by an older image: `docker compose down -v`, then start the container again. Only cached data is lost (pub packages, Gradle artifacts, shell history).
1. If your host user is not UID 1000, make sure `updateRemoteUserUID` is not set to `false` in `devcontainer.json`; the default remaps the container user to yours.

### Build fails — checksum mismatch

**Symptom:** `sha256sum: WARNING: 1 computed checksum did NOT match` while building the Android or Starship layer.

A pinned download no longer matches the checksum recorded in `docker/Dockerfile.dev`. This is the check doing its job: either the version and checksum were bumped separately (copy both from the official source — see [Updating the Image](#updating-the-image)), or the upstream file changed unexpectedly, in which case do not bump the checksum until you know why.

### `flutter doctor` shows Android licenses not accepted

Inside the container, run:

```bash
yes | flutter doctor --android-licenses
```

This is already handled at image build time but may be needed after an `sdkmanager` update.

### `pnpm: command not found` in a project's postCreateCommand

This means the image was built before Corepack/pnpm activation was added, or the container is running against a stale cached image. Pull the latest image (`docker pull alihaidar199527/flutter-devcontainer:latest`) and rebuild the dev container. If it's still missing, run `corepack --version` inside the container to confirm Corepack itself is present before filing an issue.

If `pnpm` starts downloading itself on first use, the image predates the build-time cache fix (pnpm is now prepared as the `developer` user). Pull a current image, or check with `COREPACK_ENABLE_NETWORK=0 pnpm --version`, which must print the pinned version.

### ADB cannot find device (connecting to host emulator)

Run the Android emulator on your **host** machine, then inside the container:

```bash
adb connect host.docker.internal:5555
adbdevices
```

If shown as `unauthorized`, accept the prompt on the emulator screen. If shown as `offline`:

```bash
adbrestart
adb connect host.docker.internal:5555
```

On Windows, ensure your firewall allows inbound TCP on ports `5037` and `5555` from the Docker network.

### `flutter run -d chrome` shows no window

The container has no display, so a browser window cannot open inside it. Use the web server target and open the page in your host browser:

```bash
frunw   # flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

Then open `http://localhost:8080`. Chromium is still used headlessly inside the container for `flutter test --platform chrome` and web integration tests.

### `git push` fails — permission denied (publickey)

```bash
ssh-add -l          # check loaded keys
ssh -T git@github.com   # verify auth
```

On Windows, ensure the SSH agent is running and your key is loaded before opening VS Code:

```powershell
sc config ssh-agent start= auto
net start ssh-agent
ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
```

### Out of disk space during build

Flutter SDK + Android SDK together are ~4–5 GB. Ensure Docker Desktop has at least 20 GB of disk image space allocated:
**Docker Desktop → Settings → Resources → Disk image size**

---

## Contributing

- Work on a topic branch (`feat/…`, `fix/…`, `docs/…`, `ci/…`, `chore/…`) and open a PR against `develop`, not `main` — `main` is the publish branch and merges into it trigger a live Docker Hub push. Only a `develop` → `main` PR may target `main`.
- Merge with a **merge commit** (squash and rebase are disabled). The **CI passed** check must be green.
- Follow the checklist in [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) and the guidelines in [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md). Repository settings and rulesets are documented in [`docs/github-setup.md`](docs/github-setup.md).
- Participation is governed by the [Code of Conduct](.github/CODE_OF_CONDUCT.md).
- Found a vulnerability? See [`SECURITY.md`](SECURITY.md) — do not open a public issue.

---

## Related Repositories

| Repo | Purpose |
| --- | --- |
| [`flutter-devcontainer`](https://github.com/alihaidar0/flutter-devcontainer) | ← You are here — builds the Docker image |
| [`flutter-template`](https://github.com/alihaidar0/flutter-template) | Flutter project template — pulls this image for development |

---

Flutter stable · Dart · Android API 36 · Java 21 Temurin · Node.js 24 LTS · pnpm 12.9.1 · Debian 13 Trixie · 2026
