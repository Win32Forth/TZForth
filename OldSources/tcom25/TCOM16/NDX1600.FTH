\ NDX1600.SEQ   TCOM's Index file builder for 1600 by T. Zimmer & J. Boutelle

only forth definitions assembler also host also compiler also forth also

codebytes pointer seg-ext       \ target origin extention byte segment

: ecs:          ( eaddr -- eseg eaddr ) seg-ext swap ;

I: c!-e         ( char taddr -- )       there ecs: c!l ;

: ext_init      ( -- )
                seg-ext 0=              \ allocate the space needed for
                                        \ the target compile process
                if      0 " Not enough memory for compile buffer"
                        "errmsg nosave abort
                then
                codebytes $10000. d< abort" 'DATABYTES' must be 64k"
                seg-ext      0 $8000 0 lfill
                seg-ext  $8000 $8000 0 lfill    \ Zero out 64k of ext area
                ;

\+ bin_read ' noop is bin_read  \ disable the read of precompiled code

-1 value last_taddr

: xC,-T         ( b1 -- )
                here-t last_taddr <>
                if      bytetype here-t index!
                then
                defers c,-t
                spindata
                here-t !> last_taddr ;

' xc,-t is c,-t

: x,-T          ( n1 -- )
                here-t last_taddr <>
                if      wordtype here-t index!
                then
                defers ,-t
                spindata
                here-t !> last_taddr ;

' x,-t is ,-t

: xS,-T         ( a1 n1 -- )
                stringtype here-t index!
                defers s,-t ;

' xs,-t is s,-t

: xallot-t      ( n1 -- )
                dup
                case
                        1 of  bytetype   here-t index!  endof
                        2 of  wordtype   here-t index!  endof
                              stringtype here-t index!
                              drop
                endcase
                defers allot-t ;

' xallot-t is allot-t

: xC!-T         ( b1 a1 -- )
                bytetype over index!         \ don't index extent bytes
                defers c!-t ;

' xc!-t is c!-t

: x!-T          ( n1 a1 -- )
                wordtype over index!
                defers !-t ;

' x!-t is !-t

: ?1600sizecheck  ( -- )
                ?overlimit ?exit
                here-top rombytes 1- u>
                dp-tsave rombytes 1- u> or
                if      0 " Target ROM SIZE EXCEEDED!" "errmsg
                        on> ?overlimit
                then    ;

switch ?sizecheck ?1600sizecheck

only forth also definitions

