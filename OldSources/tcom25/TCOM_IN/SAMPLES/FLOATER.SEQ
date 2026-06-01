\ FLOATER.SEQ       A VERY simple floating point example  by tjz & rls

        .options /opt /definit

needs tfloat.seq                        \ load floating point support

F# 1.23E6 FCONSTANT ONE_TWO_THREE_E_SIX

: main          ( -- )
                fclear                  \ floating point stack MUST be inited
                [F#] 110000.456 f.      \ use [F#] inside of colon defs for
                one_two_three_e_six     \ another floating point number
                FDUP                    \ duplicate it
                F.                      \ one form of floating point display
                E.                      \ exponential display format
                ;

