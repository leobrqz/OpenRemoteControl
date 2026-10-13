# Agent guidelines

## Project contracts

- Open Remote Control is an open source Android remote for Windows, licensed GPL-3.0-only.
- Mouse, keyboard and media control are essential. Connections use IP networking; Bluetooth is outside the product scope.
- Windows runs the server and notification-area icon in the background. Configuration belongs in the browser dashboard.
- Android provides the mobile controls, computer discovery, pairing and preferences. Discovery and saved connections should minimize setup.
- Preserve server identity, paired devices, user settings and signing-key continuity across updates. Provide migrations when changing persistence or protocol contracts.

## Repository layout

- `app/`: Android Flutter client with views, view models and repositories.
- `web/src/`: HTML/JavaScript dashboard with Tailwind/DaisyUI and a Node.js asset build.
- `web/server/`: Windows background host and tray, Dart services and C++/Win32 integration.
- `packages/remote_core/`: shared Dart protocol, encryption and diagnostics.
- `scripts/`: build, packaging and asset generation.
- `output/android/` and `output/windows/`: generated distribution artifacts, ignored by Git.

Keep platform-specific code and dependencies in their owning project. Share protocol code through `remote_core`. Use the official assets in `app/assets/branding/` and the branding generator for platform exports.

## Working style

- Be direct, practical and concise. Speak Portuguese with the user; write repository documentation, commit messages, issues, PRs and releases in English.
- Take ownership of authorized work and finish it. Resolve routine implementation details using the code and established project conventions.
- Ask only when missing information or authorization prevents progress. Respect explicit requests to pause, limit scope or hold publication for review.
- Give brief progress updates during longer work. Explain concrete changes, verification and remaining limitations; do not claim checks that were not performed.
- Keep product copy useful: labels, instructions and actionable errors. Avoid promotional filler, redundant explanations and decorative feature/platform labels.
- Keep documentation concise. Add documents only when the task requires them.

## Engineering

- Investigate logs and reproduce reported failures before choosing a fix. Address the cause and preserve useful diagnostics.
- Prefer established libraries and existing project components. Keep changes modular and scoped; remove obsolete code from the affected area.
- Keep business/state logic in view models and services, persistence in repositories, and rendering in views. Controls and settings must have working behavior.
- Keep dashboard scripts compatible with its CSP and retain loopback access and Origin validation. Avoid putting credentials or pairing secrets in logs or Git.
- Perform implementation tests when requested; follow release validation when shipping is requested. Cover the affected behavior and report the actual results. Reuse existing devices/emulators and preserve their configuration.
- Use the repository build scripts to produce packages. Keep Windows background processes hidden. Before recursive Windows moves/deletions, verify the resolved paths are inside the intended directory and use one shell throughout.

## Git discipline

- Commit and push small, coherent, completed changes throughout authorized work. Do not postpone all commits until the end of a long task.
- Work on `main` by default. Create another branch only when the user requests one; version releases use tags on `main`.
- Explicit user requests to review before committing, pushing or publishing override the normal continuous commit/push workflow.
- Inspect `git status --short` and stage explicit paths. Review with focused reads and `git show`; do not run `git diff` or `git diff --check`.
- Commit only intended source and required project assets. Exclude build outputs, dependency caches, credentials, keystores, logs and unrelated user changes.
- Keep `.codex/` ignored and untracked. Never remove its ignore rule or force-add its contents.
- Do not rewrite published history without an explicit user request.

## Versioning and releases

Follow the local GitHub release playbook at `.codex/workflows/github.md`. It is an agent playbook stored outside Git. If absent, recreate it locally from the rules below before shipping.

- Ordinary source commits do not create releases. A requested version delivery includes the pushed commit/tag and the published GitHub release with its artifacts.
- Keep Android and Windows pubspec versions synchronized as `MAJOR.MINOR.PATCH+BUILD`; synchronize the semantic version in the web package/lock and shared package. Increment the build number for each distributed version and retain the Android signing key.
- Use semantic versioning: patch for compatible fixes, minor for features, major for breaking changes; before `1.0`, use minor for breaking changes. Create an annotated `vMAJOR.MINOR.PATCH` tag on the release commit. Published tags and assets are immutable.
- Validate affected projects, build with `scripts/build_android.ps1` and `scripts/build_windows.ps1`, and verify artifact versions and checksums before publication.
- Include the Android APK and Windows ZIP from their `output/` directories, plus artifacts required by the release tooling. Use `gh` and real multiline body files for publication.
- Use an English release title containing the version and concise notes describing the actual changes. Include related PR/issue links only when relevant; omit empty related sections.
- Verify the published release and every attachment. Report the release URL and complete failed uploads before declaring delivery finished.

## Keeping this file durable

Store project contracts and working rules here. Keep session history, completed work, pending tasks, current versions and machine-specific details in ignored `.codex/` notes. Read current facts from source, manifests, Git and GitHub. Update this file when an agreed project contract changes.
