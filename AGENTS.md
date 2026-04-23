# Agent Workflow Rules

These rules apply to every future agent working in this repository.

1. Do not run local Flutter validation commands on this computer. This includes commands such as `flutter test`, `flutter run`, `flutter build`, and other local Flutter packaging or verification steps.
2. For this repository, GitHub Actions is the default packaging and validation path. Assume build verification will happen in CI after push unless the user explicitly asks for a different local check.
3. After code or asset changes, do not block on local Flutter verification. Instead, clearly report that local Flutter validation was intentionally skipped per repository rules.
4. Do not stop after editing only. Carry work through commit and push unless the user explicitly says not to.
5. After each completed modification, create a git commit with a clear message and push directly to the `main` branch.
6. Never leave local-only changes uncommitted at the end of a completed task unless the user explicitly requests that.
7. After committing and pushing, explicitly report back in the conversation that the code has been committed and pushed, and include the commit information so the user can see what was submitted.

Default expectation for this repo:

- Modify files
- Skip local Flutter verification on this computer
- Commit the change
- Push to `origin/main`
- Let GitHub Actions handle packaging and validation
- Tell the user which commit was pushed
