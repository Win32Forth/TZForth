# FPCForth

A SwiftUI-based host and development environment for classic FPC / Win32Forth Forth systems.

## About

This project aims to bring the powerful, traditional Forth kernel sources (the `.SEQ` block files from the FPC/Win32Forth lineage) into a modern SwiftUI application on Apple platforms.

## Current State

- Basic SwiftUI macOS/iOS app structure (`FPCForthApp.swift` + `ContentView.swift`)
- Initial integration of `KERNEL1.SEQ` (core kernel definitions, assembler primitives, vocabulary setup, etc.)
- Many additional kernel modules referenced (commented FLOAD list in `ContentView.swift`): VIDEO, KERNEL2–4, POINTER, SAVEREST, HANDLES, etc.

## Structure

- `FPCForth.xcodeproj/` — Xcode project
- `FPCForth/` — SwiftUI sources + Forth kernel files (`.SEQ`)

## Next Steps (planned)

- Implement a Forth text interpreter / console inside the app
- Load and execute the full kernel chain
- Provide editing and debugging tools for SEQ sources
- Cross-platform support where practical

## License / Attribution

The Forth kernel sources originate from the FPC (Forth for Personal Computers) / Win32Forth project by Tom Zimmer and contributors. This is an experimental modern re-hosting effort.

---

Built with SwiftUI • Experiment in progress (May 2026)
