\\ YESNO.SEQ


{
.options /opt /noinit

macro errorlevel ( n1 -- )      \ Terminate program with error level n1
                mov ax, bx
                mov ah, # $4C
                int $21         \ program never returns from this interrupt,
                end-macro       \ so there is no need to reload BX

: do_yes        ( -- )
                ." Yes" 1 ;

: yes_no        ( -- )
                dosio_init
                ." Yes, No or F1=Help (Y/N/F1) [Y] ? "
                key upc
                CASE    $0D OF  do_yes                  ENDOF
                        'J' OF  do_yes                  ENDOF
                        'Y' OF  do_yes                  ENDOF
                        'N' OF  ." No"         0        ENDOF
                                ." Help" drop 255
                ENDCASE errorlevel ;

