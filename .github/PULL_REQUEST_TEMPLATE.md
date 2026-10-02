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
- [ ] The **CI passed** check is green (lint, format, build & smoke tests on `amd64` and `arm64`, `npm audit`)
- [ ] I did **not** change any pinned tool/action version without updating the corresponding `README.md` table
- [ ] New or updated GitHub Actions are pinned to a full commit SHA with a `# vX.Y.Z` comment
- [ ] `flutter doctor` output is clean in the built image (if the Flutter/Android toolchain was touched)
- [ ] No application code, `pubspec.yaml`, or app-level CI was introduced (out of scope for this repo)
- [ ] Labels are set (they drive the release notes), or `skip-changelog` if this should not appear in them

## Related issues

<!-- Closes #123 -->
