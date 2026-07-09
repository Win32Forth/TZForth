# ANS Forth 2012 Compliance Status for TZForth

This document tracks implementation status of the 2012 ANS Forth Standard word sets in TZForth (Swift port of the lbForth model). Generated from codebase inspection (`TZForth/TZForth.swift`, `TestTZForth.swift`, `TZForthTests.swift`).

Last update: after Core Ext Tier 2 batch (`:NONAME`, `ACTION-OF`, `MARKER`, `SAVE-INPUT`, `RESTORE-INPUT`, `SOURCE-ID`, `S\"`, `REFILL`) and prior Tier 1 words.

## Summary

| Word set | Status |
|----------|--------|
| **Core (6.1)** | Complete — all required words implemented with FTEST coverage |
| **Core Ext (6.2)** | Complete — all standard Core Ext words implemented |
| **Search-Order (16)** | Substantial — `WORDLIST`, `GET/SET-ORDER`, `GET/SET-CURRENT`, `FORTH-WORDLIST`, plus `VOCABULARY`, `FORTH`, `DEFINITIONS`, `ALSO`, `ONLY`, `ORDER` |
| **Programming-Tools** | Partial — `SEE`, `HELP`, `WORDS`, `FORGET`, `>HEADER`, `>NFA`, `ID.`, `ANS-VALIDATE`; no `LOCATE`, `COMPILE`, `NEEDS`, `REQUIRED` |
| **Optional sets** | Mostly absent — Double, Float, File-Access, Exception, String, Block, Locals, Memory-Allocation, etc. |

FTEST harness: run with `FTEST=1 swift /tmp/combined.swift` (concatenate `TZForth.swift`, `TZForthTests.swift`, `TestTZForth.swift`).

## Core (6.1) — Complete

All Core words required for conformance are implemented. Notable details:

- **QUIT** is a primitive (safe RSP wipe); **SOURCE** / **PARSE** / **>IN** track the per-line `SOURCE` buffer (128 @, 256 bytes).
- **PAD** at 384, 257 bytes (count + 255 chars + NUL); shared by `WORD`, `S"`, `C"`, `. "`, `ABORT"`, etc.
- **POSTPONE** / **[COMPILE]** use captured `executeID` + emit `LIT`/`EXECUTE` for immediate words.
- **ENVIRONMENT?** returns values for `CORE`, `CORE-EXT`, `/COUNTED-STRING`, `ADDRESS-UNIT-BITS`, `MAX-CHAR`.
- Memory: 1 MB dictionary region; data/return stacks 256 cells each; **UNUSED** / **.FREE** report free dictionary bytes.

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

## TZForth-specific extensions (non-ANS)

`FLOAD`, `EDIT`, `CHDIR`, `DIR`, `FILE-ECHO`, `DEBUG-ON`/`DEBUG-OFF`, `RESET`, `CLS`, `BYE`, `ANS-VALIDATE`, `FORGET-WORD`, `>LFA`, `>HEADER`, `>NFA`, `ID.`, `\\` (block comment to `{`), `\\S`, `DP`, high-level `HERE` (`DP @`), `ERASE` (`0 FILL`), etc.

## Missing optional / future word sets

Not implemented (no current plan unless requested):

- **Double** (`D+`, `D.`, `2CONSTANT`, …)
- **Float**
- **File-Access** (`INCLUDE-FILE`, `READ-LINE`, `OPEN-FILE`, …) — `FLOAD` is a host extension, not ANS File-Access
- **Exception** (`CATCH`, `THROW`)
- **String** (`COMPARE`, `SEARCH`, …)
- **Block**
- **Locals**
- **Memory-Allocation**
- Full **Programming-Tools** (`LOCATE`, `COMPILE`, …)

## Recommendations

- TZForth is highly functional for classic Forth sources, REPL, sandboxed `FLOAD`/`EDIT`/`CHDIR`, and ANS Core + Core Ext conformance testing.
- Next logical steps (if desired): File-Access words atop existing `FLOAD`, Exception (`CATCH`/`THROW`), or vocabulary polish to hide kernel internals.

For full standard details, see the official 2012 ANS Forth document (sections 6.1, 6.2, and optional word sets in chapters 7–18).