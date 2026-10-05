# Setup and recovery guide

Everything that can live in the repository (workflows, templates, labels, rulesets as JSON) is versioned under `.github/` and comes back with a `git push`. This guide covers everything else: the settings that can only be configured on GitHub, on Docker Hub and in the Renovate app. Follow it from top to bottom to recreate the whole setup on a new repository, or to check that an existing one still matches. Menu names change occasionally; the setting names below are what to look for.

- [What lives where](#what-lives-where)
- [Branch model and merge rules](#branch-model-and-merge-rules)
- [1. Create the repository and push the branches](#1-create-the-repository-and-push-the-branches)
- [2. Docker Hub](#2-docker-hub)
- [3. Settings → General](#3-settings--general)
- [4. Settings → Actions → General](#4-settings--actions--general)
- [5. Environment and secrets](#5-environment-and-secrets)
- [6. Settings → Advanced Security (Code security)](#6-settings--advanced-security-code-security)
- [7. Renovate](#7-renovate)
- [8. Labels](#8-labels)
- [9. Rulesets](#9-rulesets)
- [10. Bootstrap order](#10-bootstrap-order)
- [11. Verify the setup](#11-verify-the-setup)
- [12. Everyday workflow](#12-everyday-workflow)
- [13. Maintenance and recovery](#13-maintenance-and-recovery)
- [Settings checklist](#settings-checklist)

## What lives where

| Where | What | How it comes back |
| --- | --- | --- |
| The repository (`git`) | Dockerfile, scripts, workflows, rulesets as JSON, labels, templates, README, docs | `git push` of `develop` and `main` |
| GitHub settings | Default branch, merge rules, Actions policy, environment and secrets, security features, imported rulesets | Sections 3 to 6 and 9 |
| Docker Hub | The image repository, its description and categories, the access token, the published images | Section 2 (images come back with the first publish) |
| Renovate (Mend) | The GitHub app installation | Section 7 |

Names used everywhere (the Docker Hub name is hardcoded as `IMAGE_NAME` in `docker.yml` and in several docs, so change them together if they ever change):

| Item | Value |
| --- | --- |
| GitHub owner and repository | `alihaidar0/flutter-devcontainer` (public) |
| Docker Hub repository | `alihaidar199527/flutter-devcontainer` (public) |
| Default branch | `develop` |
| Publish branch | `main` |
| Consuming template | `alihaidar0/flutter-template` |
| Licence | MIT |

## Branch model and merge rules

```text
feat/*  fix/*  docs/*  ci/*  chore/*  deps/*
        │  pull request, merge commit (any topic branch)
        ▼
     develop   ← integration branch and default branch, protected
        │  pull request, merge commit, source must be `develop`
        ▼
       main    ← publish branch, protected
        │  push (only when an image file changed)
        ▼
  docker.yml (publish image, then call release.yml for the GitHub Release)
```

The rules, in one place:

1. **No direct push to `main`.** `main` accepts pull requests from `develop` only.
2. **No direct push to `develop`.** `develop` accepts pull requests from any branch.
3. **The image is built and pushed to Docker Hub only when a change to an image file is merged `develop` → `main`** (or when you run the Docker workflow by hand on `main`). The files that count are `docker/**`, `scripts/**`, `.dockerignore` and `.github/workflows/docker.yml`.
4. **Nothing is published automatically.** There is no schedule that builds or pushes. The weekly automation (Dependabot, Renovate, the dependency-drift issue) only opens pull requests against `develop` or an issue.

Both branches use **merge commits** (no squash, no rebase). Squashing into `main` would rewrite `develop`'s commits and make the next promotion conflict. Pull requests into `main` from any branch other than `develop` fail the **Verify source branch** job: GitHub rulesets cannot restrict a pull request's source branch, so the rule is enforced in `ci.yml` and made mandatory through the required **CI passed** check.

## 1. Create the repository and push the branches

1. Create the repository `alihaidar0/flutter-devcontainer` as **Public**, empty (no README, licence or `.gitignore`).
2. Push both branches from a clone. The rulesets do not exist yet, so direct pushes still work:

   ```bash
   git remote add origin git@github.com:alihaidar0/flutter-devcontainer.git
   git push -u origin develop
   git push -u origin main
   ```

   `main` must hold the last published state and `develop` the integration state; they can be identical for a new start.
3. On the repository page, click the gear next to **About** and set:

   | Field | Value |
   | --- | --- |
   | Description | `Base Docker development environment image for Flutter projects — Flutter SDK · Dart · Android SDK · Node.js · Firebase CLI · FlutterFire · GitHub CLI · Starship` |
   | Website | `https://github.com/alihaidar0/flutter-template` |
   | Topics | `android` `dart` `devcontainer` `developer-environment` `docker` `firebase` `flutter` `github-actions` `vscode` |

   The description is not only cosmetic: the publish workflow copies it into the image's `org.opencontainers.image.description` label. Keep it accurate (the image has no standalone Gradle, so Gradle is not listed).

## 2. Docker Hub

The image repository is created and configured by hand; the workflows only push to it and sync its README.

1. **Create the repository.** Docker Hub → **Repositories** → **Create repository**: namespace `alihaidar199527`, name `flutter-devcontainer`, visibility **Public**. Create it before the first publish; the publish job pushes into it and the README sync only runs once it exists.
2. **Short description** (100 characters at most): `Base Flutter dev container image with Android SDK, Web, Java, Node and Firebase. amd64 + arm64.`
3. **Categories:** `Developer tools` and `Languages & frameworks`.
4. **Access token.** Docker Hub → Account settings → **Personal access tokens** → **Generate new token**, permission **Read, Write & Delete**. Copy it once; it goes into the `docker-hub` environment in section 5. Note the expiry date and renew it before then (see *Build fails — authentication error* in the README's troubleshooting section).
5. **Do not enable tag retention or inactive-image clean-up** for this repository. Old `flutter-X.Y.Z.R` tags are restore points and must not expire outside the pipeline.
6. **The README is synced by the pipeline.** The **Docker Hub Description** workflow copies `README.md` to the repository overview on every README change merged to `main`. After creating a new repository, run it once by hand (Actions → **Docker Hub Description** → **Run workflow**, branch `main`).

What the pipeline writes to the repository (all expected):

| Tag | What it is |
| --- | --- |
| `latest` | The newest image (the only moving tag) |
| `flutter-X.Y.Z.R` | Permanent name of one image: Flutter release `X.Y.Z`, image revision `R` |
| `buildcache-amd64`, `buildcache-arm64` | BuildKit layer cache, one per architecture; never pulled |
| `sha256-<digest>.sig` | Cosign signature of an image |

Deleting the **GitHub** repository does not touch Docker Hub: the published images, their tags and their description stay. Deleting the **Docker Hub** repository removes the images, tags, description and categories, and apps pinned to its tags stop working until the next publish (see [Maintenance and recovery](#13-maintenance-and-recovery)).

## 3. Settings → General

| Setting | Value |
| --- | --- |
| Default branch | `develop` |
| Features | Issues on · Wikis off · Projects off · Discussions off |
| Pull Requests → Allow merge commits | **On** (default message: pull request title and description) |
| Pull Requests → Allow squash merging | **Off** |
| Pull Requests → Allow rebase merging | **Off** |
| Pull Requests → Always suggest updating pull request branches | On |
| Pull Requests → Allow auto-merge | On |
| Pull Requests → Automatically delete head branches | On |
| Releases → Enable release immutability (if offered) | On |

**Release immutability** locks a published release and its tag, and it reserves the tag name for good: even if the release and the tag are deleted, GitHub never lets that name be used again (creating it fails with "tag_name was used by an immutable release"). The pipeline copes with this by reserving each image's git tag before publishing and skipping names that GitHub refuses (see *Starting over on Docker Hub* in section 13), so keep it on.

The default branch is `develop`, the integration branch. New pull requests, Dependabot *security* updates and the **Run workflow** dropdown therefore start from `develop`, which is where all changes belong. Three consequences are handled in the repository:

- **Scheduled workflows run from the default branch**, so the weekly jobs (Dependabot, Renovate, **Dependency drift**) run from `develop`. None of them needs the Docker Hub credentials. Publishing has no schedule at all: `docker.yml` runs on `main` only.
- **The repository page shows `develop`**, including documentation that is not published yet. The Docker Hub README is synced from `main` and always reflects what is published.
- **Manual runs of Docker and Docker Hub Description must pick `main`** in the **Branch** dropdown, because that dropdown defaults to `develop` and the environment refuses it.

## 4. Settings → Actions → General

| Setting | Value |
| --- | --- |
| Actions permissions | Allow `alihaidar0`, and select non-`alihaidar0`, actions and reusable workflows |
| Allow actions created by GitHub | On |
| Allow Marketplace actions by verified creators | Off |
| Allowed actions (one per line) | `docker/*`, `peter-evans/dockerhub-description@*`, `EndBug/label-sync@*`, `hadolint/hadolint-action@*`, `raven-actions/actionlint@*`, `anchore/scan-action@*`, `sigstore/cosign-installer@*` |
| Require actions to be pinned to a full-length commit SHA | **On** |
| Artifact and log retention | 30 days |
| Fork pull request workflows | Require approval for all external contributors |
| Send write tokens / secrets to fork pull request workflows | Off |
| Workflow permissions | **Read repository contents and packages permissions** |
| Allow GitHub Actions to create and approve pull requests | Off |

Every workflow also declares its own `permissions:` block (default `contents: read`); jobs that need more request it explicitly: the `reserve-tag` and release jobs of `docker.yml` and the reusable `release.yml` it calls (`contents: write`, to create the git tag and the release), `labels.yml` and `dependency-drift.yml` (`issues: write`), `pr-labels.yml` (`pull-requests: write`), and the manifest job of `docker.yml` (`id-token: write` for keyless image signing — no secret is involved). A job can request more than the repository default; nothing else is granted.

If you add a workflow that uses a new third-party action, add it to the allowed list above and pin it to a full commit SHA, otherwise the run is refused.

Workflows run on an explicit runner image (`ubuntu-24.04`, and `ubuntu-24.04-arm` for arm64) rather than `ubuntu-latest`. GitHub moves `ubuntu-latest` to a new Ubuntu release on its own schedule, which changes the toolchain under every job at once and shows up as a warning on each run. Moving to a newer image is a deliberate edit of the `runs-on:` lines (and the matrix runner entries) once the build has been verified on it.

## 5. Environment and secrets

The Docker Hub credentials are only needed when publishing from `main`, so scope them to an environment instead of the whole repository.

1. Settings → Environments → **New environment** → `docker-hub`.
2. Deployment branches and tags → **Selected branches and tags** → add `main` (and nothing else, in particular not `develop`).
3. Environment secrets → add `DOCKERHUB_USERNAME` (`alihaidar199527`) and `DOCKERHUB_TOKEN` (the access token from section 2).
4. Settings → Secrets and variables → Actions → **delete** any repository-level copies of both secrets. A repository secret stays readable from any branch, which defeats the environment restriction.

With this in place a manual run of **Docker** or **Docker Hub Description** from any branch other than `main` is refused with a message like "Branch `develop` is not allowed to deploy to `docker-hub`". Nothing on `develop` ever receives the credentials.

## 6. Settings → Advanced Security (Code security)

| Feature | Value |
| --- | --- |
| Dependency graph | On |
| Dependabot alerts | On |
| Dependabot security updates | On |
| Grouped security updates | On |
| Dependabot version updates | Driven by `.github/dependabot.yml` (weekly, grouped, 7-day cooldown, PRs to `develop`) |
| Secret scanning | On |
| Push protection | **On** |
| Private vulnerability reporting | **On** (`SECURITY.md` links to it) |
| Code scanning → CodeQL | Default setup, language **Actions** (analyses the workflow files). It shows up as a **CodeQL / Analyze (actions)** check on pull requests; it is not required |

Dependabot security updates are raised against the default branch, which is `develop`, so no re-targeting is needed.

## 7. Renovate

Dependabot cannot read the version pins in `docker/Dockerfile.dev`, so Renovate (the Mend-hosted app) opens the pull requests for firebase-tools, pnpm and the node base digest. Its configuration is `.github/renovate.json`; the app itself is installed by hand.

1. Open the [Renovate GitHub app](https://github.com/apps/renovate) and click **Install**.
2. Choose the `alihaidar0` account, then **Only select repositories**, then `flutter-devcontainer`. Never install it on all repositories.
3. In the onboarding wizard on `developer.mend.io`:
   - **Select Product:** **Renovate Only** (the free *Community* plan). The *Mend Application Security* option needs a paid Mend licence and is not used.
   - **Select Mode:** **Scan and Alert** (shown as *Interactive* in the portal afterwards). **Scan Only** is silent: it opens no pull requests.
4. The configuration must be on the **default branch** (`develop`) before the app runs; it is, because it is versioned in the repository. No "Configure Renovate" onboarding pull request should appear; if one does, close it without merging.
5. Check it: on `developer.mend.io`, open the repository. The status should say **onboarded**, and *Detected Dependencies* should list `firebase-tools`, `pnpm` (several README entries plus the Dockerfile) and `node 24-trixie-slim`. *No Renovate branch updates available* is correct while every pin is current.

Renovate opens pull requests at most once a week (before 09:00 UTC on Monday), only for releases at least 7 days old, and each pull request also updates the matching README entries so the **Docs sync** check passes. Its pull requests go through the same **CI passed** check. Starship and the Android cmdline-tools build are not handled by Renovate: their downloads are checksum-verified and need a deliberate manual bump.

## 8. Labels

Release notes are grouped by label (`.github/release.yml`), and labels are defined in `.github/labels.yml`.

- **Creating the labels.** The **Labels** workflow syncs `.github/labels.yml` to GitHub when that file changes on `main`. On a new repository, run it once by hand: Actions → **Labels** → **Run workflow**, branch `main` (it needs only the default token).
- **Applying the labels.** The **PR labels** workflow adds labels to a pull request from its Conventional Commit title, so nobody sets them by hand: `feat` → `feature`, `fix` → `bug`, `docs` → `documentation`, `ci` → `ci`, `chore`/`refactor`/`style`/`test`/`perf` → `chore`, scope `deps` → `dependencies`, scope `docker` → `docker`, a `!` after the type or a `BREAKING CHANGE:` line → `breaking change`, and a `develop` → `main` promotion → `skip-changelog`. It only adds labels, skips bots and forks, and every label it uses must exist in `.github/labels.yml`.
- **Dependabot and Renovate** set their own labels (`dependencies`, `github-actions`, `docker`) from their configuration files.

## 9. Rulesets

Settings → Rules → Rulesets → **New ruleset** → **Import a ruleset**, once per file:

| File | Targets | What it enforces |
| --- | --- | --- |
| `.github/rulesets/main-protect.json` | `main` | No deletion, no force-push, pull request required (merge commits only, conversations resolved, stale approvals dismissed), required check **CI passed** |
| `.github/rulesets/develop-protect.json` | `develop` | Same as `main`, and the branch must be up to date with `develop` before merging |
| `.github/rulesets/tags-protect.json` | `flutter-*` tags | Released tags cannot be moved or deleted (creating new tags stays allowed, because the `reserve-tag` job creates one per image) |

Notes:

- **Bypass list is empty** on purpose, so the rules apply to administrators too. Direct pushes to `main` and `develop` are therefore rejected for everyone.
- **Required approvals are 0.** A pull request author cannot approve their own PR, so requiring 1 approval would block a solo maintainer from merging at all. Once a second maintainer joins, set `required_approving_review_count` to `1` and `require_code_owner_review` to `true` (`CODEOWNERS` is already in place), then re-import.
- **`main-protect` does not require "up to date"** (`strict_required_status_checks_policy: false`). After every promotion `main` holds one merge commit that `develop` does not, so a strict rule would force a `main` → `develop` sync before each release. GitHub's "branch is out-of-date" notice on a `develop` → `main` pull request is therefore harmless: do not click **Update branch**.
- The **CI passed** check is the only required check. It always runs, fails if any job failed or was cancelled, and passes when jobs were skipped by design (for example the image build on a docs-only PR).
- The required check is pinned to the **GitHub Actions** app (`integration_id: 15368`), so only the `ci.yml` job can satisfy it. Another app or a commit status with the same name is not accepted.
- Import the rulesets *after* the workflows exist on `main` (see below), otherwise nothing can report the required check.
- If the tag pattern ever changes, change it in the JSON file **and** in the live ruleset (the file is only the importable reference copy).

## 10. Bootstrap order

On a brand-new repository, in this order:

1. Create the repository and push `develop` and `main` (section 1), and set the About fields.
2. Create the Docker Hub repository, its descriptions and the access token (section 2).
3. Create the `docker-hub` environment and its two secrets (section 5).
4. Apply the settings in sections 3, 4 and 6. Set the default branch to `develop` last, after both branches exist.
5. Run the **Labels** workflow once by hand (section 8).
6. Publish the first image. The rulesets are not active yet, so a normal pull request works: change an image file or `docker.yml` on a topic branch, merge it into `develop`, then promote it with a pull request `develop` → `main`. Wait for **Docker** to finish and for the first release and the `flutter-X.Y.Z.1` tag to appear. As an alternative, run **Docker** by hand (Actions → **Docker** → **Run workflow**, branch `main`).
7. Run **Docker Hub Description** once by hand on `main` so the Docker Hub overview shows the README.
8. Import the three rulesets (section 9).
9. Install and check Renovate (section 7).
10. Verify (next section), and point `flutter-template` and your projects at the new tag.

## 11. Verify the setup

- `git push origin main` and `git push origin develop` are rejected by the rulesets.
- A PR from a topic branch into `main` fails **Verify source branch**, so **CI passed** is red and the PR cannot merge.
- A PR from `develop` into `main` offers only **Create a merge commit**, and gets the `skip-changelog` label automatically.
- A docs-only PR passes **CI passed** with **Build & test** skipped, and receives its labels from the title within seconds.
- A PR that edits `docker/Dockerfile.dev` runs **Build & test (amd64)** and **Build & test (arm64)**.
- A manual run of **Docker** from the `develop` branch is refused by the `docker-hub` environment.
- After a publish from `main`: the Docker Hub tags `latest` and `flutter-X.Y.Z.R` exist, the git tag of the same name exists, the release of the same name exists (for a push or a new Flutter release), and this check succeeds:

  ```bash
  cosign verify alihaidar199527/flutter-devcontainer:latest \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp '^https://github.com/alihaidar0/flutter-devcontainer/\.github/workflows/docker\.yml@refs/heads/main$'
  ```

## 12. Everyday workflow

```bash
# 0. confirm the identity the commit will use
git config user.name
git config user.email

# 1. start from an up-to-date develop
git switch develop
git pull --ff-only

# 2. create a topic branch (feat/ fix/ docs/ ci/ chore/ deps/)
git switch -c fix/example-topic

# 3. stage explicit paths, commit with a Conventional Commit message, push
git add path/to/changed-file
git commit -m "fix(docker): describe the change"
git push -u origin fix/example-topic

# 4. open a PR into develop (the default base), wait for CI passed, then merge it
#    with "Create a merge commit"
```

Promotion: open a PR `develop` → `main` (for example `https://github.com/alihaidar0/flutter-devcontainer/compare/main...develop`) and merge it with a merge commit. If an image file changed, that push triggers **Docker** (builds, tests, publishes and signs `latest` and `flutter-X.Y.Z.R`) and **Release** (called by Docker; the release and its git tag are named after the image, with notes grouped by PR label). A promotion that changes no image file produces no new image and no release.

**Monday routine.** Nothing is published between promotions. Every Monday morning (UTC) Dependabot and Renovate open pull requests against `develop`, and **Dependency drift** opens, updates or closes one issue listing what is behind upstream (Starship, the Android cmdline-tools build, accepted npm advisories that now have a fix, and a newer Flutter stable than the published image). Review and merge the pull requests into `develop`; when everything there is good, promote once. See [Updating the Image](../README.md#updating-the-image).

## 13. Maintenance and recovery

**Publishing by hand.** Actions → **Docker** → **Run workflow**, branch **`main`** (the dropdown defaults to `develop`, which the environment refuses). `push_image` = `false` is a dry run that builds and smoke-tests both architectures without publishing. Tick *Bypass layer cache* to force a fresh Flutter clone. A manual publish takes the next free `flutter-X.Y.Z.R`; a release is created only when it is the first image of a new Flutter release.

**Rolling back `latest`.** See [Rolling back `latest`](../README.md#rolling-back-latest). No rebuild is needed.

**Starting over on Docker Hub (wipe every image).** Only if you accept that every project pinned to an existing tag breaks until the next publish:

1. In Docker Hub, delete all tags of the repository (not the repository itself, which would also remove its description and categories).
2. Run the publish: merge an image change `develop` → `main`, or run **Docker** by hand on `main`. The image is built cold (about 15 to 25 minutes, because the `buildcache-*` tags are gone too).
3. Run **Docker Hub Description** once to keep the overview in sync.

You do not need to delete the GitHub releases or git tags, and deleting them would not help. With release immutability on, GitHub keeps every tag name that a published release used reserved for good, so those revision numbers can never be used again. The `reserve-tag` job takes the first revision that is free on Docker Hub **and** creatable on GitHub, so after a wipe the first new image is the next number above the highest one ever released (for example `flutter-3.47.6.3` rather than `.1`), and the numbering simply continues.

**Recreating the whole repository.** Follow sections 1 to 11 in order. The pipeline, the rulesets, the labels and the documentation all come from the pushed branches; the Docker Hub repository and token, the `docker-hub` environment and its secrets, the settings tables above and the Renovate installation are the parts you do by hand. Published images survive on Docker Hub as long as that repository exists, and the first new publish after recreating the GitHub repository continues the `flutter-X.Y.Z.R` sequence, because the revision is the first number not on Docker Hub.

**Expired Docker Hub token.** Publishing fails with `denied: requested access to the resource is denied`. Create a new token (section 2), update `DOCKERHUB_TOKEN` in the `docker-hub` environment and re-run the failed jobs.

## Settings checklist

A one-page list to tick off after a recovery. Each line points to the section with the exact values.

| Done | Where | Setting | Section |
| --- | --- | --- | --- |
| ☐ | GitHub | Repository public, `develop` and `main` pushed | 1 |
| ☐ | GitHub | About: description, website, topics | 1 |
| ☐ | Docker Hub | Repository public, short description, categories, no tag retention | 2 |
| ☐ | Docker Hub | Access token (Read, Write & Delete) | 2 |
| ☐ | GitHub | Default branch `develop`; merge commits only; auto-delete head branches; release immutability | 3 |
| ☐ | GitHub | Actions allow-list, SHA pinning, read-only workflow permissions | 4 |
| ☐ | GitHub | `docker-hub` environment limited to `main`, with `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`, no repository-level copies | 5 |
| ☐ | GitHub | Dependabot alerts and security updates, secret scanning, push protection, private vulnerability reporting, CodeQL (Actions) | 6 |
| ☐ | Mend | Renovate app on this repository only, Renovate Only, Scan and Alert | 7 |
| ☐ | GitHub | Labels workflow run once | 8 |
| ☐ | GitHub | First image published, Docker Hub Description run once | 10 |
| ☐ | GitHub | Rulesets imported: `main-protect`, `develop-protect`, `tags-protect` (`flutter-*`) | 9 |
| ☐ | GitHub | Protection verified | 11 |
