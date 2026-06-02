\ DEFINIT.SEQ      Default Initialization for TCOM      by Tom Zimmer

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

: %DEF-INIT   ( -- )            \ some additional default initialization
                                \ done for all applications
                DECIMAL                         \ always select decimal
                CAPS ON                         \ ignore cAsE
                ;

' %DEF-INIT >EXECUTE [FORTH] IS DEF-INIT [TARGET]

: %NO-INIT      ( -- )
                ;

' %NO-INIT >EXECUTE [FORTH] IS NO-INIT [TARGET]

FORTH TARGET >TARGET

