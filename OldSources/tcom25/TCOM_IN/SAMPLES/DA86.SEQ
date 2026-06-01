\ DA86.SEQ      Disassembler for 8086 originally by Charles Curley

\ subsequent modifications by Bill Muench and Tom Zimmer

: 8086d-t@      ( a1 -- n1 )    \ d-t@ returns data in HI/LO order,
                d-t@ flip ;     \ fix it for 8086

128 array instr_buf                      \ instruction buffer

: ">            ( a1 n1 -- )            \ append text a1,n1 to inst buffer
                instr_buf +place ;

: SPACES>       ( n1 -- )
                "                 " drop swap 0max 16 min "> ;

: 2/S           ( n ct - n'| shift n right ct )
                0 ?DO U2/ LOOP ;

: 2*S           ( n ct - n' | shift n left ct )
                0 ?DO 2* LOOP ;

CODE SEXT       ( n - n' | sign extend byte to word )
\tcom           MOV AX, BX      CBW     MOV BX, AX      RET
\fpc            pop ax          cbw     1push
                END-CODE

: .#            ( -- ) " # " "> ;

: .,            ( -- ) " , " "> ;

: ?.,           ( op - op ) DUP $0C7 AND 6 <> IF ., THEN ;

: .FAR          ( -- ) " FAR " "> ;

: ID.L          ( a1 --  )
                count dup>r "> 6 r> - spaces> ;

:: SELF.L       ( Left Justified Self-doc! )
                CREATE DOES> ID.L ;

:: .SELF        ( Self-doc! )
                CREATE DOES> COUNT "> ;

: NEXTB         ( - n ) cptr d-tc@     incr> cptr ;
: NEXTW         ( - w ) cptr 8086d-t@  2 +!> cptr ;

: H.>\          ( n1 -- )
                BASE @ >R HEX
                " $" ">
                dup 255 u>
                if      0 <# # # # # #> ">
                else    0 <# # #     #> ">
                then    R> BASE ! ;

: H.>           ( n1 -- )
                H.>\ 1 SPACES> ;

: .NA           ( n ) "   ??? " "> H.> ;
: .NA0          ( n - n ) DUP .NA ;
: .NA1          ( op ext ) SWAP .NA H.> ;

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

0 value sym-file-save           \ not zero if we have source for this word?

: .SYMBOL ( a1 -- )
        dup a-function-symbol?
        IF      drop sym-seg sym-name> countl 31 min 1 max instr_buf +placel
                sym-file#> !> sym-file-save
        ELSE h.>        -1 !> sym-file-save
        THEN ;

: .DATA\ ( a1 -- )
        dup a-data-symbol?          \ in symbol table ?
        IF      drop sym-seg sym-name> countl 31 min 1 max instr_buf +placel
        ELSE    h.>\
        THEN ;

: .DATA ( a1 -- )
        .DATA\ 1 SPACES> ;

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

: 0DISP         " 0 " "> ;

: BDISP|        \ byte displacement
                cptr DISP @ + d-tc@    1 OPS +! ;

: BDISP         \ byte displacement
                BDISP| SEXT .DATA ;

: WDISP\        \ word displacement
                cptr DISP @ + 8086d-t@ .DATA\ 2 OPS +! ;

: WDISP         \ word displacement
                WDISP\ 1 SPACES> ;

: .DISP         ( op ext - op ext )
                DUP 6 2/S 3 AND EXEC: 0DISP BDISP WDISP .R/M ;

: BIMM          ( byte immediate )
                .# BDISP| h.> ( .DATA ) ;
: WIMM          ( word immediate )
                .# cptr DISP @ + 8086d-t@ h.> 2 OPS +! ;

: .IMM          ( op ) 1 AND IF WIMM EXIT THEN BIMM ;

: .MREG         ( op ext - op ext | reg + disp )
                $0C0 2DUP AND = IF ( MOD=3 ) .R/M EXIT THEN
                DUP $0C7 AND 6 =
                IF ( MOD=0 R/M=6 )  " [" "> WDISP\ " ] " "> EXIT
                THEN  .DISP  DUP 7 AND ( MOD=1 or 2 )
                EXEC: [BX+SI]_  [BX+DI]_  [BP+SI]_  [BP+DI]_
                      [SI]_     [DI]_     [BP]_     [BX]_ ;

: .SEG          ( op ) 3 2/S 3 AND EXEC: ES_ CS_ SS_ DS_ ;

: SEG:          ( op | segment override ) .SEG " :" "> ;

: POP_          ( op ) DUP 15 = IF .NA EXIT THEN " POP   " "> .SEG ;
: PUSH_         ( op ) " PUSH  " "> .SEG ;

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

:: .REGGP       ( op | register group )
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

:: 1GP          ( op | r/m reg )
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
                        " POP   " "> .MREG
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
                .FAR NEXTW NEXTW H.> .SYMBOL ;

: CALLINTER     ( interseg call ) CALL_ INTER ;

: XCHG3_        ( op | 90-97 )
                DUP 7 AND IF XCHG2_ .16REG ., AX_ EXIT THEN DROP " NOP " "> ;

: 98-9F         ( op | 98-9F )
                7 AND
                EXEC: CBW_ CWD_ CALLINTER WAIT_ PUSHF_ POPF_ SAHF_ LAHF_ ;

: 90S           ( op | 90-9F )
                DUP 3 2/S 1 AND EXEC: XCHG3_ 98-9F ;

: MOVA_         ( op | A0-A3 )
                MOV_ DUP 2 AND
                IF  WDISP .AL/X EXIT
                THEN .AL/X .,  WDISP ;

: MOVS_         ( op | A4-A5 ) " MOVS  " "> .SIZE ;
: CMPS_         ( op | A6-A7 ) " CMPS  " "> .SIZE ;

: TEST3_        ( op | A8-A9 ) TEST2_ DUP .AL/X ., .IMM ;

: STOS_         ( op | AA-AB ) " STOS  " "> .SIZE ;
: LODS_         ( op | AC-AD ) " LODS  " "> .SIZE ;
: SCAS_         ( op | AE-AF ) " SCAS  " "> .SIZE ;

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
                " RET   " "> DUP 8 AND IF .FAR THEN
                1 AND 0= IF WDISP ( ??? ) "  +SP" "> THEN ;

: .L/L          ( op ) 1 AND EXEC: LES_ LDS_ ;

: LES/LDS       ( op | C4-C5 )
                DUP .L/L NEXTB .REG ., .MREG 2DROP ;

: MOV#R/M       ( op | C6-C7 )
                NEXTB DUP $38 AND IF .NA1 EXIT THEN
                MOV_ .MREG ?., ?DISP DROP DUP .IMM .SIZE ;

: INT_          ( op | CC-CD )
                " INT   " "> 1 AND IF NEXTB ELSE 3 THEN H.> ;

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

: AAM_          ( op | D4 )  " AAM   " "> NEXTB 2DROP ;
: AAD_          ( op | D5 )  " AAD   " "> NEXTB 2DROP ;
: XLAT_         ( op | D7 )  " XLAT  " "> DROP ;

: ESC_          ( op ext - op ext | D8-DF )
                " ESC   " "> 2DUP $38 AND SWAP 7 AND OR . .MREG ;

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

: %dis1         ( <opc> -- )
                -1 !> sym-file-save
                ops off
                disp off
                incr> cptr
                255 AND DUP 6 2/S
                EXEC: 00-3F 40-7F 80-BF C0-FF ;

: dis1          ( <opc> -- )
                instr_buf off
                %dis1
                ops @ +!> cptr ;

: %DISASM       ( <opc> -- )
                drop                            \ discard opcode
                instr_buf count type            \ display instruction
                #inst-bytes +!> cptr ;          \ point CPTR to next inst

}

                       ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
                       ³Main disassembly word³
                       ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

{

\ 0 value #INST-BYTES

: %.INST-BYTES ( -- )
        hex
        cptr dup>r d-tc@ dis1           \ get the opcode for this instruction
        r@ cptr over - dup !> #inst-bytes \ get the number of bytes to print
        4 min 0                         \ upto 4 bytes
        ?DO                             \ space before to conform with MDF
           DUP i + d-tc@ 2 0.r space    \ print a byte
        LOOP drop r> !> cptr ;          \ restore code pointer

\ ==== COM FILE ======================================================

: CLOSE-COM-FILE ( -- )
        seqhandle hclose drop ;

: OPEN-COM-FILE ( -- )
        file-name handle>ext c@ '.' <>
        if      " com" ">$ file-name $>ext      \ get the file name
        then
        file-name $file
        IF screen-output
           help-them
           ." Couldn't open file, extension: .com"
           ls-abort
        THEN ibreset ;

: %LOAD-OBJ-FILE ( -- )
        open-com-file
        seqhandle handle>ext 1+ c@ upc 'C' =
        if      $100 maxobj $100 -
        else    $000 maxobj
        then    seqhandle obj-seg exhread drop
        close-com-file ;

: D-DC@ ( <target-data address> -- <target-data byte> )
        obj-seg $103 @L 16 * + obj-seg swap c@L ;

: PROCESSOR-INIT ( -- )                 \ target processor specific init stuff
        true !> ignore-library-code     \ default to exclude library functions
        ['] d-dc@ is d-datac@ ;         \ segmented, use special data fetch

