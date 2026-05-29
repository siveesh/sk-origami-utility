# Archive App Benchmark

## Referenced Projects

| Project | Useful Pattern | SK Origami Adoption |
| --- | --- | --- |
| Keka | Mature macOS archiver positioning, broad format support, encryption-first workflows. | Keep the native macOS app focus and make bundled helper availability visible instead of hiding tool limits. |
| MacPacker | Nested archive browsing, selected-file extraction, Finder extension roadmap, system preview direction. | Preserve archive browsing as a first-class workflow and route Finder-opened files directly into the workspace. |
| WinRA | Lightweight ZIP/RAR workflow, conversion focus, progress-first UX, `unar` for RAR extraction. | Adopt the pragmatic `unar`/`lsar` extraction path for RAR-style archives while keeping RAR creation out of scope. |
| PeaZip | Wide format coverage through helper engines, spanned archives, conversion, encryption, password manager, task scripts. | Bundle helper tools under `Resources/Tools` and keep the service layer process-backed for future conversion and task export features. |
| Grizzly | SwiftUI ZIP viewer, Finder association, Quick Look-oriented browsing, keyboard navigation. | Add Finder double-click support through bundle document types and app-open routing; Quick Look remains a next step. |

## Bundled Helper Decision

SK Origami now bundles macOS ARM helper executables in `Resources/Tools/darwin-arm64`:

- `7zz` from Homebrew `sevenzip` 26.01 for 7z and broad archive support.
- `unar` and `lsar` from Homebrew `unar` 1.10.8_7 for RAR/RAR5 and multi-format listing/extraction.
- `tnef` from Homebrew `tnef` 1.4.18 for `winmail.dat` / TNEF extraction.

The app resolves bundled helpers before system tools. RAR and RAR5 are extraction-only in SK Origami, so no proprietary RAR creator is bundled or surfaced in the creation UI.

## License Notes

- `sevenzip`: Homebrew metadata reports `LGPL-2.1-or-later AND BSD-3-Clause`.
- `unar`: Homebrew metadata reports `LGPL-2.1-or-later`.
- `tnef`: Homebrew metadata reports `GPL-2.0-or-later`.

License and SBOM files are stored in `Licenses` and copied into the app bundle resources.
