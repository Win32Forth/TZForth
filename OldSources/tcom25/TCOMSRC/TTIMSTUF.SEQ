\ TIMESTUF.SEQ          More words associated with timing       Tom Zimmer

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

: SEC-ELAPSED   ( --- N1 )    \ RETURN ELAPSED SECONDS < 18 HRS
                TIME-ELAPSED B>SEC ; ( -- N1 )

: 10TH-ELAPSED  ( --- N1 )
                TIME-ELAPSED 0 100 UM/MOD DROP 10 UM/MOD NIP ;

\ DEFER PAUSE-FUNC        ' NOOP IS PAUSE-FUNC

: SECONDS       ( N1 --- )   \ PAUSE FOR N1 SECONDS
                STIME 2@ 2>R >R TIME-RESET
                BEGIN   \ PAUSE  PAUSE-FUNC
                        R@ SEC-ELAPSED > 0=
                UNTIL   R>DROP 2R> STIME 2! ;

: TENTHS        ( N1 --- )       \ PAUSE FOR N1 SECONDS
                STIME 2@ 2>R >R TIME-RESET
                BEGIN   \ PAUSE  PAUSE-FUNC
                        R@ 10TH-ELAPSED > 0=
                UNTIL   R>DROP 2R> STIME 2! ;

: MINUTES       ( N1 --- )   \ PAUSE FOR N1 MINUTES
                0MAX   0 ?DO   60 SECONDS      LOOP ;

: HOURS         ( N1 --- )       \ PAUSE FOR N1 HOURS
                0MAX   0 ?DO   60 MINUTES      LOOP ;

FORTH TARGET >TARGET

