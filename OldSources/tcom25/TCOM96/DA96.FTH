\\ DA96.SEQ    disasembler for 8096 by Mike Mayo,
\   based on DIS8086.SEQ   8086 Disassembler  by Charles Curley

{

: 8096d-t@      ( a1 -- n1 )    \ d-t@ returns data in HI/LO order,
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

: NEXTB         ( - n ) cptr d-tc@ incr> cptr ;
: NEXTW         ( - w ) cptr 8096d-t@  2 +!> cptr ;

: H.>\          ( n1 -- )
                BASE @ >R HEX (U.) "> R> BASE ! ;

: H.>           ( n1 -- )
                H.>\ 1 SPACES> ;

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

: .N ( op -- op ) \ show number of unknown opcode
        " ???? " ">  dup H.>  ;

VARIABLE OPS    \ operand count
0 VALUE AMODE
: .MODE ( op -- op ) \ pick out address mode bits
        DUP 3 AND !> AMODE   ;

: .WREG  " w." "> NEXTB .data ;
: .BREG  " b." "> NEXTB .data ;
: .LREG  " L." "> NEXTB .data ;

: .IMMW   " #" ">  NEXTW .data ;
: .IMMB   " #" ">  NEXTB .data ;

: .INDIRECT
        NEXTB DUP
        1 AND IF  " [" "> 1- .data\ " ]+, " ">
            ELSE  " [" "> .data\ " ], " ">
            THEN
        ;

: .INDEXED
        " [" "> NEXTB DUP $FE AND .data\ " ] +" ">
        1 AND IF  NEXTW
            ELSE  NEXTB
            THEN
        .data\ " , " "> ;

: .WAOP   AMODE EXEC: .WREG  .IMMW  .INDIRECT  .INDEXED  ;

: .BAOP   AMODE EXEC: .BREG  .IMMB  .INDIRECT  .INDEXED  ;


: _SKIP   " SKIP  " "> .BREG  ;
: _CLR    " CLR   " "> .WREG  ;
: _NOT    " NOT   " "> .WREG  ;
: _NEG    " NEG   " "> .WREG  ;
: _DEC    " DEC   " "> .WREG  ;
: _EXT    " EXT   " "> .LREG  ;
: _INC    " INC   " "> .WREG  ;
: _SHR    " SHR   " "> .BREG  .WREG  ;
: _SHL    " SHL   " "> .BREG  .WREG  ;
: _SHRA   " SHRA  " "> .BREG  .WREG  ;
: _SHRL   " SHRL  " "> .BREG  .LREG  ;
: _SHLL   " SHLL  " "> .BREG  .LREG  ;
: _SHRAL  " SHRAL " "> .BREG  .LREG  ;
: _NORML  " NORML " "> .BREG  .LREG  ;

: 0xS ( op -- n ) \
        DUP 15 AND
        EXEC:  _SKIP  _CLR  _NOT  _NEG  .N    _DEC   _EXT    _INC
               _SHR   _SHL  _SHRA  .N  _SHRL  _SHLL  _SHRAL  _NORML  ;

: _CLRB   " CLRB  " ">  .BREG  ;
: _NOTB   " NOTB  " ">  .WREG  ;
: _NEGB   " NEGB  " ">  .BREG  ;
: _DECB   " DECB  " ">  .BREG  ;
: _EXTB   " EXTB  " ">  .WREG  ;
: _INCB   " INCB  " ">  .BREG  ;
: _SHRB   " SHRB  " ">  .BREG  .BREG  ;
: _SHLB   " SHRB  " ">  .BREG  .BREG  ;
: _SHRAB  " SHRAB " ">  .BREG  .BREG  ;

: 1xS ( op -- n ) \
        DUP 15 AND
        EXEC:  .N    _CLRB  _NOTB   _NEGB  .N  _DECB  _EXTB  _INCB
               _SHRB  _SHLB  _SHRAB  .N    .N  .N    .N    .N   ;

: _SJMP    " SJMP  " ">  DUP 7 AND 256 *  NEXTB + SEXT  cptr +  .SYMBOL  ;
: _SCALL   " SCALL " ">  DUP 7 AND 256 *  NEXTB + SEXT  cptr +  .SYMBOL  ;

: 2xS ( op -- n ) \
        DUP $28 < IF _SJMP ELSE _SCALL THEN ;

: _JBC   " JBC   " ">  DUP 7 AND .  .BREG  NEXTB SEXT  cptr +  .SYMBOL  ;
: _JBS   " JBS   " ">  DUP 7 AND .  .BREG  NEXTB SEXT  cptr +  .SYMBOL  ;

: 3xS ( op -- n ) \
        DUP $38 < IF _JBC ELSE _JBS THEN ;

: .MUL3   .MODE  .WAOP  " s" "> .WREG  " d" "> .LREG  ;
: .MULB3  .MODE  .BAOP  " s" "> .BREG  " d" "> .WREG  ;
: .MUL    .MODE  .WAOP  .LREG ;
: .MULB   .MODE  .BAOP  .WREG ;
: .DIV    .MODE  .WAOP  .LREG ;
: .DIVB   .MODE  .BAOP  .WREG ;

: _MULU3   " MULU3 " "> .MUL3 ;
: _MULUB3  " MULUB3" "> .MULB3 ;
: _MULU    " MULU  " "> .MUL  ;
: _MULUB   " MULUB " "> .MULB ;
: _DIVU    " DIVU  " "> .DIV  ;
: _DIVUB   " DIVUB " "> .DIVB ;

: _AND3   " AND3  " "> .MODE .WAOP " s" "> .WREG " d" "> .WREG ;
: _ADD3   " ADD3  " "> .MODE .WAOP " s" "> .WREG " d" "> .WREG ;
: _SUB3   " SUB3  " "> .MODE .WAOP " s" "> .WREG " d" "> .WREG ;

: 4xS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _AND3  _ADD3  _SUB3  _MULU3  ;

: _ANDB3   " ANDB3 " "> .MODE .BAOP " s" "> .BREG " d" "> .BREG ;
: _ADDB3   " ADDB3 " "> .MODE .BAOP " s" "> .BREG " d" "> .BREG ;
: _SUBB3   " SUBB3 " "> .MODE .BAOP " s" "> .BREG " d" "> .BREG ;

: 5xS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _ANDB3  _ADDB3  _SUBB3  _MULUB3  ;

: _AND   " AND   " "> .MODE .WAOP .WREG ;
: _ADD   " ADD   " "> .MODE .WAOP .WREG ;
: _SUB   " SUB   " "> .MODE .WAOP .WREG ;

: 6xS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _AND  _ADD  _SUB  _MULU  ;

: _ANDB   " ANDB  " "> .MODE .BAOP .BREG ;
: _ADDB   " ADDB  " "> .MODE .BAOP .BREG ;
: _SUBB   " SUBB  " "> .MODE .BAOP .BREG ;

: 7xS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _ANDB  _ADDB  _SUBB  _MULUB  ;

: _OR    " OR    " "> .MODE .WAOP .WREG ;
: _XOR   " XOR   " "> .MODE .WAOP .WREG ;
: _CMP   " CMP   " "> .MODE .WAOP .WREG ;

: 8xS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _OR  _XOR  _CMP  _DIVU  ;

: _ORB    " ORB   " "> .MODE .BAOP .BREG ;
: _XORB   " XORB  " "> .MODE .BAOP .BREG ;
: _CMPB   " CMPB  " "> .MODE .BAOP .BREG ;

: 9xS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _ORB  _XORB  _CMPB  _DIVUB  ;

: _LD     " LD    " "> .MODE .WAOP .WREG ;
: _ADDC   " ADDC  " "> .MODE .WAOP .WREG ;
: _SUBC   " SUBC  " "> .MODE .WAOP .WREG ;
: _LDBZE  " LDBZE " "> .MODE .BAOP .WREG ;

: AxS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _LD  _ADDC  _SUBC  _LDBZE    ;

: _LDB    " LDB   " "> .MODE .BAOP .BREG ;
: _ADDCB  " ADDCB " "> .MODE .BAOP .BREG ;
: _SUBCB  " SUBCB " "> .MODE .BAOP .BREG ;
: _LDBSE  " LDBSE " "> .MODE .BAOP .WREG ;

: BxS ( op -- n ) \
        DUP 15 AND 2/ 2/
        EXEC:  _LDB  _ADDCB  _SUBCB  _LDBSE    ;


: _BMOV  " BMOV  " ">         .WREG  .LREG  ;

: _ST    DUP $C1 = IF  _BMOV
                ELSE  " ST    " ">  .MODE  .WAOP  .WREG
                THEN  ;

: _CMPL  " CMPL  " ">         .LREG  .LREG  ;

: _STB   DUP $C5 = IF  _CMPL
                ELSE  " STB   " ">  .MODE  .BAOP  .BREG
                THEN  ;

: _PUSH  " PUSH  " ">  .MODE  .WAOP         ;

: _POP   " POP   " ">  .MODE  .WAOP         ;

: CxS ( op -- n ) \
  DUP 15 AND  2/ 2/
  EXEC:  _ST  _STB  _PUSH  _POP  ;


SELF.L _JNST ," JNST"
SELF.L _JNH ," JNH"
SELF.L _JGT ," JGT"
SELF.L _JNC ," JNC"
SELF.L _JNVT ," JNVT"
SELF.L _JNV ," JNV"
SELF.L _JGE ," JGE"
SELF.L _JNE ," JNE"
SELF.L _JST ," JST"
SELF.L _JH ," JH"
SELF.L _JLE ," JLE"
SELF.L _JC ," JC"
SELF.L _JVT ," JVT"
SELF.L _JV ," JV"
SELF.L _JLT ," JLT"
SELF.L _JE ," JE"

: .BR| ( op -- op )
        DUP  15 AND
  EXEC: _JNST _JNH _JGT _JNC _JNVT _JNV _JGE _JNE
        _JST  _JH  _JLE _JC  _JVT  _JV  _JLT _JE ;

: DxS ( op --op ) \ D0-DF branch & dest
        .BR|  NEXTB SEXT cptr + .SYMBOL ;


: _LCALL   " LCALL " ">  NEXTW  cptr +  .SYMBOL  ;
: _LJMP    " LJMP  " ">  NEXTW  cptr +  .SYMBOL  ;

: _DJNZ    " DJNZ  " ">  NEXTB H.>  NEXTB SEXT cptr +  .SYMBOL  ;
: _DJNZW   " DJNZW " ">  NEXTB H.>  NEXTB SEXT cptr +  .SYMBOL  ;
: _BR[]    " BR[]  " ">  NEXTB H.> ;

: ExS ( op -- n )
        DUP 15 AND
        CASE   0 OF _DJNZ  ENDOF
               1 OF _DJNZW ENDOF
               3 OF _BR[]  ENDOF
               7 OF _LJMP  ENDOF
              15 OF _LCALL ENDOF
              DROP .N
        ENDCASE ;

: _MUL3   " MUL3  " "> .MUL3 ;
: _MULB3  " MULB3 " "> .MULB3 ;
: _MUL    " MUL   " "> .MUL  ;
: _MULB   " MULB  " "> .MULB ;
: _DIV    " DIV   " "> .DIV  ;
: _DIVB   " DIVB  " "> .DIVB ;

: _FES  NEXTB $FC AND
        CASE
        $4C OF _MUL3  ENDOF
        $5C OF _MULB3 ENDOF
        $6C OF _MUL  ENDOF
        $7C OF _MULB ENDOF
        $8C OF _DIV  ENDOF
        $9C OF _DIVB ENDOF
        DROP ENDCASE  ;

.SELF _RET ," RET"
.SELF _F1S ," F1S"
.SELF _PUSHF ," PUSHF"
.SELF _POPF ," POPF"
.SELF _PUSHA ," PUSHA"
.SELF _POPA ," POPA"
.SELF _TRAP ," TRAP"
.SELF _CLRC ," CLRC"
.SELF _SETC ," SETC"
.SELF _DI ," DI"
.SELF _EI ," EI"
.SELF _CLRVT ," CLRVT"
.SELF _NOP ," NOP"
.SELF _RST ," RST"

: _IDLPD   " IDLPD " ">  NEXTB H.>  ;

: FxS ( op -- op )
  DUP 15 AND
  EXEC: _RET  _F1S  _PUSHF _POPF  _PUSHA _POPA _IDLPD _TRAP
        _CLRC _SETC _DI    _EI    _CLRVT _NOP  _FEs   _RST  ;

: %dis1         ( op -- op )
                ops off
                incr> cptr
                255 AND DUP 4 2/S
                EXEC: 0xS 1xS 2xS 3xS 4xS 5xS 6xS 7xS
                      8xS 9xS AxS BxS CxS DxS ExS FxS ;

: dis1          ( <opc> -- )
                %dis1 drop
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
        dup !> #inst-bytes
        4 min 0                         \ upto 4 bytes
        ?DO                             \ space before to conform with MDF
           DUP i + d-tc@ 2 0.r space    \ print a byte
        LOOP !> cptr ;

\ ==== hex file ======================================================

CODE place-hex-record ( -- ) \ move a hex record, outbuf -> to object memory
\tcom   save_bx
        push    es
        mov     ax, &> obj-seg
        mov     es, ax
        push    si
        push    bp
        mov     bx, # outbuf            \ get the size of the hex record
        mov     al, 3 [bx]
        cmp     al, # 'A'
        jl      0 $
        sub     al, # '7'
        jmp     1 $
   0 $: sub     al, # '0'
   1 $: mov     cl, al
        sub     ch, ch
        mov     al, 2 [bx]
        cmp     al, # 'A'
        jl      2 $
        sub     al, # '7'
        jmp     3 $
   2 $: sub     al, # '0'
   3 $: sub     ah, ah
        mov     dx, # $10
        mul     ax, dx
        add     cx, ax
        mov     al, 7 [bx]              \ get data address
        cmp     al, # 'A'
        jl      4 $
        sub     al, # '7'
        jmp     5 $
   4 $: sub     al, # '0'
   5 $: sub     ah, ah
        mov     di, ax
        mov     al, 6 [bx]
        cmp     al, # 'A'
        jl      6 $
        sub     al, # '7'
        jmp     7 $
   6 $: sub     al, # '0'
   7 $: sub     ah, ah
        mov     dx, # $10
        mul     ax, dx
        add     di, ax
        mov     al, 5 [bx]
        cmp     al, # 'A'
        jl      8 $
        sub     al, # '7'
        jmp     9 $
   8 $: sub     al, # '0'
   9 $: sub     ah, ah
        mov     dx, # $100
        mul     ax, dx
        add     di, ax
        mov     al, 4 [bx]
        cmp     al, # 'A'
        jl      10 $
        sub     al, # '7'
        jmp     11 $
  10 $: sub     al, # '0'
  11 $: sub     ah, ah
        mov     dx, # $1000
        mul     ax, dx
        add     di, ax
        sub     si, si
        sub     ah, ah
  12 $: mov     bp, cx                          \ save loop counter
        mov     cl, $0b [bx+si]                 \ get lower nibble
        cmp     cl, # 'A'
        jl      13 $
        sub     cl, # '7'
        jmp     14 $
  13 $: sub     cl, # '0'
  14 $: mov     al, $0a [bx+si]                 \ get upper nibble
        cmp     al, # 'A'
        jl      15 $
        sub     al, # '7'
        jmp     16 $
  15 $: sub     al, # '0'
  16 $: shl     al, # 1
        shl     al, # 1
        shl     al, # 1
        shl     al, # 1
        or      al, cl
        mov     es: 0 [di], al
        inc     si
        inc     si
        inc     di
        mov     cx, bp                          \ restore loop counter
        loop    12 $
        pop     bp
        pop     si
\tcom   load_bx
        pop     es
\tcom   ret
\fpc    next
        END-CODE

: CLOSE-HEX-FILE ( -- )
        seqhandle hclose drop ;

: OPEN-HEX-FILE ( -- )
        " hex" ">$ file-name $>ext              \ get the file name
        file-name $file
        IF screen-output
           help-them
           ." Couldn't open hex file, extension: .hex"
           ls-abort
        THEN ibreset ;

: %LOAD-OBJ-FILE ( -- )
        open-hex-file
        begin lineread c@               \ get an object line
        while place-hex-record          \ place the bytes in obj memory
        repeat close-hex-file ;

: PROCESSOR-INIT ( -- )                 \ target processor specific init stuff
        false !> ignore-library-code    \ default to exclude library functions
        ;

