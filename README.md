# TZForth

A SwiftUI-based host and development environment for based on Leif Bruder's Pblic Domain lbForth system.

**GitHub:** https://github.com/Win32Forth/TZForth (previously named FPCForth in the repo)

## About

This project aims to bring the powerful, traditional Forth kernel sources into a modern SwiftUI application on Apple platforms for the M1, M2, M3, M4, M5, etc. processor families.

## Current State

- Basic SwiftUI macOS/iOS app structure (`TZForthApp.swift` + `ContentView.swift`)
- The core is a modern Swift re-implementation of Leif Bruder's lbForth token-threaded model (TZForth.swift; file/class externally renamed from LBForth.swift to reflect TZForth)
- Full support for structured programming (IF/ELSE/THEN, BEGIN loops, DO/LOOP, CREATE DOES>), FLOAD, EDIT (opens in system TextEditor + updates cwd), CHDIR/DIR, file echo, comments (\ single-line to EOL, \\ block to next { for compatibility), \S stop load, etc.
- OldSources/ contains historical FPC/Win32Forth/GrokForth/TCOM25 Forth sources for reference and loading experiments.

## Structure

- `TZForth.xcodeproj/` — Xcode project
- `TZForth/` — SwiftUI sources + TZForth engine (the main implementation; internally based on Leif Bruder's lbForth)

## Status

The REPL console is fully working (see TZForth/ConsoleView.swift + TZForth.swift). You can:

- Type normal Forth including multi-line definitions and immediates.
- `FLOAD` (bare: opens NSOpenPanel; named: `fload Forthing.fth` or `fload forthing` with auto-.fth and case correction).
- `EDIT` (bare or named; hands off to TextEdit or your default .fth editor with write perms).
- `CHDIR` / `DIR` (logical cwd tracked for relative loads; reports persist across sandbox limits).
- `FILE-ECHO`, `DEBUG-ON/OFF`, `\S`, `."`, `WORD`, `COUNT`, `STATE` (addr), `BASE` (affects parse+print), `RESET` (full kernel dict restore), etc.
- Classic load semantics (shared by `FLOAD`, `INCLUDE`, `INCLUDE-FILE`): `FILE-ECHO ON` at top of a file takes effect for that load; `\S` aborts remainder of *that* file only; compile errors mid-load abort the rest of the file and leave REPL clean/interpreting; no per-line OK spam during loads.
- **Exception handling:** kernel faults are **CATCH-able** (standard ANS throw codes). **`.ERROR`** prints a spaced message for a code on the stack. Named **`fload`** completes synchronously so you can write `: safe-fload  ['] fload catch ?dup if  ." load failed:" .error  else  drop  then ;` — see **`THROW_CODES.md`** for the full code map.

Automated tests (`FTEST=1`; see `TestTZForth.swift` header) cover load/comment harnesses plus **290** ANS spot-checks (Core, Core Ext, File-Access, String, **Facility** structures + `PAGE`/`AT-XY`, Exception, Memory, Double, Locals, Programming-Tools, etc.). In-app: `ANS-VALIDATE` (same suite; overwrites `TZForth/ANS-VALIDATE.txt`, a tracked baseline in the Xcode project — regenerate anytime). Hayes **forth2012-test-suite** (Block omitted): **0 errors** incl. Facility — see `Tests/forth2012-test-suite/src/HAYES-RESULTS.txt`.

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

Public Domain Statement

This software is released into the public domain.
 
TZForth is free and unencumbered software dedicated to the public domain.
 
The engine (class TZForth, file TZForth.swift) and related test harness
are externally named to reflect the TZForth project and its author.
Internally, this implementation respects its origins as a Swift port of
the public-domain lbForth model and techniques by Leif Bruder (2014).

Also, I want to credit the Grok Build AI for doing most of the work.
while I ( Tom Zimmer Win32Forth@mac.com ) did pay for the use of Grok Build,
I could never have ompleted this project without the invaluble assisstance
of Grok Build. Now, at an age of almost 76, my memory and skills are not what
they once were, back in the 80s and 90s, when I was producing so many of the
Forth systems I am credited with creating. Those were good years, but they
are behind me. Having the opportunity to participate in producing another
complex Forth system in my retirement years has been very encouraging to me,
and can be credited with helping me retain or recover some of the
intelligence and skills I once had.

Thank you Grok Build, this is definitely a great adventure!

See: https://gist.github.com/lbruder/10007431

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

This is an experimental modern re-hosting effort.

---

Built with SwiftUI • Experiment in progress (May 2026)
