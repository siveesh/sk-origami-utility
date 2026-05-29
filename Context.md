# SK Origami Context

## 2026-05-29

- Created `architecture.md` before implementation with the project structure, scene model, archive service design, format capability model, password storage plan, and verification flow.
- Initialized a Git repository in the project folder.
- Scaffolded a SwiftPM macOS SwiftUI app named `SK Origami`.
- Added a system-adaptive desktop UI with a native split view, toolbar commands, drag-and-drop archive opening, archive list, searchable entry browser, creation sheet, extraction sheet, settings, and password vault.
- Added process-backed archive services for listing, creating, modifying, and extracting archive formats using local tools such as `zip`, `unzip`, `zipinfo`, `tar`, `7z`/`7zz`, `unrar`/`unar`, `rar`, `gunzip`, and `tnef` when available.
- Added preferences for same-location extraction, nuisance-file filtering, moving archives to Trash after extraction, and quitting after the last window closes.
- Generated an app icon source image, added it to `Resources/Images/AppIconSource.png`, converted it into `Resources/AppIcon.icns`, and wired it into the staged macOS app bundle. `iconcomposer` was not available through `xcrun`, so the project uses standard macOS `iconutil` icon composition for now.
- Added `script/build_and_run.sh` and `.codex/environments/environment.toml` so the Codex Run action builds and launches the app.
- Added baseline Swift tests for archive format inference.
- Added `README.md` with project overview, supported workflows, build/test commands, optional archive tooling, and icon notes for GitHub upload readiness.
- Updated `architecture.md` icon section after discovering the installed Icon Composer app and its `ictool` export-only command behavior.
- Moved the local tool/file support list out of the sidebar and into a new Settings tab named File Associations.
- Clarified `.drfx` behavior in `architecture.md` and surfaced it in Settings as a ZIP-compatible format that supports create, inspect, modify, and extract workflows.
- Benchmarked the requested reference projects in `docs/ArchiveAppBenchmark.md` and adopted the helper-engine/Finder-open patterns that fit SK Origami.
- Bundled macOS ARM helper binaries for `7zz`, `unar`, `lsar`, and `tnef` under `Resources/Tools/darwin-arm64`, with related license/SBOM files in `Licenses`.
- Updated tool lookup to prefer bundled helpers before system/Homebrew tools.
- Added Finder double-click archive opening through generated `CFBundleDocumentTypes` and `NSApplicationDelegate.application(_:open:)` routing.
- Updated product scope so RAR/RAR5 are extraction-only formats and removed RAR creation from capabilities, documentation, and tool availability.
- Added an Apple Silicon-only helper policy and `script/verify_bundled_tools.sh`, which rejects Intel helper binaries before the app is built.
- Removed the runtime project-folder helper fallback so installed copies resolve helpers only from the app bundle or system paths.
- Added `script/verify_app_bundle.sh` and wired it into `script/build_and_run.sh` to confirm helper binaries are copied into `SK Origami.app/Contents/Resources/Tools` without symlinks.
- Settings now displays bundled helper tools as "Bundled in app" instead of exposing absolute app-bundle paths.
- Strengthened app bundle verification to reject helper paths that resolve outside the staged `.app` and literal project-folder paths inside the bundle.
- Added a File Associations Settings button that uses LaunchServices to set SK Origami as the per-user default viewer for supported archive extensions.
- Added reusable app bundle staging and release packaging scripts for ZIP, DMG, and PKG distribution artifacts.
- Updated `README.md` with local install, package release, bundled helper, and notarization notes.
