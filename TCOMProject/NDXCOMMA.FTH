\ NDXCOMMA.SEQ TCOM's Index file support for TCOM by T. Zimmer & J. Boutelle

only forth definitions assembler also host also compiler also forth also

: xC,-T         ( b1 -- )
                bytetype here-t index!
                defers c,-t ;

' xc,-t is c,-t

: x,-T          ( n1 -- )
                wordtype here-t index!
                defers ,-t ;

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
                dup $8000 u<
                IF bytetype over index!         \ don't index extent bytes
                THEN defers c!-t ;

' xc!-t is c!-t

: x!-T          ( n1 a1 -- )
                wordtype over index!
                defers !-t ;

' x!-t is !-t


only forth also definitions

