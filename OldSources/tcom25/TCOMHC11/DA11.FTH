\ DA11.SEQ             DisAssembler for 6811            by Tom Zimmer

128 array instr_buf                      \ instruction buffer

: ">            ( a1 n1 -- )            \ append text a1,n1 to inst buffer
                instr_buf +place ;

: SPACES>       ( n1 -- )
                "                 " drop swap 0max 16 min "> ;

: h.##   " $" "> save> base hex  0 <# # #     #> "> restore> base ;
: h.#### " $" "> save> base hex  0 <# # # # # #> "> restore> base ;

0 value sym-file-save           \ not zero if we have source for this word?

: .SYMBOL ( a1 -- )
        dup a-function-symbol?
        IF      drop
                sym-seg sym-name> countl 31 min 1 max instr_buf +placel
                1 spaces>
                sym-file#> !> sym-file-save
        ELSE
                h.####  -1 !> sym-file-save
        THEN    ;

: .DATA ( a1 -- )
        dup a-data-symbol?          \ in symbol table ?
        IF      drop
                sym-seg sym-name> countl 31 min 1 max instr_buf +placel
                1 spaces>
        ELSE    dup 0 FFh between
                if      h.##
                else    h.####
                then
        THEN ;

: NEXTB         ( - n ) cptr d-tc@ incr> cptr ;
: NEXTW         ( - w ) cptr d-t@  2 +!> cptr ;

256 constant #opcodes
  4 constant #b/opcode
    variable pg2ptr     0 pg2ptr !      \ init page pointers to zero
    variable pg3ptr     0 pg3ptr !
    variable pg4ptr     0 pg4ptr !

#opcodes #b/opcode * ARRAY opbuf        \ opcode execution buffer

M: .instname    ( a1 -- )
        count dup>r ">                  \ show inst name if present
        4 r> - 0max 1+ spaces> ;

: doop  ( opcode -- )           \ disassemble an opcode
        #b/opcode * opbuf +
        length ?dup
        if      .instname                       \ show inst name if present
        then    @ ?dup
        if      execute
        else    " Invalid OP!" ">
        then    ;

: dopage        ( a1 -- )       \ disassemble a page 2, 3 or 4 instruction
                nextb >r
                begin   dup 2+ c@ r@ =
                        if      r>drop          \ cleanup return stack
                                3 + length swap .instname
                                execute
                                EXIT            \ **** EXITS HERE ****
                        then
                        @ ?dup 0=               \ link to next opcode
                until   r>drop
                " Invalid OP!" "> ;

\ ****************** addressing mode primitives *****************

: _inh   ( -- )  ;
: _dir   ( -- )  nextb .data ;
: _ext   ( -- )  nextw .data ;
: _absw  ( -- )  nextw .symbol ;
: _rel   ( -- )  nextb dup 128 and if FF00h or then cptr + .symbol ;
: _indx  ( -- )  nextb .data " ,X" "> ;
: _indxb ( -- )  nextb .data nextb .data " ,X" "> ;
: _indy  ( -- )  nextb .data " ,Y" "> ;
: _indyb ( -- )  nextb .data nextb .data " ,Y" "> ;
: _imm   ( -- )  " #" "> nextb .data ;
: _immd  ( -- )  " #" "> nextw .data ;
: _pg2   ( -- )  pg2ptr @ dopage ;
: _pg3   ( -- )  pg3ptr @ dopage ;
: _pg4   ( -- )  pg4ptr @ dopage ;

\ ************************* COMPILER WORDS ****************************

FORTH DECIMAL >FORTH ONLY FORTH ALSO COMPILER ALSO
HOST ALSO DEFINITIONS TARGET ALSO

: op-init ( -- )                        \ init the operand buffer to empty
        [FORTH]
        opbuf #opcodes #b/opcode * bounds
        do      0 i !-d                 \ clear out the array
     2 +loop    ;

op-init         \ clear target array at compile time

 0 value name_matched?
16 array name_save

: INAME! ( op a1 -<name>- op+1 ) \ allocate name if not already allocated
        [FORTH]
        >resaddr @
        over #b/opcode * opbuf + tuck 2+ !-d
        here-d swap !-d                         \ default to new name
        0 here-d !-d                            \ null out name
        bl word count name_save place
        off> name_matched?
        seg-data save!> sseg
        #opcodes 0
        do      i #b/opcode * opbuf + @-d ?dup
                if      name_save swap dup c@-d 1+ comp 0=
                        over i <> and           \ and not myself
                        if      \ name_save c@ 1+ negate allot-d
                                i #b/opcode * opbuf + @-d
                                over #b/opcode * opbuf + !-d
                                on> name_matched?
                                leave           \ leave string ptr on stack
                        then
                then
        loop    1+                              \ store string pointer
        name_matched? 0=
        if      name_save dup c@ 1+ s,-d        \ allocate new name
        then
        restore> sseg ;

: IPG!  ( op a1 -- op+1 )              \ insert an extended page
        [FORTH]
        >resaddr @
        over #b/opcode * opbuf + 2+ !-d 1+ ;

\       Structure: [ link ][ opcode ][ function ][ name string ]
: IPAGE! ( op func page -<name>- )              \ allocate name
        [FORTH]
        >r
        >resaddr @
        here-d r@ @-d ,-d r> !-d                \ insert into page chain
        swap c,-d                               \ lay in opcode
        ,-d                                     \ lay in function address
        bl word count name_save place
        name_save dup c@ 1+ s,-d ;              \ lay in new instruction name

\ ***************************************************************************
\ ******** Support for the various addressing modes in the 68HC11 ***********
\ ***************************************************************************

: INH   ( n1 -<name>- n2 ) ['] _inh   iname! ;  \ lay in function & name ptr
: DIR   ( n1 -<name>- n2 ) ['] _dir   iname! ;  \ lay in function & name ptr
: EXT   ( n1 -<name>- n2 ) ['] _ext   iname! ;  \ lay in function & name ptr
: ABSW  ( n1 -<name>- n2 ) ['] _absw  iname! ;  \ lay in function & name ptr
: REL   ( n1 -<name>- n2 ) ['] _rel   iname! ;  \ lay in function & name ptr
: INDX  ( n1 -<name>- n2 ) ['] _indx  iname! ;  \ lay in function & name ptr
: INDXB ( n1 -<name>- n2 ) ['] _indxb iname! ;  \ lay in function & name ptr
: IMM   ( n1 -<name>- n2 ) ['] _imm   iname! ;  \ lay in function & name ptr
: IMMD  ( n1 -<name>- n2 ) ['] _immd  iname! ;  \ lay in function & name ptr
: PG2   ( n1 -- n2 )       ['] _pg2   ipg! ;    \ lay in function only
: PG3   ( n1 -- n2 )       ['] _pg3   ipg! ;    \ lay in function only
: PG4   ( n1 -- n2 )       ['] _pg4   ipg! ;    \ lay in function only

: INH2  ( n1 -<name>- ) ['] _inh   pg2ptr ipage! ; \ lay in function & name
: DIR2  ( n1 -<name>- ) ['] _dir   pg2ptr ipage! ; \ lay in function & name
: EXT2  ( n1 -<name>- ) ['] _ext   pg2ptr ipage! ; \ lay in function & name
: ABSW2 ( n1 -<name>- ) ['] _absw  pg2ptr ipage! ; \ lay in function & name
: INDY  ( n1 -<name>- ) ['] _indy  pg2ptr ipage! ; \ lay in function & name
: INDYB ( n1 -<name>- ) ['] _indyb pg2ptr ipage! ; \ lay in function & name
: IMMD2 ( n1 -<name>- ) ['] _immd  pg2ptr ipage! ; \ lay in function & name

: DIR3  ( n1 -<name>- ) ['] _dir   pg3ptr ipage! ; \ lay in function & name
: EXT3  ( n1 -<name>- ) ['] _ext   pg3ptr ipage! ; \ lay in function & name
: INDX3 ( n1 -<name>- ) ['] _indx  pg3ptr ipage! ; \ lay in function & name
: IMMD3 ( n1 -<name>- ) ['] _immd  pg3ptr ipage! ; \ lay in function & name

: INDY4 ( n1 -<name>- ) ['] _indy  pg4ptr ipage! ; \ lay in function & name

TARGET DEFINITIONS FORTH TARGET >TARGET

\ **********************************************************************
\ ******** The instructions translation table for the 68HC11 ***********
\ **********************************************************************

0       \ start at opcode index of zero, gets bumped for each instruction
( 00 )  inh TEST          inh NOP           inh IDIV          inh FDIV
        inh LSRD          inh LSRD          inh TAP           inh TPA
( 08 )  inh INX           inh DEX           inh CLV           inh SEV
        inh CLC           inh SEC           inh CLI           inh SEI
( 10 )  inh SBA           inh CBA           dir BRSET         dir BRCLR
        dir BSET          dir BCLR          inh TAB           inh TBA
( 18 )  pg2               inh DAA           pg3               inh ABA
        indxb BSET        indxb BCLR        indxb BRSET       indxb BRCLR
( 20 )  rel BRA           rel BRN           rel BHI           rel BLS
        rel BCC/BHS       rel BCS/BLO       rel BNE           rel BEQ
( 28 )  rel BVC           rel BVS           rel BPL           rel BMI
        rel BGE           rel BLT           rel BGT           rel BLE
( 30 )  inh TSX           inh INS           inh PULA          inh PULB
        inh DES           inh TXS           inh PSHA          inh PSHB
( 38 )  inh PULX          inh RTS           inh ABX           inh RTI
        inh PSHX          inh MUL           inh WAI           inh SWI
( 40 )  inh NEGA          1+                1+                inh COMA
        inh LSRA          1+                inh RORA          inh ASRA
( 48 )  inh LSLA          inh ROLA          inh DECA          1+
        inh INCA          inh TSTA          1+                inh CLRA
( 50 )  inh NEGB          1+                1+                inh COMB
        inh LSRB          1+                inh RORB          inh ASRB
( 58 )  inh LSLB          inh ROLB          inh DECB          1+
        inh INCB          inh TSTB          1+                inh CLRB
( 60 )  indx NEG          1+                1+                indx COM
        indx LSR          1+                indx ROR          indx ASR
( 68 )  indx LSL          indx ROL          indx DEC          1+
        indx INC          indx TST          indx JMP          indx CLR
( 70 )  ext NEG           1+                1+                ext COM
        ext LSR           1+                ext ROR           ext ASR
( 78 )  ext LSL           ext ROL           ext DEC           1+
        ext INC           ext TST           absw JMP          ext CLR
( 80 )  imm SUBA          imm CMPA          imm SBCA          immd SUBD
        imm ANDA          imm BITA          imm LDAA          1+
( 88 )  imm EORA          imm ADCA          imm ORAA          imm ADDA
        immd CPX          rel bsr           immd LDS          inh XGDX
( 90 )  dir SUBA          dir CMPA          dir SBCA          dir SUBD
        dir ANDA          dir BITA          dir LDAA          dir STAA
( 98 )  dir EORA          dir ADCA          dir ORAA          dir ADDA
        dir CPX           dir JSR           dir LDS           dir STS
( A0 )  indx SUBA         indx CMPA         indx SBCA         indx SUBD
        indx ANDA         indx BITA         indx LDAA         indx STAA
( A8 )  indx EORA         indx ADCA         indx ORAA         indx ADDA
        indx CPX          indx JSR          indx LDS          indx STS
( B0 )  ext SUBA          ext CMPA          ext SBCA          ext SUBD
        ext ANDA          ext BITA          ext LDAA          ext STAA
( B8 )  ext EORA          ext ADCA          ext ORAA          ext ADDA
        ext CPX           absw JSR          ext LDS           ext STS
( C0 )  immd SUBB         immd CMPB         immd SBCB         imm ANDD
        imm ANDB          imm BITB          imm LDAB          1+
( C8 )  imm EORB          imm ADCB          imm ORAB          imm ADDB
        immd LDD          pg4               immd LDX          inh STOP
( D0 )  dir SUBB          dir CMPB          dir SBCB          dir ADDD
        dir ANDB          dir BITB          dir LADB          dir STAB
( D8 )  dir EORB          dir ADCB          dir ORAB          dir ADDB
        dir LDD           dir STD           dir LDX           dir STX
( E0 )  indx SUBB         indx CMPB         indx SBCB         indx ADDD
        indx ANDB         indx BITB         indx LDAB         indx STAB
( E8 )  indx EORB         indx ADCB         indx ORAB         indx ADDB
        indx LDD          indx STD          indx LDX          indx STX
( F0 )  ext  SUBB         ext  CMPB         ext  SBCB         ext  ADDD
        ext  ANDB         ext  BITB         ext  LDAB         ext  STAB
( F8 )  ext  EORB         ext  ADCB         ext  ORAB         ext  ADDB
        ext  LDD          ext  STD          ext  LDX          ext  STX
drop            \ cleanup the stack

\ Page 2, leading opcode 18h
    08h inh2 INY      09h inh2 DEY      1Ch indy BSET     1Dh indyb BCLR
    1Eh indyb BRSET   1Fh indyb BRCLR   30h inh2 TSY      35h inh2 TYS
    38h inh2 PULY     3Ah inh2 ABY      3Ch inh2 PSHY     60h indy NEG
    63h indy COM      64h indy LSR      66h indy ROR      67h indy ASR
    68h indy LSL      69h indy ROL      6Ah indy DEC      6Ch indy INC
    6Dh indy TST      6Eh indy JMP      6Fh indy CLR      8Ch immd2 CPY
    8Fh inh2 XGDY     9Ch dir2 CPY      A0h indy SUBA     A1h indy CMPA
    A2h indy SBCA     A3h indy SUBD     A4h indy ANDA     A5h indy BITA
    A6h indy LDAA     A7h indy STAA     A8h indy EORA     A9h indy ADCA
    AAh indy ORAA     ABh indy ADDA     ACh indy CPY      ADh indy JSR
    AEh indy LDS      AFh indy STS      BCh ext2 CPY      CEh immd2 LDY
    DEh dir2 LDY      DFh dir2 STY      E0h indy SUBB     E1h indy CMPB
    E2h indy SBCB     E3h indy ADDD     E4h indy ANDB     E5h indy BITB
    E6h indy LDAB     E7h indy STAB     E8h indy EORB     E9h indy ADCB
    EAh indy ORAB     EBh indy ADDB     ECh indy LDD      EDh indy STD
    EEh indy LDY      EFh indy STY      FEh ext2 LDY      FFh ext2 STY

\ Page 3, leading opcode 1Ah
    83h immd3 LDY     93h dir3 CPD      A3h indx3 CPD     ACh indx3 CPY
    B3h ext3 CPD      EEh indx3 LDY     EFh indx3 STY

\ Page 4, leading opcode CDh
    A3h indy4 CPD     ACh indy4 CPX     EEh indy4 LDX     EFh indy4 STX

: %DISASM       ( <opc> -- )
                drop instr_buf count type
                #inst-bytes +!> cptr ;

: %.INST-BYTES ( -- )
        instr_buf off
        cptr >r nextb doop              \ get the opcode for this instruction
        R@ cptr r> -                    \ get the number of bytes to print
        dup !> #inst-bytes              \ set instruction length
        4 min 0                         \ upto 4 bytes
        ?DO                             \ space before to conform with MDF
           DUP i + d-tc@ 2 0.r space    \ print a byte
        LOOP !> cptr ;

TRUE #IF        \ use TRUE if using the .HEX, and FALSE for .BIN

\ ==== INTEL hex file ======================================================

CODE place-hex-record ( -- ) \ move a hex record, outbuf -> to object memory
        save_bx
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
        load_bx
        pop     es
        ret
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
        begin   lineread c@              \ get an object line
        while   outbuf 8 + @             \ get the HEX record type
                dup  " 20" drop @ =      \    record type 20
                swap " 00" drop @ = or   \ or record type 00
                if place-hex-record      \ place the bytes in obj memory
                then
        repeat  close-hex-file ;

#ELSE
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

#THEN

: PROCESSOR-INIT ( -- )                 \ target processor specific init stuff
        false !> ignore-library-code    \ default to include library functions
        ;

