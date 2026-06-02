\ DEFINIT.SEQ      Default Initialization for TCOM      by Tom Zimmer

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

: %DEF-INIT   ( -- )            \ some additional default initialization
                                \ done for all applications
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                ;

' %DEF-INIT >EXECUTE [FORTH] IS DEF-INIT [TARGET]

: %NO-INIT      ( -- )
                ;

' %NO-INIT >EXECUTE [FORTH] IS NO-INIT [TARGET]

FORTH TARGET >TARGET

