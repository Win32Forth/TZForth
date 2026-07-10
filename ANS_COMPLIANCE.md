# ANS Forth 2012 Compliance Status for TZForth

This document tracks implementation status of the 2012 ANS Forth Standard word sets in TZForth (Swift port of the lbForth model). Generated from codebase inspection (`TZForth/TZForth.swift`, `TestTZForth.swift`, `TZForthTests.swift`).

Last update: Programming-Tools — pre-ANS `COMPILE` documented as intentionally omitted (superseded by `POSTPONE` / `[COMPILE]` / `COMPILE,`).

## Summary

| Word set | Status |
|----------|--------|
| **Core (6.1)** | Complete — all required words implemented with FTEST coverage |
| **Core Ext (6.2)** | Complete — all standard Core Ext words implemented |
| **Search-Order (16)** | Complete — 16.6.1 + 16.6.2; `SEARCH-WORDLIST`, `ENVIRONMENT?` `WORDLISTS` (8) |
| **Programming-Tools** | Partial — 15.6.1/15.6.2 words below; assembler `CODE`/`;CODE` stubbed; `LOCATE` (SEE alias); pre-ANS `COMPILE` omitted (`POSTPONE` / `[COMPILE]` / `COMPILE,` in Core); no `NEEDS` |
| **File-Access (11)** | Substantial — 11.6.1 core words + `INCLUDE`/`INCLUDED` + `REQUIRE`/`REQUIRED` |
| **Exception (9)** | Complete — `CATCH`, `THROW`; Core `ABORT`/`ABORT"` delegate to `THROW -1`/`-2` |
| **String (17)** | Complete — 17.6.1 (`COMPARE`, `SEARCH`, `SLITERAL`, `/STRING`, `-TRAILING`, `BLANK`, `CMOVE`, `CMOVE>`) |
| **Memory-Allocation (14)** | Complete — 14.6.1 (`ALLOCATE`, `FREE`, `RESIZE`); extension `GROWMEMORYMB` |
| **Double-Number (8)** | Complete — 8.6.1 + 8.6.2 (`2ROT`, `2VALUE`, `DU<`); trailing `.` literals |
| **Locals (13)** | Complete — `(LOCAL)`, `LOCALS|`, `{:`; `TO` for locals; max 32 (`#LOCALS`) |
| **Other optional sets** | Mostly absent — Float, Facility, Block, Extended-Character, etc. |

FTEST harness: run with `FTEST=1 swift /tmp/combined.swift` (concatenate `TZForth.swift`, `TZForthTests.swift`, `TestTZForth.swift`). Current count: **244/244** TEST6 spot-checks plus block-comment / FLOAD harness tests.

## Core (6.1) — Complete

All Core words required for conformance are implemented. Notable details:

- **QUIT** is a primitive (safe RSP wipe); **SOURCE** / **PARSE** / **>IN** track the per-line `SOURCE` buffer (128 @, **1024 bytes**). `REFILL` and `feedLine` truncate input lines longer than 1024 characters.
- **PAD** at 5248, **1024 bytes** — user/programmer scratch only. Per ANS rationale (6.2.2000), no standard words use `PAD`; TZForth keeps parsers out of `PAD` entirely.
- **STRING_BUFFER** at 1152, **4096 bytes** — system parse scratch (not exposed as a Forth word). Each interpret-time use of `WORD`, `CHAR`, `S"`, `C"`, `. "`, `ABORT"`, `S\"`, and `INCLUDE` (immediate path) allocates the next **512-byte slot** in a ring; when the offset reaches the end, allocation wraps to the start. Up to **8** concurrent transient strings can coexist before the oldest slot is reused. Counted strings are capped at **255** characters (`/COUNTED-STRING`). Contents are transient (invalidated by further parsing, dictionary growth, etc., per 3.3.3.6).
- **PARSE** / **PARSE-NAME** return slices of **SOURCE**, not `STRING_BUFFER` or `PAD`.
- Pictured numeric (`<#` … `#>`) uses a separate high-memory buffer, not `PAD`.
- **POSTPONE** / **[COMPILE]** use captured `executeID` + emit `LIT`/`EXECUTE` for immediate words.
- **ENVIRONMENT?** returns values for `CORE`, `CORE-EXT`, `/COUNTED-STRING` (255), `ADDRESS-UNIT-BITS`, `MAX-CHAR`, `SEARCH-ORDER`, `WORDLISTS` (8), `FILE`, `FILE-ACCESS`, `FILE-EXT`, `EXCEPTION`, `STRING`, `MEMORY-ALLOCATION`, `DOUBLE`, `LOCALS`, `#LOCALS` (32). **`.ENVIRONMENT`** lists all supported queries.
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
| `SOURCE-ID` | `( -- id )` — `-1` terminal, `0` evaluate string, `1` file (`FLOAD`) |
| `S\"` | compile: parse escaped `"`-string, compile `(S")` + literal; interpret undefined per ANS |
| `REFILL` | `( -- flag )` — refill input buffer; false when no further line available (line-oriented REPL) |

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

`ENVIRONMENT?` answers `STRING`. FTEST covers compare, search, trailing, blank, `/STRING`, and `SLITERAL` via `[ ]`.

### Not implemented (String extensions 17.6.2)

`REPLACES`, `SUBSTITUTE`, `UNESCAPE` — substitution/escape tables not yet wired.

## File-Access (11) — Substantial

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
- **`INCLUDE-FILE` / `INCLUDED` / `INCLUDE`** — line-at-a-time interpret loop; `SOURCE-ID` is the fileid (≥ 10 for newly opened files; host `FLOAD` uses id `1`).
- **`ENVIRONMENT?`** — returns true for `FILE`, `FILE-ACCESS`, `FILE-EXT`.

### REQUIRE / REQUIRED / INCLUDED-NAMES

- **`INCLUDED-NAMES`** — kernel `VARIABLE` holding the head of a linked list of loaded spec strings (`next | str-addr | str-u` nodes on the heap). Inspectable via `@`.
- **`REQUIRED`** — if spec `( c-addr u )` is absent from the list, `nameJoin` + load (same as sample `included`); if present, discard spec without loading.
- **`REQUIRE`** — `PARSE-NAME` then `REQUIRED`.
- **`INCLUDE` / `INCLUDED`** — always load; register spec via `nameJoin` before interpret (extended, not shadowed).
- **Host `FLOAD`** — on successful load, registers the user's parse spec in the same list.

Registry key is the **exact spec bytes** passed in, not a canonical path. **`MARKER` / `FORGET`** do not prune `INCLUDED-NAMES` (matches ANS reference sample limitation on systems with `MARKER`).

Host extension **`FLOAD`** remains available alongside ANS `INCLUDED` / `INCLUDE-FILE`.

## Exception (9) — Complete

ANS word set 9.6.1 and extensions 9.6.2 (`ABORT`/`ABORT"` as `THROW` aliases).

| Word | Stack / notes |
|------|----------------|
| `CATCH` | `( xt -- n | i*x n )` — saves data/return stack depths, `STATE`, loop-control stack, and input-source nesting; executes `xt`; pushes `0` on normal completion or the throw code |
| `THROW` | `( n -- )` — `0` is a no-op; non-zero unwinds to the nearest `CATCH`, restoring saved depths and input nesting per 9.3.5 |
| `ABORT` | `( -- )` — `THROW -1` (catchable; uncaught → print `Aborted!`, reset, REPL continues) |
| `ABORT"` | `( flag "ccc" -- )` — if flag, `THROW -2` (catchable; uncaught → type `ccc` then reset) |

Unhandled `THROW` with no active `CATCH`: `-1` → print `Aborted!`, reset stacks/input, REPL ready for next line; `-2` → type stored `ABORT"` text then reset; other codes → `? THROW n` then reset. Caught `-1`/`-2` leave the throw code on the stack with no message.

FTEST covers `ABORT`/`ABORT"` with and without `CATCH`, including REPL recovery after uncaught `ABORT`.

Not yet wired: automatic `THROW` of standard codes (-3…-75) from every ambiguous condition (division by zero still uses `errorFlag` + message).

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

## Programming-Tools (15) — Partial

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
| `EDITOR` / `ASSEMBLER` | Empty vocabularies (Search-Order stubs) |
| `LOCATE` | `( -- name )` — TZForth extension; **alias of `SEE`** (decompile from memory, not source-file context) |

`[IF]` / `[ELSE]` / `[THEN]` also satisfy Core Ext conditional compilation. Stubbed (error at use): `CODE`, `;CODE`.

### Compile-time control (Core / Core Ext — not Programming-Tools)

Pre-ANS fig/F-PC `COMPILE` is **not** implemented and is **not planned**. ANS 2012 never standardized it; compilation control lives in Core and Core Ext instead:

| Word | Set | Role |
|------|-----|------|
| `POSTPONE` | Core | Append compilation semantics of the next word; for immediates, emits `LIT xt EXECUTE` (preferred ANS form) |
| `[COMPILE]` | Core | Force compile-time reference to the next word even if immediate (older ANS form) |
| `COMPILE,` | Core Ext | `( xt -- )` — compile a known execution token |
| `NAME>COMPILE` | Programming-Tools | `( nt -- xt )` — compilation token for a name token |

Porting legacy sources that use `COMPILE name` should rewrite to `POSTPONE name`, `[COMPILE] name`, or `' name COMPILE,` as appropriate.

### Not implemented

- **`NEEDS`** — not planned.
- **Gforth-style source `LOCATE`** (retained buffers, file:line) — future enhancement; TZForth `LOCATE` remains a `SEE` alias.

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

Example: `' DUP >HEADER 32 DUMP` · `' DUP H.` · `' DUP >XID .` → `8`.

## TZForth-specific extensions (non-ANS)

`FLOAD`, `EDIT`, `CHDIR`, `DIR`, `FILE-ECHO`, `DEBUG-ON`/`DEBUG-OFF`, `RESET`, `CLS`, `BYE`, `ANS-VALIDATE`, `.ENVIRONMENT`, `.INCLUDED` (list `INCLUDED-NAMES` registry), `LOCATE` (SEE alias), `FORGET-WORD`, `>LFA`, `>HEADER`, `>NFA`, `>XID`, `ID.`, `H.` (unsigned hex print, ignores `BASE`), `\\` (block comment to `{`), `\\S`, `DP`, high-level `HERE` (`DP @`), `ERASE` (`0 FILL`), `GROWMEMORYMB`, etc.

## Missing optional / future word sets

Not implemented (no current plan unless requested):

- **Float**
- **Facility** (`AT-XY`, `TIME&DATE`, …)
- **Block**
- **Extended-Character**
- Remaining **Programming-Tools** (`NEEDS`, Gforth-style source `LOCATE`, …)

## Recommendations

- TZForth is highly functional for classic Forth sources, REPL, sandboxed `FLOAD`/`EDIT`/`CHDIR`, ANS Core + Core Ext conformance testing, and ANS File-Access file I/O / `INCLUDED`.
- Next logical steps (if desired): Float, Facility, or map remaining `errorFlag` paths to standard `THROW` codes.

For full standard details, see the official 2012 ANS Forth document (sections 6.1, 6.2, and optional word sets in chapters 7–18).