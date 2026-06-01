\\ Warm- oder Kaltstart des Rechners auslîsen
Programmiersprache:
        Forth

Compiler:
        F-PC 3.56 / TCOM 8086 xxxx  2.26

Autor:
         ⁄ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒø
         ≥      Jîrg Staben             ≥
         ≥      Hagelkreuzstr. 23       ≥
         ≥      D-4010 HILDEN           ≥
         ≥      Tel.:02103-240609       ≥
         ≥                              ≥
         ≥      Mitglied der            ≥
         ≥      Forth Gesellschaft e.V. ≥
         ≥      Postfach 1110           ≥
         ≥   D - 8044 Unterschlei·heim  ≥
         ¿ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒŸ

Version:
        1.0 jrg  20.07.92 19:25
        1.1 tjz  07/27/92 09:04 Modified to compile on TCOM 8086 2.26.

        .options /opt /noinit
{
\fpc    anew booter


}
!!!!!!!!!!!!!!  TCOM - Fehlerkorrektur !!!!!!!!!!!!!!!!!1!!
        TCOM 8086 ver.2.24
        @L und !L in der TCOM-Library erwarten die
        Parameter nicht als SEG:ADDR wie angegeben, sondern
        als ADDR:SEG !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
{
\tcom   : fetch    ( seg addr -- n )     ( swap ) @l ;
                                        \ 07/27/92 Version 2.26 is fixed
\fpc    : fetch    ( seg addr -- n )     @l ;

\tcom   : store    ( n  seg addr -- )     ( swap ) !l ;
                                        \ 07/27/92 Version 2.26 is fixed
\fpc    : store    ( n  seg addr -- )     !l ;


}
**********************  jrg  20.07.92 19:54  *****************************
        Vokabular RESTART zur Aufrufsicherheit
        damit BOOT nicht sofort interaktiv aufgerufen werden kann
**************************************************************************
{
\tcom   false #IF
\fpc    true  #IF

        only forth also definitions
        Vocabulary RESTART  restart definitions
#THEN


    0 Constant cold      \ Forth kennt COLD
$1234 Constant warm      \ Forth kennt WARM

$40 $72 2Constant boot_address

}
**********************  jrg  20.07.92 19:26 *************************
        BOOT
        lîst einen Warm - oder Kaltstart aus
        Aufruf innerhalb vom Vokabular RESTART:
        cold boot | warm boot
*********************************************************************
{
\tcom   false #IF       \ added version for TCOM, INLINE is for F-PC only
\fpc    true  #IF

: boot          ( cold|warm -- )
                boot_address store
     Inline     jmp far $FFFF 0000
     End-inline
     ;


     only forth also definitions

#ELSE           \ The TCOM version uses a macro to include an instruction
                \ in the colon definition.

macro go-boot   ( -- )          \ just jump to reboot in bios
                jmp far $FFFF $0000     end-macro

: boot          ( cold|warm -- )
                boot_address store
                go-boot ;

#THEN

\ ******************    TCOM    *************************************
\tcom   false #IF
\fpc    true  #IF
        cr .( FÅr diese Applikation ist TCOM zwar besser geeignet.)
        cr .( Aber zum öbersetzen fehlt TCOM die JMP FAR Anweisung.)
        cr
        cr .( Aufruf von F-PC aus:      RESTART WARM BOOT  oder)
        cr .(                           RESTART COLD BOOT )
        \S
        #THEN



: .title        ( -- )
                cls             \ 07/27/92 09:00 tjz added
                54 4   76 13
                box&fill
                    ."  Small modifications"
                bcr ."  for      TCOM"
                bcr ."  by    Tom Zimmer"
                bcr
                bcr ."  English usage:
                bcr
                bcr ."  RESTART /W   (warm)"
                bcr ."  RESTART /C   (cold)"
                10 4   51 17
                box&fill
                    ."   BOOT    lîst ein Neustart aus   "
                bcr ."           BOOT /W  einen Warmstart"
                bcr ."           BOOT /K  einen Kaltstart"
                bcr
                bcr ."           BOOT ist FREEWARE          "
                bcr ."    und eine F-PC/TCOM Forth Anwendung"
                bcr ."            [c] J.Staben 1992         "
                bcr
                bcr ."               ?? Forth ??           "
                bcr ."          Forth Gesellschaft e.V.    "
                bcr ."          Postfach 1110              "
                bcr ."          D - 8044 UNTERSCHLEISSHEIM "
                bcr bcr
                ;

: tcom_init     ( -- )
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                ;

: main
        tcom_init
        .title
        #tib c@
[long]  IF
                bl word ?UPPERCASE
                dup  1+ c@ '/' =
                over 1+ c@ 'W' = or
                swap 1+ c@ 'C' = or
[long]          IF      here count 'W' scan nip
                        IF     cr ." Warm" warm
                        ELSE   cr ." Cold" cold
                        THEN   cr ." boot in 5 seconds, press any key to cancel"
                        50 0
                        do      1 tenths
                                key? ?leave
                        loop    key? ?exit
                        cr ." Sorry, Too Late!" boot    \ perform a reboot
                ELSE         ." Falscher Parameter; nur /w oder /k "
                        bcr  ." Valid    Parameter; is  /w or   /c "
                THEN

        ELSE
                ." Bitte Parameter /W oder /K   angeben!" bcr
                ." The   Parameter /W or   /C is needed!"
        THEN
        ;


