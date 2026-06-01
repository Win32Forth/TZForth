\ DA5.SEQ       another modification to work with the listing generator

\ DIS8086.SEQ   8086 Disassembler  by Charles Curley
\ Prefix conversion by  Bill Muench  9 September 88
\ conversion to TCOM and symbolic additions by Tom Zimmer  03/07/90
\ conversion to 6805 by Andrew McKewan 12/17/90
\ conversion to work with listing generator Tom Zimmer 09/10/91

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

: ID.L          ( a1 --  )
                count dup>r "> 6 r> - spaces> ;

:: .SELF         ( Left Justified Self-doc! )
                CREATE DOES> ID.L ;

: NEXTB         ( - n ) cptr d-tc@ incr> cptr ;
: NEXTW         ( - w ) cptr d-t@  2 +!> cptr ;

: H.>\          ( n1 -- )
                BASE @ >R HEX (U.) "> R> BASE ! ;

: H.>           ( n1 -- )
                H.>\ 1 SPACES> ;

VARIABLE OPS    \ operand count

\ Display hex object code

: ##    save> base hex  0 <# # #     #> "> 1 spaces>  restore> base ;
: ####  save> base hex  0 <# # # # # #> "> 1 spaces>  restore> base ;

: bit#  ( opcode -- bit# )  2/ 7 and ;
: B>W  ( byte -- n )  DUP 128 AND IF 256 - THEN ;


.self _??? ," ???"

.self _NEG ," NEG"      .self _COM ," COM"      .self _LSR ," LSR"
.self _ROR ," ROR"      .self _ASR ," ASR"      .self _LSL ," LSL"
.self _ROL ," ROL"      .self _DEC ," DEC"      .self _INC ," INC"
.self _TST ," TST"      .self _CLR ," CLR"      .self _SUB ," SUB"
.self _CMP ," CMP"      .self _SBC ," SBC"      .self _CPX ," CPX"
.self _UND ," AND"      .self _BIT ," BIT"      .self _LDA ," LDA"
.self _STA ," STA"      .self _EOR ," EOR"      .self _ADC ," ADC"
.self _ORA ," ORA"      .self _ADD ," ADD"      .self _JMP ," JMP"
.self _JSR ," JSR"      .self _LDX ," LDX"      .self _STX ," STX"

.self _BRA ," BRA"      .self _BRN ," BRN"      .self _BHI ," BHI"
.self _BLS ," BLS"      .self _BCC ," BCC"      .self _BCS ," BCS"
.self _BNE ," BNE"      .self _BEQ ," BEQ"      .self _BHCC ," BHCC"
.self _BHCS ," BHCS"    .self _BPL ," BPL"      .self _BMI ," BMI"
.self _BMC ," BMC"      .self _BMS ," BMS"      .self _BIL ," BIL"
.self _BIH ," BIH"

: .SYMBOL ( a1 -- )
        dup a-function-symbol?
        IF      drop sym-seg sym-name> countl instr_buf +placel
        ELSE h.>
        THEN ;

: .DATA\ ( a1 -- )
        dup a-data-symbol?          \ in symbol table ?
        IF      drop sym-seg sym-name> countl instr_buf +placel
        ELSE    h.>\
        THEN ;

: .DATA ( a1 -- )
        .DATA\ 1 SPACES> ;

\ address modes:

: dir   nextb .data   ( 1 ops +! ) ;
: ext   nextw .symbol ( 2 ops +! ) ;
: imm   " #" "> dir ;
: ix    " ,X" "> ;
: ix1   dir " ,X" "> ;
: ix2   ext " ,X" "> ;
: rel   nextb b>w cptr + .symbol ;
: bsc   cptr 1- d-tc@ bit# H.>\ " ," "> dir 1 ops +! ;
: btb   bsc " ," "> rel ;
: inha  " A" "> ;
: inhx  " X" "> ;


: .brset  ( opcode -- )
        dup 1 and if " BRCLR " "> else " BRSET  " "> then btb ;

: .bset  ( opcode -- )
        dup 1 and if " BCLR  " "> else " BSET  " "> then bsc ;

: .bop   ( opcode -- )
        15 and exec: _bra _brn _bhi _bls _bcc _bcs _bne _beq
                     _bhcc _bhcs _bpl _bmi _bmc _bms _bil _bih ;

: .bran  ( opcode -- )
        .bop rel ;


: op1  ( opcode -- )
        15 and exec: _sub _cmp _sbc _cpx _und _bit _lda _sta
                     _eor _adc _ora _add _jmp _jsr _ldx _stx ;

: mode1  ( mode -- )
        10 - 5 min exec: imm dir ext ix2 ix1 ix ;

: arith  ( opcode mode -- )
        over $ad = if drop " BSR   " "> rel exit then
        swap op1 mode1 ;


: op2  ( opcode -- )
        15 and exec: _neg _??? _??? _com _lsr _??? _ror _asr
                     _lsl _rol _dec _??? _inc _tst _??? _clr ;

: mode2  ( mode -- )
        3 - 4 min
\        dup 1 2 between not if >operand then
        exec: dir inha inhx ix1 ix ;

: rmw   ( opcode mode -- )
        over $42 = if " MUL " "> 2drop exit then
        swap op2 mode2 ;

: misc  ( opcode -- )
        case
        $80 of " RTI" ">  endof         $81 of " RTS" ">  endof
        $83 of " SWI" ">  endof         $8e of " STOP" "> endof
        $8f of " WAIT" "> endof         $97 of " TAX" ">  endof
        $98 of " CLC" ">  endof         $99 of " SEC" ">  endof
        $9a of " CLI" ">  endof         $9b of " SEI" ">  endof
        $9c of " RSP" ">  endof         $9d of " NOP" ">  endof
        $9f of " TXA" ">  endof
        _??? drop endcase ;


: %DIS1         ( op -- )
                ops off
                incr> cptr
                dup 16 /
                dup 0= if drop .brset exit then
                dup 1 = if drop .bset exit then
                dup 2 = if drop .bran exit then
                dup 3 7 between if rmw exit then
                dup 8 9 between if drop misc exit then
                arith ;

: dis1          ( <opc> -- )
                %dis1
                ops @ +!> cptr ;

: %DISASM       ( <opc> -- )
                drop instr_buf count type
                #inst-bytes +!> cptr ;

}

                       ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
                       ³Main disassembly word³
                       ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

{

: %.INST-BYTES ( -- )
        hex
        instr_buf off
        cptr dup>r d-tc@ dis1           \ get the opcode for this instruction
        R@ cptr r> -                    \ get the number of bytes to print
        dup !> #inst-bytes              \ set instruction length
        4 min 0                         \ upto 4 bytes
        ?DO                             \ space before to conform with MDF
           DUP i + d-tc@ 2 0.r space    \ print a byte
        LOOP !> cptr ;

\ ==== BIN FILE ======================================================

: CLOSE-BIN-FILE ( -- )
        seqhandle hclose drop ;

: OPEN-BIN-FILE ( -- )
        " bin" ">$ file-name $>ext              \ get the file name
        file-name $file
        IF screen-output
           help-them
           ." Couldn't open file, extension: .com"
           ls-abort
        THEN ibreset ;

: %LOAD-OBJ-FILE ( -- )
        open-BIN-file
        $0000 maxobj seqhandle obj-seg exhread drop
        close-BIN-file ;

: PROCESSOR-INIT ( -- )                 \ target processor specific init stuff
        false !> ignore-library-code    \ default to exclude library functions
        ;



