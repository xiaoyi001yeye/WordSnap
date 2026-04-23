# Agent Workflow Rules

These rules apply to every future agent working in this repository.

1. After every code or asset change, verify the project is still buildable/packageable before finishing.
2. Prefer the strongest available verification for the current change:
   - Run the relevant Flutter tests when Flutter is available.
   - Run a project build or packaging command when available.
   - If full packaging is too expensive, run the closest meaningful verification and clearly report any remaining risk.
3. Do not stop after editing only. Carry work through verification, commit, and push unless the user explicitly says not to.
4. After each completed modification, create a git commit with a clear message and push directly to the `main` branch.
5. If verification or packaging cannot be run because tools or environment are missing, say so explicitly before committing, and only proceed if the user has not asked to block on verification.
6. Never leave local-only changes uncommitted at the end of a completed task unless the user explicitly requests that.
7. After committing and pushing, explicitly report back in the conversation that the code has been committed and pushed, and include the commit information so the user can see what was submitted.

Default expectation for this repo:

- Modify files
- Verify the app can still package or build
- Commit the change
- Push to `origin/main`
- Tell the user which commit was pushed
