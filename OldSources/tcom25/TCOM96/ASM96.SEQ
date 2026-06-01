\\ ASM96.SEQ  assembler for 8096 and 80196

Adapted by Mike Mayo from PASM.SEQ,
a PREFIX & POSTFIX assembler by Robert L. Smith & Tom Zimmer

{
\ anew assem96

warning off     \ lots of redefinitions, I DON'T want to know about!

only FORTH definitions

vocabulary ASM96
' ASM96 alias [ASM96] immediate

only FORTH also ASSEMBLER also ASM96 definitions also

\ some alias headers so we dont have to redefine these words in
\ the new target assembler.

' $             alias $
' $:            alias $:
' ll-global?    alias ll-global?
' ll-errs?      alias ll-errs?
' end-code      alias end-code  immediate
' end-code      alias c;        immediate
' here          alias here
' tc@           alias tc@
' tc!           alias tc!
' t!            alias t!
' ,             alias ,
' c,            alias c,
' ic,           alias ic,
' cc,           alias cc,
' oc,           alias oc,
' o,            alias o,
' a;            alias a;                \ normal a;
' offset_8,     alias offset_8,
' offset_16,    alias offset_16,
' relative_8,   alias relative_8,
' relative_16,  alias relative_16,
' asm!lref      alias asm!lref
' reserr        alias reserr            \ any lower = error
' res_byte/rel  alias res_byte/rel      \ type 1
' res_word/rel  alias res_word/rel      \ type 2
' res_byte/off  alias res_byte/off      \ type 3
' res_word/off  alias res_word/off      \ type 4
' resolve_ref   alias resolve_ref

only FORTH also ASM96 definitions also

: a;!                           \ modified a;!
        >in_word c@ !> asm->in  \ save the source column position
        a;!                     \ normal a;!
        ;

\ : Ic, ( n -- )  \ a special c, that tells the indexer that this is
\                 \ the first byte of an instruction
\         on>  firstcodebyte
\         c,      \ This is c, from the ASSEMBLER vocabulary
\         off> firstcodebyte
\         ;

: SAc, ( n -- ) \ Signed Absolute c,
                \ Tells the indexer that this is a byte of code, not the first
\         on>  othercodebyte
        dup -128 127 between
        0= ABORT"  SIGNED-ABSOLUTE out of range"
        oc,
\         off> othercodebyte
        ;
: Ac, ( n -- ) \ a special c, for absolute references
               \ Tells the indexer that this is a byte of code, not the first
\         on>  othercodebyte
        OFFSET_8,
\         off> othercodebyte
        ;
: A, ( n -- )   \ a special ,  for absolute references
                \ Tells the indexer that this is a byte of code, not the first
\         on>  othercodebyte
        OFFSET_16,
\         off> othercodebyte
        ;

: Rc, ( n -- )  \ a special c, for relative references
                \ Tells the indexer that this is a byte of code, not the first
\         on>  othercodebyte
        RELATIVE_8,
\         off> othercodebyte
        ;
: R, ( n -- )   \ a special ,  for relative references
                \ Tells the indexer that this is a byte of code, not the first
\         on>  othercodebyte
        RELATIVE_16,
\         off> othercodebyte
        ;

: shortc, ( a1 opcode -- ) \ compile a SJMP or SCALL
        here 5 asm!lref                         \ resolver type 5
        >r here 2+ -  dup FLIP $07 and r> or Ic,
\         on>  othercodebyte
        $0ff and oc,
\         off> othercodebyte
        ;

: res_short ( targ_addr -- ) \ resolve a forward SJMP or SCALL
        [ compiler ]
        dup>r c@-t              \ get opcode
        [ asm96 ]
        $F8 and flip            \ regenerate opcode without offset
        here r@ -  2-           \ make the proper offset
        $7FF and or             \ merge into opcode
        dup flip r@ tc! r> 1+ tc!       \ store the instruction
        ;

: resolve_8096 ( targ_addr res_type -- ) \ resolve a forward reference
                0max 6 min exec:
                reserr                                  \ any lower = error
                res_byte/rel                            \ type 1
                res_word/rel                            \ type 2
                res_byte/off                            \ type 3
                res_word/off                            \ type 4
                res_short                               \ type 5
                reserr ;                                \ any higher = error

' resolve_8096 is resolve_ref

FORTH DEFINITIONS assembler also

: DOASSEM96     ( --- )
                  ['] RUN-A; IS RUN
                0 ['] DROP A;!
                APRIOR 4 + 2@ APRIOR 2!
                ll-global? 0=
                if      llab-init               \ in case labels used
                then
                ASMSTUFF ALSO ASM96 ;

: setasm96      ['] DOASSEM96 IS SETASSEM  ;
\ : setasm86      ['] doassem   is setassem  ;

setasm96

ONLY FORTH ALSO ASM96 DEFINITIONS ALSO


\ Equates to Addressing Modes

0 CONSTANT RDIRECT       1 CONSTANT IMMED     2 CONSTANT INDIRECT
3 CONSTANT INDEXED

VARIABLE AMODE \ 0 = register direct    1 = immediate
               \ 2 = indirect           3 = indexed
VARIABLE AUTOINC \ 0 = don't auto-increment   1 = do auto-increment

\ Assembler words for setting addressing mode

: []    INDIRECT AMODE ! ;
: []+   INDIRECT AMODE !   1 AUTOINC !  ;
: #     IMMED    AMODE ! ;
: [I]   INDEXED  AMODE ! ;

VARIABLE SDMODE  \ for 3-operand instructions
: <--   SDMODE ON  ;

\ Initialize all variables and flags

headers

: RESETF   0 AMODE !  0 AUTOINC !  0 SDMODE !  ;

headerless


: breg ( breg -- ) \ assemble a byte register reference
        DUP   256 <  IF    Ac,
                     ELSE  " reg over 255" doerror
                     THEN    ;

: wreg ( wreg -- ) \ assemble a word register reference
        DUP 1 AND 0= IF    breg
                     ELSE  DROP  " wreg not even" doerror
                     THEN    ;

: Lreg ( Lreg -- ) \ assemble a long register reference
        DUP 3 AND 0= IF    breg
                     ELSE  DROP  " Lreg not /4" doerror
                     THEN    ;


\ Words to build the instructions:

: 1MIF          ( A1 --- )
                C@ Ic, RESETF ;           \ Single Byte Inst.

: 1MI     CREATE C, DOES> ['] 1MIF A;! A; ;


: 2MIF          ( A1 -- )
                C@ Ic, breg  RESETF ;     \ e.g. CLRB breg

: 2MI     CREATE C, DOES> ['] 2MIF A;! A; ;


: 3MIF          ( A1 -- )
                C@ Ic, wreg  RESETF ;     \ e.g. CLR wreg

: 3MI     CREATE C, DOES> ['] 3MIF A;! A; ;


: 4MIF          ( A1 -- )
                C@ Ic, breg Lreg  RESETF ;     \ e.g. SHLL Lreg cnt/breg

: 4MI     CREATE C, DOES> ['] 4MIF A;! A; ;


: 5MIF          ( A1 -- )
                C@ Ic, breg breg  RESETF ;     \ e.g. SHLL breg cnt/breg

: 5MI     CREATE C, DOES> ['] 5MIF A;! A; ;


: 6MIF          ( A1 -- )
                C@ Ic, breg wreg  RESETF ;     \ e.g. SHLL wreg cnt/breg

: 6MI     CREATE C, DOES> ['] 6MIF A;! A; ;


VARIABLE MIOP
: 7MIF  ( waop A1 -- )   \ e.g. PUSH  POP
        ( offset wreg A1 -- )  \ indexed
    C@ MIOP !
    AMODE @ CASE
        0 OF    DUP 256 < IF    MIOP @ Ic,  wreg   \ register direct
                          ELSE  MIOP @ 3 OR Ic,    \ long indexed pseudo-direct
                                1 Ac,  A,
                          THEN
          ENDOF
        1 OF    MIOP @ 1 OR Ic,  A,  ENDOF        \ immediate
        2 OF    MIOP @ 2 OR Ic,                  \ indirect
                $0FE AND  AUTOINC @ OR  Ac,  ENDOF
        3 OF    MIOP @ 3 OR Ic,                  \ indexed
                over -128 127
                between IF    $0FE AND Ac,  SAc, \  -short
                        ELSE  1 OR Ac, A,        \  -long
                        THEN
          ENDOF
    ENDCASE
    RESETF ;

: 7MI     CREATE C, DOES> ['] 7MIF A;! A; ;


: SD?Ic, ( opcode -- )      \  switch for 3-operand instructions
        SDMODE @ IF  MIOP C@ $1C or
                     $7C <> if ." Not a 3-operand instruction "  then
                     $20 xor
               THEN
        Ic,  ;

: 8MIF  ( breg baop A1 -- )  \ e.g. ADDB breg baop
        ( breg offset wreg A1 -- ) \ indexed
        ( Dbreg Sbreg baop A1 -- ) \ e.g. ADDB Dbreg <-- Sbreg baop
    C@ MIOP !
    AMODE @ CASE
        0 OF    DUP 256 < IF    MIOP @ SD?Ic,  breg   \ register direct
                          ELSE  MIOP @ 3 OR SD?Ic,    \ long indexed pseudo-direct
                                1 Ac,  A,
                          THEN
          ENDOF
        1 OF    MIOP @ 1 OR SD?Ic,  Ac,  ENDOF        \ immediate
        2 OF    MIOP @ 2 OR SD?Ic,                  \ indirect
                $0FE AND  AUTOINC @ OR  Ac,  ENDOF
        3 OF    MIOP @ 3 OR SD?Ic,                  \ indexed
                over -128 127
                between IF    $0FE AND Ac,  SAc, \  -short
                        ELSE  1 OR Ac, A,        \  -long
                        THEN
          ENDOF
    ENDCASE
    breg  SDMODE @ IF breg THEN   RESETF ;

: 8MI     CREATE C, DOES> ['] 8MIF A;! A; ;


: 9MIF  ( wreg waop A1 -- )   \ e.g. ADD wreg waop
        ( wreg offset wreg A1 -- ) \ indexed
    C@ MIOP !
    AMODE @ CASE
        0 OF  DUP 256 < IF    MIOP @ SD?Ic,  wreg  \ register direct
                        ELSE  MIOP @ 3 OR SD?Ic,   \ long indexed pseudo-direct
                              1 Ac,  A,
                        THEN
          ENDOF
        1 OF    MIOP @ 1 OR SD?Ic,  A,  ENDOF        \ immediate
        2 OF    MIOP @ 2 OR SD?Ic,                  \ indirect
                $0FE AND  AUTOINC @ OR  Ac,  ENDOF
        3 OF    MIOP @ 3 OR SD?Ic,                  \ indexed
                over -128 127
                between IF    $0FE AND Ac,  SAc, \  -short
                        ELSE  1 OR Ac, A,        \  -long
                        THEN
          ENDOF
    ENDCASE
    wreg  SDMODE @ IF wreg THEN   RESETF ;

: 9MI     CREATE C, DOES> ['] 9MIF A;! A; ;


: 10MIF  ( Lreg waop A1 -- )      \ e.g. DIVU Lreg waop
         ( Lreg offset wreg A1 -- ) \ indexed
         ( Lreg wreg waop A1 -- ) \ e.g. MUL Lreg <-- wreg waop
    C@ MIOP !
    AMODE @ CASE
        0 OF  DUP 256 < IF    MIOP @ SD?Ic,  wreg  \ register direct
                        ELSE  MIOP @ 3 OR SD?Ic,   \ long indexed pseudo-direct
                              1 Ac,   A,
                        THEN
          ENDOF
        1 OF    MIOP @ 1 OR SD?Ic,  A,  ENDOF        \ immediate
        2 OF    MIOP @ 2 OR SD?Ic,                  \ indirect
                $0FE AND  AUTOINC @ OR  Ac,  ENDOF
        3 OF    MIOP @ 3 OR SD?Ic,                  \ indexed
                over -128 127
                between IF    $0FE AND Ac,  SAc, \  -short
                        ELSE  1 OR Ac, A,        \  -long
                        THEN
          ENDOF
    ENDCASE
    SDMODE @ IF  wreg  THEN    Lreg   RESETF ;

: 10MI     CREATE C, DOES> ['] 10MIF A;! A; ;


: 11MIF  ( wreg baop A1 -- )      \ e.g. DIVUB wreg baop
         ( wreg offset wreg A1 -- ) \ indexed
         ( wreg breg baop A1 -- ) \ e.g. MULB wreg <-- breg baop
    C@ MIOP !
    AMODE @ CASE
        0 OF  DUP 256 < IF    MIOP @ SD?Ic,  breg  \ register direct
                        ELSE  MIOP @ 3 OR SD?Ic,   \ long indexed pseudo-direct
                              1 Ac,   A,
                        THEN
          ENDOF
        1 OF    MIOP @ 1 OR SD?Ic,  Ac,  ENDOF       \ immediate
        2 OF    MIOP @ 2 OR SD?Ic,                  \ indirect
                $0FE AND  AUTOINC @ OR  Ac,  ENDOF
        3 OF    MIOP @ 3 OR SD?Ic,               \ indexed
                over -128 127
                between IF    $0FE AND Ac,  SAc, \  -short
                        ELSE  1 OR Ac, A,        \  -long
                        THEN
          ENDOF
    ENDCASE
    SDMODE @ IF  breg  THEN    wreg   RESETF ;

: 11MI     CREATE C, DOES> ['] 11MIF A;! A; ;


: LCALLf  ( destination 0 -- )             \ LCALL
        drop
        $0EF Ic,  R,
        RESETF    ;
: LCALL   0  ['] LCALLf A;! A; ;

: SCALLf  ( destination 0 -- )             \ SCALL
        drop
        $28 shortc,
        RESETF    ;
: SCALL   0  ['] SCALLf A;! A; ;

: CALLf  ( destination 0 -- )             \ SCALL and LCALL
        drop  DUP   HERE 2+ -
        -1024 1023  between IF  0 SCALLf  ELSE  0 LCALLf  THEN   ;
: CALL   0  ['] CALLf A;! A; ;


: LJMPf  ( destination 0 -- )             \ LJMP
        drop
        $0E7 Ic,  R,
        RESETF    ;
: LJMP   0  ['] LJMPf A;! A; ;

\ $E7 =: JMP_OPCODE       \ Make long label test use the right OPCODE

: SJMPf  ( destination 0 -- )             \ SJMP
        drop
        $20 shortc,
        RESETF    ;
: SJMP    0  ['] SJMPf A;! A; ;

: JMPf  ( destination 0 -- )             \ SJMP and LJMP
        drop  DUP   HERE 2+ -
        -1024 1023  between IF  SJMPf  ELSE  LJMPf  THEN   ;
: JMP   0  ['] JMPf A;! A; ;


: JBCf ( breg n destination 0 -- )                  \ JBC
        drop  swap 7 and $30 or  Ic,
        swap breg
        Rc,
        RESETF ;
: JBC  0  ['] JBCf A;! A; ;

: JBSf ( breg n destination 0 -- )                  \ JBS
        drop  swap 7 and $38 or  Ic,
        swap breg
        Rc,
        RESETF ;
: JBS  0  ['] JBSf A;! A; ;

: DJNZf  ( breg destination 0 -- )      \ DJNZ for labels
        drop   $E0 Ic,  swap breg
        Rc,
        RESETF    ;
: DJNZ    0  ['] DJNZf A;! A; ;

: DJNZWf ( breg destination 0 -- )      \ DJNZW for labels
        drop   $E1 Ic,  swap wreg
        Rc,
        RESETF ;
: DJNZW  0  ['] DJNZWf A;! A; ;



\ jump instructions for IF ELSE THEN etc.

: BITSETf ( breg n 0 -- )               \ BITSET breg n IF
        drop  7 and $30 or  Ic,  breg
        RESETF ;
: BITSET  0  ['] BITSETf A;! A; ;

: BITCLEARf ( breg n 0 -- )             \ BITCLEAR breg n IF
        drop  7 and $38 or  Ic,  breg
        RESETF ;
: BITCLEAR  0  ['] BITCLEARf A;! A; ;

: DEC0=f ( breg 0 -- )                  \ DEC0= breg UNTIL
        drop  $E0 Ic,  breg
        RESETF ;
: DEC0=  0  ['] DEC0=f A;! A; ;

: WDEC0=f ( breg 0 -- )                 \ WDEC0= wreg UNTIL
        drop  $E1 Ic,  wreg
        RESETF ;
: WDEC0=  0  ['] WDEC0=f A;! A; ;


headers

\ Now let's create the actual instructions.

$F8     1MI     CLRC
$FC     1MI     CLRVT
$FA     1MI     DI
$FB     1MI     EI
$FD     1MI     NOP
$F5     1MI     POPA
$F3     1MI     POPF
$F4     1MI     PUSHA
$F2     1MI     PUSHF
$F0     1MI     RET
$FF     1MI     RST
$F9     1MI     SETC
$F7     1MI     TRAP
\ $F1  $F6  $FE

$11     2MI     CLRB
$15     2MI     DECB
$17     2MI     INCB
$13     2MI     NEGB
$12     2MI     NOTB
$00     2MI     SKIP

$E3     3MI     BR[]
$01     3MI     CLR
$05     3MI     DEC
$16     3MI     EXTB
$07     3MI     INC
$03     3MI     NEG
$02     3MI     NOT

$0F     4MI     NORML
$0D     4MI     SHLL
$0E     4MI     SHRAL
$0C     4MI     SHRL

$19     5MI     SHLB
$1A     5MI     SHRAB
$18     5MI     SHRB

$09     6MI     SHL
$08     6MI     SHR
$0A     6MI     SHRA

$CC     7MI     POP
$C8     7MI     PUSH

$74     8MI     ADDB
$B4     8MI     ADDCB
$70     8MI     ANDB
$98     8MI     CMPB
$B0     8MI     LDB
$90     8MI     ORB
$C4     8MI     STB
$78     8MI     SUBB
$B8     8MI     SUBCB
$94     8MI     XORB

$64     9MI     ADD
$A4     9MI     ADDC
$60     9MI     AND
$88     9MI     CMP
$A0     9MI     LD
$80     9MI     OR
$C0     9MI     ST
$68     9MI     SUB
$A8     9MI     SUBC
$84     9MI     XOR

$8C    10MI     DIVU
$6C    10MI     MULU

: DIV   A; $0FE Ic, DIVU ;
: MUL   A; $0FE Ic, MULU ;

$9C    11MI     DIVUB
$7C    11MI     MULUB
$AC    11MI     LDBZE
$BC    11MI     LDBSE

: DIVB   A; $0FE Ic, DIVUB ;
: MULB   A; $0FE Ic, MULUB ;


\ other individual types

: EXTf  ( Lreg -- )
        drop  $06 Ic,  Lreg   RESETF ;         \ EXT
: EXT   0  ['] EXTf A;! A; ;

1 value IDLE    2 value POWERDOWN    3 value RESETCPU \ keys for IDLPD
: IDLPDf  ( key -- )
        drop  $06 Ic,  Ac,   RESETF ;           \ IDLPD key
: IDLPD   0  ['] IDLPDf A;! A; ;

: NORMLf ( Lreg breg -- )
        drop  $0F Ic,  breg Lreg  RESETF ;     \ NORML Lreg breg
: NORML   0  ['] NORMLf A;! A; ;

: CMPLf ( Lreg Lreg -- )
        drop  $C5 Ic,  Lreg Lreg  RESETF ;     \ CMPL dLreg sLreg
: CMPL   0  ['] CMPLf A;! A; ;

: BMOVf ( Lreg wreg -- )
        drop  $C1 Ic,  wreg Lreg  RESETF ;     \ BMOV Lreg wreg
: BMOV   0  ['] BMOVf A;! A; ;


headerless

: 12MIf ( A1 A2 -- )
        C@ Ic,  Rc,  RESETF ;         \ Conditional jumps
: 12MI  CREATE C, DOES> ['] 12MIF A;! A; ;

headers

$D0 12MI JNST
$D8 12MI JST

$D1 12MI JNH
$D9 12MI JH

$D2 12MI JGT
$DA 12MI JLE

$D3 12MI JNC
$DB 12MI JC

$D4 12MI JNVT
$DC 12MI JVT

$D5 12MI JNV
$DD 12MI JV

$D6 12MI JGE
$DE 12MI JLT

$D7 12MI JNE
$DF 12MI JE


\ The same conditional jumps, but for assembler IF, BEGIN, etc..
headerless

: 13MIf ( A1 A2 -- )
        C@ Ic,  RESETF ;                 \ compile only the first byte
: 13MI  CREATE C, DOES> ['] 13MIF A;! A; ;

headers

$D0 13MI ST0<>      \ JNST
$D8 13MI ST0=       \ JST

$D1 13MI U0>        \ JNH
$D9 13MI U0<=       \ JH

$D2 13MI 0<=        \ JGT
$DA 13MI 0>         \ JLE

$D3 13MI C0<>       \ JNC
$DB 13MI C0=        \ JC

$D4 13MI VT0<>      \ JNVT
$DC 13MI VT0=       \ JVT

$D5 13MI OV0<>      \ JNV
$DD 13MI OV0=       \ JV

$D6 13MI 0<         \ JGE
$DE 13MI 0>=        \ JLT

$D7 13MI 0=         \ JNE
$DF 13MI 0<>        \ JE

$20 13MI UJMP>      \ SJMP forwards up to 127
$27 13MI <UJMP      \ SJMP backwards up to 128

: x?>MARK    ( -- f addr ) TRUE   HERE   0 Ac,   ;
: x?>RESOLVE ( f addr -- ) HERE OVER 1+ - SWAP TC! ?CONDITION ;
: x?<MARK    ( -- f addr ) TRUE   HERE   ;
: x?<RESOLVE ( f addr -- ) Rc,   ?CONDITION   ;

: BEGIN ( - a f ) A; x?<MARK ;
: UNTIL ( a f - ) A; x?<RESOLVE ;
: AGAIN ( a f - ) A; <UJMP UNTIL ;              \ SJMP backwards up to 127
: IF    ( - A f ) A; x?>MARK ;
: THEN ( A f - )  A; x?>RESOLVE ;
: ELSE ( A f - A f ) A; UJMP> IF                \ SJMP forwards up to 127
                     2SWAP THEN ;
: REPEAT ( A f a f - )  AGAIN THEN ;
: WHILE ( a f - A f a f ) IF 2SWAP ;





\  behead

}
    Symbolic names for the i/o registers of the 8096 and the 80c196
{
hex

0       constant    R0
2       constant    AD_RESULT
2       constant    AD_COMMAND
3       constant    HSI_MODE
4       constant    HSO_TIME
4       constant    HSI_TIME
6       constant    HSO_COMMAND
6       constant    HSI_STATUS
7       constant    SBUF
8       constant    INT_MASK
9       constant    INT_PEND
0A      constant    TIMER1
0A      constant    WATCHDOG
0B      constant    IOC2
0C      constant    TIMER2
0E      constant    BAUD_RATE
0E      constant    IOPORT0
0F      constant    IOPORT1
10      constant    IOPORT2
11      constant    SP_CON
11      constant    SP_STAT
12      constant    INT_PEND1
13      constant    INT_MASK1
14      constant    WSR
15      constant    IOC0
15      constant    IOS0
16      constant    IOC1
16      constant    IOS1
17      constant    PWM_CONTROL
17      constant    IOS2
18      constant    SP

decimal


ONLY FORTH DEFINITIONS ALSO


