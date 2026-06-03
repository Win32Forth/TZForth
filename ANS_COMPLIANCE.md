# ANS Forth 2012 Compliance Status for TZForth / LBForth

This document summarizes the implementation status of the Core and Core Extensions word sets from the 2012 ANS Forth Standard in the current codebase (as of the latest commits).

## Implemented Words (Core + Extensions, non-exhaustive)
The engine implements a substantial and practical subset of the standard, focused on usability for classic Forth sources (e.g., F-PC style, Forthing.fth). This includes:

- Core arithmetic, stack, comparisons, logic, memory, I/O, control flow, defining words, etc.
- Many Core Ext: 2>R 2R@ 2R>, NIP, PICK, ROLL, TUCK, U.R, WITHIN, ?DO, etc.
- App-specific but useful extensions: FLOAD, EDIT, CHDIR, DIR, FILE-ECHO, DEBUG-ON/OFF, >HEADER, >NFA, ID., FORGET-WORD, etc.
- High-level conveniences: HERE as DP @, >LFA, >NFA, ID., etc.
- Full test coverage expanded in TestLBForth.swift (FTEST) for many words per standard stack effects.

See `TZForth/LBForth.swift` (register calls + primitiveHelpData + bootstrap high-level defs) and `TestLBForth.swift` for details. `WORDS` in the REPL shows current dictionary.

## Missing from Core Word Set (6.1 - required for conformance)
(Compiled via comparison of standard list vs. current `primitiveHelpData` + live WORDS + registrations. ~42 items.)

*/
*/MOD
+!
/
2DROP
2DUP
2OVER
2SWAP
<#
>BODY
>IN
>NUMBER
ABORT
ABORT"
ACCEPT
ALIGN
ALIGNED
ENVIRONMENT?
EVALUATE
EXECUTE
FILL
FIND
FM/MOD
HOLD
IMMEDIATE
J
LITERAL
M*
MOVE
POSTPONE
QUIT
RECURSE
S"
S>D
SIGN
SM/REM
SOURCE
U<
UM*
UM/MOD
[']
[CHAR]

Notes on some:
- Many 2- stack words (2DROP etc.) are absent (though 2@ 2! 2>R family exist).
- No ABORT/ABORT" (error handling is via errorFlag + recover).
- No full IMMEDIATE word (flag is internal for ; etc.).
- No J (only I for DO loops).
- No LITERAL (internal LIT used in compilation).
- No S" (." exists for compile-time strings).
- No QUIT as user word (internal loop exists; BYE/RESET provided).
- No RECURSE.
- Some like ALIGN, >BODY, FIND, etc., not needed for the current use cases but standard.

## Missing from Core Extensions Word Set (6.2)
(~29 items.)

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
PAD
PARSE
PARSE-NAME
RESTORE-INPUT
SAVE-INPUT
SOURCE-ID
U>
UNUSED
VALUE
[COMPILE]

Notes:
- The engine has good coverage of practical extensions (PICK/ROLL/TUCK/NIP/U.R/WITHIN/?DO etc.).
- Missing many for full "programming tools" like DEFER, CASE, VALUE, PARSE family, etc.
- Some like AGAIN, 2>R etc. *are* present.

## Recommendations / Status
- The system is **highly functional** for the user's needs (loading classic sources, REPL, FLOAD/EDIT/CHDIR in sandbox, FILE-ECHO, \S, ." , WORD, etc.).
- Recent work (FLOAD reliability, compact .", DP/HERE, header tools, expanded ANS tests in FTEST) has made it much closer to usable classic Forth.
- Full ANS conformance would require implementing the above missing items + tests + documentation.
- Current tests (TestLBForth.swift FTEST) cover a lot of the *implemented* core words per standard + special behaviors.
- To continue under credit limits: prioritize user-requested words from Forthing.fth or specific missing ones that block porting.

Generated from codebase inspection (LBForth.swift, TestLBForth.swift, live runs).
Last update: after ANS test expansion commit.

For full standard details, refer to the official 2012 ANS Forth document (sections 6.1 and 6.2).
