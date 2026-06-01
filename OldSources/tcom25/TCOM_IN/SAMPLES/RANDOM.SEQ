\ RANDOM.SEQ           Generate a random number        by Tom Zimmer
        .options /opt /noinit                   \ compiler options

comment:
  Command line program to generate a random number from a specified limit
value given on the command line.

        Usage:  RANDOM {limit_number(1-32000) {text to prepend}}

      Example:  RANDOM 4 SET IDLE=>TMP.BAT

  The above example will create a file containing the following line:

                SET IDLE=x

  Where "x" is a random number in the range 0 to 4 inclusive.

  This is useful for performing a random batch file program selection as
is shown in the following batch file example:

        --------------------------------------------------

                @echo off
                random 4 set idle=>tmp.bat
                call tmp
                del tmp.bat
                if "%idle%"=="0" ssblit
                if "%idle%"=="1" gclock
                if "%idle%"=="2" rings
                if "%idle%"=="3" gss
                if "%idle%"=="4" linescan
                set idle=

        --------------------------------------------------

  This batch file example allows the random invocation of one of a set
of screen saver programs depending on the result returned by RANDOM.

  NOTE: The only difficulty with the above technique is that is does
require some environment space (in this case about 8 bytes) to work.

  Compile RANDOM with the following command line:

        TCOM RANDOM <enter>

  **********************************************************************

comment;

0 value SEED1
0 value SEED2
0 value SEED3

CODE (RANDOMIZE) ( -- u )
                save_bx
                MOV AH, # 0
                INT 26
                mov bx, dx
                ret     END-CODE

: RANDOMIZE     ( -- )
                (RANDOMIZE)        !> SEED1
                (RANDOMIZE) 2* 1-  !> SEED2
                (RANDOMIZE) 2/ 1+  !> SEED3 ;

: RND           ( n1 -- n2 )
                1 max
                SEED1 177 /MOD  2*    SWAP  171 *  SWAP  - DUP  !> SEED1
                SEED2 176 /MOD  35 *  SWAP  172 *  SWAP  - DUP  !> SEED2
                SEED3 178 /MOD  63 *  SWAP  170 *  SWAP  - DUP  !> SEED3
                +  + SWAP  MOD  ;

: main          ( -- )
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                    \ default to min code space
                DOS_TO_TIB                      \ move command tail to TIB
                randomize
                bl word ?uppercase number? 2drop
                1+ 1 max 32768 umin rnd
                0 word count type 1 .r ;

