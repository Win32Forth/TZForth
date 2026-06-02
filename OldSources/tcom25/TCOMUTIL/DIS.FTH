\ DIS8086.SEQ   8086 Disassembler  by Charles Curley
\ Prefix conversion by  Bill Muench  9 September 88
\ conversion to TCOM and symbolic additions by Tom Zimmer  03/07/90
\ conversion to handle the new symbol format by Tom Zimmer 09/17/91
.options /opt /noinit /nostack /tailopton
comment:

  A disassembler, for taking apart .COM files built by TCOM. This
program reads a file.COM and its .SYM (symbol) files, then proceeds to
disassemble to the display with symbols. I/O redirection is
supported for output, with the normal DOS ">" symbol.  The data portion
of the .COM file is displayed at the end of the listing in a dump type
format.

        USAGE:  DIS CLOCK TIK/TOK >CLOCK.LST  [Enter]

  This will disassemble CLOCK.COM, using CLOCK.SYM to provide symbols
for the disassembly. Disassembly will start at symbol "TIK/TOK" if it
is found in the symbol table file. Output will be directed to the file
CLOCK.LST.

  If the .SYM file is not available, disassembly continues without
symbols. If NON-TCOM files are disassembled, DIS will not know how
much of the file to disassemble, but will proceed anyway until
terminated or until what it thinks is the end of file is reached. If
no symbol is specified, or the specified symbol is not found, then
disassembly starts at HEX 100.

  Disassembly with symbols is a relatively slow process, so if you
redirect output to a file, be prepared to wait upto several minutes
for the disassembly to complete.  The file created by DIS with I/O
redirection are usually fairly large, so make sure you have lots of
disk space. I ran DIS on the SZ editor, and created a file SZ.LST that
was over 600k bytes long. It took six minutes to complete on a 20mhz
80386 machine.

  A companion program to TCOM called LS86 can be used to create better
listings, with embeded source. LS86 is also much faster since it
buffers its output to minimize the DOS io redirection overhead.

comment;

\fpc    variable broken 0 broken !

: COL ( n ) #OUT @ - SPACES ;

0 value ?DISSEG:

: 2/S           ( n ct - n'| shift n right ct )
                0 ?DO U2/ LOOP ;

: 2*S           ( n ct - n' | shift n left ct )
                0 ?DO 2* LOOP ;

CODE SEXT       ( n - n' | sign extend byte to word )
                MOV AX, BX
                CBW
                MOV BX, AX
                RET             END-CODE

: 8086-t@       ( a - w ) ?disseg: swap @l ;
: d-tc@         ( a - n ) ?disseg: swap c@l ;

: .#            ( -- ) ." # " ;

: .,            ( -- ) ." , " ;

: ?.,           ( op - op ) DUP $0C7 AND 6 <> IF ., THEN ;

: .FAR          ( -- ) ." FAR " ;

: ID.L          ( a1 -- )
                #OUT @ SWAP count type #OUT @ - 6 + SPACES ;

: SELF.L        ( Left Justified Self-doc! )
                CREATE DOES> ID.L ;

: .SELF         ( Self-doc! )
                CREATE DOES> COUNT TYPE ;

0 value cptr

: NEXTB         ( - n ) cptr d-tc@ incr> cptr ;
: NEXTW         ( - w ) cptr 8086-t@  2 +!> cptr ;

: .NA           ( n ) ."   ??? " H. ;
: .NA0          ( n - n ) DUP .NA ;
: .NA1          ( op ext ) SWAP .NA H. ;

VARIABLE OPS    \ operand count
VARIABLE DISP   \ 2nd operand ext, flag, ct

: ?DISP         ( op ext - op ext | ?MOD disp )
                DUP 6 2/S ?DUP 0=
                IF ( MOD=0 ) DUP 7 AND ( ?R/M ) 6 = 2 AND
                THEN DUP 3 = IF ( MOD=3 ) DROP 0 THEN DISP ! ;

.SELF AL_ ," AL"  .SELF AX_   ," AX"   .SELF [BX+SI]_  ," [BX+SI]"
.SELF CL_ ," CL"  .SELF CX_   ," CX"   .SELF [BX+DI]_  ," [BX+DI]"
.SELF DL_ ," DL"  .SELF DX_   ," DX"   .SELF [BP+SI]_  ," [BP+SI]"
.SELF BL_ ," BL"  .SELF BX_   ," BX"   .SELF [BP+DI]_  ," [BP+DI]"
.SELF AH_ ," AH"  .SELF SP_   ," SP"   .SELF [SI]_     ," [SI]"
.SELF CH_ ," CH"  .SELF BP_   ," BP"   .SELF [DI]_     ," [DI]"
.SELF DH_ ," DH"  .SELF SI_   ," SI"   .SELF [BP]_     ," [BP]"
.SELF BH_ ," BH"  .SELF DI_   ," DI"   .SELF [BX]_     ," [BX]"
.SELF RP_ ," RP"  .SELF [RP]_ ," [RP]"    \ Return Stack Pointer
.SELF IP_ ," IP"  .SELF [IP]_ ," [IP]"    \ Interpreter Pointer
.SELF ES_ ," ES"
.SELF CS_ ," CS"
.SELF SS_ ," SS"
.SELF DS_ ," DS"

DEFER .SYMBOL

.SELF BYTE_ ,"  BYTE"
.SELF WORD_ ,"  WORD"

: .SIZE         ( op ) 1 AND EXEC: BYTE_ WORD_ ;

: .8REG         ( ext )
                7 AND EXEC: AL_ CL_ DL_ BL_ AH_ CH_ DH_ BH_ ;

: .16REG        ( ext )
                7 AND EXEC: AX_ CX_ DX_ BX_ SP_ BP_ SI_ DI_ ;

: .R8/16        ( op ext )
                SWAP 1 AND EXEC: .8REG .16REG ;

: .R/M          ( op ext - op ext ) 2DUP .R8/16 ;
: .REG          ( op ext - op ext ) 2DUP 3 2/S .R8/16 ;

: 0DISP         ." 0 " ;

: BDISP|        \ byte displacement
                cptr DISP @ + d-tc@    1 OPS +! ;

: BDISP         \ byte displacement
                BDISP| SEXT .SYMBOL ;

: WDISP         \ word displacement
                cptr DISP @ + 8086-t@ .SYMBOL 2 OPS +! ;

: .DISP         ( op ext - op ext )
                DUP 6 2/S 3 AND EXEC: 0DISP BDISP WDISP .R/M ;

: BIMM          ( byte immediate ) .# BDISP| .SYMBOL ;
: WIMM          ( word immediate ) .# WDISP space ;

: .IMM          ( op ) 1 AND IF WIMM EXIT THEN BIMM ;

: .MREG         ( op ext - op ext | reg + disp )
                $0C0 2DUP AND = IF ( MOD=3 ) .R/M EXIT THEN
                DUP $0C7 AND 6 =
                IF ( MOD=0 R/M=6 )  ." [" WDISP ." ] " EXIT
                THEN  .DISP  DUP 7 AND ( MOD=1 or 2 )
                EXEC: [BX+SI]_  [BX+DI]_  [BP+SI]_  [BP+DI]_
                      [SI]_     [DI]_     [BP]_     [BX]_ ;

: .SEG          ( op ) 3 2/S 3 AND EXEC: ES_ CS_ SS_ DS_ ;

: SEG:          ( op | segment override ) .SEG ." :" ;

: POP_          ( op ) DUP 15 = IF .NA EXIT THEN ." POP   " .SEG ;
: PUSH_         ( op ) ." PUSH  " .SEG ;

: P/P           ( op ) DUP 1 AND EXEC: PUSH_ POP_ ;

SELF.L DAA_ ," DAA"     SELF.L DAS_ ," DAS"
SELF.L AAA_ ," AAA"     SELF.L AAS_ ," AAS"

: .ADJ          ( op ) 3 2/S 3 AND EXEC: DAA_ DAS_ AAA_ AAS_ ;

: P/SEG         ( op | push  seg override )
                DUP 5 2/S 1 AND EXEC: P/P SEG: ;

: P/ADJ         ( op | pop  adjust )
                DUP 5 2/S 1 AND EXEC: P/P .ADJ ;

SELF.L ADD_ ," ADD"     SELF.L ADC_ ," ADC"
SELF.L AND_ ," AND"     SELF.L XOR_ ," XOR"
SELF.L OR_  ," OR"      SELF.L SBB_ ," SBB"
SELF.L SUB_ ," SUB"     SELF.L CMP_ ," CMP"

: .AL/X         ( op ) 1 AND EXEC: AL_ AX_ ;

: .ALU          ( op )
                3 2/S 7 AND EXEC:
                ADD_ OR_ ADC_ SBB_ AND_ SUB_ XOR_ CMP_ ;

: ALU           ( op - op )
                DUP .ALU DUP 4 AND
                IF      DUP .AL/X ., .IMM  EXIT
                THEN    NEXTB OVER 2 AND
                IF      .REG ., .MREG
                ELSE    .MREG ?., .REG
                THEN    2DROP ;

: 00-3F         ( op - op | 00-3F )
                DUP 7 AND EXEC: ALU ALU ALU ALU ALU ALU P/SEG P/ADJ ;

: .REGGP        ( op | register group )
                CREATE DOES> ID.L .16REG ;

.REGGP INC_    ," INC"          .REGGP DEC_   ," DEC"
.REGGP PUSH2_  ," PUSH"         .REGGP POP2_  ," POP"

: REGS          ( op | 40-5F )
                DUP 3 2/S 3 AND EXEC: INC_ DEC_ PUSH2_ POP2_ ;

: 60-6F ( op ) .NA ;

SELF.L JA_  ," JA"       SELF.L JAE_ ," JAE"
SELF.L JB_  ," JB"       SELF.L JBE_ ," JBE"
SELF.L JE_  ," JE"       SELF.L JG_  ," JG"
SELF.L JGE_ ," JGE"      SELF.L JL_  ," JL"
SELF.L JLE_ ," JLE"      SELF.L JNE_ ," JNE"
SELF.L JNO_ ," JNO"      SELF.L JNS_ ," JNS"
SELF.L JO_  ," JO"       SELF.L JPE_ ," JPE"
SELF.L JPO_ ," JPO"      SELF.L JS_  ," JS"

: .BR|          ( op )
                15 AND
                EXEC: JO_ JNO_ JB_  JAE_ JE_ JNE_ JBE_ JA_
                      JS_ JNS_ JPE_ JPO_ JL_ JGE_ JLE_ JG_ ;

: .BRANCH       ( op | 70-7F branch & dest )
                .BR| NEXTB SEXT cptr + .SYMBOL ;

: 40-7F         ( op | 40-7F )
                DUP 4 2/S 3 AND EXEC: REGS REGS 60-6F .BRANCH ;

: ALU#          ( op | 80-81 )
                NEXTB DUP .ALU .MREG ?., ?DISP DROP DUP .IMM .SIZE ;

: .NA1X         ( op ext ) .NA1
\FPC            2R> 2DROP
\TCOM           R>DROP
                ;

: .MATH         ( ext )
                3 2/S 7 AND
                EXEC:   ADD_   .NA1X  ADC_   SBB_
                        .NA1X  SUB_   .NA1X  CMP_ ;

: 83S           ( op | 83 )
                NEXTB DUP .MATH .MREG ?., ?DISP BIMM DROP .SIZE ;

: 1GP           ( op | r/m reg )
                CREATE DOES> ID.L NEXTB .MREG ?., .REG 2DROP ;

   1GP TEST1_ ," TEST"       1GP XCHG1_ ," XCHG"
SELF.L LEA_   ," LEA"     SELF.L MOV_   ," MOV"

: MOVRM/REG     ( op | 88-89 )
                MOV_ NEXTB .MREG ?., .REG 2DROP ;

: MOVD_         ( op | 8A-8B )
                MOV_ NEXTB .REG ., .MREG 2DROP ;

: MOVS>M        ( op | 8C-8F )
                NEXTB OVER $8D =
                IF      LEA_ .REG ., .MREG 2DROP EXIT
                THEN    OVER $8F =
                IF      DUP $38 AND IF .NA1 EXIT THEN
                        ." POP   " .MREG
                ELSE    ( 8C 8E ) DUP $20 AND IF .NA1 EXIT THEN
                        MOV_ SWAP 1 OR ( Force 16bit moves only )
                        SWAP OVER 2 AND
                        IF      ( 8E ) DUP .SEG ., .MREG
                        ELSE    ( 8C ) .MREG ?., DUP .SEG
                        THEN
                THEN    2DROP ;

: 8MOVS         ( op | 80-8F )
                DUP 2/ 7 AND
                EXEC: ALU#       83S    TEST1_  XCHG1_
                      MOVRM/REG  MOVD_  MOVS>M  MOVS>M ;

SELF.L XCHG2_ ," XCHG"   SELF.L CBW_   ," CBW"
SELF.L CWD_   ," CWD"    SELF.L CALL_  ," CALL"
SELF.L WAIT_  ," WAIT"   SELF.L PUSHF_ ," PUSHF"
SELF.L POPF_  ," POPF"   SELF.L SAHF_  ," SAHF"
SELF.L LAHF_  ," LAHF"   SELF.L TEST2_ ," TEST"

: INTER         \ interseg jmp or call
                .FAR NEXTW NEXTW H. .SYMBOL ;

: CALLINTER     ( interseg call ) CALL_ INTER ;

: XCHG3_        ( op | 90-97 )
                DUP 7 AND IF XCHG2_ .16REG ., AX_ EXIT THEN DROP ." NOP " ;

: 98-9F         ( op | 98-9F )
                7 AND
                EXEC: CBW_ CWD_ CALLINTER WAIT_ PUSHF_ POPF_ SAHF_ LAHF_ ;

: 90S           ( op | 90-9F )
                DUP 3 2/S 1 AND EXEC: XCHG3_ 98-9F ;

: MOVA_         ( op | A0-A3 )
                MOV_ DUP 2 AND
                IF  WDISP space .AL/X EXIT
                THEN .AL/X .,  WDISP space ;

: MOVS_         ( op | A4-A5 ) ." MOVS  " .SIZE ;
: CMPS_         ( op | A6-A7 ) ." CMPS  " .SIZE ;

: TEST3_        ( op | A8-A9 ) TEST2_ DUP .AL/X ., .IMM ;

: STOS_         ( op | AA-AB ) ." STOS  " .SIZE ;
: LODS_         ( op | AC-AD ) ." LODS  " .SIZE ;
: SCAS_         ( op | AE-AF ) ." SCAS  " .SIZE ;

: A0S           ( op | A0-AF )
                DUP 2/ 7 AND
                EXEC: MOVA_ MOVA_ MOVS_ CMPS_ TEST3_ STOS_ LODS_ SCAS_ ;

: MOV#          ( op | B0-BF )
                MOV_ DUP 8 AND
                IF .16REG ., WIMM EXIT THEN .8REG ., BIMM ;

: 80-BF         ( op | 80-BF )
                DUP 4 2/S 3 AND EXEC: 8MOVS 90S A0S MOV# ;

SELF.L LES_  ," LES"     SELF.L LDS_  ," LDS"
SELF.L INTO_ ," INTO"    SELF.L IRET_ ," IRET"

: RET_          ( op | C2-C3 CA-CB )
                ." RET   " DUP 8 AND IF .FAR THEN
                1 AND 0= IF WDISP ( ??? ) ."  +SP" THEN ;

: .L/L          ( op ) 1 AND EXEC: LES_ LDS_ ;

: LES/LDS       ( op | C4-C5 )
                DUP .L/L NEXTB .REG ., .MREG 2DROP ;

: MOV#R/M       ( op | C6-C7 )
                NEXTB DUP $38 AND IF .NA1 EXIT THEN
                MOV_ .MREG ?., ?DISP DROP DUP .IMM .SIZE ;

: INT_          ( op | CC-CD )
                ." INT   " 1 AND IF NEXTB ELSE 3 THEN H. ;

: INTO/IRET     ( op | CE-CF )
                1 AND EXEC: INTO_ IRET_ ;

: C0S           ( op | C0-CF )
                DUP 2/ 7 AND
                EXEC: .NA RET_ LES/LDS MOV#R/M .NA RET_ INT_ INTO/IRET ;

SELF.L ROL_ ," ROL"      SELF.L ROR_ ," ROR"
SELF.L RCL_ ," RCL"      SELF.L RCR_ ," RCR"
SELF.L SHL_ ," SHL"      SELF.L SHR_ ," SHR"
SELF.L SAR_ ," SAR"

: .SHIFTS       ( ext )
                3 2/S 7 AND EXEC:
                ROL_ ROR_ RCL_ RCR_ SHL_ SHR_ .NA0 SAR_ ;

: SHIFTS        ( op | D0-D3 )
                NEXTB DUP 3 2/S 7 AND 6 = IF .NA1 EXIT THEN
                DUP .SHIFTS .MREG DROP 2 AND IF ?., CL_ THEN ;

: AAM_          ( op | D4 )  ." AAM   " NEXTB 2DROP ;
: AAD_          ( op | D5 )  ." AAD   " NEXTB 2DROP ;
: XLAT_         ( op | D7 )  ." XLAT  " DROP ;

: ESC_          ( op ext - op ext | D8-DF )
                ." ESC   " 2DUP $38 AND SWAP 7 AND OR . .MREG ;

: D0S           ( op | D0-DF )
                DUP 8 AND
                IF      NEXTB ESC_ 2DROP EXIT
                THEN
                DUP 7 AND
                EXEC:   SHIFTS  SHIFTS  SHIFTS  SHIFTS
                        AAM_    AAD_    .NA     XLAT_  ;

SELF.L LOOPE_  ," LOOPE"
SELF.L LOOP1_  ," LOOP"
SELF.L LOOPNE_ ," LOOPNE"
SELF.L JCXZ_   ," JCXZ"

: .LOOP         ( op )
                3 AND EXEC:
                LOOPNE_  LOOPE_  LOOP1_  JCXZ_  ;

: LOOPS_         ( op | E0-E3 )
                .LOOP NEXTB SEXT cptr + .SYMBOL ;

SELF.L IN_  ," IN"
SELF.L OUT_ ," OUT"
SELF.L JMP_ ," JMP"

: IO#           ( op | E4-E7 )
                DUP 2 AND
                IF      OUT_  BIMM   .AL/X
                ELSE    IN_   .AL/X  .,     BIMM
                THEN    ;

: IOX           ( op | EC-EF )
                DUP 2 AND
                IF      OUT_  DX_    .,  .AL/X
                ELSE    IN_   .AL/X  .,  DX_
                THEN    ;

: .CALL         ( op )
                3 AND EXEC: CALL_ JMP_ JMP_ JMP_ ;

: CALLS_        ( op | E8-EB )
                DUP .CALL DUP 2 AND
                IF      DUP 1 AND
                        IF NEXTB SEXT cptr + .SYMBOL
                        ELSE INTER
                        THEN
                ELSE    NEXTW cptr + .SYMBOL
                        ( make smart about DEBUG's tricks and E0 )
                        DUP $0E9 = cptr d-tc@ $0E0 = AND IF incr> cptr THEN
                THEN    DROP ;

: E0S           ( op | E0-EF )
                DUP 2 2/S 3 AND EXEC: LOOPS_ IO# CALLS_ IOX ;

: FTEST         ( op | F6-F7 )
                TEST2_ .MREG ?., ?DISP DROP DUP .IMM .SIZE ;

SELF.L NOT1_ ," NOT"     SELF.L NEG_   ," NEG"
SELF.L MUL_  ," MUL"     SELF.L IMUL_  ," IMUL"
SELF.L DIV_  ," DIV"     SELF.L IDIV_  ," IDIV"
SELF.L REP_  ," REP"     SELF.L REPNE_ ," REPNE"
SELF.L LOCK_ ," LOCK"    SELF.L HLT_   ," HLT"
SELF.L CMC_  ," CMC"     SELF.L CLC_   ," CLC"
SELF.L STC_  ," STC"     SELF.L CLI_   ," CLI"
SELF.L STI_  ," STI"     SELF.L CLD_   ," CLD"
SELF.L STD_  ," STD"     SELF.L INC1_  ," INC"
SELF.L DEC1_ ," DEC"     SELF.L PUSH3_ ," PUSH"

: .MUL/DIV      ( ext )
                3 2/S 3 AND EXEC: MUL_ IMUL_ DIV_ IDIV_ ;

: MUL/DIV ( op ext | F6-F7 )
  DUP .MUL/DIV .MREG 2DROP ;

: .NOT/NEG      ( ext )
                3 2/S 1 AND EXEC: NOT1_ NEG_ ;

: NOT/NEG       ( op ext | F6-F7 )
                DUP .NOT/NEG .MREG 2DROP ;

: F6-F7S        ( op | F6-F7 )
                NEXTB DUP 3 2/S 7 AND
                EXEC:   FTEST    .NA1     NOT/NEG  NOT/NEG
                        MUL/DIV  MUL/DIV  MUL/DIV  MUL/DIV ;

: .FES          ( ext )
                3 2/S 1 AND EXEC: INC1_ DEC1_ ;

: FES_          ( op | FE )
                NEXTB DUP 3 2/S 6 AND
                IF      .NA1
                ELSE    DUP .FES .MREG 2DROP
                THEN    ;

: .FCALL/JMP    ( ext )
                2/ 1 AND EXEC: JMP_ CALL_ ;

: FCALL/JMP     ( op ext | FF )
                DUP 3 2/S DUP .FCALL/JMP 1 AND
                IF .FAR THEN .MREG 2DROP ;

: FPUSH_        ( op ext | FF )
                DUP 4 AND
                IF      PUSH3_ .MREG 2DROP
                ELSE    .NA1
                THEN    ;

: .FINC         ( op ext )
                3 2/S 1 AND EXEC: INC1_ DEC1_ ;

: FINC_         ( op ext | FF )
                DUP .FINC .MREG $0C7 AND 6 = IF WORD_ THEN DROP ;

: FFS_          ( op | FF )
                NEXTB DUP 4 2/S 3 AND
                EXEC: FINC_ FCALL/JMP FCALL/JMP FPUSH_ ;

: .NAF1         ( a - a ) dup d-tc@ .NA ;

: F0S           ( op | F0-FF )
                DUP 15 AND DUP 7 AND 6 < IF NIP THEN
                EXEC:   LOCK_  .NAF1 REPNE_  REP_
                        HLT_   CMC_  F6-F7S  F6-F7S
                        CLC_   STC_  CLI_    STI_
                        CLD_   STD_  FES_    FFS_ ;

: C0-FF         ( op | C0-FF )
                DUP 4 2/S 3 AND EXEC: C0S D0S E0S F0S ;

: .INST         ( op )
                255 AND DUP 6 2/S
                EXEC: 00-3F 40-7F 80-BF C0-FF ;

: INST          \ display opcode at ip  advancing as needed
                save> base hex
                cptr 0 <# # # # # #> TYPE 4 SPACES
                cptr >R
                #OUT @ >R
                NEXTB .INST
                OPS @ +!> cptr
                R> #OUT @ - 28 + 1 max SPACES
                R> cptr SWAP
                ?DO     I d-tc@ 0 <# # # #> TYPE
                LOOP
                OPS OFF
                DISP OFF
                restore> base ;

\ **********************************************************************
\ Here starts the "file" disassembler above the instruction level
\ **********************************************************************

\fpc    $10000. pointer comseg
\tcom         0 value   comseg
              0 value   symbuf
              0 value   symcnt
              0 value   symptr
                handle  symhndl
              0 value   comcnt

: ifield        ( n1 n2 -<name>- n3 )   \ define fields of symbol
                ( a1 -- a2 )
                create over c, +        \ compile offset & increment to next
                does> c@ + ;            \ adjust a1 to field address a2

/nostack        \ no stack checking needed here
0                       \ starting at field offset zero (0),
 32 ifield >symname     \ symbol name as a counted string
  1 ifield >symtype     \ symbol type for TCOM (macro, function, variable..)
  2 ifield >symresaddr  \ symbols resolution address
  2 ifield >symvalue    \ symbols initial value if a VALUE or CONSTANT
  1 ifield >symfile#    \ source file number in .FIL file
  4 ifield >symoffset   \ source file offset in bytes
  2 ifield >symsize     \ size of symbol in bytes for data symbols
  4 ifield >symunused   \ unused space in symbol table entry
constant sym_len        \ length of symbol record buffer

sym_len 1200 * constant symmax

0 constant macrotype
1 constant constanttype
2 constant 2constanttype
3 constant fconstanttype
4 constant variabletype
5 constant valuetype
6 constant calltype
7 constant defertype
8 constant tabletype

: read_sym      ( -- )          \ read the symbol file from disk
                bl word symhndl $>handle
                " SYM" ">$ symhndl $>ext
                symhndl hopen
                if      cr ." Could not open " symhndl count type
                        ." , no symbols available."
                        off> symcnt symbuf off exit
                then    cr ." Opened " symhndl count type ." , read "
                symbuf symmax symhndl hread dup =: symcnt
                U. ." bytes"
                symhndl hclose drop ;

: .disusage     ( -- )
                cr
    ." Usage: DIS filename {/D} {/Pn} {starting_symbol or hex_address} {>outfile}"
                cr 21 spaces ." /D         skip CODE and start with DATA."
                cr 21 spaces ." /P{n}      {n} Pages to disassemble."
                cr 21 spaces ." {symbol}   start disassembly at 'USER_symbol'."
                cr 21 spaces ." {address}  start desassembly at 'HEX_address'."
                cr 21 spaces ." >outfile   redirects output to 'outfile'."
                cr abort ;

: read_com      ( -- )          \ assumes symbol file has been read
                " COM" ">$ symhndl $>ext
                symhndl hopen
                if      cr ." Could not open " symhndl count type cr
                        .disusage
                then
\tcom           $1000 alloc 8 = \ allocate some space for the .COM file.
\tcom           if      cr ." Not enough memory, leaving" abort
\tcom           then    =: comseg drop
\fpc            comseg drop
                cr ." Opened " symhndl count type ." , read "
                $100 $FE00 symhndl comseg exhread dup =: comcnt
                u. ." bytes"
                symhndl hclose drop ;

: %>symbol      ( a1 -- a2 f1 )        \ given a1 the symbol address, return
                                        \ a2 = the symbols address
                                        \ f1 = true if symbol found
                                        \ else f1 false symbol not found
                !> symptr 0 0
                symbuf symcnt bounds
                ?do     i >symresaddr @ symptr =
                        if      2drop
                                i -1 leave
                        then
        sym_len +loop   ;

defer >symbol

: ?.symbol      ( a1 -- )
                dup     >symbol
                if      count type
                else    SWAP H.
                then    DROP ;

: .show_symbol  ( -- )          \ display the symbol for this address
                cptr >symbol
                if      dup >symtype c@ calltype =
                        if      dup >symname count
                                ." ; " type cr
                        then    drop
                else    drop
                then    ;

: ?address      ( a1 -- <a2> f1 )       \ given a1 the symbol name, return
                                        \ a2 addr, & f1 = true if addr found
                                        \ else f1 false addr not found
                ?uppercase =: symptr
                symptr c@ dup 0= ?exit drop
                symptr number? nip      \ pass in a number directly
                if      true exit
                then    drop
                0
                symbuf symcnt bounds
                ?do     i >symname symptr dup c@ 1+ caps-comp 0=
                        if      drop
                                i >symresaddr @
                                -1 leave
                        then
        sym_len +loop   ;

0 value ?paging
0 value #pages
0 value maxpages

: page_check?   ( -- )          \ display in 132 columns
                1000 !> maxpages
                >in @
                bl word 1+ " /P" caps-comp
                if      >in !
                        exit                    \ ***** EXIT's HERE
                then    drop cr
                >in @ here c@ 2- - >in !        \ backup to after "/P"
                bl word number?
                if      drop !> maxpages        \ set max pages
                else    2drop
                then
                on> ?paging
                5 #line ! ;

: ?.new_page    ( -- )          \ output a pagebreak if needed
                ?paging 0= ?exit
                #line @ 62 < ?exit
                cr cr
                ."    Page# " #pages 1+ 3 .r
                ."    TCOM DISassembler by Tom Zimmer"
                cr 12 emit #line off
                incr> #pages
                #pages maxpages >=
                if      0 0 bdos        \ leave program
                then    cr cr ;

: DIS           ( a1 -- )       \ disassemble from address a1
                !> cptr ?cs: !> ?disseg:
                begin   cr
                        .show_symbol
                        8 spaces
                        INST
                        ?KEYPAUSE
                again   cr ;

\fpc    true    #IF
\tcom   ?DIS 0= #IF             \ If we are not just appending disassembler
                                \ but are actually building a standalone
                                \ disassembler, then include this

: .1inst_line   ( -- )
                CR
                .show_symbol
                8 spaces
                INST ;

0 value tstartln

: targ.r        ( n1 n2 -- )    \ display n1 in a field of n2 digits
                over !> tstartln
                swap 0 <# rot 0 ?do # loop #> type ;

: targetc@      ( a1 -- n1 )
                $103 8086-t@ $10 * + d-tc@ ;

: .targascii    ( a1 n1 -- )    \ show ascii n1 bytes previous to a1
                dup>r - r> bounds 53 sp>col ."  |"
                ?do     i targetc@ $20 $7F between
                        if      i targetc@ emit
                        else    ." ."
                        then
                        broken @ if bye then
                        ?keypause
                loop    ;

: ?targascii    ( a1 -- )
                #out @ 51 >=
                if      dup 16 .targascii
                        cr dup 1+ 4 targ.r
                then    drop ;

: .targbyte     ( a1 -- )
                targetc@ 0 <# # # #> space type ;

: datadump      ( a1 n1 -- )    \ dump darget data from a1 for length n1
                2dup + >r
                dup 3 <
                if      bounds dup !> tstartln
                       ?do      i .targbyte
                                ?keypause
                                broken @ if bye then
                        loop
                else    bounds  cr dup 4 targ.r
                        do      i .targbyte
                                i ?targascii
                                ?keypause
                                broken @ if bye then
                        loop
                then    r> dup tstartln - .targascii ;

0 value datasum

: .stringsym    ( a1 -- )       \ display nameless string
                cr datasum 4 u.r ."  String" 16 sp>col
                ." <noname>" 32 sp>col
                >symresaddr @
                ."  of " dup datasum - 3 u.r ."  bytes "
                dup>r datasum - datasum swap datadump
                r> !> datasum ;

: .datasym      ( a1 n1 a2 -- ) \ display string a1,n1 with symbol a2
                dup>r >symresaddr @ datasum <>
                if      r@ .stringsym
                then
                cr r@ >symresaddr @ 4 u.r type 16 sp>col
                r@ >symname count type
                32 sp>col
                r@ >symsize @ dup +!> datasum ."  of " 3 u.r ."  bytes "
                r@ >symresaddr @ r> >symsize @ datadump ;

: .data_symbol  ( a1 -- )               \ display the data symbol at a1
                dup>r >symtype c@
                dup variabletype =
                if      drop    "  Variable"    r> .datasym exit
                then
                dup valuetype    =
                if      drop    "  Value"       r> .datasym exit
                then
                dup defertype    =
                if      drop    "  Defered"     r> .datasym exit
                then
                dup tabletype    =
                if      drop    "  Table"       r> .datasym exit
                then    drop
                r>drop ;

: .program_data ( -- )
                ?.new_page
                save> base hex
                off> datasum
                symbuf symcnt bounds
                ?do     i .data_symbol
                        ?keypause
        sym_len +loop
                comcnt $100 + $103 8086-t@ 16 * -       \ total data length
                dup datasum <>
                if      dup datasum - over over - swap
                        cr over 4 targ.r datadump
                then    drop
                restore> base ;

: data_only?    ( -- )
                >in @
                bl word 1+ " /D" compare        \ if NO MATCH!
                if      >in !
                        exit                    \ ***** EXIT's HERE
                then    drop
                .program_data bye ;             \ else display prog data

VARIABLE CPEND

\fpc    symmax 2+ array fsymbuf

: UDIS          ( -- )
                CAPS ON
\tcom           ?ds: sseg !
\tcom           DOSIO_INIT                      \ init EMIT, TYPE & SPACES
\tcom           symmax 2+ ds:alloc =: symbuf
\fpc            fsymbuf !> symbuf
\tcom           $FFF0 SET_MEMORY                \ default to 64k code space
\tcom           DOS_TO_TIB                      \ move command tail to TIB
                DECIMAL
\tcom           lineread_init
                ['] ?.symbol is .symbol
                ['] %>symbol is >symbol
                off> #pages
                #tib @ 0=                       \ if no command line params
                if      .disusage               \ display usage and leave
                then
                read_sym                        \ read symbol table
                read_com                        \ read .COM file
                comseg !> ?disseg:
                HEX
                cr
                data_only?
                page_check?
                bl word ?address        \ find word following, if found
                if      !> cptr         \ set as starting address
                else    $100 !> cptr    \ else use $100 for starting
                then    symcnt                  \ if symbol file presend,
                if      comseg $0103 @L $10 *   \ then assume its a TCOM file
                else    $FF00                   \ else just do whole .COM file
                then    comcnt $100 + umin cpend !
                BEGIN   .1inst_line
                        ?.new_page
                        ?keypause
                        cptr cpend @ u>
                        broken @ if bye then
                UNTIL   cr
                .program_data
                ?paging
                if      12 emit
                then    ;

#ENDIF

