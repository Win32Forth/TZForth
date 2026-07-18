# ANS Forth 2012 Compliance Status for TZForth

This document tracks implementation status of the 2012 ANS Forth Standard word sets in TZForth (Swift port of the lbForth model). Generated from codebase inspection (`TZForth/TZForth.swift`, `TestTZForth.swift`, `TZForthTests.swift`).

Last update: Hayes forth2012-test-suite **0 errors** (Block + Float `fp/` included); Facility + Block + Extended-Character + Programming-Tools CODE + Float Tier A/B/C on TZForth host; FTEST **430/430**; in-app `ANS-VALIDATE` **427/427** (baseline `TZForth/ANS-VALIDATE.txt`).

## Summary

| Word set | Status |
|----------|--------|
| **Core (6.1)** | Complete — all required words implemented with FTEST coverage |
| **Core Ext (6.2)** | Complete — all standard Core Ext words implemented |
| **Search-Order (16)** | Complete — 16.6.1 + 16.6.2; `SEARCH-WORDLIST`, `ENVIRONMENT?` `WORDLISTS` (8) |
| **Programming-Tools** | Complete — 15.6.1/15.6.2; minimal threaded `CODE`/`;CODE` with `RET` (ASSEMBLER vocab) |
| **File-Access (11)** | Complete — 11.6.1 + 11.6.2; Hayes filetest 0 errors |
| **Exception (9)** | Complete — `CATCH`, `THROW`, `.ERROR`; kernel faults CATCH-able; `ABORT`/`ABORT"` → `-1`/`-2` |
| **String (17)** | Complete — 17.6.1 + 17.6.2 (`REPLACES`, `SUBSTITUTE`, `UNESCAPE`); Hayes stringtest 0 errors |
| **Memory-Allocation (14)** | Complete — 14.6.1 (`ALLOCATE`, `FREE`, `RESIZE`); extension `GROWMEMORYMB` |
| **Double-Number (8)** | Complete — 8.6.1 + 8.6.2 (`2ROT`, `2VALUE`, `DU<`); trailing `.` literals |
| **Locals (13)** | Complete — `(LOCAL)`, `LOCALS|`, `{:`; `TO` for locals; max 32 (`#LOCALS`) |
| **Facility (10)** | Complete (TZForth host) — structures, `PAGE`/`AT-XY`, `MS`, `TIME&DATE`, `EKEY*`, `EMIT?`, `K-*`; Hayes `facilitytest.fth` 0 errors |
| **Block (10)** | Complete — file-backed `.blk`, LRU buffer cache; Hayes `blocktest.fth` 0 errors; FTEST Block + TZ extension spot-checks |
| **Extended-Character (18)** | Complete — UTF-8 codec; shadow `CHAR`/`[CHAR]`/`PARSE`; `XEMIT`/`XKEY`/`XKEY?`/`EKEY>XCHAR`; `XHOLD`; `XC-WIDTH`/`X-WIDTH`; ENVIRONMENT? queries |
| **Float (12)** | Tier A + **Tier B (Float Ext)** + **Tier C** (`REPRESENT`, `FS.`/`FE.`/`F.`) — IEEE 64-bit, separate 16-deep F stack; literals incl. `0e`/`1E`; trig/exp/log; `F~`, `FVARIABLE`/`FVALUE`/`TO`, `F>D`/`F>S`, `SF@`/`DF@` |

FTEST harness: run with `FTEST=1 swift /tmp/combined.swift` (concatenate `TZForth.swift`, `TZForthSettings.swift`, `TZForthBlock.swift`, `TZForthXChar.swift`, `TZForthAssembler.swift`, `TZForthFloat.swift`, `TZForthTests.swift`, `TestTZForth.swift`). Current count: **430/430** TEST6 spot-checks plus block-comment / FLOAD / INCLUDE load tests (three extra CLI-only checks vs in-app). In-app **`ANS-VALIDATE`** runs the same core suite (**427/427** in the tracked baseline) and writes **`ANS-VALIDATE.txt`** to the logical cwd (regenerate anytime; **`EDIT ans-validate.txt`** resolves the file from any directory). Tracked reference copy: **`TZForth/ANS-VALIDATE.txt`** (in the Xcode project; excluded from the app bundle so regeneration stays writable). Validation restores dictionary bytes and interpret-session state (`evaluateNesting`, input-source stack, block subsystem) so the REPL still prints **`OK`** after `ANS-VALIDATE` or Hayes `fload test`. During validation, `onMsDelayRequested` is cleared so **`MS`** uses the engine `Thread.sleep` fallback (synchronous `feedLine` / `ansTest` output checks).

## Core (6.1) — Complete

All Core words required for conformance are implemented. Notable details:

- **QUIT** is a primitive (safe RSP wipe); **SOURCE** / **PARSE** / **>IN** track the per-line `SOURCE` buffer (128 @, **1024 bytes**). `REFILL` and `feedLine` truncate input lines longer than 1024 characters.
- **PAD** at 5248, **1024 bytes** — user/programmer scratch only. Per ANS rationale (6.2.2000), no standard words use `PAD`; TZForth keeps parsers out of `PAD` entirely.
- **STRING_BUFFER** at 1152, **4096 bytes** — system parse scratch (not exposed as a Forth word). Each interpret-time use of `WORD`, `CHAR`, `S"`, `C"`, `. "`, `ABORT"`, `S\"`, and `INCLUDE` (immediate path) allocates the next **512-byte slot** in a ring; when the offset reaches the end, allocation wraps to the start. Up to **8** concurrent transient strings can coexist before the oldest slot is reused. Counted strings are capped at **255** characters (`/COUNTED-STRING`). Contents are transient (invalidated by further parsing, dictionary growth, etc., per 3.3.3.6).
- **PARSE** / **PARSE-NAME** return slices of **SOURCE**, not `STRING_BUFFER` or `PAD`.
- Pictured numeric (`<#` … `#>`) uses a separate high-memory buffer, not `PAD`.
- **POSTPONE** / **[COMPILE]** use captured `executeID` + emit `LIT`/`EXECUTE` for immediate words.
- **ENVIRONMENT?** returns values for `CORE`, `CORE-EXT`, `/COUNTED-STRING` (255), `ADDRESS-UNIT-BITS`, `MAX-CHAR`, `SEARCH-ORDER`, `WORDLISTS` (8), `FILE`, `FILE-ACCESS`, `FILE-EXT`, `EXCEPTION`, `STRING`, `MEMORY-ALLOCATION`, `DOUBLE`, `LOCALS`, `#LOCALS` (32), `EXTENDED-CHARACTER`, `XCHAR-ENCODING` (`"UTF-8"`), `MAX-XCHAR` (`$10FFFF`), `XCHAR-MAXMEM` (4). **`.ENVIRONMENT`** lists all supported queries.
- Memory: **1 MB** default linear region (growable via **`GROWMEMORYMB`**); low fixed layout `SOURCE` (1024) → `STRING_BUFFER` (4096) → `PAD` (1024) → data/return stacks; **UNUSED** / **.FREE** report free dictionary bytes up to the PNO buffer anchor.

### Low-memory map (implementation-defined)

| Region | Base @ | Size | Used by |
|--------|--------|------|---------|
| `SOURCE` | 128 | 1024 | `REFILL`, `SOURCE`, `PARSE`, `PARSE-NAME` |
| `STRING_BUFFER` | 1152 | 4096 | `WORD`, `CHAR`, interpret `S"`/`C"`/`. "`/`ABORT"`, `S\"` compile parse, `INCLUDE` immediate |
| `PAD` | 5248 | 1024 | User only (`READ-LINE` buffers, scratch, etc.) |
| Data stack | ~6272 | 256 cells | — |
| Return stack | above data | 256 cells | — |

`WORD` buffer size (4.1.1): each slot is 512 bytes (minimum 33 required by 3.3.3.6). Compiled `S"` / `C"` / `. "` strings are inlined in the word body and do not use `STRING_BUFFER`.

## Core Extensions (6.2) — Complete

### Recently added (Tier 2)

| Word | Stack / notes |
|------|----------------|
| `:NONAME` | `( C: -- colon-sys ) ( -- xt )` — anonymous colon definition; `;` leaves xt on stack |
| `ACTION-OF` | `( xt1 -- xt2 )` — current deferred execution token (same as `DEFER@`) |
| `MARKER` | `( "name" -- )` — saves dict/search-order state; execution restores and removes marker + subsequent defs |
| `SAVE-INPUT` | `( -- x1 ... xn n )` — saves input source state (implementation-defined tuple on stack) |
| `RESTORE-INPUT` | `( x1 ... xn n -- flag )` — restores state; flag true if restore failed |
| `SOURCE-ID` | `( -- id )` — `-1` terminal, `0` evaluate string, `≥2` open fileid while loading |
| `S\"` | compile: parse escaped `"`-string, compile `(S")` + literal; interpret undefined per ANS |
| `REFILL` | `( -- flag )` — refill input buffer; false when no further line available (line-oriented REPL) |

### Hayes character-literal token (not an ANS word)

ANS Core provides **`CHAR`** / **`[CHAR]`** and **`'`** (tick, execution token of a name). The John Hayes **forth2012-test-suite** also uses a **non-ANS token form** `'c'` — apostrophe, one character, apostrophe — which the text interpreter treats as an ASCII cell literal (e.g. `'z'` → `122`). This is **not** a dictionary entry and **not** tick: whitespace still separates `' T10` (tick + name) from `'z'` (one token). In compile state, `'c'` compiles as `LIT` + value like other numeric literals.

### Previously added (Tier 1 and earlier)

`.R`, `C"`, `PARSE-NAME`, `UNUSED`, `.FREE`, `HOLDS`, `BUFFER:`, `<>`, `U>`, `0<>`, `VALUE`, `IS`, `TO`, `DEFER`, `DEFER!`, `DEFER@`, `CASE`/`OF`/`ENDOF`/`ENDCASE`, `COMPILE,`, `ERASE`, pictured numeric (`<#` `#` `#S` `#>` `HOLD` `SIGN`), `S"`, loops/control (`?DO` `+LOOP` `UNLOOP` `LEAVE`, `2>R` `2R@` `2R>`, `NIP` `PICK` `ROLL` `TUCK`, `U.R`, `WITHIN`, `AGAIN`, etc.).

### Search-order / vocab (Core Ext + word set 16)

`VOCABULARY`, `FORTH`, `DEFINITIONS`, `ALSO`, `ONLY`, `ORDER`, `WORDS` (optional filter). `FORTH` is default; new vocabs start empty; `VOCABULARY` prepends to search order so `FORTH` remains visible unless `ONLY` is used.

## Search-Order (16) — Complete

ANS word set 16.6.1 and extensions 16.6.2.

| Word | Stack / notes |
|------|----------------|
| `WORDLIST` | `( -- wid )` — create empty word list |
| `FORTH-WORDLIST` | `( -- wid )` — the `FORTH` list (`LATEST` head cell) |
| `GET-ORDER` | `( -- wid1 ... widn n )` |
| `SET-ORDER` | `( wid1 ... widn n -- )` — max **8** lists (`WORDLISTS`) |
| `GET-CURRENT` / `SET-CURRENT` | compilation word list |
| `SEARCH-WORDLIST` | `( c-addr u wid -- 0 \| xt 1 \| xt -1 )` — search one list |
| `FIND` | `( c-addr -- c-addr 0 \| xt 1 \| xt -1 )` — search order; **xt is the cfa** (code-field address) |
| `DEFINITIONS` | set `CURRENT` to first list in order |
| `ALSO` / `ONLY` / `PREVIOUS` / `FORTH` / `ORDER` | classic vocab stack (16.6.2) |
| `VOCABULARY` | compatibility: `CREATE WORDLIST` + `PUSH-ORDER` |

`ENVIRONMENT?` answers `SEARCH-ORDER` and `WORDLISTS` (8). FTEST covers `SEARCH-WORDLIST`, order round-trip, and vocab isolation.

## String (17) — Complete

ANS word set 17.6.1 (character-string operations). Core `MOVE`/`FILL` remain; `CMOVE`/`BLANK` follow ANS stack effects.

| Word | Stack / notes |
|------|----------------|
| `BLANK` | `( c-addr u -- )` — fill with `BL` (32) |
| `CMOVE` | `( c-addr1 c-addr2 u -- )` — copy with overlap-safe direction |
| `CMOVE>` | `( c-addr1 c-addr2 u -- )` — copy high-to-low |
| `COMPARE` | `( c-addr1 u1 c-addr2 u2 -- n )` — byte-wise `-1` / `0` / `1` |
| `/STRING` | `( c-addr u n -- c-addr' u' )` — skip or include `n` characters |
| `-TRAILING` | `( c-addr u -- c-addr' u' )` — drop trailing spaces |
| `SEARCH` | `( c-addr1 u1 c-addr2 u2 -- c-addr3 u3 flag )` — first match; empty needle matches |
| `SLITERAL` | `( c-addr u -- )` immediate — compile `(S")` + inline literal |

`ENVIRONMENT?` answers `STRING`. FTEST / `ANS-VALIDATE` cover compare, search, trailing, blank, `/STRING`, and `SLITERAL` via `[ ]`.

### String extensions (17.6.2)

| Word | Stack / notes |
|------|----------------|
| `REPLACES` | `( c-addr1 u1 c-addr2 u2 -- )` — define `%name%` → replacement text (interpret only) |
| `SUBSTITUTE` | `( c-addr1 u1 c-addr2 u2 -- c-addr2 u3 n )` — left-to-right `%name%` expansion; `n` = replacements or negative on overlap error |
| `UNESCAPE` | `( c-addr1 u1 c-addr2 -- c-addr2 u2 )` — copy to dest, doubling each `%` |

Hayes **stringtest.fth** exercises all three (including overlapping-buffer `SUBSTITUTE` cases). Substitution table is a linked list on the heap; `MARKER` / `FORGET` do not prune entries (same limitation as `INCLUDED-NAMES`).

## File-Access (11) — Complete

ANS optional word set 11.6.1 (file operations) and key 11.6.2 extensions are implemented on top of the host filesystem. Files are held in memory while open; `CLOSE-FILE` and `FLUSH-FILE` write dirty buffers back to disk.

### Access methods and I/O results

| Constant | Value | Meaning |
|----------|-------|---------|
| `R/O` | 1 | read-only |
| `W/O` | 2 | write-only |
| `R/W` | 3 | read/write |
| `BIN` | 8 | OR with base fam (binary; line translation suppressed for `READ-LINE`/`WRITE-LINE`) |
| I/O success | 0 | `ior` on success |
| I/O error | 1 | `ior` on failure |

### Implemented words

`OPEN-FILE`, `CLOSE-FILE`, `CREATE-FILE`, `DELETE-FILE`, `RENAME-FILE`, `READ-FILE`, `WRITE-FILE`, `READ-LINE`, `WRITE-LINE`, `FILE-POSITION`, `FILE-SIZE`, `REPOSITION-FILE`, `RESIZE-FILE`, `FILE-STATUS`, `FLUSH-FILE`, `INCLUDE-FILE`, `INCLUDED`, `INCLUDE` (immediate), `REQUIRE`, `REQUIRED`, `INCLUDED-NAMES` (variable).

### Integration with input and loading

- **`REFILL`** — when interpreting from an open file (`interpreterInputFileId` ≥ 2), refills `SOURCE` from that file; returns false at EOF.
- **`(`** — multi-line parenthesized comments span file lines (refills when `)` not found on current line).
- **Shared load loop** — `INCLUDE-FILE`, `INCLUDED`, `INCLUDE`, and host **`FLOAD`** all use the same line-at-a-time interpret path (`includeFileInterpret`): `FILE-ECHO`, `\S`, mid-file abort, no per-line `OK`, `DEBUG-ON`/`OFF` per line, and `SOURCE-ID` = the open **fileid** (≥ 10 for newly opened files).
- **`FLOAD`** — resolves path (`.fth` auto-append, cwd, host sandbox via `onPerformNamedLoad`), opens text with UTF-8/Latin-1 tolerance, then runs the shared include loop; registers spec in `INCLUDED-NAMES` on success.
- **Nested relative path resolution (TZForth, not ANS-mandated)** — ANS File-Access does not require changing directory on include; how relative names resolve is implementation-defined. TZForth’s host load path temporarily sets the logical cwd to the **loaded file’s folder** for the duration of that load (then restores the prior cwd) so nested `INCLUDED` / `FLOAD` of sibling bare names work as expected (e.g. Hayes `test.fth` → `fp/runfptests.fth`, or Library modules via **`FROMLIB FLOAD`**). Nested specs should be relative to the **including file’s directory**, not necessarily the user’s original project root.
- **`RESTORE-INPUT` during load** — nested `SAVE-INPUT` / `RESTORE-INPUT` inside a colon on an `FLOAD` line can repoint `SOURCE` mid-line; the interpreter continues through the remainder of that line and subsequent file lines (Hayes filetest `SI2`).
- **`ENVIRONMENT?`** — returns true for `FILE`, `FILE-ACCESS`, `FILE-EXT`.

### REQUIRE / REQUIRED / INCLUDED-NAMES

- **`INCLUDED-NAMES`** — kernel `VARIABLE` holding the head of a linked list of loaded spec strings (`next | str-addr | str-u` nodes on the heap). Inspectable via `@`.
- **`REQUIRED`** — if spec `( c-addr u )` is absent from the list, `nameJoin` + load (same as sample `included`); if present, discard spec without loading.
- **`REQUIRE`** — `PARSE-NAME` then `REQUIRED`.
- **`INCLUDE` / `INCLUDED`** — always load; register spec via `nameJoin` before interpret (extended, not shadowed).
- **Host `FLOAD`** — same registry and interpret loop as `INCLUDED`; differs only in name resolution and host dialog/sandbox hooks.

Registry key is the **exact spec bytes** passed in, not a canonical path. **`MARKER` / `FORGET`** do not prune `INCLUDED-NAMES` (matches ANS reference sample limitation on systems with `MARKER`).

Host extension **`FILE-ECHO`** applies to all loaded sources (`FLOAD`, `INCLUDE`, `INCLUDE-FILE`, …).

## Exception (9) — Complete

ANS word set 9.6.1 and extensions 9.6.2 (`ABORT`/`ABORT"` as `THROW` aliases).

| Word | Stack / notes |
|------|----------------|
| `CATCH` | `( xt -- n | i*x n )` — saves data/return stack depths, `STATE`, loop-control stack, and input-source nesting; executes `xt`; pushes `0` on normal completion or the throw code |
| `THROW` | `( n -- )` — `0` is a no-op; non-zero unwinds to the nearest `CATCH`, restoring saved depths and input nesting per 9.3.5 |
| `ABORT` | `( -- )` — `THROW -1` (catchable; uncaught → print `Aborted!`, reset, REPL continues) |
| `ABORT"` | `( flag "ccc" -- )` — if flag, `THROW -2` (catchable; uncaught → type `ccc` then reset) |
| `.ERROR` | `( n -- )` — TZForth: type spaced standard message for CATCH/THROW code `n` (`0` = silent) |
| `CATCH-EVALUATE` | `( c-addr u -- n )` — TZForth: `EVALUATE` under `CATCH` (interpret-friendly) |

Unhandled `THROW` with no active `CATCH`: `-1` → print `Aborted!`, reset stacks/input, REPL ready for next line; `-2` → type stored `ABORT"` text then reset; other codes → `? …` from `lastKernelThrowMessage` then reset. Caught throws push **only the numeric code** (no message on stack).

FTEST / `ANS-VALIDATE` cover `ABORT`/`ABORT"` with and without `CATCH`, standard kernel codes, compile `STATE` preservation, file faults, nested `CATCH`, `['] fload catch` (safe-fload), mid-file `INCLUDE-FILE`, user **-40**, and `.ERROR` for file codes. Colon definitions that compile `CATCH` then `>R` (Hayes `exceptiontest` `C6`) resume correctly after `EXIT` and nested `deliverThrow`.

John Hayes **forth2012-test-suite** (Block + Float `fp/` included): **0 errors** on all executed word sets (Block SAVE-INPUT/RESTORE/REFILL, EMPTY-BUFFERS, pictured-string `TCSIRIR2`/`TCSIRIR4`, REFILL spill, FP paranoia **END OF TEST** all pass). **Canonical run:** TZForth app → `CHDIR Tests/forth2012-test-suite/src` → **`FLOAD test`** (`test.fth` driver). CLI `HAYES=1 swift /tmp/combined.swift` runs a smaller non-FP subset only. Results: **`HAYES-RESULTS.txt`**.

## Block (10) — Implemented (file-backed `.blk`)

Pre-allocated growable **`.blk`** files, per-file block numbering, LRU buffer cache in high memory below PNO, auto-default `blocks.blk` in logical cwd. Application settings: **`TZForthSettings`** (`~/Library/Application Support/TZForth/settings.json`); kernel variables `BLOCK-SIZE`, `DEFAULT-BLOCK-COUNT`, `BLOCK-BUFFER-COUNT`; words `.SETTINGS`, `SAVE-SETTINGS`.

| Category | Words |
|----------|-------|
| ANS Block | `BLOCK`, `BUFFER`, `UPDATE`, `FLUSH`, `EMPTY-BUFFERS`, `SAVE-BUFFERS`, `BLK`, `LOAD`, `LIST`, `SCR`, `THRU`, `\` (line comment) |
| TZForth extensions | `CREATE-BLOCK-FILE`, `OPEN-BLOCK-FILE`, `CLOSE-BLOCK-FILE`, `GROW-BLOCK-FILE`, `USE-BLOCK-FILE`, `BLOCK-FILE`, `.BLOCK-FILES` |
| ENVIRONMENT? | `BLOCK`, `/BLOCK`, `BLOCK-EXT` |

Default: `BLOCK-SIZE` = 1024, `BLOCK-BUFFER-COUNT` = 4, buffers at `blockPoolBase` (below PNO). `BYE`/app quit calls `shutdownBlockSubsystem()` (flush all dirty buffers, close open block files). FTEST / `ANS-VALIDATE` cover ANS Block words plus TZ extensions (`CREATE/OPEN/USE/CLOSE/GROW-BLOCK-FILE`, `.BLOCK-FILES`, `.SETTINGS`). `ANS-VALIDATE` calls `resetBlockSubsystemSession()` and restores the pre-validation dictionary so Hayes `fload test` can run immediately afterward.

**Standard THROW codes (Phases 1–5, complete):** Runtime (-3…-9), memory (-7), compile-only (-14), control (-15/-16), limits (-17), search order (-20), names (-10), undefined (-13), dictionary misuse (-20), file-access (-67 closed file, -68 invalid file-id, -70 I/O abort, -74 not found). User range from **-40**. **`OPEN-FILE`** and related words still return **`ior`** on the stack (ANS file-access). Named **`FLOAD`** loads synchronously (`onPerformNamedLoad` in the app) so parsing words can be wrapped with `['] fload catch`. Mid-file line errors propagate the **specific** fault code to the enclosing `CATCH`. Full map: **`THROW_CODES.md`**.

Catchable named load example:

```forth
: safe-fload  ( -- )
  ['] fload catch ?dup if  ." load failed:" .error  else  drop  then ;
```

## Memory-Allocation (14) — Complete

ANS word set 14.6.1 (heap allocate / free / resize). Heap grows **downward** from the PNO buffer (top-anchored); dictionary grows upward from `HERE`. `UNUSED` reflects the gap between `HERE` and the heap/PNO anchor.

| Word | Stack / notes |
|------|----------------|
| `ALLOCATE` | `( u -- a-addr ior )` — allocate `u` bytes; `ior` 0 = success, 1 = failure |
| `FREE` | `( a-addr -- ior )` — return block to free list |
| `RESIZE` | `( a-addr u -- a-addr' ior )` — resize block; may move; shrink leaves tail on free list |

`ENVIRONMENT?` answers `MEMORY-ALLOCATION`. FTEST covers allocate/free/resize, grow, and rule violations.

### TZForth extension: `GROWMEMORYMB`

`( n -- )` — grow the linear memory array to **n megabytes** (minimum 1, maximum 64). Rules:

- **Once per session** — second call aborts with `? GROWMEMORYMB already used (once per session)`
- **No shrink** — `n` must exceed current size
- **Before `ALLOCATE`** — not permitted after any `ALLOCATE` use in the session
- **Early use** — intended shortly after startup (including during `FLOAD`); sets `errorFlag` and prints message on violation

Default memory at startup: **1 MB**.

## Double-Number (8) — Complete

ANS word set 8.6.1 and extensions 8.6.2. Double-cell layout matches existing Core words (`M*`, `UM/MOD`, pictured numeric): lower cell on stack first, upper cell on top; 64-bit value in two cells (low 32 / high 32).

| Word | Stack / notes |
|------|----------------|
| `D+` `D-` `DNEGATE` `DABS` `D2*` `D2/` | arithmetic |
| `D.` `D.R` | display signed double in `BASE` |
| `D<` `D=` `D0<` `D0=` `DU<` | comparisons |
| `D>S` | drop high cell |
| `DMIN` `DMAX` | extrema |
| `M+` `M*/` | mixed single/double arithmetic |
| `2CONSTANT` `2VARIABLE` `2LITERAL` `2VALUE` | defining / compile |
| `2ROT` | rotate third pair to top |
| `S>D` | sign-extend single to double (Core Ext) |

**Text interpreter (8.3.1):** a number token ending in `.` (and not a definition name) is compiled or pushed as a double-cell literal (e.g. `1234.` → `1234` `0`).

`TO` accepts a double on the stack for words created by `2VALUE`. `ENVIRONMENT?` answers `DOUBLE`.

## Locals (13) — Complete

ANS word set 13.6.1 and extension 13.6.2. Locals are searched before the dictionary while compiling. Run-time storage uses a re-entrant frame stack in Swift (not the data stack); `EXIT` / `;` release the innermost frame. `ABORT` / `CATCH` release frames per 13.3.3.1.

| Word | Notes |
|------|-------|
| `(LOCAL)` | Compile-only message interface (`c-addr u`; `u=0` ends sequence) |
| `LOCALS|` | Immediate; `name1 ... namen \|` — args initialized from stack (first name ← TOS) |
| `{:` | Immediate; `{: arg ... \| val ... -- out ... :}` — rightmost arg ← TOS; vals default to 0 |

`TO name` works for locals during compilation. Minimum **32** locals per definition (`ENVIRONMENT?` `#LOCALS`). FTEST covers `LOCALS|`, `{:`, `TO`, and `DO`/`LOOP`.

## Programming-Tools (15) — Complete

Hayes **toolstest.fth** subset (implemented words only): **0 errors**. TZForth implements a **minimal threaded assembler** (not machine code): `CODE`/`;CODE` build definitions whose CFA holds a `codeEntry` marker and threaded body; `RET` in the **ASSEMBLER** vocabulary compiles `EXIT`; `;CODE` appends `EXIT` when the body is empty (noop). FTEST covers noop and explicit `RET`.

ANS words implemented from 15.6.1 / extensions:

| Word | Notes |
|------|-------|
| `.S` | Data stack dump |
| `?` | `( addr -- )` — display `@ addr` |
| `DUMP` | `( addr u -- )` — hex dump of **u address units (bytes)**; 16 per line, uppercase hex, ASCII gutter |
| `SEE` | Decompile / list word |
| `WORDS` | List dictionary (optional vocab filter) |
| `FORGET` | Parse name; truncate dictionary from that word forward |
| `NAME>STRING` | `( nt -- c-addr u )` — **nt** = header address (link field); transient buffer |
| `NAME>INTERPRET` | `( nt -- xt )` — xt is cfa |
| `NAME>COMPILE` | `( nt -- xt )` — immediate → cfa; non-immediate → hidden compile stub |
| `TRAVERSE-WORDLIST` | `( xt wid -- )` — skips hidden / empty-name entries |
| `SYNONYM` | `( "new" "old" -- )` — execution + compilation delegate to oldname |
| `[DEFINED]` / `[UNDEFINED]` | Compile-time existence tests (immediate) |
| `N>R` / `NR>` | Block transfer between data and return stacks |
| `CS-PICK` / `CS-ROLL` | Control-flow stack = data stack during compilation |
| `AHEAD` | Unconditional forward branch placeholder (with `THEN`) |
| `EDITOR` / `ASSEMBLER` | Vocabs for search order; **ASSEMBLER** holds `RET` |
| `CODE` / `;CODE` | Threaded CODE definitions (TZForth model; see above) |
| `RET` | Assembler vocab — compile `EXIT` into open CODE body |

`[IF]` / `[ELSE]` / `[THEN]` also satisfy Core Ext conditional compilation.

## Dictionary introspection (fig-style extensions)

TZForth exposes the linked-list header layout for debugging (not ANS-standard; parallel to `NAME>STRING` / name tokens in ANS 2012).

| Word | Stack | Notes |
|------|-------|-------|
| `'` | `( -- cfa ) name` | Tick — **returns cfa**, not the kernel dispatch ID |
| `FIND` | `( c-addr -- … xt … )` | xt is **cfa** (same convention as `'`) |
| `>HEADER` / `>LFA` | `( cfa -- header )` | Link field / start of dictionary entry |
| `>NFA` | `( cfa -- nfa )` | Name field (`>HEADER 8 +`) |
| `ID.` | `( cfa -- )` | Print name (masks immediate/hidden flags in count byte) |
| `>XID` | `( cfa -- xid \| 0 )` | Kernel primitive dispatch ID from first cfa cell; **0** for colon/CREATE words |

Compiled colon bodies still store **compact primitive IDs** for kernel words; use `>XID` to map cfa → dispatch ID. `COMPILE,` and `[']` accept cfa from `'`.

Example: `' DUP >HEADER 32 DUMP` · `' DUP H.` · `' DUP >XID .` → primitive dispatch ID (implementation-defined).

## TZForth-specific extensions (non-ANS)

`FLOAD` (synchronous named load, catchable `-74`), `EDIT`, `CHDIR`, `DIR`, `FILE-ECHO`, `DEBUG-ON`/`DEBUG-OFF`, `RESET`, `CLS`, `BYE`, `ANS-VALIDATE`, `.ENVIRONMENT`, `.ERROR` (spaced throw message), `.INCLUDED` (list `INCLUDED-NAMES` registry), `CATCH-EVALUATE`, `FORGET-WORD`, `>LFA`, `>HEADER`, `>NFA`, `>XID`, `ID.`, `H.` (unsigned hex print, ignores `BASE`), `\\` (block comment to `{`), `\\S`, `DP`, high-level `HERE` (`DP @`), `ERASE` (`0 FILL`), `GROWMEMORYMB`, `STEP-LIMIT`, etc.

### BIG-INTEGER multiprecision (not ANS)

Optional teaching word set for multiprecision integers (base **10⁹** limbs, 64-bit cells). **Not** an ANS word set and **not** part of Hayes forth2012.

| Component | Notes |
|-----------|--------|
| Vocabulary **`BIG-INTEGER`** | Kernel; host **`BI-MUL`**, **`BI-DIVMOD`**, **`BI-ISQRT`** |
| **`TZForth/Library/big-int.fth`** (→ Resources/Library) | Alloc, add/sub, `BI*` → `BI-MUL`, print, … |
| **`Library/pi-chudnovsky.fth`**, **`pi-test.fth`** | Chudnovsky π; load with `FROMLIB FLOAD pi-test.fth` |
| **`FROMLIB` / `FROM-LIBRARY`** | Next file op rooted at Resources/Library (`FLOAD`/`EDIT`/`DIR`/`CHDIR`, …) |
| **`STEP-LIMIT`** | Interpreter step budget; `0` disables (needed for large π runs) |

Load pattern: `ONLY FORTH ALSO BIG-INTEGER DEFINITIONS` … library … `ONLY FORTH ALSO DEFINITIONS`. Use `ALSO BIG-INTEGER` (or execute the vocab) before using BI words. `WORDS` lists the **first** search-order wordlist only (`ONLY FORTH ALSO BIG-INTEGER WORDS` → BI set).

## Facility (10) — Complete (TZForth host)

ANS 10.6.2 structure words (Hayes `facilitytest.fth`):

| Word | Notes |
|------|-------|
| `BEGIN-STRUCTURE` | Immediate; parse structure name; reset offset; push `struct-sys` |
| `END-STRUCTURE` | Immediate; pop `struct-sys`; `CREATE` size constant from pending name |
| `+FIELD` | Immediate; `( u "name" -- )` — field offset word with `DOES> @ +` |
| `FIELD:` | Immediate; cell-aligned field (`1 CELLS +FIELD`) |
| `CFIELD:` | Immediate; char field (`1 CHARS +FIELD`) |

During an active structure, **`ALIGNED`** aligns the structure offset (for `ALIGNED STRCT3 +FIELD` nested layouts). `ENVIRONMENT?` answers `FACILITY`.

### Facility terminal (10.6.1)

| Word | Notes |
|------|-------|
| `KEY?` | Done — non-blocking `inputQueue` test |
| `PAGE` | Clears **80×25** facility buffer, homes cursor; `onTerminalRefresh` updates host console |
| `AT-XY` | `( u1 u2 -- )` — column `u1`, row `u2` (0-based); subsequent `EMIT`/`TYPE`/`CR` write into buffer |

`CLS` deactivates the facility buffer and clears scrollback (TZForth host). `EMIT`/`TYPE`/`CR`/`SPACES` route to the buffer while terminal mode is active (after `PAGE` or `AT-XY`).

### Facility extensions (10.6.2) — done

| Word | Notes |
|------|-------|
| `MS` | Async delay via `onMsDelayRequested` (ConsoleView); CLI/FTEST falls back to `Thread.sleep` |
| `TIME&DATE` | Local wall clock — `( -- sec min hr day mon yr )`, year on top |
| `EKEY` / `EKEY?` | Extended key queue; blocking `provideExtendedKey` from ConsoleView |
| `EKEY>CHAR` / `EKEY>FKEY` | Decode TZForth event encoding (char tag `0x01xxxxxx`, fkey tag `0x02xxxxxx`) |
| `EMIT?` | Always true (`-1`) in console host |
| `K-*` | `K-LEFT`…`K-F12`, `K-PRIOR`/`K-NEXT`, `K-INSERT`/`K-DELETE`, shift/ctrl/alt masks |

## Extended-Character (18) — Complete

ANS word set 18.6.1 and 18.6.2 with UTF-8 as the xchar encoding (`TZForthXChar.swift`). Malformed UTF-8 or invalid code points throw **-77**.

### Memory and string (18.6.1)

| Word | Stack / notes |
|------|----------------|
| `XC-SIZE` | `( xchar -- u )` — encoded byte count |
| `X-SIZE` | `( xc-addr u -- u' )` — size from leading byte |
| `XC@+` / `XC!+` / `XC!+?` / `XC,` | fetch/store/append encoded xchars |
| `XCHAR+` / `XCHAR-` | advance/retreat within UTF-8 buffer |
| `+X/STRING` / `X\STRING-` | skip/include xchars in bounded string |
| `-TRAILING-GARBAGE` | trim incomplete trailing UTF-8 sequence |

### Parsing and I/O (18.6.2)

Shadow Core **`CHAR`**, **`[CHAR]`**, **`PARSE`** — first xchar / delimiter parsing in UTF-8. **`XEMIT`**, **`XKEY`**, **`XKEY?`**, **`EKEY>XCHAR`** — terminal I/O. **`XHOLD`** — pictured numeric (UTF-8 bytes via `picturedHoldsBytes`). **`XC-WIDTH`** / **`X-WIDTH`** — display columns (ANS wc-table).

### Environmental queries (18.3.2)

| Query | Returns |
|-------|---------|
| `EXTENDED-CHARACTER` | `-1` (word set present) |
| `XCHAR-ENCODING` | `c-addr u` → `"UTF-8"` |
| `MAX-XCHAR` | `u` → `$10FFFF` |
| `XCHAR-MAXMEM` | `u` → `4` |

FTEST / `ANS-VALIDATE` cover codec, memory/string words, shadow parsing, I/O, pictured `XHOLD`, display width, and all four ENVIRONMENT? queries.

## Float (12) — Tier A + Tier B (Float Ext)

Implemented in **`TZForthFloat.swift`**. IEEE **64-bit double** on a **separate 16-deep floating-point stack** fixed in low memory (after return stack, before dictionary `DP`). Decimal/scientific literals when `BASE` is 10 (ANS 12.3.7), including bare `0e` / `1E` / `10E`; tokens ending in `.` alone (e.g. `42.`) remain double-cell literals. `>FLOAT` accepts optional `D` suffix (`1D`, `2.0D0`).

| Category | Words |
|----------|-------|
| Stack | `FDEPTH`, `FDROP`, `FDUP`, `FOVER`, `FSWAP`, `FROT`, `F-ROT` |
| Memory | `F@`, `F!`, `SF@`, `SF!`, `DF@`, `DF!`, `FLOATS`/`SFLOATS`/`DFLOATS`, `FLOAT+`/`SFLOAT+`/`DFLOAT+`, `FALIGN`/`SFALIGN`/`DFALIGN`, `FALIGNED`/`SFALIGNED`/`DFALIGNED` |
| Math | `F+`, `F-`, `F*`, `F/`, `FNEGATE`, `FABS`, `FMAX`, `FMIN`, `FMOD`, `FLOOR`, `FROUND`, `FSQRT`, `F**` |
| Trig / hyperbolic | `FSIN`, `FCOS`, `FTAN`, `FASIN`, `FACOS`, `FATAN`, `FATAN2`, `FSINCOS`, `FSINH`, `FCOSH`, `FTANH`, `FASINH`, `FACOSH`, `FATANH` |
| Exp / log | `FEXP`, `FEXPM1`, `FLN`, `FLNP1`, `FLOG`, `FALOG` |
| Compare | `F0=`, `F0<`, `F<`, `F~` |
| Convert | `S>F`, `D>F`, `F>D`, `F>S`, `>FLOAT` |
| I/O | `F.`, `FS.`, `FE.`, `.FS`, `REPRESENT`, `PRECISION`, `SET-PRECISION` |
| Defining | `FCONSTANT`, `FVARIABLE`, `FVALUE` (+ `TO`), `FLITERAL` (+ threaded `FLIT`) |
| ENVIRONMENT? | `FLOATING`, `FLOAT-EXT`, `FLOATING-STACK` (16), `MAX-FLOAT` |

FTEST / `ANS-VALIDATE` cover Tier A words plus Tier B spot-checks (`0e`, `FVARIABLE`, `FVALUE`/`TO`, `F~`, `F>D`, `FABS`, `FROT`, `FSIN`, `FATAN2`, `SF@`/`SF!`, `FSQRT`, `ENVIRONMENT? FLOAT-EXT`). Hayes `fp/` suite (`ttester.fs`, `paranoia.4th`, `ak-fp-test.fth`, etc.) passes via `test.fth` / `fp/runfptests.fth` — see **`HAYES-RESULTS.txt`**.

## Missing optional / future word sets

Not implemented (no current plan unless requested):

## Recommendations

- TZForth is ready for distribution packaging: classic Forth sources, REPL, sandboxed `FLOAD`/`EDIT`/`CHDIR`, Hayes forth2012 validation (**0 errors**, Block + Float `fp/` via `test.fth`), FTEST **430/430**, in-app `ANS-VALIDATE` **427/427**, file-backed Block (`.blk`), UTF-8 Extended-Character, minimal threaded `CODE`, Float Tier A/B/C, and ANS File-Access file I/O / `INCLUDED`.
- Hayes reproduction: `CHDIR Tests/forth2012-test-suite/src` → **`FLOAD test`**; transcript baseline **`Tests/forth2012-test-suite/src/HAYES-RESULTS.txt`**.

For full standard details, see the official 2012 ANS Forth document (sections 6.1, 6.2, and optional word sets in chapters 7–18).