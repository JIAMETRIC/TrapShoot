# Git workflow

**Trunk‑based.** `main` is always buildable and always what TestFlight is cut from.

## Branches

- `feat/<short-name>` new behaviour, `fix/<short-name>` a bug, `chore/<short-name>` tooling and docs.
- Short‑lived: a branch should merge within days. Rebase on `main` before opening the pull request.
- No long‑running release branches. A release is a tag on `main`.

## Commits

- One topic per commit, imperative subject under 72 characters, a body that says **why**.
- Never commit secrets, API keys, provisioning profiles or `xcuserdata`. (`.gitignore` covers the usual.)
- Fixtures (`Packages/TrapCore/Tests/TrapCoreTests/Fixtures`) are generated: regenerate with the script, never hand‑edit.

## Pull requests

- Open one for every change to `main`, even solo; the template lists the checks. CI must be green.
- Squash‑merge small PRs; merge‑commit PRs whose history matters (a port with its golden tests).
- Review focus, in order: timing behaviour, data format compatibility (document v2, CSV), accessibility, design tokens.

## Tags and versions

- `MARKETING_VERSION` is the shooter‑visible version (8.0.0); `CURRENT_PROJECT_VERSION` is the build and increases on every upload.
- Tag TestFlight builds `v8.0.0-b3`, App Store releases `v8.0.0`. `git describe --tags` then names any build.

## Xcode project file

- `*.pbxproj` uses `merge=union` in `.gitattributes`; after a merge, open Xcode once and let it re‑sort.
- Prefer changes in Swift packages over changes in the project file; the project file changes only for new targets,
  resources and capabilities.

## Repository protection (set in GitHub once)

- Require a pull request and the `CI` checks before merging to `main`.
- No force pushes to `main`; linear history optional.
