# TZForth

An ANS 2012 Standard Forth computer language development environment based on Leif Bruder's public-domain lbForth system.

**GitHub:** https://github.com/Win32Forth/TZForth

## About

This project aims to bring the powerful, traditional Forth kernel sources into a modern SwiftUI application on Apple platforms for the M1, M2, M3, M4, M5, etc. processor families.

## Current State

- Basic SwiftUI macOS/iOS app structure (`TZForthApp.swift` + `ContentView.swift`)
- The core is a modern Swift re-implementation of Leif Bruder's lbForth token-threaded model (TZForth.swift; file/class externally renamed from LBForth.swift to reflect TZForth)
- Full support for structured programming (IF/ELSE/THEN, BEGIN loops, DO/LOOP, CREATE DOES>), FLOAD, EDIT (opens in system TextEditor + updates cwd), CHDIR/DIR, file echo, comments (\ single-line to EOL, \\ block to next { for compatibility), \S stop load, etc.

## Structure

- `TZForth.xcodeproj/` — Xcode project
- `TZForth/` — SwiftUI sources + TZForth engine (internally based on Leif Bruder's lbForth):
  - `TZForth.swift` — core kernel and interpreter
  - `TZForthBlock.swift`, `TZForthXChar.swift`, `TZForthAssembler.swift`, `TZForthFloat.swift` — optional word-set extensions
  - `TZForthTests.swift`, `TestTZForth.swift` — `ANS-VALIDATE` / FTEST harness

## Status

The REPL console is fully working (see TZForth/ConsoleView.swift + TZForth.swift). You can:

- Type normal Forth including multi-line definitions and immediates.
- `FLOAD` (bare: opens NSOpenPanel; named: `fload Forthing.fth` or `fload forthing` with auto-.fth and case correction).
- `EDIT` (bare or named; hands off to TextEdit or your default .fth editor with write perms).
- `CHDIR` / `DIR` (logical cwd tracked for relative loads; reports persist across sandbox limits).
- `FILE-ECHO`, `DEBUG-ON/OFF`, `\S`, `."`, `WORD`, `COUNT`, `STATE` (addr), `BASE` (affects parse+print), `RESET` (full kernel dict restore), etc.
- Classic load semantics (shared by `FLOAD`, `INCLUDE`, `INCLUDE-FILE`): `FILE-ECHO ON` at top of a file takes effect for that load; `\S` aborts remainder of *that* file only; compile errors mid-load abort the rest of the file and leave REPL clean/interpreting; no per-line OK spam during loads.
- **Exception handling:** kernel faults are **CATCH-able** (standard ANS throw codes). **`.ERROR`** prints a spaced message for a code on the stack. Named **`fload`** completes synchronously so you can write `: safe-fload  ['] fload catch ?dup if  ." load failed:" .error  else  drop  then ;` — see **`THROW_CODES.md`** for the full code map.

Automated tests (`FTEST=1`; see `TestTZForth.swift` header) cover load/comment harnesses plus **430** ANS spot-checks (Core, Core Ext, File-Access, String, **Facility** (structures, terminal, `EKEY*`/`MS`/`TIME&DATE`), Exception, Memory, Double, Locals, Programming-Tools (**CODE**/`;CODE`/`RET`), **Extended-Character** (UTF-8), **Float** Tier A/B/C (IEEE 64-bit separate F stack, `REPRESENT`, `FS.`/`FE.`), **Block** + TZ `.blk` extensions, etc.). In-app: **`ANS-VALIDATE`** (same core suite, **427/427**; writes `ANS-VALIDATE.txt` to logical cwd — use **`EDIT ans-validate.txt`** from any directory; tracked baseline: `TZForth/ANS-VALIDATE.txt`). After `ANS-VALIDATE` or `fload test`, the REPL restores dictionary and interpret-session state so normal commands still print **`OK`**. Hayes **forth2012-test-suite** (Block + Float `fp/` included): **0 errors** on all executed word sets — reproduce with `CHDIR Tests/forth2012-test-suite/src` then **`FLOAD test`** (driver: `Tests/forth2012-test-suite/src/test.fth`); baseline transcript: `Tests/forth2012-test-suite/src/HAYES-RESULTS.txt`. Details: **`ANS_COMPLIANCE.md`**.

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
- **Nested relative includes:** During a named `FLOAD` / `INCLUDED`, TZForth temporarily sets the logical cwd to the **loaded file’s directory** so nested bare names (e.g. `S" helper.fth" INCLUDED` next to the parent) resolve correctly. The outer cwd is restored when that load finishes. This is **not** required by ANS Forth-2012 (path resolution is implementation-defined). For app-shipped modules use **`FROMLIB FLOAD name`** (`Resources/Library/`).

In short: it is *not* hopeless. One bare `fload` + pick in the folder containing Forthing.fth (or your sources) is enough to make the default "the right place" and keep named FLOAD working thereafter (even after quitting/relaunching the app).

## AutoLoad (product boot)

AutoLoad turns TZForth from a bare development REPL into a **product host**: you ship Forth sources inside the app; on launch they are loaded and an optional **`MAIN`** word runs. The console stays open (hybrid app + REPL). Hiding the console is future work.

### Where files live

| Location | Role |
|----------|------|
| **Project** `TZForth/AutoLoad/` | Source of truth in the repo / Xcode project |
| **App bundle** `YourApp.app/Contents/Resources/AutoLoad/` | What the running app loads and what users can browse after install |

At **build** time, the **Copy AutoLoad** Run Script phase copies **everything** in `TZForth/AutoLoad/` into `Contents/Resources/AutoLoad/` (whole folder; not a hand-maintained file list). The `AutoLoad` folder is excluded from Xcode’s automatic Resources membership so files are **not** also flattened into `Contents/Resources/`.

### Boot contract

1. After the console is ready, TZForth looks for:
   ```text
   Contents/Resources/AutoLoad/autoload.fth
   ```
   The boot file name must be **`autoload.fth`** (lowercase). Other names in that folder are **not** auto-loaded.
2. **If the file is missing** → do nothing (silent). Normal development REPL.
3. **If present** → load and interpret it (no host “AutoLoad: …” banners).
   - During load, logical cwd is the **AutoLoad** directory, so nested  
     `S" helper.fth" INCLUDED` resolves next to `autoload.fth`.
   - Interpret-time output (e.g. `.( Hello) CR`) appears in the console as usual.
4. **If `MAIN` is defined** after that load → execute **`MAIN`** once (no host banner).
5. **If `MAIN` is absent** → silent; the file has already been interpreted.
6. Console remains open for further commands.

Suggested structure (see also `AutoLoad-Sample.fth`):

```forth
DECIMAL
\ S" my-lib.fth" INCLUDED   \ optional companions in the same folder

: APP-RUN  ( -- )
  CLS
  .( My product starts here.) CR
  ;

: MAIN  ( -- )
  ['] APP-RUN CATCH
  ?DUP IF  .ERROR CR  THEN
  ;
```

Prefer **`CATCH`** around the real app body so faults return cleanly to the REPL.

### Tools menu

```text
Tools
  CLS
  EDIT              bare EDIT (file picker → TextEdit)
  FLOAD             bare FLOAD (file picker → load)
  CHDIR             folder picker
  AUTOLOAD ▸
    VIEW AutoLoad Folder   → Finder on Contents/Resources/AutoLoad/
  ────────
  RESET
```

**VIEW AutoLoad Folder** is the supported way to inspect or customize the **bundle** AutoLoad tree after install (especially for zip distribution). Open files from Finder to edit/save. There is **no** separate “EDIT autoload.fth” menu item.

### Development vs Release

| Workflow | What happens |
|----------|----------------|
| **Xcode Run (Debug)** | Copy AutoLoad runs each build; edit `TZForth/AutoLoad/` in the project, Run, and the app gets a fresh copy under DerivedData’s `.app`. |
| **Archive / zip** | Same copy phase; ship the `.app` with your AutoLoad content baked in. |
| **User customizes a zip’d app** | **VIEW AutoLoad Folder**, then edit files in `…/Resources/AutoLoad/`. Restart the app to re-run boot. Gatekeeper / signature notes apply if the package was signed (see below). |

`CLS` clears the **entire** console window (including the TZForth title banner), which is useful at the start of `MAIN` / `APP-RUN`.

### Packaging a different product

1. Put `autoload.fth` and helpers in **`TZForth/AutoLoad/`**.
2. Optionally rename/adapt **`AutoLoad-Sample.fth`**.
3. Set app name / icon / bundle ID as needed.
4. **Product → Archive** (or Release build) and distribute the `.app` (zip or App Store).

The AutoLoad sources are **your** product logic; the TZForth engine is the host.

### Distribution notes (zip vs App Store)

- **Pre-Archive AutoLoad content** is normal and fully supported (part of the signed app).
- **Editing files inside a shipped `.app`** after install is fine for personal/zip use (VIEW AutoLoad Folder). It can invalidate a **code signature**; App Store apps should treat Resources as read-only product content. For end-user writable data that survives updates, a future option is Application Support (not used by AutoLoad today).
- Someone shipping “their own app” should rebuild/archive with **their** AutoLoad and **their** signing identity—not re-upload a modified install of TZForth.

### Project files in `TZForth/AutoLoad/`

| File | Role |
|------|------|
| **`autoload.fth`** | Boot file loaded at startup (if present) |
| **`AutoLoad-Sample.fth`** | Documented example with `MAIN` + `CATCH`; not loaded unless used as `autoload.fth` |
| **`README.txt`** | Short in-folder notes |

## Library and FROMLIB (1.1.0+)

Reusable Forth modules ship under:

```text
YourApp.app/Contents/Resources/Library/
```

(from project **`TZForth/Library/`** via the **Copy Library** build phase).

### FROMLIB / FROM-LIBRARY

| Word | Role |
|------|------|
| **`FROMLIB`** | Set **`FROM-LIBRARY`** (one-shot arm for the next file load) |
| **`FROM-LIBRARY`** | Variable; `ON` / `OFF` or set by `FROMLIB` |
| **`VIEW-LIBRARY`** | Open `Resources/Library` in Finder |

When a file word starts (**`FLOAD` / `INCLUDE` / `INCLUDED` / `REQUIRE` / `REQUIRED` / `EDIT` / `DIR`**):

1. If **`FROM-LIBRARY`** is set, it is **cleared immediately**.
2. For a **relative** path (or bare **`DIR`**), cwd is switched to **`Resources/Library/`** for that operation (saved/restored on a stack — nesting-safe).
3. Leaf names **without an extension** get **`.fth`** early for load/edit (so `big-int` and `big-int.fth` match). Not applied to `DIR` wildcards.
4. Absolute / `~` paths ignore Library; bare **`FLOAD`** / **`EDIT`** (dialog) clear the flag without using Library.
5. **REQUIRED** identity uses the **resolved absolute path** after the above.
6. **`EDIT`** opens the resolved file in TextEdit; **`DIR`** lists Library (or a subpath/filter under it).

**In a source file**, multi-line is allowed:

```forth
FROMLIB
FLOAD big-int.fth
```

**In the console**, put them on one line:

```forth
FROMLIB FLOAD big-int.fth
FROMLIB EDIT pi-test.fth
FROMLIB DIR
FROMLIB DIR *.fth
```

If `FROMLIB` is left armed at the end of a console line, it is cleared with a short reminder message. At end of a **file**, an unused arm is cleared quietly.

**Tools → LIBRARY → VIEW Library Folder** (same as **`VIEW-LIBRARY`**).

AutoLoad stays separate: boot may use `FROMLIB FLOAD …` inside `autoload.fth`.

## BIG-INTEGER (multiprecision, not ANS)

TZForth includes an optional **`BIG-INTEGER`** vocabulary for base-10⁹ multiprecision integers (teaching / demos; **not** an ANS word set). Sources ship in **`TZForth/Library/`** → **`Resources/Library/`** (not a separate top-level `lib/`).

| Piece | Role |
|--------|------|
| Vocabulary **`BIG-INTEGER`** | Kernel vocab; host **`BI-MUL`**, **`BI-DIVMOD`**, **`BI-ISQRT`** |
| **`Library/big-int.fth`** | Full library (alloc, add/sub, `BI*`, print, …) |
| **`Library/pi-chudnovsky.fth`** | Chudnovsky π |
| **`Library/pi-test.fth`** | Demo π to 20/50/100 (recorded results in file) |
| **`Library/bi-test.fth`** | Unit tests for big-int (+ π smoke) |
| **`STEP-LIMIT`** | Inner-interpreter step budget; demos set `0` for large π |

```forth
FROMLIB FLOAD big-int.fth
ALSO BIG-INTEGER
FROMLIB FLOAD pi-test.fth     \ demo
FROMLIB FLOAD bi-test.fth     \ unit tests
```

Layout and word list: header of **`TZForth/Library/big-int.fth`**.

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
I could never have completed this project without the invaluble assistance
of Grok Build. Now, at an age 76, my memory and skills are not what
they once were back in the 80s and 90s, when I was producing so many of the
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

Built with SwiftUI • Experiment in progress (July 2026)
