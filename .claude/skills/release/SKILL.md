---
name: release
description: Cut a new Saldo release end to end — write a curated changelog, bump the version in every file, commit, tag and push to trigger the RPM/DEB/APK builds on GitHub Actions. Use when the user asks to release, cut, publish or ship a version, e.g. "suba a versão 0.0.2", "release 0.0.2", "/release 0.0.2".
---

# Release a new version

Cut and publish version `X.Y.Z` of Saldo. The version is single-sourced from `CMakeLists.txt`;
`tools/bump-version.sh` syncs it everywhere and writes the changelogs; pushing the tag `vX.Y.Z`
triggers the RPM + DEB + APK builds in `.github/workflows/release.yml`.

## Before anything

- Get the target version `X.Y.Z` from the request (semver `major.minor.patch`). If the user said
  "next patch/minor/major" instead, compute it from the current `project(saldo VERSION ...)` in
  `CMakeLists.txt`.
- Run `git status` / `git branch --show-current`. You must be on `main` with a clean working tree.
  If it is dirty or on another branch, **stop and ask** — do not bundle unrelated changes into a
  release.
- Confirm there are commits to release: `git log "$(git describe --tags --abbrev=0)"..HEAD`
  (for the very first release there is no tag yet: use the whole history). If empty, tell the
  user there is nothing new to release and stop.
- Build and run the tests once:
  `cmake -B build -G Ninja -DBUILD_TESTING=ON && cmake --build build && QT_QPA_PLATFORM=offscreen ctest --test-dir build --output-on-failure`.
  Do not release on red tests.
- Check the distribution packages: `tools/build-packages.sh fedora:42 fedora:43 fedora:44 debian:13
  ubuntu:26.04`, then `tools/test-package.sh <image> dist` for each supported release (Fedora
  42–45, Debian 13 and testing, Ubuntu 26.04 and 26.10). The release workflow runs the same test
  and refuses to publish on a failure; locally it catches it before the tag (a tag is never
  reused). Fix any QML warning it prints.
- **New series (X.Y.0) only:** a short manual check in a virtual machine (GNOME Boxes or
  virt-manager) with the KDE images of Fedora, Debian and Kubuntu, what no container covers:
  install the package, open the demo, switch the theme, add the widget to the panel, save fake
  credentials in the keyring. Ask the user to do it (or to skip it) and wait for the answer.
- If the release changes anything the Android app shows (QML, Android files, the core), check it
  on the phone first: `tools/phone-test.sh install`, `smoke` and `matrix` (CLAUDE.md, "Phone
  tests"). Ask the user to connect the phone and sign the APK if `adb devices` shows nothing.

## Steps

1. **Curate the changelog (always).** The release changelog is a short, **user-facing** summary —
   never the raw commit list. Read the commits since the last tag
   (`git log --no-merges --pretty='%s' "$(git describe --tags --abbrev=0)"..HEAD`), condense them
   into a few plain-language lines (drop pure docs/chore/ci noise, group related work, reword for a
   user), and write one line per entry to a notes file (e.g. in a scratch dir).
2. **Bump + sync:** run `tools/bump-version.sh X.Y.Z <notes-file>`. It updates `CMakeLists.txt`,
   the RPM spec (+ `%changelog`), the AppStream metainfo (+ `<release>`), `debian/changelog` and
   the `.po` header, using the curated lines so all three changelogs stay identical. (The APK
   version comes from CMake through ECM; nothing to bump for Android.)
3. **Review:** show the user the result (`git diff -- debian/changelog` is the most readable) and
   get a go-ahead to publish.
4. **Commit:** `git commit -am "chore: release X.Y.Z"` (only the tracked files the script edited;
   `git add -A` would sweep untracked leftovers into the release commit).
   Never add Claude attribution (no `Co-Authored-By`, no "Generated with…").
5. **Tag + push:** `git tag vX.Y.Z` then `git push origin main vX.Y.Z`.
   Pushing is over SSH with the personal account (`hernique33comiitei`) — never the work account.
   This publishes the release, so only do it after the user confirmed in step 3.
6. **Report:** the tag push started the `Release` workflow (build per distribution → test on
   every supported release → publish). Watch it
   (`gh run watch "$(gh run list -R hernique33comiitei/saldo --limit 1 --json databaseId --jq '.[0].databaseId')"`)
   and confirm every **Build RPM**, **Build DEB**, **Test on …** and **Build APK** job passes and
   the `.rpm`s (one per Fedora), `.deb`s (Debian and Ubuntu) and the `.apk` are attached to the
   GitHub Release. If the APK is named `*-debug-key.apk`, the signing secrets
   are missing: tell the user (see `tools/create-android-keystore.sh`). If a job fails, read its log,
   fix it in a new commit and cut the next patch version (tags are never moved or reused).

7. **Supported platforms (each new series, X.Y.0; or whenever a build image changed):** once the
   release is published, run `tools/check-platforms.sh X.Y.Z`. It downloads the release's packages,
   installs the `.rpm` and the `.deb` in clean containers of every distribution the README lists
   ("Onde roda") and runs `saldo --version` there, and reads the APK's minimum Android version.
   Add a column `Saldo X.Y.x` to each README table (keep the older series' columns: they tell
   users on an older distribution which series still runs there), with what the script printed,
   commit it as `docs: list where X.Y.x runs` and push. A distribution the previous series ran on
   that now fails is a bug: read the log the script printed, fix it and cut the next patch
   version. Patch releases (X.Y.Z with Z > 0) skip this step unless a build image changed.

## Notes

- **The changelog is always curated** (user-facing, not raw commits) — this is a standing decision.
- A tag name is never reused or moved (no `-f`); each release, including a fix of a failed one, is
  a new number.
- `tools/bump-version.sh` with no argument re-syncs every file to the current CMake version (a safe
  no-op when already consistent) — useful if the packaging files ever drift.
- The widget's `metadata.json` version comes from CMake automatically; nothing to bump there.
