\ ATEST.SEQ             ANSI code test file             by Tom Zimmer

        .options /ansi

: ATEST         ( -- )
                CR  32. 2DUP 5 D.R  2 DUP 3 .R ."  F/ " FM/MOD 3 .R 3 .R
                CR -32. 2DUP 5 D.R  2 DUP 3 .R ."  F/ " FM/MOD 3 .R 3 .R
                CR -32. 2DUP 5 D.R -2 DUP 3 .R ."  F/ " FM/MOD 3 .R 3 .R
                CR  32. 2DUP 5 D.R -2 DUP 3 .R ."  F/ " FM/MOD 3 .R 3 .R
                CR  32. 2DUP 5 D.R  2 DUP 3 .R ."  S/ " SM/REM 3 .R 3 .R
                CR -32. 2DUP 5 D.R  2 DUP 3 .R ."  S/ " SM/REM 3 .R 3 .R
                CR -32. 2DUP 5 D.R -2 DUP 3 .R ."  S/ " SM/REM 3 .R 3 .R
                CR  32. 2DUP 5 D.R -2 DUP 3 .R ."  S/ " SM/REM 3 .R 3 .R ;
\S

                ." Type lines, press [Control-Break] to terminate:" CR
                BEGIN   BEGIN   KEY?
                                BROKEN @ ?EXIT
                        UNTIL   KEY DUP EMIT
                        13 =    IF  10 EMIT THEN        \ if CR, also LF
                AGAIN   ;

