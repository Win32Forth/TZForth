# ANS Forth 2012 Compliance Status for TZForth

This document tracks implementation status of the 2012 ANS Forth Standard word sets in TZForth (Swift port of the lbForth model). Generated from codebase inspection (`TZForth/TZForth.swift`, `TestTZForth.swift`, `TZForthTests.swift`).

Last update: `SOURCE` input buffer expanded to 1024 bytes.

## Summary

| Word set | Status |
|----------|--------|
| **Core (6.1)** | Complete — all required words implemented with FTEST coverage |
| **Core Ext (6.2)** | Complete — all standard Core Ext words implemented |
| **Search-Order (16)** | Substantial — `WORDLIST`, `GET/SET-ORDER`, `GET/SET-CURRENT`, `FORTH-WORDLIST`, plus `VOCABULARY`, `FORTH`, `DEFINITIONS`, `ALSO`, `ONLY`, `ORDER` |
| **Programming-Tools** | Partial — `SEE`, `HELP`, `WORDS`, `FORGET`, `>HEADER`, `>NFA`, `ID.`, `ANS-VALIDATE`; no `LOCATE`, `COMPILE`, `NEEDS`, `REQUIRED` |
| **File-Access (11)** | Substantial — 11.6.1 core words + `INCLUDE`/`INCLUDED`; no `REQUIRE`/`REQUIRED` |
| **Other optional sets** | Mostly absent — Double, Float, Exception, String, Block, Locals, Memory-Allocation, etc. |

FTEST harness: run with `FTEST=1 swift /tmp/combined.swift` (concatenate `TZForth.swift`, `TZForthTests.swift`, `TestTZForth.swift`).

## Core (6.1) — Complete

All Core words required for conformance are implemented. Notable details:

- **QUIT** is a primitive (safe RSP wipe); **SOURCE** / **PARSE** / **>IN** track the per-line `SOURCE` buffer (128 @, **1024 bytes**). `REFILL` and `feedLine` truncate input lines longer than 1024 characters.
- **PAD** at 5248, **1024 bytes** — user/programmer scratch only. Per ANS rationale (6.2.2000), no standard words use `PAD`; TZForth keeps parsers out of `PAD` entirely.
- **STRING_BUFFER** at 1152, **4096 bytes** — system parse scratch (not exposed as a Forth word). Each interpret-time use of `WORD`, `CHAR`, `S"`, `C"`, `. "`, `ABORT"`, `S\"`, and `INCLUDE` (immediate path) allocates the next **512-byte slot** in a ring; when the offset reaches the end, allocation wraps to the start. Up to **8** concurrent transient strings can coexist before the oldest slot is reused. Counted strings are capped at **255** characters (`/COUNTED-STRING`). Contents are transient (invalidated by further parsing, dictionary growth, etc., per 3.3.3.6).
- **PARSE** / **PARSE-NAME** return slices of **SOURCE**, not `STRING_BUFFER` or `PAD`.
- Pictured numeric (`<#` … `#>`) uses a separate high-memory buffer, not `PAD`.
- **POSTPONE** / **[COMPILE]** use captured `executeID` + emit `LIT`/`EXECUTE` for immediate words.
- **ENVIRONMENT?** returns values for `CORE`, `CORE-EXT`, `/COUNTED-STRING` (255), `ADDRESS-UNIT-BITS`, `MAX-CHAR`, `FILE`, `FILE-ACCESS`, `FILE-EXT`.
- Memory: 1 MB dictionary region; low fixed layout `SOURCE` (1024) → `STRING_BUFFER` (4096) → `PAD` (1024) → data/return stacks; **UNUSED** / **.FREE** report free dictionary bytes.

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

`VOCABULARY`, `FORTH`, `DEFINITIONS`, `ALSO`, `ONLY`, `ORDER`, `WORDS` (optional filter). `FORTH` is default; new vocabs start empty; lookup falls back to `FORTH` for system words.

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

`OPEN-FILE`, `CLOSE-FILE`, `CREATE-FILE`, `DELETE-FILE`, `RENAME-FILE`, `READ-FILE`, `WRITE-FILE`, `READ-LINE`, `WRITE-LINE`, `FILE-POSITION`, `FILE-SIZE`, `REPOSITION-FILE`, `RESIZE-FILE`, `FILE-STATUS`, `FLUSH-FILE`, `INCLUDE-FILE`, `INCLUDED`, `INCLUDE` (immediate).

### Integration with input and loading

- **`REFILL`** — when interpreting from an open file (`interpreterInputFileId` ≥ 2), refills `SOURCE` from that file; returns false at EOF.
- **`(`** — multi-line parenthesized comments span file lines (refills when `)` not found on current line).
- **`INCLUDE-FILE` / `INCLUDED` / `INCLUDE`** — line-at-a-time interpret loop; `SOURCE-ID` is the fileid (≥ 10 for newly opened files; host `FLOAD` uses id `1`).
- **`ENVIRONMENT?`** — returns true for `FILE`, `FILE-ACCESS`, `FILE-EXT`.

### Not implemented (File-Access extensions)

- **`REQUIRE` / `REQUIRED`** — load-once tracking (Programming-Tools / File-Access ext; needs separate load registry).

Host extension **`FLOAD`** remains available alongside ANS `INCLUDED` / `INCLUDE-FILE`.

## TZForth-specific extensions (non-ANS)

`FLOAD`, `EDIT`, `CHDIR`, `DIR`, `FILE-ECHO`, `DEBUG-ON`/`DEBUG-OFF`, `RESET`, `CLS`, `BYE`, `ANS-VALIDATE`, `FORGET-WORD`, `>LFA`, `>HEADER`, `>NFA`, `ID.`, `\\` (block comment to `{`), `\\S`, `DP`, high-level `HERE` (`DP @`), `ERASE` (`0 FILL`), etc.

## Missing optional / future word sets

Not implemented (no current plan unless requested):

- **Double** (`D+`, `D.`, `2CONSTANT`, …)
- **Float**
- **Exception** (`CATCH`, `THROW`)
- **String** (`COMPARE`, `SEARCH`, …)
- **Block**
- **Locals**
- **Memory-Allocation**
- Full **Programming-Tools** (`LOCATE`, `COMPILE`, …)

## Recommendations

- TZForth is highly functional for classic Forth sources, REPL, sandboxed `FLOAD`/`EDIT`/`CHDIR`, ANS Core + Core Ext conformance testing, and ANS File-Access file I/O / `INCLUDED`.
- Next logical steps (if desired): `REQUIRE`/`REQUIRED`, Exception (`CATCH`/`THROW`), or vocabulary polish to hide kernel internals.

For full standard details, see the official 2012 ANS Forth document (sections 6.1, 6.2, and optional word sets in chapters 7–18).