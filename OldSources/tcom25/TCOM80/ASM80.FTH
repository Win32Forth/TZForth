\\ ASM80.SEQ            An 8080 Assembler          05/08/90 TJZ

The 8080 Assembler is largely due to John Cassady, who recently
published it in Forth Dimensions.  It implements the full 8080
instruction set as well as structured conditionals.  To create
an Assembler language definition, use the defining word CODE.
It may, but does not have to be, terminated with C;.  How the
assembler operates is a very interesting example of the power
of CREATE DOES>  Basically, the instructions are categorized
and a defining word is created for each category.  When the
mnemonic for the instruction is interpreted, it compiles
itself.

Modified for F-PC and TCOM by Tom Zimmer 05/08/90

{

WARNING OFF

ONLY FORTH ALSO DEFINITIONS VOCABULARY ASM80
' ASM80 ALIAS [ASM80] IMMEDIATE
ONLY FORTH ALSO ASSEMBLER ALSO ASM80 DEFINITIONS ALSO

\ some alias headers so we dont have to redefine these words in
\ the new target assembler.

        ' a;            alias a;
        ' a;!           alias a;!
        ' $             alias $
        ' $:            alias $:
        ' ll-global?    alias ll-global?
        ' ll-errs?      alias ll-errs?
        ' end-code      alias end-code  immediate
        ' end-code      alias c;        immediate
        ' c,            alias c,
        ' ,             alias ,
        ' here          alias here
        ' tc@           alias tc@
        ' tc!           alias tc!
        ' t!            alias t!
        ' IC,           ALIAS IC,
        ' OC,           ALIAS OC,
        ' CC,           ALIAS CC,
        ' O,            ALIAS O,
        ' OFFSET_16,    ALIAS OFFSET_16,
        ' OFFSET_8,     ALIAS OFFSET_8,

FORTH DEFINITIONS

: DOASSEM80     ( --- )
                @> RUN =: ARUNSAVE
                  ['] RUN-A; IS RUN
                0 ['] DROP A;!
                APRIOR 4 + 2@ APRIOR 2!
                LIHERE =: LINESTRT
                ll-global? 0=
                if      llab-init               \ in case labels used
                then
                ALSO ASM80 ;

: SETASM80      ['] DOASSEM80 IS SETASSEM  ;

SETASM80

ONLY FORTH ALSO ASM80 DEFINITIONS ALSO

\ 8080 Assembler Defining Words & Registers           09MAR83HHL

7 CONSTANT A
0 CONSTANT B   1 CONSTANT C      2 CONSTANT D   3 CONSTANT E
0 CONSTANT I   1 CONSTANT I'     2 CONSTANT W   3 CONSTANT W'
0 CONSTANT IP  1 CONSTANT IP'    4 CONSTANT H   5 CONSTANT L
6 CONSTANT M   6 CONSTANT PSW    6 CONSTANT SP  6 CONSTANT S

: 1MI CREATE C, DOES> C@ IC, ;
: 2MI CREATE C, DOES> C@ + IC, ;
: 3MI CREATE C, DOES> C@ SWAP 8* + IC, ;
: 4MI CREATE C, DOES> C@ IC, OC, ;
: 5MI CREATE C, DOES> C@ IC, OFFSET_16, ;
: 6MI CREATE C, DOES> C@ CC, OFFSET_16, ;

\ 8080 Assembler mnemonics                            09MAR83HHL

$00 1MI NOP   $76 1MI HLT  $F3 1MI DI   $FB 1MI EI    $07 1MI RLC
$0F 1MI RRC   $17 1MI RAL  $1F 1MI RAR  $E9 1MI PCHL  $EB 1MI XCHG
$C9 1MI RET   $C0 1MI RNZ  $C8 1MI RZ   $D0 1MI RNC   $D8 1MI RC
$2F 1MI CMA   $37 1MI STC  $3F 1MI CMC  $F9 1MI SPHL  $E3 1MI XTHL
$E0 1MI RPO   $E8 1MI RPE  $F8 1MI RM   $27 1MI DAA

$80 2MI ADD   $88 2MI ADC  $90 2MI SUB  $98 2MI SBB   $A0 2MI ANA
$A8 2MI XRA   $B0 2MI ORA  $B8 2MI CMP

$02 3MI STAX  $04 3MI INR
$03 3MI INX   $09 3MI DAD  $0B 3MI DCX  $C1 3MI POP   $C5 3MI PUSH
$C7 3MI RST   $05 3MI DCR  $0A 3MI LDAX

$D3 4MI OUT   $DB 4MI IN
$C6 4MI ADI   $CE 4MI ACI  $D6 4MI SUI  $DE 4MI SBI   $E6 4MI ANI
$EE 4MI XRI   $F6 4MI ORI  $FE 4MI CPI

$22 5MI SHLD
$2A 5MI LHLD  $32 5MI STA  $3A 5MI LDA  $C3 5MI JMP
$C2 5MI JNZ   $CA 5MI JZ   $D2 5MI JNC  $DA 5MI JC   $E2 5MI JPO
$EA 5MI JPE   $F2 5MI JP   $FA 5MI JM

$CD 6MI CALL

\ 8080 Assembler Branches                             29AUG84MJM

$DA CONSTANT C0=  $D2 CONSTANT C0<>  $D2 CONSTANT CS
$C2 CONSTANT 0=   $CA CONSTANT 0<>   $E2 CONSTANT PE
$F2 CONSTANT 0<   $FA CONSTANT 0>=

: NOT           8 [ FORTH ] XOR   ;
: MOV           8* $40 + +  IC, ;        \ source destination MOV
: MVI           8*   6 +    IC, OC, ;
: LXI           8*   1+     IC, OFFSET_16, ;

: x?>MARK       ( -- f addr )           TRUE   HERE   0 ,   ;
: x?>RESOLVE    ( f addr -- )           HERE SWAP T! ?CONDITION ;
: x?<MARK       ( -- f addr )           TRUE   HERE   ;
: x?<RESOLVE    ( f addr -- )           O,   ?CONDITION   ;

: BEGIN         ( - a f )               A; x?<MARK ;
: UNTIL         ( a f n - )             >R A; R> IC, x?<RESOLVE A; ;
: AGAIN         ( a f - )               $0C3 UNTIL ;
: IF            ( n - A f )             >R A; R> IC, x?>MARK A; ;
: FORWARD       ( - A f )               $0C3 IF ;
: THEN          ( A f - )               A; x?>RESOLVE ;
: AFT           ( a f - a f A f )       2DROP FORWARD BEGIN 2SWAP ;
: ELSE          ( A f - A f )           FORWARD 2SWAP THEN ;
: REPEAT        ( A f a f - )           A; AGAIN THEN ;
: CONTINUE      (  a f A f - a f )      2OVER REPEAT ;
: WHILE         ( a f - A f a f )       IF 2SWAP ;

CR .( 8080 Machine Dependent Code Loaded )

ONLY FORTH ALSO DEFINITIONS

WARNING ON

