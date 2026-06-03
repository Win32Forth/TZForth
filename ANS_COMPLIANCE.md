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
(~25 items after recent moves.)

.R
0<>
:NONAME
<>
ACTION-OF
BUFFER:
C"
CASE
COMPILE,
DEFER
DEFER!
DEFER@
ENDCASE
ENDOF
ERASE
HOLDS
IS
MARKER
OF
PARSE-NAME
RESTORE-INPUT
SAVE-INPUT
SOURCE-ID
U>
UNUSED
VALUE

Notes:
- The engine has good coverage of practical extensions (PICK/ROLL/TUCK/NIP/U.R/WITHIN/?DO etc.).
- Core Ext items like PAD, PARSE, [COMPILE] were Core or moved as they are now present.
- Missing many for full "programming tools" like DEFER, CASE, VALUE, etc. (planned post-Core; some will be high-level Forth for SEE).
- Some like AGAIN, 2>R etc. *are* present.

## Recommendations / Status
- The system is **highly functional** for the user's needs (loading classic sources, REPL, FLOAD/EDIT/CHDIR in sandbox, FILE-ECHO, \S, ." , WORD, etc.).
- Core word set now substantially complete (101/101 tests clean). Recent work added final Core words QUIT/SOURCE/PARSE/PAD/POSTPONE/[COMPILE] + ENV improvements + input >IN integration.
- Per user direction: refactoring more to high-level Forth (for smaller Swift kernel + better SEE decompile) is deferred until after Core; future Core Ext and complex (debugger, assembler, VOCABULARYs) are good candidates for : defs.
- Current tests (TestTZForth.swift FTEST + embedded ANS-VALIDATE) cover the implemented words per standard + special behaviors (smart quotes, load semantics, etc.).
- To continue: next would be remaining Core Ext per explicit plan, then vocabularies to hide internals.

Generated from codebase inspection (TZForth.swift, TZForthTests.swift, TestTZForth.swift, live runs).
Last update: after final Core batch (QUIT/SOURCE/PARSE/POSTPONE etc).

For full standard details, refer to the official 2012 ANS Forth document (sections 6.1 and 6.2).
