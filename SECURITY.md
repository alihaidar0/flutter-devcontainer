# Security Policy

## Scope

This repository builds and publishes a **development-only** Docker image (`alihaidar199527/flutter-devcontainer`). It is not intended to run in production, and contains no application secrets or user data by design.

## Supported versions

Only the `latest` tag (built from `main`) receives security fixes. Pinned `flutter-X.Y.Z.R` tags are not patched retroactively — move to `latest` or to a newer revision to pick up fixes.

## Reporting a vulnerability

If you find a security issue in this image (e.g. a vulnerable pinned dependency, an exposed credential, or an insecure default):

1. **Do not open a public issue.**
2. Use GitHub's [private vulnerability reporting](https://github.com/alihaidar0/flutter-devcontainer/security/advisories/new) for this repository.
3. Include the affected tag/digest, the vulnerable component, and reproduction steps if applicable.

You should expect an initial response within 5 business days.

## Supply chain

- Published images are signed with Sigstore (keyless, GitHub OIDC) and carry SBOM and provenance attestations. See [Verifying the image](README.md#verifying-the-image) to check a pulled image.
- Downloads baked into the image (Android command-line tools, Starship) are verified against pinned SHA-256 checksums, and the base image is pinned by digest.
- Pull requests scan the built image for critical vulnerabilities that already have a fix, and audit the `firebase-tools` dependency tree exactly as it is installed. Where upstream has not yet picked up a patched transitive dependency, `docker/firebase-tools-overrides.json` applies it. A high or critical advisory with no available fix must be recorded with its reason in `.github/npm-audit-allowlist.txt`. The image build upgrades the Debian packages, so security fixes published after the base image was built are included. The publish workflow scans the published image again for fixable high and critical findings. A finding in the image itself that cannot be fixed from this repository (for example a library bundled inside Google's Android command-line tools, or inside npm in the Node base image) must be recorded with its reason in `.github/grype.yaml`, scoped to the exact package version; both scans read that file, so a warning on the published image is always a finding that has not been reviewed yet. The weekly dependency-drift workflow flags those entries as soon as a fix is published.
- The image is built and published only when an image change is merged to `main` (or by a manual run); nothing is published on a schedule. Each build upgrades the Debian packages and takes the newest Flutter stable, so base-image and Flutter updates reach `latest` with the next publish.

## Dependency updates

- **GitHub Actions** are scanned weekly by Dependabot and opened as PRs against `develop` (see `.github/dependabot.yml`).
- **Node.js** is intentionally pinned at 24 LTS and excluded from automated major and minor updates — see [Upgrading Node.js](README.md#upgrading-nodejs). Only the digest of the pinned base image tag is refreshed, by Renovate.
- **Firebase CLI**, **pnpm** and the **node base image digest** are pinned in `docker/Dockerfile.dev`; Renovate opens a pull request against `develop` for each new release at least 7 days old, and updates the README entries with it. **Starship** and the Android command-line tools build are checksum-verified downloads and are bumped by hand. A weekly workflow opens an issue when any pin is behind upstream, or when a newer Flutter stable is out than the published image — see [Updating the Image](README.md#updating-the-image).
