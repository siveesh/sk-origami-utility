# SK Origami

SK Origami is a macOS SwiftUI utility for opening, inspecting, creating, modifying, and extracting common archive formats. It can also create DMG and ISO disk images from folders.

## Features

- Choose a toolbar mode to control drag-and-drop behavior.
- Drop archive files to open or extract them.
- Drop files or folders to prefill a new archive.
- Drop folders to stage DMG or ISO disk image creation.
- Default folders containing `.exe` or `.msi` files to ISO; default other folders to DMG.
- View archive contents without extracting.
- Search archive entries.
- Extract an entire archive or selected entries.
- Create ZIP, JAR, DRFX, TAR, tar.gz, tar.xz, tar.bz2, and 7z archives.
- Split new ZIP and 7-Zip archives into user-sized multipart volumes.
- Modify ZIP-style archives by adding files.
- Extract ZIP, JAR, APK, DRFX, TAR variants, Gzip, 7z, RAR/RAR5, and TNEF/winmail.dat when compatible local tools are installed.
- Extract common multipart archive families such as `.7z.001`, `.zip`/`.z01`, `.part1.rar`, and `.r00`.
- Uses bundled helper tools first, so 7z/RAR/TNEF extraction works without requiring the user to install Homebrew tools separately on supported macOS ARM builds.
- Extracts associated archive files from Finder double-clicks using the saved extraction settings and shows extraction progress instead of archive contents.
- Prompts for a password during Finder extraction only when the archive is encrypted.
- Accepts folders through Finder Open With, Dock drops, and the **Create Disk Image with SK Origami** Finder Service.
- Store archive passwords for later reference.
- Filter `.DS_Store` and `__MACOSX`.
- Move archives to Trash after successful extraction, including all detected parts of multipart archives.
- Move source folders to Trash after successful disk image creation when enabled.
- Use system appearance automatically.

## Drag and Drop Modes

The main toolbar controls what SK Origami does with dropped items:

- **Open**: open dropped archive files.
- **Create**: add dropped files or folders to a new archive.
- **Image**: stage dropped folders for DMG or ISO creation.
- **Extract**: open a dropped archive and show extraction options.

Each toolbar icon has a hover tooltip. The password-key icon opens saved archive passwords and does not change drop behavior.

## Requirements

- macOS 14 or later.
- Swift 5.9 or later.
- RAR/RAR5 extraction is handled by bundled `7zz`/`unar` helpers. RAR creation is intentionally not included.
- DMG/ISO creation uses macOS `/usr/bin/hdiutil`.

## Build and Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM app, stages `dist/SK Origami.app`, copies the app icon, and launches the app as a foreground macOS application.

## Install Locally

```bash
rm -rf "/Applications/SK Origami.app"
cp -R "dist/SK Origami.app" /Applications/
```

After installation, open `SK Origami > Settings > File Associations` and use **Set Default** if you want Finder double-clicks for supported archives to open in SK Origami.

## Package Release

```bash
./script/package_release.sh 0.3.0
```

Release artifacts are written to `dist/releases`:

- `SK-Origami-0.3.0-macOS-arm64.zip`
- `SK-Origami-0.3.0-macOS-arm64.dmg`
- `SK-Origami-0.3.0-macOS-arm64.pkg`
- `SHA256SUMS.txt`

The release workflow creates a SwiftPM release build, stages `SK Origami.app`, copies bundled helper tools into the app bundle, verifies no helper links back to the project folder, applies ad-hoc signing, and creates ZIP, DMG, and PKG artifacts. Notarization is not included because it requires Apple Developer signing and notary credentials.

## Tests

```bash
swift test
```

## Icon

The generated app icon source is stored at `Resources/Images/AppIconSource.png`, and the macOS bundle icon is stored at `Resources/AppIcon.icns`.

Apple Icon Composer is installed on this machine, but its bundled `ictool` exports from existing `.icon` documents rather than creating them from a PNG in a noninteractive flow. The current checked-in app icon was composed from the generated source image using the standard macOS iconset plus `iconutil` path.

## Bundled Tools

Bundled archive helpers live in `Resources/Tools/darwin-arm64`. License and SBOM files live in `Licenses` and are copied into the app bundle by `script/build_and_run.sh`.

Bundled helpers are Apple Silicon only. `script/verify_bundled_tools.sh` rejects Intel-only helper binaries before the app is built, and `script/verify_app_bundle.sh` confirms the staged `.app` contains copied helpers instead of links back to the project folder.
