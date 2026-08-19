## Summary

<!-- What does this PR change and why? -->

## Type of change

- [ ] Dockerfile / image content change
- [ ] GitHub Actions workflow change
- [ ] Dependency version bump
- [ ] Documentation only
- [ ] Other (describe above)

## Checklist

- [ ] I did **not** change any pinned tool/action version without updating the corresponding `README.md` table
- [ ] `docker/Dockerfile.dev` builds successfully for both `linux/amd64` and `linux/arm64` (verified via the PR's `docker.yml` check)
- [ ] `flutter doctor` output is clean in the built image (if the Flutter/Android toolchain was touched)
- [ ] No application code, `pubspec.yaml`, or app-level CI was introduced (out of scope for this repo)
- [ ] Target branch is `develop` (unless this is an approved release PR into `main`)

## Related issues

<!-- Closes #123 -->
