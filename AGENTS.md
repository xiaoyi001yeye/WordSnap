# Agent Workflow Rules

These rules apply to every future agent working in this repository.

1. Do not run local Flutter validation commands on this computer. This includes commands such as `flutter test`, `flutter run`, `flutter build`, and other local Flutter packaging or verification steps.
2. For this repository, GitHub Actions is the default packaging and validation path. Assume build verification will happen in CI after push unless the user explicitly asks for a different local check.
3. After code or asset changes, do not block on local Flutter verification. Instead, clearly report that local Flutter validation was intentionally skipped per repository rules.
4. Do not stop after editing only. Carry work through commit and push unless the user explicitly says not to.
5. After each completed modification, create a git commit with a clear message and push directly to the `main` branch.
6. Never leave local-only changes uncommitted at the end of a completed task unless the user explicitly requests that.
7. After committing and pushing, explicitly report back in the conversation that the code has been committed and pushed, and include the commit information so the user can see what was submitted.
8. When the user asks to "publish a new version", "release a new version", "发布一个新版本", "正式发布", or similar, treat that as a request to create a formal GitHub Release from a version tag unless the user explicitly says otherwise.
9. The default formal release flow is:
   - Read the current `pubspec.yaml` version.
   - Increment the patch version by 1 and increment the build number by 1. For example, `0.1.0+1` becomes `0.1.1+2`.
   - Commit the version bump to `main` with a clear release commit message, such as `Release v0.1.1`.
   - Push `main` to `origin/main`.
   - Create an annotated git tag matching the visible version, such as `v0.1.1`.
   - Push the tag to `origin`.
   - Let GitHub Actions create the formal GitHub Release and attach the APK assets.
10. Do not use the rolling `WordSnap Latest Installers` prerelease as the formal release path. Formal app upgrades should come from `v*` tag releases only.
11. If the user specifies an exact version, use that version instead of auto-incrementing. Still ensure the Android build number after `+` increases compared with the previous release.
12. After pushing a release tag, report the pushed commit hash and tag name, and remind the user that GitHub Actions will produce the final Release assets.

Default expectation for this repo:

- Modify files
- Skip local Flutter verification on this computer
- Commit the change
- Push to `origin/main`
- Let GitHub Actions handle packaging and validation
- Tell the user which commit was pushed

Default formal release expectation:

- Update `pubspec.yaml` to the next version
- Commit the release version bump
- Push `main`
- Create and push a `v*` annotated tag
- Let GitHub Actions create the GitHub Release
- Tell the user which commit and tag were pushed
