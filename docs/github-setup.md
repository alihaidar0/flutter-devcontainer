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
  docker.yml (publish image) + release.yml (GitHub Release)
```

- Nobody pushes to `develop` or `main` directly.
- Every change goes on a topic branch and opens a PR against `develop`.
- When `develop` is verified, one PR `develop` → `main` promotes it.
- Both branches use **merge commits** (no squash, no rebase). Squashing into `main` would rewrite `develop`'s commits and make the next promotion conflict.

Pull requests into `main` from any branch other than `develop` fail the **Verify source branch** job. GitHub rulesets cannot restrict a PR's source branch, so the rule is enforced in `ci.yml` and made mandatory through the required **CI passed** check.

## 1. Settings → General

| Setting | Value |
| --- | --- |
| Default branch | `main` |
| Features | Issues on · Wikis off · Projects off · Discussions off |
| Pull Requests → Allow merge commits | **On** (default message: pull request title and description) |
| Pull Requests → Allow squash merging | **Off** |
| Pull Requests → Allow rebase merging | **Off** |
| Pull Requests → Always suggest updating pull request branches | On |
| Pull Requests → Allow auto-merge | On |
| Pull Requests → Automatically delete head branches | On |
| Releases → Enable release immutability (if offered) | On |

The default branch stays `main` so the repository page, the Docker Hub README and scheduled workflows reflect what is published. Dependabot *version* updates already target `develop`; Dependabot *security* updates are raised against the default branch, so expect those PRs against `main` and re-target them to `develop`.

## 2. Settings → Actions → General

| Setting | Value |
| --- | --- |
| Actions permissions | Allow `alihaidar0`, and select non-`alihaidar0`, actions and reusable workflows |
| Allow actions created by GitHub | On |
| Allow Marketplace actions by verified creators | Off |
| Allowed actions (one per line) | `docker/*`, `peter-evans/dockerhub-description@*`, `EndBug/label-sync@*`, `hadolint/hadolint-action@*`, `raven-actions/actionlint@*` |
| Require actions to be pinned to a full-length commit SHA | **On** |
| Artifact and log retention | 30 days |
| Fork pull request workflows | Require approval for all external contributors |
| Send write tokens / secrets to fork pull request workflows | Off |
| Workflow permissions | **Read repository contents and packages permissions** |
| Allow GitHub Actions to create and approve pull requests | Off |

Every workflow also declares its own `permissions:` block (default `contents: read`); jobs that need more (`release.yml`, `labels.yml`) request it explicitly.

## 3. Environment and secrets

The Docker Hub credentials are only needed when publishing from `main`, so scope them to an environment instead of the whole repository.

1. Settings → Environments → **New environment** → `docker-hub`.
2. Deployment branches and tags → **Selected branches and tags** → add `main`.
3. Environment secrets → add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (a Docker Hub access token with **Read, Write & Delete**).
4. Settings → Secrets and variables → Actions → **delete** the repository-level copies of both secrets. A repository secret stays readable from any branch, which defeats the environment restriction.

With this in place a manual run of **Docker** or **Docker Hub Description** from any branch other than `main` is refused.

## 4. Settings → Advanced Security (Code security)

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
| Code scanning → CodeQL | Default setup, language **Actions** (analyses the workflow files) |

## 5. Rulesets

Settings → Rules → Rulesets → **New ruleset** → **Import a ruleset**, once per file:

| File | Targets | What it enforces |
| --- | --- | --- |
| `.github/rulesets/main-protect.json` | `main` | No deletion, no force-push, pull request required (merge commits only, conversations resolved, stale approvals dismissed), required check **CI passed** |
| `.github/rulesets/develop-protect.json` | `develop` | Same as `main`, and the branch must be up to date with `develop` before merging |
| `.github/rulesets/tags-protect.json` | `v*` tags | Released tags cannot be moved or deleted |

Notes:

- **Bypass list is empty** on purpose, so the rules apply to administrators too.
- **Required approvals are 0.** A pull request author cannot approve their own PR, so requiring 1 approval would block a solo maintainer from merging at all. Once a second maintainer joins, set `required_approving_review_count` to `1` and `require_code_owner_review` to `true` (`CODEOWNERS` is already in place), then re-import.
- **`main-protect` does not require "up to date"** (`strict_required_status_checks_policy: false`). After every promotion `main` holds one merge commit that `develop` does not, so a strict rule would force a `main` → `develop` sync before each release.
- The **CI passed** check is the only required check. It always runs, fails if any job failed or was cancelled, and passes when jobs were skipped by design (for example the image build on a docs-only PR).
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

Promotion: open a PR `develop` → `main` (title `release: <summary>`) and merge it with a merge commit. That push triggers **Release** (tag `vYYYY.MM.DD`, notes grouped by PR label) and, when `docker/` or `scripts/` changed, **Docker** (publishes `latest` and `sha-xxxxxxx`).
