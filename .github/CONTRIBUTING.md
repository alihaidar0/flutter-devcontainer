# Contributing

Thanks for helping improve `flutter-devcontainer`. This repository has one job: build and publish the base Flutter development image to Docker Hub. Changes here reach every project that uses the image, so they are kept small and verified.

## Scope

In scope: the image recipe (`docker/Dockerfile.dev`), the shell setup (`scripts/shell_setup.sh`), the pipeline that builds and checks it (`.github/`), and the documentation.

Out of scope: Flutter project files, `pubspec.yaml`, application code, app-level CI, and project-level packages. Those belong in the project repositories, or in [`flutter-template`](https://github.com/alihaidar0/flutter-template). If you are unsure whether an idea belongs in the base image, open a feature request first.

## Branching and pull requests

- Work on a topic branch (`feat/…`, `fix/…`, `docs/…`, `ci/…`, `chore/…`, `deps/…`) and open the pull request against **`develop`**.
- Only a `develop` → `main` pull request may target `main`; a merge into `main` publishes the image.
- Merge with a **merge commit**. Squash and rebase merging are disabled.
- Fill in the [pull request template](PULL_REQUEST_TEMPLATE.md). Use a Conventional Commit title: the labels that drive the release notes are added from it automatically (adjust them by hand if needed).
- The **CI passed** check must be green before merging.

The full branch model, repository settings, Docker Hub and Renovate setup, and rulesets are described in [`docs/github-setup.md`](../docs/github-setup.md).

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) with a scope where it helps:

```text
fix(docker): correct the Android SDK path
docs(readme): clarify volume handling
ci(deps): bump the docker/build-push-action group
build(deps): bump firebase-tools to 15.32.1
```

## Changing the image

- **Pinned versions live in several places.** When you change a pin in `docker/Dockerfile.dev` (firebase-tools, pnpm, Starship, the cmdline-tools build, the Node base digest, Android API levels), update the same version everywhere it appears in `README.md`, refresh the "Last verified" date above the `ENV` block, and update checksums together with their version. The **Docs sync** check enforces the README side. See [Updating the Image](../README.md#updating-the-image).
- **Verify before you bump.** Take versions and checksums from the official release channel. Do not bump speculatively.
- **Node stays on 24.** `NODE_VERSION` in the Dockerfile, `ci.yml` and `docker.yml`, and the Dependabot ignore rule must agree.
- **Keep it multi-architecture.** Every layer must build on `linux/amd64` and `linux/arm64`; branch on `$(dpkg --print-architecture)` instead of hard-coding one.
- **Keep layers lean:** `--no-install-recommends`, and clean the apt lists in the same `RUN`.
- **Aliases are documented twice.** An alias added, renamed or removed in `scripts/shell_setup.sh` must change in the README alias tables too.
- **Line endings are LF.** A CRLF shell script breaks the image build.
- **GitHub Actions** are pinned to a full commit SHA with a `# vX.Y.Z` comment, declare least-privilege `permissions:`, set `persist-credentials: false` on checkout, and receive `${{ }}` values through `env:` instead of inline in `run:` scripts.

## Checking your change locally

Docker is required for the image build; the linters can run in containers.

```bash
docker build -f docker/Dockerfile.dev -t flutter-devcontainer:local .
bash .github/scripts/smoke-test.sh flutter-devcontainer:local    # needs jq
bash .github/scripts/check-sync.sh                               # README ↔ implementation

docker run --rm -v "$PWD:/repo" -w /repo hadolint/hadolint hadolint --config .hadolint.yaml docker/Dockerfile.dev
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -no-color
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable $(git ls-files '*.sh')
```

A cold image build takes about 15–20 minutes. CI runs the same checks, builds both architectures natively and scans the image.

## Security issues

Do not open a public issue for a vulnerability. See [`SECURITY.md`](../SECURITY.md).

## Conduct

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
