# GitHub repository setup

Everything that can live in the repository (workflows, templates, labels, rulesets as JSON) is versioned under `.github/`. This guide covers the parts that can only be configured in the GitHub UI. Menu names change occasionally; the setting names below are what to look for.

## Branch model

```text
feat/*  fix/*  docs/*  ci/*  chore/*  deps/*
        │  pull request, merge commit
        ▼
     develop   ← integration branch, protected
        │  pull request, merge commit, source must be `develop`
        ▼
       main    ← publish branch, protected
        │  push
        ▼
  docker.yml (publish image, then call release.yml for the GitHub Release)
```

- Nobody pushes to `develop` or `main` directly.
- Every change goes on a topic branch and opens a PR against `develop`.
- When `develop` is verified, one PR `develop` → `main` promotes it.
- Both branches use **merge commits** (no squash, no rebase). Squashing into `main` would rewrite `develop`'s commits and make the next promotion conflict.

Pull requests into `main` from any branch other than `develop` fail the **Verify source branch** job. GitHub rulesets cannot restrict a PR's source branch, so the rule is enforced in `ci.yml` and made mandatory through the required **CI passed** check.

## 1. Settings → General

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

The default branch is `develop`, the integration branch. New pull requests, Dependabot *security* updates and the **Run workflow** dropdown therefore start from `develop`, which is where all changes belong. Three consequences are handled in the repository:

- **Scheduled workflows run from the default branch**, so the weekly jobs (Dependabot, Renovate, **Dependency drift**) run from `develop`. None of them needs the Docker Hub credentials. Publishing has no schedule at all: `docker.yml` runs on `main` only.
- **The repository page shows `develop`**, including documentation that is not published yet. The Docker Hub README is synced from `main` and always reflects what is published.
- **Manual runs of Docker and Docker Hub Description must pick `main`** in the **Branch** dropdown, because that dropdown defaults to `develop` and the environment refuses it.

## 2. Settings → Actions → General

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

Every workflow also declares its own `permissions:` block (default `contents: read`); jobs that need more request it explicitly: the release job of `docker.yml` and the reusable `release.yml` it calls (`contents: write`), `labels.yml` and `dependency-drift.yml` (`issues: write`), and the manifest job of `docker.yml` (`id-token: write` for keyless image signing — no secret is involved).

Workflows run on an explicit runner image (`ubuntu-24.04`, and `ubuntu-24.04-arm` for arm64) rather than `ubuntu-latest`. GitHub moves `ubuntu-latest` to a new Ubuntu release on its own schedule, which changes the toolchain under every job at once and shows up as a warning on each run. Moving to a newer image is a deliberate edit of the `runs-on:` lines (and the matrix runner entries) once the build has been verified on it.

The **PR labels** workflow adds labels from the pull request title and needs the default workflow permissions to allow a job to request `pull-requests: write` (the job asks for it explicitly; nothing else is granted).

## 3. Environment and secrets

The Docker Hub credentials are only needed when publishing from `main`, so scope them to an environment instead of the whole repository.

1. Settings → Environments → **New environment** → `docker-hub`.
2. Deployment branches and tags → **Selected branches and tags** → add `main`.
3. Environment secrets → add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (a Docker Hub access token with **Read, Write & Delete**).
4. Settings → Secrets and variables → Actions → **delete** the repository-level copies of both secrets. A repository secret stays readable from any branch, which defeats the environment restriction.

With this in place a manual run of **Docker** or **Docker Hub Description** from any branch other than `main` is refused. Nothing on `develop` ever receives the credentials.

The publish workflow also writes layer-cache tags (`buildcache-amd64`, `buildcache-arm64`) and signature tags (`sha256-<digest>.sig`) to the Docker Hub repository. Both are expected; the token's **Read, Write & Delete** scope covers them.

## 4. Settings → Advanced Security (Code security)

| Feature | Value |
| --- | --- |
| Dependency graph | On |
| Dependabot alerts | On |
| Dependabot security updates | On |
| Grouped security updates | On |
| Dependabot version updates | Driven by `.github/dependabot.yml` (weekly, grouped, 7-day cooldown, PRs to `develop`) |
| Renovate | Install the [Renovate GitHub app](https://github.com/apps/renovate) on this repository only; it reads `.github/renovate.json` (firebase-tools, pnpm and the node digest, PRs to `develop`, 7-day minimum release age). Its PRs go through the same `CI passed` check |
| Secret scanning | On |
| Push protection | **On** |
| Private vulnerability reporting | **On** (`SECURITY.md` links to it) |
| Code scanning → CodeQL | Default setup, language **Actions** (analyses the workflow files) |

## 5. Rulesets

Settings → Rules → Rulesets → **New ruleset** → **Import a ruleset**, once per file:

| File | Targets | What it enforces |
| --- | --- | --- |
| `.github/rulesets/main-protect.json` | `main` | No deletion, no force-push, pull request required (merge commits only, conversations resolved, stale approvals dismissed), required check **CI passed** |
| `.github/rulesets/develop-protect.json` | `develop` | Same as `main`, and the branch must be up to date with `develop` before merging |
| `.github/rulesets/tags-protect.json` | `flutter-*` tags | Released tags cannot be moved or deleted |

Notes:

- **Bypass list is empty** on purpose, so the rules apply to administrators too.
- **Required approvals are 0.** A pull request author cannot approve their own PR, so requiring 1 approval would block a solo maintainer from merging at all. Once a second maintainer joins, set `required_approving_review_count` to `1` and `require_code_owner_review` to `true` (`CODEOWNERS` is already in place), then re-import.
- **`main-protect` does not require "up to date"** (`strict_required_status_checks_policy: false`). After every promotion `main` holds one merge commit that `develop` does not, so a strict rule would force a `main` → `develop` sync before each release.
- The **CI passed** check is the only required check. It always runs, fails if any job failed or was cancelled, and passes when jobs were skipped by design (for example the image build on a docs-only PR).
- The required check is pinned to the **GitHub Actions** app (`integration_id: 15368`), so only the `ci.yml` job can satisfy it. Another app or a commit status with the same name is not accepted.
- Import the rulesets *after* the workflows exist on `main` (see below), otherwise nothing can report the required check.

## 6. First-time bootstrap order

1. Create the `docker-hub` environment and move the secrets (section 3).
2. Merge the automation PR into `develop`, then promote it with a PR `develop` → `main` (the rulesets are not active yet, so normal PRs work).
3. Confirm on `main`: **Labels** ran, **Release** published the first release, and **Docker** published the image (this change touches `docker.yml`, which is in its path filter).
4. Apply the settings in sections 1, 2 and 4.
5. Import the three rulesets (section 5).
6. Verify (next section).

## 7. Verify the protection works

- `git push origin main` and `git push origin develop` are rejected by the rulesets.
- A PR from a topic branch into `main` fails **Verify source branch**, so **CI passed** is red and the PR cannot merge.
- A PR from `develop` into `main` offers only **Create a merge commit**.
- A docs-only PR passes **CI passed** with **Build & test** skipped.
- A PR that edits `docker/Dockerfile.dev` runs **Build & test (amd64)** and **Build & test (arm64)**.

## 8. Everyday workflow

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

# 4. open a PR into develop and merge it with "Create a merge commit"
```

Promotion: open a PR `develop` → `main` (title `release: <summary>`) and merge it with a merge commit. When `docker/` or `scripts/` changed, that push triggers **Docker** (builds, tests, publishes and signs `latest`, `flutter-X.Y.Z.R` and `sha-xxxxxxx`; the immutable `sha-` tag is created only by push-triggered runs) and **Release** (called by Docker; the release and its git tag are named after the image, `flutter-X.Y.Z.R`, with notes grouped by PR label). A promotion that changes neither produces no new image and no release.

Nothing is published between promotions. **Dependency drift** opens (or updates, or closes) one issue every Monday listing what is behind upstream, and Dependabot and Renovate open pull requests against `develop`. Handle them like any other change: review, merge into `develop`, then promote once; see [Updating the Image](../README.md#updating-the-image).
