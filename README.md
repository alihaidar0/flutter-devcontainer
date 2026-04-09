# flutter-devcontainer

> Blank-canvas base Docker image for VS Code Dev Containers.
> One image, shared across all your Flutter projects.

**Flutter (stable) · Dart · Android SDK 36 · Java 21 (Temurin) · Node.js 24 LTS · Firebase CLI · FlutterFire CLI · Gradle 9.4.1 · GitHub CLI · Starship**

[![Docker Build](https://github.com/alihaidar0/flutter-devcontainer/actions/workflows/docker.yml/badge.svg)](https://github.com/alihaidar0/flutter-devcontainer/actions/workflows/docker.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/alihaidar0/flutter-devcontainer)](https://hub.docker.com/r/alihaidar0/flutter-devcontainer)
[![Image Size](https://img.shields.io/docker/image-size/alihaidar0/flutter-devcontainer/latest)](https://hub.docker.com/r/alihaidar0/flutter-devcontainer)

```bash
docker pull alihaidar0/flutter-devcontainer:latest
```

---

## Overview

Every Flutter project needs the same developer tooling: Flutter SDK, Android SDK, Dart, Java, Gradle, Firebase, and a productive terminal. Configuring all of this from scratch on every machine — or worse, on every project — wastes time and produces inconsistent environments.

This repository solves that problem with a single shared base image. Push a change here and all your Flutter projects get the upgrade on the next `docker pull` — without touching any project code.

**This repo has one job:** build and publish the base development Docker image to Docker Hub.

It contains no Flutter project files, no `pubspec.yaml`, no application code, and no app-level CI. Flutter packages, app configuration, and deployment workflows all belong in the project repositories that consume this image.

---

## Architecture

This image is one half of a two-repo system.

| Repo | Responsibility |
|---|---|
| `flutter-devcontainer` ← **you are here** | Build and publish the base dev image |
| `flutter-template` | GitHub Template — the starting point for every new Flutter project |

When you open a Flutter project that uses this image, the container starts via Docker Compose with your project folder mounted at `/workspace` and your Git identity and SSH keys available for pushing to GitHub.

---

## What's Inside

### Runtime & Language

| Tool | Version | Purpose |
|---|---|---|
| **Flutter SDK** | stable channel | Flutter framework + Dart SDK |
| **Dart SDK** | bundled with Flutter | Language runtime (included in Flutter) |
| **Java (Eclipse Temurin)** | 21 | Required by Android build toolchain and Gradle |
| **Node.js** | 24 LTS (`bookworm-slim`) | Required by Firebase CLI and FlutterFire CLI |

### Android

| Tool | Version | Purpose |
|---|---|---|
| **Android SDK** | API 36 | Latest Android platform |
| **Android Build Tools** | 36.0.0 | APK/AAB compilation |
| **Android Platform Tools** | latest | `adb`, `fastboot` |
| **Android Cmdline Tools** | latest (14742923) | `sdkmanager`, `avdmanager` |
| **Gradle** | 9.4.1 | Android build system — pre-cached in image |

### Web & Desktop

| Tool | Version | Purpose |
|---|---|---|
| **Google Chrome** | stable (amd64) | `flutter run -d web`, `flutter test --platform chrome` |
| **Chromium** | latest (arm64) | Web target on Apple Silicon |
| **Linux desktop deps** | — | clang, cmake, ninja, GTK3 — for `flutter build linux` |

### Developer Tools

| Tool | Version | Purpose |
|---|---|---|
| **Firebase CLI** | 15.13.0 | Firebase project management and deployment |
| **FlutterFire CLI** | latest | Configure Firebase in Flutter projects |
| **GitHub CLI** | latest | `gh pr create`, `gh run watch`, `gh auth login` |
| **openssh-client** | — | `git push` via SSH from inside the container |
| **Starship** | latest | Terminal prompt — git branch, Flutter version, status |
| **Utilities** | — | curl, git, jq, nano, htop, tree, procps |

### What is NOT inside

These are intentionally absent. Add them to your `pubspec.yaml` per project:

```
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
|---|---|---|
| Android APK / AAB | `flutter build apk`, `flutter build appbundle` | ✅ Full support |
| Web | `flutter build web`, `flutter run -d web` | ✅ Full support |
| Linux Desktop | `flutter build linux` | ✅ Full support |
| iOS | `flutter build ipa` | ❌ Requires macOS + Xcode — impossible in Linux containers |
| macOS Desktop | `flutter build macos` | ❌ Requires macOS |
| Windows Desktop | `flutter build windows` | ❌ Requires Windows host |

### iOS Note

Apple's build toolchain (`Xcode`, `codesign`, `xcodebuild`) only runs on macOS by Apple's own enforcement — this is not a tooling gap. iOS is handled at the CI layer:

- **CI:** Use a `macos-latest` GitHub Actions runner in your `flutter-template` CI workflow to build, sign, and upload to TestFlight automatically on every push to `main`.
- **When you get a Mac:** The same devcontainer works identically. For iOS, also install Xcode on the Mac host — `flutter doctor` detects it automatically. No image changes needed.
- **No Mac at all:** Rent one for $1–5/hour on [Codemagic](https://codemagic.io) or [MacInCloud](https://www.macincloud.com) for the one-time certificate and provisioning profile setup.

---

## Repository Structure

```
flutter-devcontainer/
├── .github/
│   ├── CODEOWNERS                        ← Auto-requests reviewer on every PR
│   ├── dependabot.yml                    ← Weekly auto-updates for Actions + Docker base image
│   ├── labels.yml                        ← Label definitions — name, color, description
│   └── workflows/
│       ├── docker.yml                    ← Builds + pushes image on push/PR to main
│       ├── dockerhub-description.yml     ← Syncs README.md to Docker Hub on push to main
│       └── labels.yml                    ← Syncs labels.yml to GitHub labels
├── docker/
│   └── Dockerfile.dev                    ← The image recipe ← MAIN FILE
├── scripts/
│   └── shell_setup.sh                    ← Installs Starship + bakes aliases into the image
├── .dockerignore                         ← Excludes unnecessary files from the build context
├── .gitignore                            ← Ensures secrets are never committed
└── README.md                             ← This file — also synced to Docker Hub
```

---

## GitHub Automation

Five files under `.github/` handle everything automatically.

### Workflow trigger summary

| File | Trigger | What happens |
|---|---|---|
| `workflows/docker.yml` | Push to `main` (`docker/`, `scripts/` changed) | Builds + pushes `:latest` + `:sha-xxx` to Docker Hub |
| `workflows/docker.yml` | PR targeting `main` (same path filter) | Builds only — validates Dockerfile, never pushes |
| `workflows/docker.yml` | Manual dispatch | Builds + pushes, with force-rebuild and push toggle |
| `workflows/dockerhub-description.yml` | Push to `main` (`README.md` changed) | Updates Docker Hub description |
| `workflows/dockerhub-description.yml` | PR targeting `main` (`README.md` changed) | Runs but skips update until merged |
| `workflows/dockerhub-description.yml` | Manual dispatch | Forces immediate Docker Hub sync |
| `workflows/labels.yml` | Push to `main` (`.github/labels.yml` changed) | Syncs all labels to GitHub |
| `workflows/labels.yml` | Manual dispatch | Bootstrap all labels in one go |
| `dependabot.yml` | Every Monday 09:00 UTC | Scans Actions + Docker base image, opens PRs against `main` |

### `workflows/docker.yml`

Builds the multi-platform Docker image (`linux/amd64` + `linux/arm64`) and pushes it to Docker Hub. Path-filtered so a README change never triggers an unnecessary rebuild. PR builds validate the Dockerfile without pushing — only merged pushes publish to Docker Hub. Generates SBOM and provenance attestations on every build.

> **Note:** On `pull_request` events (including Dependabot PRs), GitHub withholds repository secrets by design. The workflow handles this correctly — login and push are both skipped on PRs, so the build validates the Dockerfile without needing credentials. The `IMAGE_NAME` is hardcoded (not from a secret) so the tag is always valid.

### `workflows/dockerhub-description.yml`

Syncs `README.md` to the Docker Hub repository description page on every `README.md` change merged to `main`. PRs trigger the workflow for the GitHub check but skip the actual Docker Hub update until merged.

### `workflows/labels.yml`

Keeps GitHub repository labels in sync with `.github/labels.yml`. Labels are version-controlled — add or rename a label in the file, push, and GitHub reflects the change automatically. Run manually to bootstrap on a new repo.

### `dependabot.yml`

Automatically monitors two ecosystems and opens grouped PRs when updates are found:

- **`github-actions`** — all action versions across every workflow file, grouped into one weekly PR
- **`docker`** — the `node:24-bookworm-slim` base image in `Dockerfile.dev`

Node.js is intentionally frozen at version 24 (all update types ignored). Firebase CLI is pinned via `FIREBASE_TOOLS_VERSION` in `Dockerfile.dev` and updated manually — see [Upgrading Firebase CLI](#upgrading-firebase-cli) below.

Both run every Monday at 09:00 UTC and target `main`.

---

## How the Build Works

```
Push to main (Dockerfile or scripts changed)
  → GitHub Actions detects the change
  → Builds linux/amd64 + linux/arm64 in parallel using layer cache
  → Pushes :latest and :sha-<commit> to Docker Hub
  → Syncs README to Docker Hub description
  → Job summary written to Actions log

PR targeting main (Dockerfile or scripts changed)
  → GitHub Actions detects the change
  → Builds linux/amd64 + linux/arm64 to validate
  → Does NOT push — PR check goes green or red
  → Merge when green
```

The first build takes ~15–20 minutes (Flutter SDK + Android SDK are large). Subsequent builds complete in 3–5 minutes thanks to GitHub Actions layer caching.

---

## Platforms

| Platform | Architecture |
|---|---|
| Windows · Linux · GCP | `linux/amd64` |
| Apple Silicon Mac | `linux/arm64` |

Docker pulls the correct platform automatically.

---

## Tags

| Tag | Published when |
|---|---|
| `latest` | Every push to `main` |
| `sha-xxxxxxx` | Every build — pin to this for rollback |

---

## Shell Aliases

All aliases are defined in `scripts/shell_setup.sh` and baked into the image.

### Flutter

| Alias | Expands to | Notes |
|---|---|---|
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
| `fbuildlinux` | `flutter build linux --release` | Release Linux desktop |
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
|---|---|
| `dpub` | `dart pub` |
| `dget` | `dart pub get` |
| `daudit` | `dart pub audit` |
| `dformat` | `dart format .` |
| `danalyze` | `dart analyze` |
| `dtest` | `dart test` |
| `drun` | `dart run` |
| `dcompile` | `dart compile` |
| `dglobal` | `dart pub global` |

### Firebase

| Alias | Expands to |
|---|---|
| `fblogin` | `firebase login` |
| `fbdeploy` | `firebase deploy` |
| `fbserve` | `firebase serve` |
| `fbuse` | `firebase use` |
| `fblist` | `firebase projects:list` |
| `ffinit` | `flutterfire configure` |

### Android / ADB

| Alias | Expands to |
|---|---|
| `adbdevices` | `adb devices` |
| `adblog` | `adb logcat` |
| `adbinstall` | `adb install` |
| `adbrestart` | `adb kill-server && adb start-server` |

### Git

| Alias | Expands to |
|---|---|
| `gs` | `git status` |
| `ga` | `git add` |
| `gc` | `git commit -m` |
| `gp` | `git push` |
| `gpl` | `git pull` |
| `gl` | `git log --oneline --graph --decorate` |
| `gco` | `git checkout` |
| `gb` | `git branch` |
| `gd` | `git diff` |

---

## Updating the Image

### Upgrading Flutter

Flutter is installed via `git clone -b stable`, so it always tracks the latest stable release at build time. To get a new Flutter version, trigger a manual rebuild from the **Actions** tab or push any change to `docker/` or `scripts/`.

### Upgrading Node.js

Node.js is intentionally frozen at 24 LTS via `ARG NODE_VERSION=24` in `docker/Dockerfile.dev`. Dependabot is configured to ignore all Node update types so it will not open PRs for Node upgrades. To upgrade Node, update the ARG manually:

```dockerfile
ARG NODE_VERSION=26
```

Verify the tag exists at [hub.docker.com/_/node/tags](https://hub.docker.com/_/node/tags) first. Commit, push to a branch, open a PR. The PR build validates the new version. Merge when green — image publishes automatically.

### Upgrading Firebase CLI

Firebase CLI is pinned via `ENV FIREBASE_TOOLS_VERSION` in `docker/Dockerfile.dev` and is **updated manually** — Dependabot does not track it. To upgrade:

1. Check the latest version at [npmjs.com/package/firebase-tools](https://www.npmjs.com/package/firebase-tools)
2. Update the env in `docker/Dockerfile.dev`:

```dockerfile
ENV GRADLE_VERSION=9.4.1 \
    FIREBASE_TOOLS_VERSION=15.13.0 \
```

3. Open a PR, let the build validate, merge.

### Upgrading Gradle

Update `ENV GRADLE_VERSION` in `docker/Dockerfile.dev`:

```dockerfile
ENV GRADLE_VERSION=9.5.0 \
```

Check the latest stable release at [gradle.org/releases](https://gradle.org/releases). Do not use release candidates.

### Upgrading Android SDK

Update the `sdkmanager` call in `docker/Dockerfile.dev`:

```dockerfile
&& sdkmanager \
   "platform-tools" \
   "platforms;android-37" \
   "build-tools;37.0.0" \
   "cmdline-tools;latest"
```

Check new API levels at [developer.android.com/tools/releases/platforms](https://developer.android.com/tools/releases/platforms).

### Upgrading Android Cmdline Tools

The cmdline-tools zip URL contains a build number (`14742923`). When Google releases a new version, update the URL in `docker/Dockerfile.dev`:

```dockerfile
https://dl.google.com/android/repository/commandlinetools-linux-NEW_BUILD_latest.zip
```

Find the latest build number on the [Android Studio download page](https://developer.android.com/studio#command-tools).

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

1. Go to **Settings → Secrets and variables → Actions**
2. Confirm both `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are present
3. Confirm the token has **Read, Write & Delete** scope — Read-only tokens cannot push
4. If expired: Docker Hub → **Account Settings → Personal access tokens** → delete → create new → update secret
5. Re-run from the **Actions** tab

### Build fails — invalid image tag on pull_request

**Symptom:** `ERROR: invalid tag "/flutter-devcontainer:sha-xxx": invalid reference format`

**Cause:** On `pull_request` events, GitHub withholds all repository secrets. If the image name were built from the `DOCKERHUB_USERNAME` secret it would resolve to an empty string.

**Fix:** `IMAGE_NAME` in `docker.yml` is hardcoded directly — the Docker Hub username is not sensitive:

```yaml
env:
  IMAGE_NAME: alihaidar199527/flutter-devcontainer
```

### `flutter doctor` shows Android licenses not accepted

Inside the container, run:

```bash
yes | flutter doctor --android-licenses
```

This is already handled at image build time but may be needed after an `sdkmanager` update.

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

### Chrome not found for web builds

Chrome is only installed on `linux/amd64`. On `linux/arm64` (Apple Silicon), `flutter run -d web` uses the web server target instead:

```bash
frunw   # flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

Then open `http://localhost:8080` on your host browser.

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

## Related Repositories

| Repo | Purpose |
|---|---|
| [`flutter-devcontainer`](https://github.com/alihaidar0/flutter-devcontainer) | ← You are here — builds the Docker image |
| [`flutter-template`](https://github.com/alihaidar0/flutter-template) | Flutter project template — pulls this image for development |

---

*Flutter stable · Dart · Android API 36 · Java 21 Temurin · Node.js 24 LTS · Gradle 9.4.1 · Debian 12 Bookworm · 2026*