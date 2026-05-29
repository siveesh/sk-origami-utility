# SK Origami Architecture

## Product Direction

SK Origami is a macOS SwiftUI archive utility focused on fast drag-and-drop archive workflows, simple format conversion, archive inspection without extraction, selective extraction, archive creation, and easy preferences for common cleanup behavior.

The app supports system appearances by using semantic SwiftUI styles, native materials, and macOS settings storage. The UI is designed as a normal Dock app with a primary archive workspace window and a separate Settings scene.

## Project Shape

- `Package.swift` is the build entrypoint.
- `Sources/SKOrigami/App` contains the SwiftUI app entrypoint and app delegate.
- `Sources/SKOrigami/Views` contains the root window, archive browser, creation sheet, extraction sheet, password vault, and settings UI.
- `Sources/SKOrigami/Models` contains value models for archives, formats, entries, jobs, and preferences.
- `Sources/SKOrigami/Stores` contains observable app state and lightweight persisted preferences.
- `Sources/SKOrigami/Services` contains process-backed archive operations, password persistence, drag-and-drop intake, and system integration.
- `Sources/SKOrigami/Support` contains reusable helpers and extensions.
- `Resources` contains app assets such as the generated app icon.
- `script/build_and_run.sh` is the local build/run entrypoint.
- `.codex/environments/environment.toml` wires the Codex app Run action to the local script.

## Scene Model

The app uses:

- `WindowGroup` for the main workspace.
- `Settings` for preferences such as default extraction location, filtering unwanted files, moving archives to Trash after extraction, and quitting after the last window closes.
- A tabbed Settings layout separates general behavior from file-format support and local tool availability.
- App-level state in `ArchiveWorkspaceStore`.
- Durable user preferences through `@AppStorage`.

## Archive Engine

Archive work is coordinated by `ArchiveService`, which delegates to installed command-line tools where available:

- ZIP/JAR/APK/DRFX inspection and extraction use `/usr/bin/zipinfo`, `/usr/bin/unzip`, and `/usr/bin/ditto` where available.
- TAR, tar.gz, tar.xz, and tar.bz2 use `/usr/bin/tar`.
- Gzip single-file extraction uses `/usr/bin/gunzip` or equivalent process operations.
- 7z/RAR/RAR5 extraction support is exposed through bundled `7zz` and `unar` helpers.
- TNEF/winmail.dat support is exposed when a `tnef` compatible extractor is installed.

SK Origami prefers bundled helper tools from the installed app bundle at `SK Origami.app/Contents/Resources/Tools/<platform>` before falling back to system tools. Runtime code must not resolve helper tools from the project folder, otherwise an installed copy would be stranded after leaving the development workspace. The service layer keeps the command invocation contract isolated so bundled binaries or future native libraries can be swapped without changing the UI.

Bundled helper tools are Apple Silicon only. The project does not ship Intel-only helper binaries because future macOS releases are expected to move away from Intel support. Build verification rejects non-arm64 helpers in `Resources/Tools/darwin-arm64`, and bundle verification confirms those helpers are copied into the staged `.app`.

Bundled helper adoption must account for redistribution terms:

- 7-Zip/p7zip-style helpers are suitable for broad multi-format extraction and creation when their licenses are preserved.
- RAR and RAR5 are extraction-only formats in SK Origami.
- TNEF extraction can be bundled only if the selected implementation's license is compatible with the app distribution plan.

## Format Capabilities

Each archive format declares separate capabilities for:

- creation
- extraction
- listing
- modification
- encryption
- multi-volume output

The UI surfaces unavailable capabilities instead of pretending every format can be created. RAR and RAR5 are intentionally extraction-only and are handled through bundled `7zz`/`unar` helpers.

DRFX files are treated as ZIP-compatible archives with a `.drfx` extension. The app can inspect, extract, create, and add files to DRFX packages through the ZIP-style archive path.

## Password Handling

`PasswordVault` stores archive-password references locally using `UserDefaults` in the first version. The service interface is isolated so this can move to Keychain without affecting callers. Passwords are associated with archive display names, file paths, format, and creation dates.

## File Safety

- Extraction defaults to the same folder as the archive unless the user chooses a custom destination.
- The extraction pipeline can filter nuisance files such as `.DS_Store` and `__MACOSX`.
- Moving an archive to Trash after successful extraction is handled by `FileManager.trashItem`.
- Archive modification creates temporary working output before replacing files.
- Finder double-click support is implemented through bundle document types and `application(_:open:)`, which routes archives opened from Finder into the workspace.
- File association setup is exposed from Settings. `FileAssociationService` uses LaunchServices to ask macOS to make SK Origami the default viewer for supported archive UTIs/extensions. This is a per-user system setting and is most reliable after the app has been staged or installed as a normal `.app` bundle.

## Icon

The app icon is generated as a project asset, then converted into a macOS `.icns` file for the staged app bundle. Apple's Icon Composer is installed locally, and its bundled `ictool` can export existing `.icon` documents. Because the tool does not provide a noninteractive PNG-to-`.icon` authoring path, the current implementation keeps the generated PNG source in the repository and uses the standard macOS iconset plus `iconutil` path to produce `Resources/AppIcon.icns`.

## Verification

Build and launch are verified through `./script/build_and_run.sh`. The script builds the SwiftPM GUI app, stages `dist/SK Origami.app`, copies resources, writes bundle metadata, and opens the app as a foreground macOS application.

## Distribution

`script/package_release.sh` prepares a release app bundle from the SwiftPM release binary, copies the app icon, bundled Apple Silicon helper tools, and licenses into `SK Origami.app`, validates the bundle, applies ad-hoc signing for local distribution testing, and emits distributable ZIP, DMG, and PKG artifacts under `dist/releases`. Notarization is not performed in this local workflow because it requires an Apple Developer signing identity and notary credentials.
