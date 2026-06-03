# ANS Forth 2012 Compliance Status for TZForth (based on Leif Bruder's lbForth / LBForth model)

This document summarizes the implementation status of the Core and Core Extensions word sets from the 2012 ANS Forth Standard in the current codebase (as of the latest commits).

## Implemented Words (Core + Extensions, non-exhaustive)
The engine implements a substantial and practical subset of the standard, focused on usability for classic Forth sources (e.g., F-PC style, Forthing.fth). This includes:

- Core arithmetic (incl. new / +! */MOD etc), double-cell stack ops, memory (FILL etc), literals/immediate, pictured numeric (<# etc), S", etc. (see added list in missing section notes).
- Many Core Ext: 2>R 2R@ 2R>, NIP, PICK, ROLL, TUCK, U.R, WITHIN, ?DO, etc.
- App-specific but useful extensions: FLOAD, EDIT, CHDIR, DIR, FILE-ECHO, DEBUG-ON/OFF, >HEADER, >NFA, ID., FORGET-WORD, etc.
- High-level conveniences: HERE as DP @, >LFA, >NFA, ID., etc.
- Full test coverage expanded in TestTZForth.swift (FTEST; originally TestLBForth.swift) for many words per standard stack effects.

See `TZForth/TZForth.swift` (register calls + primitiveHelpData + bootstrap high-level defs; originally LBForth.swift) and `TestTZForth.swift` for details. `WORDS` in the REPL shows current dictionary.

## Missing from Core Word Set (6.1 - required for conformance)
Core is now substantially complete. Recent batches added (with tests in both FTEST and ANS-VALIDATE): doubles, extra arith, memory ops, compile/immed ([CHAR] ['] LITERAL etc), pictured + S", EXECUTE/J/RECURSE, >IN/>NUMBER/ABORT/ABORT"/ACCEPT/ENV/EVALUATE/FIND, and final: QUIT, SOURCE, PARSE, PAD, POSTPONE, [COMPILE], plus supporting SP! RSP! (to enable clean high-level QUIT etc). 101/101 in expanded harness.

Some Core words are implemented as Swift primitives (necessary for early bootstrap / input model / RSP wipe safety in QUIT); high-level Forth defs are used where it makes sense for SEE decompile (e.g. HERE, >NFA, ID., and future complex like debuggers per user guidance). Vocabularies planned post-Core to hide internals.

(Full list of implemented is in primitiveHelpData + WORDS.)

Notes:
- QUIT is primitive (safe RSP empty); SOURCE/PARSE track >IN into per-line SOURCE_BUFFER (EVALUATE and FLOAD lines supported).
- POSTPONE/[COMPILE] use captured executeID + emit LIT/EXECUTE for imm case.
- ENVIRONMENT? now returns values for "CORE", "/COUNTED-STRING", "ADDRESS-UNIT-BITS", "MAX-CHAR" etc.

## Missing from Core Extensions Word Set (6.2)
(~15 items after this batch.)

.R
:NONAME
<>
ACTION-OF
BUFFER:
C"
HOLDS
MARKER
PARSE-NAME
RESTORE-INPUT
SAVE-INPUT
SOURCE-ID
U>
UNUSED

Notes:
- The engine has good coverage of practical extensions (PICK/ROLL/TUCK/NIP/U.R/WITHIN/?DO etc.).
- Added in this batch (with ansTest in both harnesses): VALUE IS CASE OF ENDOF ENDCASE 0<> COMPILE, ERASE DEFER DEFER! DEFER@ .
- CASE/OF/ENDOF/ENDCASE added as high-level Forth defs in bootstrap so they decompile cleanly via SEE (per guidance).
- VALUE uses IS for assignment (also works for DEFER); DEFER family fully supported (DEFER DEFER! DEFER@ IS).
- Still missing many for full "programming tools" like :NONAME, ACTION-OF, BUFFER:, C", HOLDS, MARKER, PARSE-NAME, RESTORE/SAVE-INPUT, SOURCE-ID, UNUSED (planned post-Core; many good as high-level : defs for SEE).
- Some like AGAIN, 2>R etc. *are* present.

## Recommendations / Status
- The system is **highly functional** for the user's needs (loading classic sources, REPL, FLOAD/EDIT/CHDIR in sandbox, FILE-ECHO, \S, ." , WORD, etc.).
- Core word set complete (101/101). This batch added requested Core Ext words (VALUE IS CASE OF ENDOF ENDCASE 0<> COMPILE, ERASE + full DEFER family). Tests now higher count in both harnesses.
- CASE etc defined high-level in bootstrap for nice SEE output. IS works for both VALUE and DEFER.
- Per user direction: more high-level Forth for remaining Ext and complex tools (debugger etc.) when we get to them; vocabularies after more Ext.
- Current tests (TestTZForth.swift FTEST + embedded ANS-VALIDATE) cover the implemented words per standard + special behaviors (smart quotes, load semantics, etc.).
- To continue: next would be remaining Core Ext per explicit plan, then vocabularies to hide internals.

Generated from codebase inspection (TZForth.swift, TZForthTests.swift, TestTZForth.swift, live runs).
Last update: after Core Ext batch (VALUE IS CASE/OF/ENDOF/ENDCASE 0<> COMPILE, ERASE DEFER family).

For full standard details, refer to the official 2012 ANS Forth document (sections 6.1 and 6.2).
