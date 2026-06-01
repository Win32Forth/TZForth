\ DEFINIT.SEQ      Default Initialization for TCOM      by Tom Zimmer

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

I| : %DEF-INIT   ( -- )          \ some additional default initialization
                                \ done for all applications
                DECIMAL                         \ always select decimal
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                ;

' %DEF-INIT >EXECUTE [FORTH] IS DEF-INIT [TARGET]

I| : %NO-INIT    ( -- )
                ;

' %NO-INIT >EXECUTE [FORTH] IS NO-INIT [TARGET]

FORTH TARGET >TARGET

