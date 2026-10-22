---
name: release
description: "Use when preparing a Clinical Assistant release: review commits, choose a version, update release documentation and roadmap, reconcile GitHub issues, run project quality gates, and verify the Android/iOS release workflow."
---

# Release

Prepare a Clinical Assistant app release from recent changes. Keep release notes,
version metadata, roadmap status, and platform compliance information aligned
with the implementation.

## Arguments

Provide the next semantic app version, optionally followed by a build number
(for example, `0.2.0 14`). If no version is provided, inspect the latest release
tag and commits since that tag to recommend a version. Ask before choosing when
the change set does not clearly indicate patch, minor, or major impact.

## Workflow

1. **Check repository state and release history.** Run `git status --short`,
   inspect the current branch, find the latest version tag with
   `git describe --tags --abbrev=0`, and review commits since that tag. If there
   is no tag, use the current `pubspec.yaml` version and recent history as
   context; do not invent a previous release boundary. Read commit subjects,
   bodies, changed paths, and relevant diffs. Record dates, authors, and issue
   or PR references when available. Preserve all pre-existing worktree changes.

2. **Inventory the documentation.** Find tracked Markdown files with
   `rg --files -g '*.md'`, excluding generated/build output. Review relevant
   content in `README.md`, `ROADMAP.md`, `PRODUCT.md`, `PRIVACY.md`,
   `.github/DEPLOYMENT_GUIDE.md`, and any other docs affected by the changes.
   This repository may not yet have a `CHANGELOG.md`; create one for a release
   when a durable release history is needed.

3. **Choose and apply version metadata.** The app version is declared in the
   root `pubspec.yaml` as `major.minor.patch+build`. Use semantic versioning:
   patch for compatible fixes, minor for compatible user-facing capabilities,
   and major for incompatible changes. Update the version only for a release
   being prepared, and keep the app version consistent with the release tag and
   notes. Each store upload needs a build number not already used for that app
   version. The current GitHub release workflow uses `${{ github.run_number }}`
   as the build number; local builds should pass an unused `--build-number`.
   Do not edit generated platform version fields unless the project stops
   deriving them from Flutter metadata.

4. **Write release notes.** Add a dated version section to `CHANGELOG.md` if
   present or create it when appropriate. Summarize user-visible additions,
   changes, fixes, removals, and security or performance work in concise,
   grouped bullets. Include verified issue/PR links using the actual repository
   URL; do not guess issue numbers, ownership, or links.

5. **Update product documentation.** Update `README.md` for meaningful user-
   facing changes and update `PRODUCT.md`, `PRIVACY.md`, or
   `.github/DEPLOYMENT_GUIDE.md` only when their claims or instructions changed.
   Keep documentation specific to implemented behavior; do not document
   roadmap proposals as shipped features.

6. **Reconcile the roadmap and GitHub issues.** Review completed roadmap items
   against code and the release changes. Query issues with
   `gh issue list --state all --limit 1000 --json number,title,state,url,labels,updatedAt`
   when GitHub CLI access is available. Reflect verified issue state and add
   links using the repository's actual URL. Do not close, reopen, edit, or create
   GitHub issues unless explicitly requested. Update roadmap counts, milestones,
   and release history only if those sections exist and can be computed
   accurately; label unavailable or incomplete data rather than guessing.

7. **Review agent and developer guidance.** Check `AGENTS.md`, `.agents/`, and
   `.github/` instructions for architecture or workflow notes that the release
   changes make inaccurate. Update only relevant guidance; do not create
   generic instruction files or duplicate existing rules.

8. **Cross-check the release.** Verify version strings, feature descriptions,
   issue links, internal Markdown links, configuration names, and cited source
   paths against the repository. Review iOS HealthKit purpose strings and
   entitlements, Android health permissions, privacy disclosures, and any
   encryption/export-compliance declarations affected by the changes. Do not
   claim an encryption exemption without confirming the app's export
   classification; `ITSAppUsesNonExemptEncryption` must match that assessment.

9. **Run project release checks.** Follow `AGENTS.md` and
   `.github/workflows/release.yml`. At minimum run:

   ```sh
   dart format --output=none --set-exit-if-changed .
   flutter analyze --fatal-infos --fatal-warnings
   flutter test
   ```

   Build platform artifacts when requested and the required host, signing
   credentials, and provisioning are available. The local commands are
   `flutter build appbundle --release` and `flutter build ipa --release`; use
   an unused build number where needed. GitHub Actions also builds Android APK
   and App Bundle artifacts, configures iOS signing from repository secrets,
   uploads to configured stores, and can attach artifacts to a GitHub Release.
   Never print or ask the user to paste credentials into chat.

10. **Keep release actions authorized.** Do not commit, create or push tags,
    publish a GitHub Release, deploy to an app store, or mutate GitHub issues
    unless the user explicitly asks for that action. Do not imply an upload
    succeeded unless a tool or workflow confirms it. Report missing signing,
    API credentials, review steps, or unavailable tests plainly.

## Completion Report

Summarize the version/build decision, documentation and roadmap changes, issue
state checked, quality gates and builds run, artifact locations, and any release
actions not completed or compliance details requiring confirmation.