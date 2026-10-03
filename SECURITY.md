# Security Policy

## Scope

This repository builds and publishes a **development-only** Docker image (`alihaidar199527/flutter-devcontainer`). It is not intended to run in production, and contains no application secrets or user data by design.

## Supported versions

Only the `latest` tag (built from `main`) receives security fixes. Pinned `sha-xxxxxxx` tags are not patched retroactively — rebuild from a current commit to pick up fixes.

## Reporting a vulnerability

If you find a security issue in this image (e.g. a vulnerable pinned dependency, an exposed credential, or an insecure default):

1. **Do not open a public issue.**
2. Use GitHub's [private vulnerability reporting](https://github.com/alihaidar0/flutter-devcontainer/security/advisories/new) for this repository.
3. Include the affected tag/digest, the vulnerable component, and reproduction steps if applicable.

You should expect an initial response within 5 business days.

## Supply chain

- Published images are signed with Sigstore (keyless, GitHub OIDC) and carry SBOM and provenance attestations. See [Verifying the image](README.md#verifying-the-image) to check a pulled image.
- Downloads baked into the image (Android command-line tools, Starship) are verified against pinned SHA-256 checksums, and the base image is pinned by digest.
- Pull requests scan the built image for critical vulnerabilities that already have a fix, and audit the `firebase-tools` dependency tree exactly as it is installed. Where upstream has not yet picked up a patched transitive dependency, `docker/firebase-tools-overrides.json` applies it. A high or critical advisory with no available fix must be recorded with its reason in `.github/npm-audit-allowlist.txt`. A critical finding in the image itself that cannot be fixed from this repository (for example a library bundled inside Google's Android command-line tools) must be recorded with its reason in `.github/grype.yaml`, scoped to the exact package version. The weekly dependency-drift workflow flags those entries as soon as a fix is published.
- The image is rebuilt every week so base-image and Flutter updates reach `latest` without a code change.

## Dependency updates

- **GitHub Actions** are scanned weekly by Dependabot and opened as PRs against `develop` (see `.github/dependabot.yml`).
- **Node.js** is intentionally pinned and excluded from automated updates — see [Upgrading Node.js](README.md#upgrading-nodejs).
- **Firebase CLI**, **pnpm**, **Starship**, the Android command-line tools build and the **node base image digest** are pinned in `docker/Dockerfile.dev`. A weekly workflow opens an issue when any of them is behind upstream, and they are bumped manually — see [Updating the Image](README.md#updating-the-image).
