# TZForth

A SwiftUI-based host and development environment for classic FPC / Win32Forth Forth systems.

## About

This project aims to bring the powerful, traditional Forth kernel sources (the `.SEQ` block files from the FPC/Win32Forth lineage) into a modern SwiftUI application on Apple platforms.

## Current State

- Basic SwiftUI macOS/iOS app structure (`TZForthApp.swift` + `ContentView.swift`)
- The core is a modern Swift re-implementation of Leif Bruder's lbForth token-threaded model (LBForth.swift)
- Full support for structured programming (IF/ELSE/THEN, BEGIN loops, DO/LOOP, CREATE DOES>), FLOAD, EDIT (opens in system TextEditor + updates cwd), CHDIR/DIR, file echo, block comments \\ ... {, \S stop, etc.
- OldSources/ contains historical FPC/Win32Forth .FTH sources for reference and loading experiments.

## Structure

- `TZForth.xcodeproj/` — Xcode project
- `TZForth/` — SwiftUI sources + LBForth engine (the main implementation)

## Next Steps (planned)

- Implement a Forth text interpreter / console inside the app
- Load and execute the full kernel chain
- Provide editing and debugging tools for SEQ sources
- Cross-platform support where practical

## License / Attribution

The Forth kernel sources originate from the FPC (Forth for Personal Computers) / Win32Forth project by Tom Zimmer and contributors. This is an experimental modern re-hosting effort.

---

Built with SwiftUI • Experiment in progress (May 2026)
