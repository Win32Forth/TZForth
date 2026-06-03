# TZForth

A SwiftUI-based host and development environment for classic FPC / Win32Forth Forth systems.

## About

This project aims to bring the powerful, traditional Forth kernel sources (the `.SEQ` block files from the FPC/Win32Forth lineage) into a modern SwiftUI application on Apple platforms.

## Current State

- Basic SwiftUI macOS/iOS app structure (`TZForthApp.swift` + `ContentView.swift`)
- The core is a modern Swift re-implementation of Leif Bruder's lbForth token-threaded model (LBForth.swift)
- Full support for structured programming (IF/ELSE/THEN, BEGIN loops, DO/LOOP, CREATE DOES>), FLOAD, EDIT (opens in system TextEditor + updates cwd), CHDIR/DIR, file echo, comments (\ single-line to EOL, \\ block to next { for compatibility), \S stop load, etc.
- OldSources/ contains historical FPC/Win32Forth .FTH sources for reference and loading experiments.

## Structure

- `TZForth.xcodeproj/` — Xcode project
- `TZForth/` — SwiftUI sources + LBForth engine (the main implementation)

## Status

The REPL console is fully working (see TZForth/ConsoleView.swift + LBForth.swift). You can:

- Type normal Forth including multi-line definitions and immediates.
- `FLOAD` (bare: opens NSOpenPanel; named: `fload Forthing.fth` or `fload forthing` with auto-.fth and case correction).
- `EDIT` (bare or named; hands off to TextEdit or your default .fth editor with write perms).
- `CHDIR` / `DIR` (logical cwd tracked for relative loads; reports persist across sandbox limits).
- `FILE-ECHO`, `DEBUG-ON/OFF`, `\S`, `."`, `WORD`, `COUNT`, `STATE` (addr), `BASE` (affects parse+print), `RESET` (full kernel dict restore), etc.
- Classic load semantics: `FILE-ECHO ON` at top of .fth takes effect for that load; `\S` aborts remainder of *that* file only; compile errors mid-load abort the rest of the file and leave REPL clean/interpreting; no per-line OK spam during loads.

Automated tests (FTEST=1) cover echo, \S, debug-in-file, .", WORD, STATE addr, load-abort-on-err, nested, etc.

## Sandbox and FLOAD (important for loading your own Forthing.fth etc.)

The app is sandboxed with "user selected files" read-write entitlement. This means:

- On first launch (or after clearing UserDefaults / no prior bookmark), the default "Current directory:" is guessed from Xcode env (PROJECT_DIR etc.) or ~/Documents/XCodeProjects/TZForth (matches common layout for this project). This makes `chdir` and bare `chdir` reports, plus named FLOAD resolve attempts, start at the "right place".
- Named `fload foo` / `fload foo.fth` (typed after launch or after `chdir`) will only succeed for data read if a security-scoped bookmark covers the directory. Bookmarks are created automatically when you use bare `fload` (or EDIT) and *pick a file inside the desired folder* via the panel. After that one-time authorization:
  - The exact picked dir is bookmarked + made the logical cwd.
  - Future launches default to it (persisted).
  - `chdir sub` (within tree) + named fload there works, and hardens a bookmark for the subdir.
  - You can then successfully do `fload Forthing.fth` (any case, with or without .fth) when the file is in the current logical directory.
- If a named FLOAD fails with "not found or unreadable", the console now prints a hint. Just type `fload` (no name) and pick any .fth (or file) from the folder containing your sources — that grants the scope for the whole tree for this and future sessions.
- `chdir` to a path before authorizing will still set the logical view and report it (so resolves use the right path), but open/list will fail until the grant; the note in output explains.
- Full paths or ~ work for FLOAD/EDIT/CHDIR when they are under a granted tree.
- EDIT after FLOAD in same dir works for write (NSWorkspace handoff uses the active scope + file bookmarks).

In short: it is *not* hopeless. One bare `fload` + pick in the folder containing Forthing.fth (or your sources) is enough to make the default "the right place" and keep named FLOAD working thereafter (even after quitting/relaunching the app).

## License / Attribution

The Forth kernel sources originate from the FPC (Forth for Personal Computers) / Win32Forth project by Tom Zimmer and contributors. This is an experimental modern re-hosting effort.

---

Built with SwiftUI • Experiment in progress (May 2026)
