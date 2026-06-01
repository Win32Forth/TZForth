\\ DECIDE.SEQ   Ask the user to answer a question       by J”rg Staben

Note from Tom Zimmer:

    This program is a minor rework of a program by J”rg Staben
    called "YES_NO" that performs a similar function.

    I have added enhancements to accept a following string argument
    that will be displayed before prompting for an answer from the
    user.

    Other minor changes help keep the program down to a manageble size.

{
                .options /opt /noinit

macro errorlevel ( n1 -- )      \ Terminate program with error level n1
                mov ax, bx
                mov ah, # $4C
                int $21         \ Program never returns from this interrupt,
                end-macro       \ so there is no need to reload BX.

: do_yes        ( -- )          \ This subroutine just saves some program
                ." Yes" 1 ;     \ space, it is referenced three times.

: decide        ( -- )          \ ask user for a decision
                dosio_init
                dos_to_tib
                ?ds: sseg !
                0 word c@
                if      here count bl skip type cr
                then    ." Yes, No or F1=Help (Y/N/F1) [Y] ? "
                key upc
                CASE    $0D OF  do_yes           ENDOF
                        'J' OF  do_yes           ENDOF
                        'Y' OF  do_yes           ENDOF
                        'N' OF  ." No"         0 ENDOF
                                ." Help" drop -1
                ENDCASE errorlevel ;

