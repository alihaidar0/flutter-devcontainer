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

## Dependency updates

- **GitHub Actions** and the **Docker base image** are scanned weekly by Dependabot and opened as PRs against `develop` (see `.github/dependabot.yml`).
- **Node.js** is intentionally pinned and excluded from automated updates — see [Upgrading Node.js](README.md#upgrading-nodejs).
- **Firebase CLI** and **Gradle** are pinned via `ENV` in `docker/Dockerfile.dev` and updated manually — see [Updating the Image](README.md#updating-the-image).
