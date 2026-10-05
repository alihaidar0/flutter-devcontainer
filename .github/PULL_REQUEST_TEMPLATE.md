## Summary

<!-- What does this PR change and why? -->

## Type of change

- [ ] Dockerfile / image content change
- [ ] GitHub Actions workflow / repository automation change
- [ ] Dependency version bump
- [ ] Documentation only
- [ ] Other (describe above)

## Checklist

- [ ] This PR targets `develop` (only the `develop` → `main` release PR targets `main`)
- [ ] The **CI passed** check is green (lint, format, docs sync, build, smoke tests and image scan on `amd64` and `arm64`, `npm audit`)
- [ ] I did **not** change any pinned tool/action version without updating the corresponding `README.md` table, and any pinned download has its checksum updated with it
- [ ] New or updated GitHub Actions are pinned to a full commit SHA with a `# vX.Y.Z` comment
- [ ] `flutter doctor` output is clean in the built image (if the Flutter/Android toolchain was touched)
- [ ] No application code, `pubspec.yaml`, or app-level CI was introduced (out of scope for this repo)
- [ ] The PR title is a Conventional Commit (`type(scope): summary`); the labels that drive the release notes are added from it automatically, or add `skip-changelog` if this should not appear in them

## Related issues

<!-- Closes #123 -->
