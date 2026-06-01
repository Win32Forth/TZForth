\\ ASM86.SEQ            8086 Assembler               by Tom Zimmer

------------------------------------------------------------------------

 12/30/92 18:02 tjz
  This assembler now assembles the F-PC kernel, generating an identical
KERNEL.COM file.

 12/28/92 18:15 tjz
  Added immediate to displaced memory pointer to all instructions. They
had been overlooked.

 12/23/92 tjz
  Completed initial pass on the 8086 assembler. All instructions and
addressing modes included have been tested. Probably still some missing,
but will run into them later.

 12/17/92 09:16 tjz
  This assembler is based on an assembler implemented for the SSP1600 DSP
processor.

 12/17/92 08:10 tjz
  Additional modifications to make the valid operand list easier to
setup and maintain.

  This assembler is based on the assembler written by Jerry Boutelle for
the SAMSUNG SAM8 microcontroller and subsequently implemented by Robert
Smith for the SAMSUNG 56000 micro controller.

  This assembler was originally based on PASM.SEQ. PASM was developed by
Tom Zimmer and Robert Smith for the F-PC Forth system.


------------------------------------------------------------------------
  Use "SETASM86" to select this new 8086 assembler.

  Use "SET8086"  to re-select the old 8086 assembler.

{

true  directive \asmdebug       \ controls whether debugging stuf is loaded

\asmdebug needs dis8086.seq

warning off                     \ we have many re-definitions

HEADERS

only forth also definitions vocabulary ASM86 assembler also

' ASM86 ALIAS [ASM86] IMMEDIATE

HEADERLESS

: INIT-APRIOR   ( -- )
                0 ['] drop a;!             \ init with harmless operation
                aprior 4 + 2@ aprior 2! ;

: DOASSEM86   ( -- )   \ initial setup of 8086 assembler by CODE
                @> run =: arunsave
                init-aprior
                lihere =: linestrt
                ll-global? 0=
                IF
\- init_labels          llab-init       \ initialize all local labels
                                        \ if used on F-PC
\+ init_labels          init_labels     \ initialize only first 40 labels
                                        \ if used in TCOM
                THEN also ASM86 ;

: SETASM86    ( -- )  \ assemble 86 code
                ['] DOASSEM86 is setassem clear_labels ;

SETASM86

\ define SET8086 only if its NOT already defined.

\- set8086 : SET8086 ( -- ) \ assemble 8086 code
\- set8086         ['] doassem is setassem clear_labels ;

only forth also assembler also ASM86 definitions also

\ some alias headers so we don't have to redefine these words in
\ the new target assembler.

HEADERS

' $             alias $
' $:            alias $:
' ic,           alias ic,
' oc,           alias oc,
' o,            alias o,
' c,            alias c,
' ,             alias ,
' here          alias here
' end-code      alias end-code  immediate
' end-code      alias c;        immediate

' o,            alias offset_16,
' oc,           alias offset_8,
' oc,           alias signed_8,
' oc,           alias relative_8,
' o,            alias relative_16,

HEADERLESS

' a;            alias a;
' a;!           alias a;!
' ll-global?    alias ll-global?
' ll-errs?      alias ll-errs?

\+ compiler     true
\- compiler     false
#IF

compiler also
' "errmsg       alias "errmsg

#ELSE

: "errmsg       ( cfa a1 n1 -- )
                cr type drop abort ;

' assembler alias [assembler] immediate

#THEN

only forth also ASM86 definitions also


}       The following constants define the individual operands that
        are possible.
{

57 constant opbval              \ the operand base value

opbval  3 + dup constant _NULL  \ no operand (a funny code to detect)
        3 + dup constant _(R)   \ indirect register
        3 + dup constant _AL    \ AL register addressing
        3 + dup constant _AX    \ AX register addressing
        3 + dup constant _DA    \ direct address
        3 + dup constant _FAR   \ far call
        3 + dup constant _IMM   \ immediate data
        3 + dup constant _IND   \ indirect
        3 + dup constant _R16   \ word register operand
        3 + dup constant _R8    \ byte register operand
        3 + dup constant _SEG   \ segment register
drop

 8 array operands       \ room for seven operands plus a verification code
 0 value opoff          \ operand offset

: operand!      ( n1 -- )
                operands opoff + c!  incr> opoff ;

: operand0      ( -- )
                operands 6 _null fill  \ fill with _NULL for 6 bytes
                off> opoff ;

0 value optable

: opdef:      ( -<name op op op op>- )  \ define an legal operand set
                create
                ' execute c,            \ upto three operands are legal
                ' execute c,
                ' execute c,
                does>
                body> optable - 2/ ;    \ returns CFA of the operand set

here !> optable         \ pointer to start of operand table
here 0 ,                \ length of operands

\ 58 valid operand sets for the 8086 plus "WORD" in many cases

opdef:  NO-OPR          _null   _null   _null   \ ret
opdef:  R16             _r16    _null   _null   \ dec cx
opdef:  R16,(R)         _r16    _(r)    _null   \ ld bx (bx)
opdef:  R16,DA          _r16    _da     _null   \ adc ax,bingo
opdef:  R16,DA,(R)      _r16    _da     _(r)    \ ld bx 34 (bx)
opdef:  R16,IMM         _r16    _imm    _null   \ mov bx,#123
opdef:  R16,R16         _r16    _r16    _null   \ adc ax,si
opdef:  R16,R8          _r16    _r8     _null   \ out dx,al
opdef:  R16,SEG         _r16    _seg    _null   \ mov ax,ds
opdef:  R8              _r8     _null   _null   \ inc al
opdef:  R8,(R)          _r8     _(r)    _null   \ ld bl (bx)
opdef:  R8,DA           _r8     _da     _null   \ mov al,bingo
opdef:  R8,DA,(R)       _r8     _da     _(r)    \ ld bl 34 (bx)
opdef:  R8,IMM          _r8     _imm    _null   \ mov al,#23
opdef:  R8,R8           _r8     _r8     _null   \ adc al,cl
opdef:  AX              _ax     _null   _null   \ dec cx
opdef:  AX,(R)          _ax     _(r)    _null   \ ld bx (bx)
opdef:  AX,DA           _ax     _da     _null   \ adc ax,bingo
opdef:  AX,DA,(R)       _ax     _da     _(r)    \ ld bx 34 (bx)
opdef:  AX,IMM          _ax     _imm    _null   \ adc ax,#1234
opdef:  AX,R16          _ax     _r16    _null   \ adc ax,si
opdef:  AX,R8           _ax     _r8     _null   \ rcl ax,cl
opdef:  AX,SEG          _ax     _seg    _null   \ mov ax,ds
opdef:  AL              _al     _null   _null   \ inc al
opdef:  AL,(R)          _al     _(r)    _null   \ ld bl (bx)
opdef:  AL,DA           _al     _da     _null   \ mov al,bingo
opdef:  AL,DA,(R)       _al     _da     _(r)    \ ld bl 34 (bx)
opdef:  AL,IMM          _al     _imm    _null   \ adc al,#23
opdef:  AL,R8           _al     _r8     _null   \ adc al,cl
opdef:  AL,R16          _al     _r16    _null   \ in al,dx
opdef:  DA              _da     _null   _null   \ jmp bingo
opdef:  DA,(R)          _da     _(r)    _null   \ dec $23 (bp)
opdef:  DA,(R),R16      _da     _(r)    _r16    \ ld 34 (bx) dx
opdef:  DA,(R),R8       _da     _(r)    _r8     \ ld 34 (bx) dl
opdef:  DA,(R),SEG      _da     _(r)    _seg    \ mov $24 (si) ds
opdef:  DA,(R),IMM      _da     _(r)    _imm    \ mov $24 (si) # $23
opdef:  DA,IMM          _da     _imm    _null   \ mov bingo,#1234
opdef:  DA,R16          _da     _r16    _null   \ adc bingo,ax
opdef:  DA,R8           _da     _r8     _null   \ adc bingo,ah
opdef:  DA,SEG          _da     _seg    _null   \ mov bingo,ds
opdef:  (R)             _(r)    _null   _null   \ dec (bx)
opdef:  (R),R16         _(r)    _r16    _null   \ ld (bx) dx
opdef:  (R),R8          _(r)    _r8     _null   \ ld (bx) dl
opdef:  (R),SEG         _(r)    _seg    _null   \ mov (si), ds
opdef:  (R),IMM         _(r)    _imm    _null   \ mov (si), # $23
opdef:  FAR             _far    _null   _null   \ ret far
opdef:  FAR,DA          _far    _da     _null   \ ret far 2
opdef:  FAR,DA,DA       _far    _da     _da     \ call far otherseg bingo
opdef:  FAR,IND,DA      _far    _ind    _da     \ call far [] bingo
opdef:  IMM,R8          _imm    _r8     _null   \ out # 23 al
opdef:  IMM,R16         _imm    _r16    _null   \ out # 23 ax
opdef:  IND,DA          _ind    _da     _null   \ call [] bingo
opdef:  IND,FAR,DA      _ind    _far    _da     \ call [] far bingo
opdef:  SEG             _seg    _null   _null   \ pop ds
opdef:  SEG,DA          _seg    _da     _null   \ mov ds,bingo
opdef:  SEG,R16         _seg    _r16    _null   \ mov es,cx
opdef:  SEG,(R)         _seg    _(r)    _null   \ mov es,(si)
opdef:  SEG,DA,(R)      _seg    _da     _(r)    \ mov es, $23 (si)

here over - swap !      \ fill in length of operand table to this END POINT

                        \ next define the bad combination of operands
opdef:  BADOP           _null   _null   _null   \ can't ever get here

false \asmdebug drop true       \ debugging verson in high level
#IF

: @.op          ( a1 -- a2 )
                count opbval 3 + - 3 / 5 * ['] _null + >name.id ;

: .optable      ( -- )
                save> base hex
                optable length 6 - bounds
                do      cr decimal
                        i optable - 2/ 3 u.r space
                           hex
                        i optable - 2/ 4 u.r ." h  "
                        i >name.id 30 sp>col
                        i >body @.op @.op @.op drop
                        50 ms ?keypause
             6 +loop
                cr operands @.op @.op @.op drop
                restore> base ;

: findopt       ( -- optype ) \ find operand code for this set of operands
                false save!> caps
                _null operand!          \ add an extra verification marker
\               cr ." Looking for: " operands @.op @.op @.op drop
                operands 3 optable length search
                if      optable + 2+    \ return the valid operand set BODY
\                       cr ." Found      : " dup @.op @.op @.op drop
                        body>
\                       ."  of type: " dup h. dup >name .id
                        optable - 2/
                else    drop badop      \ return the BAD operand flag
                then
                restore> caps ;

: .i            ( -<inst_name>- )       \ display an instruction
                ' cr ." Instruction: " dup >name.id
                >body @ >body length +xseg
                swap count dup ." operand_cnt: " . 0
                save> base hex
                do      cr
                         4 sp>col count 2* optable +
                        dup c@ ( CALL ) $E8 <> 1 and + >name.id
                        16 sp>col over i 4 * 6 +
                        2dup @L 2 u.r 2+ space
                             @L >name.id
                        50 ms ?keypause
                loop    2drop
                restore> base ;

#ELSE

SET8086
code findopt    ( -- optype )   \ find operand code for this set of operands
                mov dx, si              \ save SI for later restore
                mov di, # operands      \ get addr of current op set
                mov si, &> optable      \ get addr of valid op sets
                mov cx, 0 [si]          \ get length of valid op sets
                add cx, si              \ calc to end, then plus 2 makes
                add cx, # 2             \ CX point to just beyond op sets
                add si, # 5             \ adjust valid ptr to data area
        0 $:    sub bx, bx              \ preclear bx
        1 $:    mov al, 0 [bx+di]       \ get first byte of current op set
                cmp al, 0 [bx+si]       \ do they match
                je 2 $                  \ if match, then go bump to next word
                add si, # 6             \ else add 6 bytes to next table entry
                cmp si, cx              \ end reached
                jl 0 $                  \ back for next try
                mov ax, # badop         \ if at end, then return bad op set
                jmp 3 $                 \ goto the exit routine
        2 $:    add bx, # 1             \ bump BX to next byte
                cmp bx, # 3             \ each entry is 3 bytes long
                jl 1 $                  \ if not at end of op set
                mov ax, bx              \ found it, get offset to op set
                add ax, si              \ plus op set base
                sub ax, # 6             \ back to CFA of valid op set
                sub ax, &> optable      \ subtract table base
                shr ax, # 1             \ Shift right one bit
        3 $:    mov si, dx              \ recover saved SI
                1push                   \ push the result
                end-code
SETASM86
#THEN

0 value A-SM            \ assembler stack mark
0 value A-WD            \ assembler word flag

defer    8-BIT          \ operand form for an 8 bit number
defer   16-BIT          \ operand form for a 16 bit number

' _da   is  8-bit
' _da   is 16-bit

: ?NOS ( ? -- ? ) \ is there a number on the stack ?
        sp@ a-sm - abs 2/ dup 1- swap 0
        ?DO dup i - 1+ pick       \ look at deepest on stack first
           $ff u>                 \ is this stack entry > 255 ?
           IF   16-bit            \ yes, its a 16 bit number
           ELSE  8-bit            \ no,  its a  8 bit number
           THEN operand!
        LOOP drop
        sp@ !> a-sm ;             \ store assembler stack mark

: INST-RESET ( -- ) \ reset assembler for next instruction
        sp@ !> a-sm             \ store assembler stack mark
        ['] _da   is  8-bit     \ default to  8 bit number is byte
        ['] _da   is 16-bit     \ default to 16 bit number is direct adr
        off> a-wd               \ clear the assembler word flag
        operand0 ;

}               ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                º error handling º
                ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

defer IS-BAD                   \ defer for other forms of error handling

: _IS-BAD ( -- )
        init-aprior
        0 " Invalid OPERAND" "errmsg ;

' _is-bad is is-bad

: ?"asmerr      ( f1 a1 n1 -- )
                rot
                if      0 -rot "errmsg
                else    2drop
                then    ;

}               ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                º  extension byte generation º
                ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

: do-op         ( opcode  code_generator  -- )
\asmdebug       dup >name cr .id
                execute ;               \ execute the code generator

set8086

}
     The internal structure of op-code definitions is somewhat complex.
     The following diagram shows code space and list space for the assembler
     word  ADC :
              ÚÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂ\---------\ÂÄÄÄÄÄÄÄÄÄÄÄ¿
  List space: ³  SCANOPT  ³ ptr-to-cnt³   $A9     ³    $00    ³  CG01     ³
              ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÅ\---------\ÅÄÄÄÄÄÄÄÄÄÄÄ´
                    ^           |     ³  $D0AA    ³    $00    ³  CGxx     ³
                    |           |     ÀÄÄÄÄÄÄÄÄÄÄÄÁ\---------\ÁÄÄÄÄÄÄÄÄÄÄÄÙ
              ÚÄÄÄÄÄÄÄÄÄÄ¿      |                    \_ NOT PRESENT IN 8086
              ³  +XSEG   ³      |
              ÀÄÄÄÄÄÄÄÄÄÄÙ      |_______
                    |_________          |
                              |         V            WORD       WORD
  (Headerless : def)     ÚÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿
  Code space: JMP DOCOL  ³  pointer  ³operand cnt³   r,ir    ³  rr,rr    ³
               ^         ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÙ
               |______________          BYTE
                              |
  ADC definition in      ÚÄÄÄÄÄÄÄÄÄÄÄ¿
  code space: JMP DOVAR  ³  pointer  ³
                         ÀÄÄÄÄÄÄÄÄÄÄÄÙ

{

code scanopt    ( optype -- )   \ scan the operand types of an instruction
                                \ and execute the corresponding code gen
                pop ax
                cmp ax, # badop
                jne 2 $
         1 $:   mov es, 2 [rp]          \ load es & si from above definition
                mov si, 0 [rp]
                add rp, # 4             \ discard them from return stack
                mov ax, # ' is-bad      \ execution address
                jmp ax                  \ the instruction operands are bad
         2 $:   mov di, es: 0 [si]      \ get addr of scan array
                xor ch, ch
                mov cl, 0 [di]          \ and get length of array
                mov bx, cx              \ save for later in BX
                dec bx                  \ adj to valid limit
                inc di                  \ bump to start of array data
                add si, # 2             \ bump SI to beyond array ptr
                mov dx, es
                mov es, sseg            \ preserve and set srch seg
                repnz scasb             \ scan for matching BYTE \ ********
                jnz 1 $                 \ no match found
                mov es, dx              \ restore ES
                sub bx, cx              \ cvt to item number
                shl bx, # 1             \ mult by 2
                mov cx, bx
                shl bx, # 1             \ mult by 4
                add bx, si              \ to start of opcodes
                mov cx, es: 0 [bx]      \ get the opcode
                push cx                 \ to stack
                mov cx, es: 2 [bx]      \ get the code generator address \ ***
                push cx                 \ to stack
                mov es, 2 [rp]          \ load es & si from above definition
                mov si, 0 [rp]
                add rp, # 4             \ discard them from return stack
                mov ax, # ' do-op       \ execution address
                jmp ax  end-code        \ go execute the code generator
setASM86

}       The following words are used to define machine code instructions.
        These words build a sequence of legal operand types list space
        and a corresponding list of instruction opcodes, extension byte
        codes and code generator addresses in code space. When an
        instruction is executed, the generated operand type is compared,
        by scanopt above, with the sequence of bytes in list space. If a
        match is found the corresponding code generator is executed. If
        no match occurs the operands do not match the instruction and
        the word IS-BAD is executed.
{


false value IN_WORD!ED \ true if in_word captured in translation

HEADERS

' ; alias }i: immediate

: %i{          ( -- )
                compile findopt
                compile scanopt
                here dup x, 0 c,                \ lay in a null count
                begin   depth
                                '                       \ look up BYTE
                        begin   here c@ 0=              \ end of line
                                here 1+ c@ '\' = or     \ or comment ?
                        while   drop filltib            \ load next line
                                '
                                here c@ 0=
                                abort" End of file encountered"
                        repeat  dup ['] }i: <>  \ while not "}i:"
                while   execute c,              \ compile operand set BYTE
                        depth 1- <> abort" Op must return a value!"
                        1 over c+!              \ increase array length by 1
                        bl word ?uppercase
                        number drop x,          \ compile opcode
                        ' x,
                repeat  nip nip execute ;

: do-i          ( n1 -- )
                >r ?nos r>
                execute ;

: i{           ( -- a1 )
                here
                !csp   current @ context !
                ,jump
                xhere paragraph +
                dup xdpseg !
                xseg @ - ,
                xdp off
                state on
                %i{
                dup 3 + >nest swap - over 1+ !          \ make a ":" def
                create ,
                does>
                   @                    \ save address of mnemonic data
                   ['] do-i a;!         \  and execution address in aprior
                   a;                   \ assemble previous instruction
                   in_word!ed 0=
                   IF >in_word @
                      !> asm->in        \ save in pointer for index file
                   THEN
                   inst-reset ;         \ reset for next instruction

}               ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                º machine code generation º
                ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

' 8* alias <<3          \ shift n1 left three bits

: ?cl?          ( n1 -- )       \ check for CL register
        1 <> " Only CL is valid for shifts and rotates" ?"asmerr ;

: ?byte?        ( n1 -- n1 )    \ check for byte value 0 to FF
        dup $FF u> " Only a byte value allowed" ?"asmerr ;

: ?imm=1?       ( n1 -- )       \ check immediate is one only
        1 <> " Only immediate 1 allowed" ?"asmerr ;

: cg00  ( opcode -- )                   \ no operand byte opcode
        ic, ;

: cg01  ( opcode -- )                   \ no operand word opcode
        split ic, oc, ;

: cg02  ( r16 r16 opcode -- )           \ r16,r16 or r8,r8
        >r swap r>                              \ reverse the normal op order
        split ic, rot <<3 or or oc, ;

: cg03  ( r16 da opcode -- )            \ r16,da or r8,da
        ic, swap <<3 6 or oc, offset_16, ;

: cg04  ( da r16 opcode -- )            \ da,r16 or da,r8
        ic, <<3 6 or oc, offset_16, ;

: cg05  ( r16 imm opcode -- )           \ r16,imm or r8,imm
        over -128 127 between
        if      split 2 or ic, rot or oc, offset_8,
        else    split 1 or ic, rot or oc, offset_16,
        then    ;

: cg06  ( da opcode -- )                \ call
        ic, relative_16, ;

: cg07  ( da imm opcode -- )            \ add da,imm
        over $FF u> if $100 or then
        over -128 127 between a-wd and if $200 or then
        a-wd or                                 \ add in WORD flag
        dup>r
        split ic, oc, swap o,
        r> $300 and $100 = if o, else oc, then ;

: cg08  ( da opcode -- )                \ ret
        ic, offset_16, ;

: cg09  ( da imm opcode -- )            \ and da,imm
        over $FF u> if $100 or then
        a-wd or                                 \ add in WORD flag
        dup>r
        split ic, oc, swap o,
        r> $100 and if o, else oc, then ;

: cg10  ( da imm opcode -- )            \ cmp r16,imm
        over -128 127 between if $200 or then
        dup>r split ic, rot or oc,
        r> $300 and $100 = if o, else oc, then ;

: cg11  ( r16/r8 imm opcode -- )        \ and r16,imm or and r8,imm
        split dup>r ic, rot or oc,
        r> 1 and if o, else oc, then ;

: cg12  ( r16 da (r- opcode -- )        \ adc r16,da,(r)
        ic, rot <<3 or
        over $100 u<
        if      over 0= over 7 and 6 <> and
                if      oc, drop
                else    $40 or oc, signed_8,
                then
        else    $80 or oc, offset_16,
        then ;

: cg13  ( da (r- r16 opcode -- )        \ adc da,(r),r16
        ic, <<3 or
        over $100 u<
        if      over 0= over 7 and 6 <> and
                if      oc, drop
                else    $40 or oc, signed_8,
                then
        else    $80 or oc, offset_16,
        then ;

: cg14  ( r16/r8 (r- opcode -- )        \ adc r16,(r) or adc r8,(r)
        ic,
        dup 6 <>                        \ (BP)?
        if      swap <<3 or oc,
        else    swap <<3 or $40 or oc, 0 oc,
        then    ;

: cg15  ( (r- r16/r8 opcode -- )        \ adc (r),r16 or adc (r),r8
        ic,
        over 6 <>                               \ (bp) test
        if      <<3 or oc,
        else    <<3 or $40 or oc, 0 oc,
        then    ;

: cg16  ( ind da opcode -- )            \ call [] bingo
        split ic, 6 or oc, offset_16, drop ;

: cg17  ( far da da opcode -- )         \ call far otherseg bingo
        ic, relative_16, o, drop ;

: cg18  ( ind far da opcode -- )        \ call [] far bingo
        split ic, 6 or oc, offset_16, 2drop ;

: cg19  ( ax/al imm opcode -- )         \ adc ax,#1234 or adc al,#23
        dup ic, 1 and
        if      offset_16,
        else    ?byte? offset_8,
        then    drop ;

: cg20  ( opcode -- )                   \ cmps
        a-wd u16/ u16/ or                       \ add in WORD flag
        ic, ;

: cg21  ( r16 opcode -- )               \ dec bx
        or ic, ;

: cg22  ( r8 opcode -- )                \ dec bl
        split ic, or oc, ;

: cg23  ( (r- opcode -- )               \ dec (bx)
        a-wd or                                 \ add in WORD flag
        split ic, over 6 <>                     \ (bp) test
        if      or oc,
        else    or $40 or oc, 0 oc,
        then    ;

: cg25  ( da opcode -- )                \ dec bingo
        a-wd or                                 \ add in WORD flag
        split ic, 6 or oc, offset_16, ;

: cg26  ( da (r- opcode -- )            \ dec $23 (di)
        a-wd or                                 \ add in WORD flag
        split ic, or over $100 u<
        if      over 0= over 7 and 6 <> and
                if      oc, drop
                else    $40 or oc, signed_8,
                then
        else    $80 or oc, offset_16,
        then    ;

: cg29  ( al/ax r16 opcode -- )         \ in ax dx or in al dx
        ic, 2 <> " Only DX valid in IN instruction" ?"asmerr
        drop ;

: cg30  ( da opcode -- )                \ int $21
        over $FF u> " Invalid Interrupt number" ?"asmerr
        over 3 =
        if      ic, drop
        else    1 or ic, oc,
        then    ;

: cg31  ( da opcode -- )                \ ja bingo
        ic, relative_8, ;

: cg32  ( da opcode -- )                \ jmp da  (long or short)
        over here 1+ - -128 127 between
        if      split drop ic, relative_8,
        else    split ic, drop relative_16,
        then    ;

: cg33  ( r16/r8 imm opcode -- )        \ mov si, # 23
        dup 8 and
        if      rot or ic, o,
        else    rot or ic, ?byte? oc,
        then    ;

: cg34  ( ax/al da opcode -- )          \ mov ax, bingo   or mov al, bingo
        ic, o, drop ;

: cg35  ( da r16/r8 opcode -- )         \ mov da,r16  or  mov da,r8
        over 0=                         \ AX or AL
        if      1 and                   \ 16bit?
                if      $A3 ic, drop o,         \ special handler for AX
                else    $A2 ic, drop o,         \ special handler for AL
                then
        else    ic, <<3 6 or oc, o,
        then    ;

: cg36  ( r16 seg opcode -- )           \ r16,seg
        split ic, rot <<3 or or oc, ;

: cg37  ( da ax/al opcode -- )          \ out $123,ax  or  out $23,al
        swap 0<> " Source MUST be AX or AL in OUT instruction" ?"asmerr
        dup ic, 1 and
        if      o,
        else    ?byte? oc,
        then    ;

: cg38  ( r16 al/ax opcode -- )         \ out dx ax  or  out dx al
        ic,
        swap 2 <> or                    \ src must be AX/AL & dest must be DX
        " Only DX,AX or DX,AL valid in OUT instruction" ?"asmerr
        ;

: cg39  ( r16 opcode -- )               \ pop ax  or pop si
        swap <<3 or ic, ;

: cg40  ( (r- cl opcode -- )            \ rcl (r),cl
        a-wd or                                 \ add in WORD flag
        swap ?cl? cg22 ;

: cg42  ( al imm opcode -- )            \ rcl al,#1
        swap ?imm=1? cg22 ;

: cg43  ( da (r- cl opcode -- )         \ rcl 23 (bp,si) cl
        swap ?cl? cg26 ;

: cg44  ( da imm opcode -- )            \ rcl bingo # 1
        swap ?imm=1? cg25 ;

: cg46  ( r16 imm opcode -- )           \ r16,imm or r8,imm
        split 1 or ic, rot or oc, o, ;

: cg47  ( r8 imm opcode -- )            \ test r8,imm
        split ic, rot or oc, ?byte? oc, ;

: cg48  ( ax r16 opcode -- )            \ xchg ax,dx
        or ic, drop ;

: cg49  ( da (r- imm opcode -- )        \ adc da,(r),imm
        over $FF u> if $100 or then
        over -128 127 between a-wd and if $200 or then
        a-wd or                                 \ add in WORD flag
        dup>r
        split ic, rot or 2 pick $FF u>
        if      $80 or oc, swap offset_16,
        else    2 pick 0= over 7 and 6 <> and
                if      oc, nip
                else    $40 or oc, swap signed_8,
                then
        then    r> $300 and $100 = if o, else oc, then ;

: cg50  ( (r- imm opcode -- )           \ adc (r),imm
        >r 0 -rot r> cg49 ;

: cg51  ( (r- imm opcode -- )           \ and (r),imm
        over $FF u> if $100 or then
        a-wd or                                 \ add in WORD flag
        dup>r
        split ic, rot dup 6 <>                  \ (bp) test
        if      or oc,
        else    or $40 or oc, 0 oc,
        then    r> $100 and if o, else oc, then ;

: cg53  ( far opcode -- )               \ ret far
        nip ic, ;

: cg54  ( far da opcode -- )            \ ret far 2
        cg08 drop ;

: cg55  ( da (r- imm opcode -- )        \ and da,(r),imm
        over $FF u> if $100 or then
        a-wd or                                 \ add in WORD flag
        dup>r
        split ic, rot or 2 pick $FF u>
        if      $80 or oc, swap offset_16,
        else    2 pick 0= over 7 and 6 <> and
                if      oc, nip
                else    $40 or oc, swap signed_8,
                then
        then    r> $100 and if o, else oc, then ;

: cg56  ( r16 r16 opcode -- )           \ xchg r16,r16
        >r swap r>
        2 pick 0=                               \ if source is AX
        if      drop $90 cg48                   \ then special case for AX
        else    split ic, rot <<3 or or oc,
        then    ;

}               ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                º 8086 instructions º
                ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼

{

HEADERS

i{  no-opr                $37 cg00 }i: AAA    \ Ascii adjust for addition

i{  no-opr              $D50A cg01 }i: AAD    \ Ascii adjust for division

i{  no-opr              $D40A cg01 }i: AAM    \ Ascii adjust for multiply

i{  no-opr                $3F cg00 }i: AAS    \ Ascii adjust for subtraction

i{  (r),r16               $11 cg15            \
    (r),r8                $10 cg15            \
    (r),imm             $8010 cg50            \
    al,(r)                $12 cg14            \
    al,da                 $12 cg03            \
    al,da,(r)             $12 cg12            \
    al,imm                $14 cg19            \
    al,r8               $10C0 cg02            \
    ax,(r)                $13 cg14            \
    ax,da                 $13 cg03            \
    ax,da,(r)             $13 cg12            \
    ax,imm                $15 cg19            \
    ax,r16              $11C0 cg02            \
    da,(r),r16            $11 cg13            \
    da,(r),r8             $10 cg13            \
    da,(r),imm          $8010 cg49            \
    da,imm              $8016 cg07            \
    da,r16                $11 cg04            \
    da,r8                 $10 cg04            \
    r16,(r)               $13 cg14            \
    r16,da                $13 cg03            \
    r16,da,(r)            $13 cg12            \
    r16,imm             $81D0 cg05            \
    r16,r16             $11C0 cg02            \
    r8,(r)                $12 cg14            \
    r8,da                 $12 cg03            \
    r8,da,(r)             $12 cg12            \
    r8,imm              $82D0 cg05            \
    r8,r8               $10C0 cg02 }i: ADC    \ Addition with carry

i{  (r),r16               $01 cg15            \
    (r),r8                $00 cg15            \
    (r),imm             $8000 cg50            \
    al,(r)                $02 cg14            \
    al,da                 $02 cg03            \
    al,da,(r)             $02 cg12            \
    al,imm                $04 cg19            \
    al,r8               $00C0 cg02            \
    ax,(r)                $03 cg14            \
    ax,da                 $03 cg03            \
    ax,da,(r)             $03 cg12            \
    ax,imm                $05 cg19            \
    ax,r16              $01C0 cg02            \
    da,(r),r16            $01 cg13            \
    da,(r),r8             $00 cg13            \
    da,(r),imm          $8000 cg49            \
    da,imm              $8006 cg07            \
    da,r16                $01 cg04            \
    da,r8                 $00 cg04            \
    r16,(r)               $03 cg14            \
    r16,da                $03 cg03            \
    r16,da,(r)            $03 cg12            \
    r16,imm             $81C0 cg05            \
    r16,r16             $01C0 cg02            \
    r8,(r)                $02 cg14            \
    r8,da                 $02 cg03            \
    r8,da,(r)             $02 cg12            \
    r8,imm              $82C0 cg05            \
    r8,r8               $00C0 cg02 }i: ADD    \ Addition

i{  (r),r16               $21 cg15            \
    (r),r8                $20 cg15            \
    (r),imm             $8020 cg51            \
    al,(r)                $22 cg14            \
    al,da                 $22 cg03            \
    al,da,(r)             $22 cg12            \
    al,imm                $24 cg19            \
    al,r8               $20C0 cg02            \
    ax,(r)                $23 cg14            \
    ax,da                 $23 cg03            \
    ax,da,(r)             $23 cg12            \
    ax,imm                $25 cg19            \
    ax,r16              $21C0 cg02            \
    da,(r),r16            $21 cg13            \
    da,(r),r8             $20 cg13            \
    da,(r),imm          $8020 cg55            \
    da,imm              $8026 cg09            \
    da,r16                $21 cg04            \
    da,r8                 $20 cg04            \
    r16,(r)               $23 cg14            \
    r16,da                $23 cg03            \
    r16,da,(r)            $23 cg12            \
    r16,imm             $81E0 cg11            \
    r16,r16             $21C0 cg02            \
    r8,(r)                $22 cg14            \
    r8,da                 $22 cg03            \
    r8,da,(r)             $22 cg12            \
    r8,imm              $80E0 cg11            \
    r8,r8               $20C0 cg02 }i: AND    \

i{  da                    $E8 cg06            \
    far,da,da             $9A cg17            \
    far,ind,da          $FF18 cg18            \
    ind,da              $FF10 cg16            \
    ind,far,da          $FF18 cg18 }i: CALL   \ Call a subroutine

i{  no-opr                $98 cg00 }i: CBW    \ Convert byte to word
i{  no-opr                $F8 cg00 }i: CLC    \ Clear carry
i{  no-opr                $FC cg00 }i: CLD    \ Clear direction flag
i{  no-opr                $FA cg00 }i: CLI    \ Clear interrupt enable flag
i{  no-opr                $F5 cg00 }i: CMC    \ Complement carry flag

i{  (r),r16               $39 cg15            \
    (r),r8                $38 cg15            \
    (r),imm             $8038 cg50            \
    al,(r)                $3A cg14            \
    al,da                 $3A cg03            \
    al,da,(r)             $3A cg12            \
    al,imm                $3C cg19            \
    al,r8               $38C0 cg02            \
    ax,(r)                $3B cg14            \
    ax,da                 $3B cg03            \
    ax,da,(r)             $3B cg12            \
    ax,imm                $3D cg19            \
    ax,r16              $39C0 cg02            \
    da,(r),r16            $39 cg13            \
    da,(r),r8             $38 cg13            \
    da,(r),imm          $8038 cg49            \
    da,imm              $803E cg07            \
    da,r16                $39 cg04            \
    da,r8                 $38 cg04            \
    r16,(r)               $3B cg14            \
    r16,da                $3B cg03            \
    r16,da,(r)            $3B cg12            \
    r16,imm             $81F8 cg10            \
    r16,r16             $39C0 cg02            \
    r8,(r)                $3A cg14            \
    r8,da                 $3A cg03            \
    r8,da,(r)             $3A cg12            \
    r8,imm              $80F8 cg11            \
    r8,r8               $38C0 cg02 }i: CMP    \

i{  no-opr                $A6 cg20 }i: CMPS   \ Compare string (byte or word)
i{  no-opr                $A6 cg20 }i: CMPSB  \ Compare string byte
i{  no-opr                $A7 cg20 }i: CMPSW  \ Compare string word

i{  no-opr                $99 cg00 }i: CWD    \ Convert word to double word

i{  no-opr                $27 cg00 }i: DAA    \ Decimal adjust for addition

i{  no-opr                $2F cg00 }i: DAS    \ Decimal adjust for subtraction

i{  al                  $FEC8 cg22            \
    ax                    $48 cg21            \
    r16                   $48 cg21            \
    r8                  $FEC8 cg22            \
    (r)                 $FE08 cg23            \
    da                  $FE08 cg25            \
    da,(r)              $FE08 cg26 }i: DEC    \ Decrement register of memory

i{  al                  $F6F0 cg22            \
    ax                  $F7F0 cg22            \
    r16                 $F7F0 cg22            \
    r8                  $F6F0 cg22            \
    (r)                 $F630 cg23            \
    da                  $F630 cg25            \
    da,(r)              $F630 cg26 }i: DIV    \ Divide

i{  al                  $F6F8 cg22            \
    ax                  $F7F8 cg22            \
    r16                 $F7F8 cg22            \
    r8                  $F6F8 cg22            \
    (r)                 $F638 cg23            \
    da                  $F638 cg25            \
    da,(r)              $F638 cg26 }i: IDIV   \ Integer divide

i{  al                  $F6E8 cg22            \
    ax                  $F7E8 cg22            \
    r16                 $F7E8 cg22            \
    r8                  $F6E8 cg22            \
    (r)                 $F628 cg23            \
    da                  $F628 cg25            \
    da,(r)              $F628 cg26 }i: IMUL   \ Integer multiply

i{  al,da                 $E4 cg19            \
    ax,da                 $E5 cg19            \
    al,imm                $E4 cg19            \
    ax,imm                $E5 cg19            \
    al,r16                $EC cg29            \
    ax,r16                $ED cg29 }i: IN     \ input port

i{  al                  $FEC0 cg22            \
    ax                    $40 cg21            \
    r16                   $40 cg21            \
    r8                  $FEC0 cg22            \
    (r)                 $FE00 cg23            \
    da                  $FE00 cg25            \
    da,(r)              $FE00 cg26 }i: INC    \ Increment register or memory

i{  da                    $CC cg30 }i: INT    \ Interrupt

i{  no-opr                $CE cg00 }i: INTO   \ Interrupt on overflow

i{  no-opr                $CF cg00 }i: IRET   \ Interrupt return

i{  da                    $77 cg31 }i: JA     \ Jump above
i{  da                    $77 cg31 }i: JNBE   \ Jump on not below or equal
i{  da                    $73 cg31 }i: JAE    \ Jump on above or equal
i{  da                    $73 cg31 }i: JNB    \ Jump on not below
i{  da                    $72 cg31 }i: JB     \ Jump on below
i{  da                    $72 cg31 }i: JNAE   \ Jump on not above or equal
i{  da                    $76 cg31 }i: JBE    \ Jump on below or equal
i{  da                    $76 cg31 }i: JNA    \ Jump on not above
i{  da                    $72 cg31 }i: JC     \ Jump on carry
i{  da                    $E3 cg31 }i: JCXZ   \ Jump on CX not zero
i{  da                    $74 cg31 }i: JE     \ Jump on equal
i{  da                    $74 cg31 }i: JZ     \ Jump on zero
i{  da                    $7F cg31 }i: JG     \ Jump on greater
i{  da                    $7F cg31 }i: JNLE   \ Jump on not less than or equal
i{  da                    $7D cg31 }i: JGE    \ Jump on greater or equal
i{  da                    $7D cg31 }i: JNL    \ Jump on not less than
i{  da                    $7C cg31 }i: JL     \ Jump on less than
i{  da                    $7C cg31 }i: JNGE   \ Jump on not greater than or equal
i{  da                    $7E cg31 }i: JLE    \ Jump on less than or equal
i{  da                    $7E cg31 }i: JNG    \ Jump on not greater than

i{  da                  $E9EB cg32
    ax                  $FFE0 cg22
    r16                 $FFE0 cg22
    far,da,da             $EA cg17
    far,ind,da          $FF28 cg18
    ind,da              $FF20 cg16
    ind,far,da          $FF28 cg18 }i: JMP    \ Jump to an address

i{  da                    $73 cg31 }i: JNC    \ Jump on not carry
i{  da                    $75 cg31 }i: JNE    \ Jump on not equal
i{  da                    $75 cg31 }i: JNZ    \ Jump on not zero
i{  da                    $71 cg31 }i: JNO    \ Jump on not overflow
i{  da                    $79 cg31 }i: JNS    \ Jump on not sign
i{  da                    $7B cg31 }i: JNP    \ Jump on not parity
i{  da                    $7B cg31 }i: JPO    \ Jump on parity odd
i{  da                    $70 cg31 }i: JO     \ Jump on overflow
i{  da                    $7A cg31 }i: JP     \ Jump on parity
i{  da                    $7A cg31 }i: JPE    \ Jump on parity equal
i{  da                    $78 cg31 }i: JS     \ Jump on sign

i{  no-opr                $9F cg00 }i: LAHF   \ Load register AH from Flags

i{  ax,(r)                $C5 cg14            \
    ax,da                 $C5 cg03            \
    ax,da,(r)             $C5 cg12            \
    r16,(r)               $C5 cg14            \
    r16,da                $C5 cg03            \
    r16,da,(r)            $C5 cg12 }i: LDS    \ Load pointer using DS

i{  ax,(r)                $8D cg14            \
    ax,da                 $8D cg03            \
    ax,da,(r)             $8D cg12            \
    r16,(r)               $8D cg14            \
    r16,da                $8D cg03            \
    r16,da,(r)            $8D cg12 }i: LEA    \ Load effective address

i{  ax,(r)                $C4 cg14            \
    ax,da                 $C4 cg03            \
    ax,da,(r)             $C4 cg12            \
    r16,(r)               $C4 cg14            \
    r16,da                $C4 cg03            \
    r16,da,(r)            $C4 cg12 }i: LES    \ Load pointer using ES

i{  no-opr                $F0 cg00 }i: LOCK   \ Lock the bus

i{  no-opr                $AC cg20 }i: LODS   \ load string (byte or word)
i{  no-opr                $AC cg20 }i: LODSB  \ load string byte
i{  no-opr                $AD cg20 }i: LODSW  \ load string word

i{  no-opr                $E2 cg31            \
    da                    $E2 cg31 }i: LOOP   \ Loop
i{  da                    $E1 cg31 }i: LOOPE  \ Loop while equal
i{  da                    $E1 cg31 }i: LOOPZ  \ Loop while zero
i{  da                    $E0 cg31 }i: LOOPNZ \ Loop while not zero
i{  da                    $E0 cg31 }i: LOOPNE \ Loop while not equal

i{  (r),r16               $89 cg15            \
    (r),r8                $88 cg15            \
    (r),seg               $8C cg15            \
    (r),imm             $C600 cg51            \
    al,(r)                $8A cg14            \
    al,da                 $A0 cg34            \
    al,da,(r)             $8A cg12            \
    al,imm                $B0 cg33            \
    al,r8               $8AC0 cg36            \
    ax,(r)                $8B cg14            \
    ax,da                 $A1 cg34            \
    ax,da,(r)             $8B cg12            \
    ax,imm                $B8 cg33            \
    ax,r16              $8BC0 cg36            \
    ax,seg              $8CC0 cg02            \
    da,(r),r16            $89 cg13            \
    da,(r),r8             $88 cg13            \
    da,(r),seg            $8C cg13            \
    da,(r),imm          $C600 cg55            \
    da,imm              $C606 cg09            \
    da,r16                $89 cg35            \
    da,r8                 $88 cg35            \
    da,seg                $8C cg04            \
    r16,(r)               $8B cg14            \
    r16,da                $8B cg03            \
    r16,da,(r)            $8B cg12            \
    r16,imm               $B8 cg33            \
    r16,r16             $8BC0 cg36            \
    r16,seg             $8CC0 cg02            \
    r8,(r)                $8A cg14            \
    r8,da                 $8A cg03            \
    r8,da,(r)             $8A cg12            \
    r8,imm                $B0 cg33            \
    r8,r8               $8AC0 cg36            \
    seg,(r)               $8E cg14            \
    seg,da                $8E cg03            \
    seg,da,(r)            $8E cg12            \
    seg,r16             $8EC0 cg36 }i: MOV    \

i{  no-opr                $A4 cg20 }i: MOVS   \ Move string (byte or word)
i{  no-opr                $A4 cg20 }i: MOVSB  \ Move string byte
i{  no-opr                $A5 cg20 }i: MOVSW  \ Move string word

i{  al                  $F6E0 cg22            \
    ax                  $F7E0 cg22            \
    r16                 $F7E0 cg22            \
    r8                  $F6E0 cg22            \
    (r)                 $F620 cg23            \
    da                  $F620 cg25            \
    da,(r)              $F620 cg26 }i: MUL    \ Multiply

i{  al                  $F6D8 cg22            \
    ax                  $F7D8 cg22            \
    r16                 $F7D8 cg22            \
    r8                  $F6D8 cg22            \
    (r)                 $F618 cg23            \
    da                  $F618 cg25            \
    da,(r)              $F618 cg26 }i: NEG    \ Negate

i{  no-opr                $90 cg00 }i: NOP    \ No operation

i{  al                  $F6D0 cg22            \
    ax                  $F7D0 cg22            \
    r16                 $F7D0 cg22            \
    r8                  $F6D0 cg22            \
    (r)                 $F610 cg23            \
    da                  $F610 cg25            \
    da,(r)              $F610 cg26 }i: NOT    \ Logical not

i{  (r),r16               $09 cg15            \
    (r),r8                $08 cg15            \
    (r),imm             $8008 cg51            \
    al,(r)                $0A cg14            \
    al,da                 $0A cg03            \
    al,da,(r)             $0A cg12            \
    al,imm                $0C cg19            \
    al,r8               $08C0 cg02            \
    ax,(r)                $0B cg14            \
    ax,da                 $0B cg03            \
    ax,da,(r)             $0B cg12            \
    ax,imm                $0D cg19            \
    ax,r16              $09C0 cg02            \
    da,(r),r16            $09 cg13            \
    da,(r),r8             $08 cg13            \
    da,(r),imm          $8008 cg55            \
    da,imm              $800E cg09            \
    da,r16                $09 cg04            \
    da,r8                 $08 cg04            \
    r16,(r)               $0B cg14            \
    r16,da                $0B cg03            \
    r16,da,(r)            $0B cg12            \
    r16,imm             $81C8 cg11            \
    r16,r16             $09C0 cg02            \
    r8,(r)                $0A cg14            \
    r8,da                 $0A cg03            \
    r8,da,(r)             $0A cg12            \
    r8,imm              $80C8 cg11            \
    r8,r8               $08C0 cg02 }i: OR     \ logical or

i{  da,r8                 $E6 cg37            \
    da,r16                $E7 cg37            \
    imm,r8                $E6 cg37            \
    imm,r16               $E7 cg37            \
    r16,r8                $EE cg38            \
    r16,r16               $EF cg38 }i: OUT    \ Output to port

i{  ax                    $58 cg21            \
    r16                   $58 cg21            \
    (r)                 $8F00 cg23            \
    da                  $8F00 cg25            \
    da,(r)              $8F00 cg26            \
    seg                   $07 cg39 }i: POP    \ Pop register or memory

i{  ax                    $50 cg21            \
    r16                   $50 cg21            \
    (r)                 $FF30 cg23            \
    da                  $FF30 cg25            \
    da,(r)              $FF30 cg26            \
    seg                   $06 cg39 }i: PUSH   \ Push register or memory

i{  no-opr                $9C cg00 }i: PUSHF  \ Push flags

i{  (r),r8              $D210 cg40            \
    al,imm              $D0D0 cg42            \
    al,r8               $D2D0 cg42            \
    ax,imm              $D1D0 cg42            \
    ax,r8               $D3D0 cg42            \
    da,(r),r8           $D210 cg43            \
    da,imm              $D010 cg44            \
    da,r8               $D210 cg44            \
    r16,imm             $D1D0 cg42            \
    r16,r8              $D3D0 cg42            \
    r8,imm              $D0D0 cg42            \
    r8,r8               $D2D0 cg42 }i: RCL    \ Rotate through carry left

i{  (r),r8              $D218 cg40            \
    al,imm              $D0D8 cg42            \
    al,r8               $D2D8 cg42            \
    ax,imm              $D1D8 cg42            \
    ax,r8               $D3D8 cg42            \
    da,(r),r8           $D218 cg43            \
    da,imm              $D018 cg44            \
    da,r8               $D218 cg44            \
    r16,imm             $D1D8 cg42            \
    r16,r8              $D3D8 cg42            \
    r8,imm              $D0D8 cg42            \
    r8,r8               $D2D8 cg42 }i: RCR    \ Rotate through carry right

i{  no-opr                $F3 cg00 }i: REP    \ Repeat
i{  no-opr                $F3 cg00 }i: REPE   \ Repeat while equal
i{  no-opr                $F3 cg00 }i: REPZ   \ Repeat while zero
i{  no-opr                $F2 cg00 }i: REPNE  \ Repeat while not equal
i{  no-opr                $F2 cg00 }i: REPNZ  \ Repeat while not zero

i{  no-opr                $C3 cg00            \
    da                    $C2 cg08            \
    far                   $CB cg53            \
    far,da                $CA cg54 }i: RET    \ Return from subroutine

i{  no-opr                $CB cg00            \
    da                    $CA cg08 }i: RETF   \ Return from far subroutine

i{  (r),r8              $D200 cg40            \
    al,imm              $D0C0 cg42            \
    al,r8               $D2C0 cg42            \
    ax,imm              $D1C0 cg42            \
    ax,r8               $D3C0 cg42            \
    da,(r),r8           $D200 cg43            \
    da,imm              $D000 cg44            \
    da,r8               $D200 cg44            \
    r16,imm             $D1C0 cg42            \
    r16,r8              $D3C0 cg42            \
    r8,imm              $D0C0 cg42            \
    r8,r8               $D2C0 cg42 }i: ROL    \ Rotate left

i{  (r),r8              $D208 cg40            \
    al,imm              $D0C8 cg42            \
    al,r8               $D2C8 cg42            \
    ax,imm              $D1C8 cg42            \
    ax,r8               $D3C8 cg42            \
    da,(r),r8           $D208 cg43            \
    da,imm              $D008 cg44            \
    da,r8               $D208 cg44            \
    r16,imm             $D1C8 cg42            \
    r16,r8              $D3C8 cg42            \
    r8,imm              $D0C8 cg42            \
    r8,r8               $D2C8 cg42 }i: ROR    \ Rotate right

i{  no-opr                $9E cg00 }i: SAHF   \ Store register AH into flags

i{  (r),r8              $D220 cg40            \
    al,imm              $D0E0 cg42            \
    al,r8               $D2E0 cg42            \
    ax,imm              $D1E0 cg42            \
    ax,r8               $D3E0 cg42            \
    da,(r),r8           $D220 cg43            \
    da,imm              $D020 cg44            \
    da,r8               $D220 cg44            \
    r16,imm             $D1E0 cg42            \
    r16,r8              $D3E0 cg42            \
    r8,imm              $D0E0 cg42            \
    r8,r8               $D2E0 cg42 }i: SAL    \ Shift arithmetic left

' SAL ALIAS SHL

i{  (r),r8              $D238 cg40            \
    al,imm              $D0F8 cg42            \
    al,r8               $D2F8 cg42            \
    ax,imm              $D1F8 cg42            \
    ax,r8               $D3F8 cg42            \
    da,(r),r8           $D238 cg43            \
    da,imm              $D038 cg44            \
    da,r8               $D238 cg44            \
    r16,imm             $D1F8 cg42            \
    r16,r8              $D3F8 cg42            \
    r8,imm              $D0F8 cg42            \
    r8,r8               $D2F8 cg42 }i: SAR    \ Shift arithmetic right

i{  (r),r16               $19 cg15            \
    (r),r8                $18 cg15            \
    (r),imm             $8018 cg50            \
    al,(r)                $1A cg14            \
    al,da                 $1A cg03            \
    al,da,(r)             $1A cg12            \
    al,imm                $1C cg19            \
    al,r8               $18C0 cg02            \
    ax,(r)                $1B cg14            \
    ax,da                 $1B cg03            \
    ax,da,(r)             $1B cg12            \
    ax,imm                $1D cg19            \
    ax,r16              $19C0 cg02            \
    da,(r),r16            $19 cg13            \
    da,(r),r8             $18 cg13            \
    da,(r),imm          $8018 cg49            \
    da,imm              $801E cg07            \
    da,r16                $19 cg04            \
    da,r8                 $18 cg04            \
    r16,(r)               $1B cg14            \
    r16,da                $1B cg03            \
    r16,da,(r)            $1B cg12            \
    r16,imm             $81D8 cg05            \
    r16,r16             $19C0 cg02            \
    r8,(r)                $1A cg14            \
    r8,da                 $1A cg03            \
    r8,da,(r)             $1A cg12            \
    r8,imm              $82D8 cg05            \
    r8,r8               $18C0 cg02 }i: SBB    \ Subtract with borrow

i{  no-opr                $AE cg20 }i: SCAS   \ Scan (byte or word) string
i{  no-opr                $AF cg20 }i: SCASW  \ Scan word string
i{  no-opr                $AE cg20 }i: SCASB  \ Scan byte string

i{  (r),r8              $D228 cg40            \
    al,imm              $D0E8 cg42            \
    al,r8               $D2E8 cg42            \
    ax,imm              $D1E8 cg42            \
    ax,r8               $D3E8 cg42            \
    da,(r),r8           $D228 cg43            \
    da,imm              $D028 cg44            \
    da,r8               $D228 cg44            \
    r16,imm             $D1E8 cg42            \
    r16,r8              $D3E8 cg42            \
    r8,imm              $D0E8 cg42            \
    r8,r8               $D2E8 cg42 }i: SHR    \ Shift right

i{  no-opr                $F9 cg00 }i: STC    \ Set carry

i{  no-opr                $FD cg00 }i: STD    \ Set direction flag

i{  no-opr                $FB cg00 }i: STI    \ Set interrupt enable flag

i{  no-opr                $AA cg20 }i: STOS   \ Store (byte or word) string
i{  no-opr                $AB cg20 }i: STOSW  \ Store word string
i{  no-opr                $AA cg20 }i: STOSB  \ Store byte string

i{  (r),r16               $29 cg15            \
    (r),r8                $28 cg15            \
    (r),imm             $8028 cg50            \
    al,(r)                $2A cg14            \
    al,da                 $2A cg03            \
    al,da,(r)             $2A cg12            \
    al,imm                $2C cg19            \
    al,r8               $28C0 cg02            \
    ax,(r)                $2B cg14            \
    ax,da                 $2B cg03            \
    ax,da,(r)             $2B cg12            \
    ax,imm                $2D cg19            \
    ax,r16              $29C0 cg02            \
    da,(r),r16            $29 cg13            \
    da,(r),r8             $28 cg13            \
    da,(r),imm          $8028 cg49            \
    da,imm              $802E cg07            \
    da,r16                $29 cg04            \
    da,r8                 $28 cg04            \
    r16,(r)               $2B cg14            \
    r16,da                $2B cg03            \
    r16,da,(r)            $2B cg12            \
    r16,imm             $81E8 cg05            \
    r16,r16             $29C0 cg02            \
    r8,(r)                $2A cg14            \
    r8,da                 $2A cg03            \
    r8,da,(r)             $2A cg12            \
    r8,imm              $82E8 cg05            \
    r8,r8               $28C0 cg02 }i: SUB    \ Subtract

i{  al,(r)                $84 cg14            \
    al,da                 $84 cg03            \
    al,da,(r)             $84 cg12            \
    al,imm                $A8 cg19            \
    al,r8               $84C0 cg02            \
    ax,(r)                $85 cg14            \
    ax,da                 $85 cg03            \
    ax,da,(r)             $85 cg12            \
    ax,imm                $A9 cg19            \
    ax,r16              $85C0 cg36            \
    da,imm              $F60C cg07            \
    r16,(r)               $85 cg14            \
    r16,da                $85 cg03            \
    r16,da,(r)            $85 cg12            \
    r16,imm             $F7C0 cg46            \
    r16,r16             $85C0 cg36            \
    r8,(r)                $84 cg14            \
    r8,da                 $84 cg03            \
    r8,da,(r)             $84 cg12            \
    r8,imm              $F6C0 cg47            \
    r8,r8               $84C0 cg02 }i: TEST   \ Test memory or register

i{  no-opr                $9B cg00 }i: WAIT   \ Wait till test line inactive

i{  (r),r16               $87 cg15            \
    (r),r8                $86 cg15            \
    ax,r16                $90 cg48            \
    ax,da                 $87 cg03            \
    al,r8               $86C0 cg02            \
    al,da                 $86 cg03            \
    da,(r),r16            $87 cg13            \
    da,(r),r8             $86 cg13            \
    da,r16                $87 cg04            \
    da,r8                 $86 cg04            \
    r16,r16             $87C0 cg56            \
    r16,da                $87 cg03            \
    r8,da                 $86 cg03            \
    r8,r8               $86C0 cg02 }i: XCHG   \ Exchange

i{  no-opr                $D7 cg00 }i: XLAT   \ Translate (byte)

i{  (r),r16               $31 cg15            \
    (r),r8                $30 cg15            \
    (r),imm             $8030 cg51            \
    al,(r)                $32 cg14            \
    al,da                 $32 cg03            \
    al,da,(r)             $32 cg12            \
    al,imm                $34 cg19            \
    al,r8               $30C0 cg02            \
    ax,(r)                $33 cg14            \
    ax,da                 $33 cg03            \
    ax,da,(r)             $33 cg12            \
    ax,imm                $35 cg19            \
    ax,r16              $31C0 cg02            \
    da,(r),r16            $31 cg13            \
    da,(r),r8             $30 cg13            \
    da,(r),imm          $8030 cg55            \
    da,imm              $8036 cg09            \
    da,r16                $31 cg04            \
    da,r8                 $30 cg04            \
    r16,(r)               $33 cg14            \
    r16,da                $33 cg03            \
    r16,da,(r)            $33 cg12            \
    r16,imm             $81F0 cg11            \
    r16,r16             $31C0 cg02            \
    r8,(r)                $32 cg14            \
    r8,da                 $32 cg03            \
    r8,da,(r)             $32 cg12            \
    r8,imm              $80F0 cg11            \
    r8,r8               $30C0 cg02 }i: XOR    \ logical exclusive or

}               ÉÍÍÍÍÍÍÍÍÍÍ»
                º operands º
                ÈÍÍÍÍÍÍÍÍÍÍ¼
{

I: OPERAND ( -- n1 )
        CREATE
         ,                              \ store actual operand value
         ,                              \ store register value
        DOES>   >r ?nos                 \ see if there is a number on stack
                r@ @ opoff 0<>          \ only allow ax or al as first oper
                if      _ax over = if drop _r16 then    \ replace with _r16
                        _al over = if drop _r8  then    \ replace with _r8
                then    operand!        \ get the operand code
                r> 2+ @                 \ get register value
                sp@ !> a-sm  ;          \ store assembler stack mark

\ 16 bit register operands

$00 _ax  operand AX     ' AX alias AX,
$01 _r16 operand CX     ' CX alias CX,
$02 _r16 operand DX     ' DX alias DX,
$03 _r16 operand BX     ' BX alias BX,
$04 _r16 operand SP     ' SP alias SP,
$05 _r16 operand BP     ' BP alias BP,  ' BP alias RP   ' BP alias RP,
$06 _r16 operand SI     ' SI alias SI,  ' SI alias IP   ' SI alias IP,
$07 _r16 operand DI     ' DI alias DI,

\ 8 bit register operands

$00 _al operand AL      ' AL alias AL,
$01 _r8 operand CL      ' CL alias CL,
$02 _r8 operand DL      ' DL alias DL,
$03 _r8 operand BL      ' BL alias BL,
$04 _r8 operand AH      ' AH alias AH,
$05 _r8 operand CH      ' CH alias CH,
$06 _r8 operand DH      ' DH alias DH,
$07 _r8 operand BH      ' BH alias BH,

\ Segment operands

$00 _seg operand ES     ' ES ALIAS ES,
$01 _seg operand CS     ' CS ALIAS CS,
$02 _seg operand SS     ' SS ALIAS SS,
$03 _seg operand DS     ' DS ALIAS DS,


\ Indirect 16bit register operands

$00 _(r) operand [BX+SI]        ' [BX+SI] ALIAS [SI+BX]
                                ' [BX+SI] ALIAS [BX+SI],
                                ' [BX+SI] ALIAS [SI+BX],
                                ' [BX+SI] ALIAS [BX+IP],
                                ' [BX+SI] ALIAS [IP+BX],
$01 _(r) operand [BX+DI]        ' [BX+DI] ALIAS [DI+BX]
                                ' [BX+DI] ALIAS [BX+DI],
                                ' [BX+DI] ALIAS [DI+BX],
$02 _(r) operand [BP+SI]        ' [BP+SI] ALIAS [SI+BP]
                                ' [BP+SI] ALIAS [RP+IP],
                                ' [BP+SI] ALIAS [IP+RP],
                                ' [BP+SI] ALIAS [BP+IP],
                                ' [BP+SI] ALIAS [IP+BP],
                                ' [BP+SI] ALIAS [BP+SI],
$03 _(r) operand [BP+DI]        ' [BP+DI] ALIAS [DI+BP]
                                ' [BP+DI] ALIAS [RP+DI]
                                ' [BP+DI] ALIAS [RP+DI],
                                ' [BP+DI] ALIAS [DI+RP],
                                ' [BP+DI] ALIAS [BP+DI],
                                ' [BP+DI] ALIAS [DI+BP],
$04 _(r) operand [SI]           ' [SI]    ALIAS [IP]
                                ' [SI]    ALIAS [SI],
                                ' [SI]    ALIAS [IP],
$05 _(r) operand [DI]           ' [DI]    ALIAS [DI],
$06 _(r) operand [BP]           ' [BP]    ALIAS [RP]
                                ' [BP]    ALIAS [BP],
                                ' [BP]    ALIAS [RP],
$07 _(r) operand [BX]           ' [BX]    ALIAS [BX],

\ Directives

$00 _far  operand FAR
$02 _ind  operand []

: WORD  ( -- )
        $100 !> a-wd ;  \ $100 weight is used as a bit mask for opcode

: BYTE  ( -- )
        off> a-wd ;

: #     ( n1 -- n1 ) \ expect an immediate
        ?nos                       \ see if there is a number on stack
        ['] _imm is  8-bit         \ set  8-bit number to an 8 bit immediate
        ['] _imm is  16-bit        \ set  16-bit number to a 16 bit immediate
        ;

: seg_over      ( n1 -<segment_name>- )
                create c, does> c@ ic, ;        \ segment over-ride

\ Segment over-ride commands:
$26 seg_over ES:
$2E seg_over CS:
$36 seg_over SS:
$3E seg_over DS:

only forth definitions also

decimal

warning on       \ re-enable the redefinition warning flag

true \asmdebug drop false
#IF \S #THEN            \ stop loading if not debugging

cr .( Type "ASMTEST" to assemble test instructions to the screen, or)
cr .( Type ">B ASMTEST" to assemble test instructions to the file BROWSE.PRN.)
: ASMTEST       [ loadline @ 2+ ] literal LOAD ;
\s


: .ins          ( -- )
                [ dis8086 ]
                ( cr ) a;
                depth
                if      ?stack cr .s
                        true
                        abort" The Instruction just assembled left data on stack"
                then
                save> base hex
                ?cs: =seg  reloc off
                outbuf count
                $20 skip 6 - 0max -trailing
                 5 sp>col type cp @
                30 sp>col inst
                62 sp>col
                [ forth ] here swap over umin over 7 - umax
                do i c@ 3 .r loop
                [ dis8086 ]
                here cp !
                restore> base
                ?keypause 30 ms ;

autoeditoff
statoff
.s

variable bingo

dis8086 here cp ! forth

code test86
        aaa                             .ins
        aad                             .ins
        aam                             .ins
        aas                             .ins
\
        adc ax, bx                      .ins
        adc di, si                      .ins
        adc bh, cl                      .ins
        adc si, bingo                   .ins
        adc bl, bingo                   .ins
        adc bingo ax                    .ins
        adc bingo ch                    .ins
        adc bingo # $123                .ins
        adc bingo # $23                 .ins
        adc bingo # -64                .ins
        adc bingo # $23 WORD            .ins
        adc di, # 1234                  .ins
        adc di, # 123                   .ins
        adc cl, # 123                   .ins
        adc bx, $23 [bp]                .ins
        adc bl, $23 [bp]                .ins
        adc bl, $23 [si]                .ins
        adc $23 [bp+si], cx             .ins
        adc $23 [bp+si], cl             .ins
        adc bx, 0 [bp]                  .ins
        adc bl, 0 [si]                  .ins
        adc 0 [bp+si], cx               .ins
        adc 0 [bp+si], cl               .ins
        adc ax, # $1234                 .ins
        adc al, # $34                   .ins
        adc $23 [bp], # $25             .ins
        adc $23 [bp+si], # $25          .ins
        adc $23 [bp+si], # $2556        .ins
        adc $23 [bp+si], # $25 word     .ins
        adc [bp], # $25                 .ins
        adc [bp], # $2556               .ins
        adc [bp+si], # $25              .ins
        adc [bp+si], # $25 word         .ins
\
        add ax, bx                      .ins
        add di, si                      .ins
        add bh, cl                      .ins
        add si, bingo                   .ins
        add bl, bingo                   .ins
        add bingo ax                    .ins
        add bingo ch                    .ins
        add bingo # $123                .ins
        add bingo # $23                 .ins
        add bingo # -64                 .ins
        add bingo # $23 WORD            .ins
        add di, # 1234                  .ins
        add di, # 123                   .ins
        add dx, # $c8                   .ins
        add cl, # 123                   .ins
        add bx, $23 [bp]                .ins
        add bl, $23 [bp]                .ins
        add bl, $23 [si]                .ins
        add $23 [bp+si], cx             .ins
        add $23 [bp+si], cl             .ins
        add bx, 0 [bp]                  .ins
        add bl, 0 [si]                  .ins
        add 0 [bp+si], cx               .ins
        add 0 [bp+si], cl               .ins
        add ax, # $1234                 .ins
        add al, # $34                   .ins
        add $23 [bp+si], # $25          .ins
        add $23 [bp+si], # $25 word     .ins
        add [bp+si], # $25              .ins
        add [bp+si], # $25 word         .ins
 \
        and ax, bx                      .ins
        and di, si                      .ins
        and bh, cl                      .ins
        and si, bingo                   .ins
        and bl, bingo                   .ins
        and bingo ax                    .ins
        and bingo ch                    .ins
        and bingo # $123                .ins
        and bingo # $23                 .ins
        and bingo # -64                 .ins
        and bingo # $23 WORD            .ins
        and di, # 1234                  .ins
        and di, # 123                   .ins
        and cl, # 123                   .ins
        and bx, $23 [bp]                .ins
        and bl, $23 [bp]                .ins
        and bl, $23 [si]                .ins
        and $23 [bp+si], cx             .ins
        and $23 [bp+si], cl             .ins
        and bx, 0 [bp]                  .ins
        and bl, 0 [si]                  .ins
        and 0 [bp+si], cx               .ins
        and 0 [bp+si], cl               .ins
        and ax, # $1234                 .ins
        and al, # $34                   .ins
        and $23 [bp+si], # $25          .ins
        and $23 [bp+si], # $25 word     .ins
        and [bp+si], # $25              .ins
        and [bp+si], # $25 word         .ins
\
        call bingo                      .ins
        call [] bingo                   .ins
        call far ?cs: bingo             .ins
        call [] far bingo               .ins
        call far [] bingo               .ins
\
        cbw                             .ins
        clc                             .ins
        cld                             .ins
        cli                             .ins
        cmc                             .ins
\
        cmp ax, bx                      .ins
        cmp dx, bx                      .ins
        cmp bx, dx                      .ins
        cmp di, si                      .ins
        cmp bh, cl                      .ins
        cmp si, bingo                   .ins
        cmp bl, bingo                   .ins
        cmp bingo ax                    .ins
        cmp bingo ch                    .ins
        cmp bingo # $123                .ins
        cmp bingo # $23                 .ins
        cmp bingo # -64                 .ins
        cmp bingo # $23 WORD            .ins
        cmp di, # 1234                  .ins
        cmp di, # 123                   .ins
        cmp cl, # 123                   .ins
        cmp bx, $23 [bp]                .ins
        cmp bl, $23 [bp]                .ins
        cmp bl, $23 [si]                .ins
        cmp $23 [bp+si], cx             .ins
        cmp $23 [bp+si], cl             .ins
        cmp bx, 0 [bp]                  .ins
        cmp bl, 0 [si]                  .ins
        cmp 0 [bp+si], cx               .ins
        cmp 0 [bp+si], cl               .ins
        cmp ax, # $1234                 .ins
        cmp al, # $34                   .ins
        cmp $23 [bp+si], # $25          .ins
        cmp $23 [bp+si], # $25 word     .ins
        cmp [bp+si], # $25              .ins
        cmp [bp+si], # $25 word         .ins
\
        cmps                            .ins
        cmps word                       .ins
\
        dec al                          .ins
        dec ax                          .ins
        dec cx                          .ins
        dec ch                          .ins
        dec 0 [si]                      .ins
        dec 0 [di] word                 .ins
        dec 0 [bp]                      .ins
        dec 0 [bp] word                 .ins
        dec bingo                       .ins
        dec $1234 [bp]                  .ins
        dec $23 [bx] word               .ins
        dec $1234 [bx]                  .ins
        dec bingo word                  .ins
\
        div al                          .ins
        div ax                          .ins
        div cx                          .ins
        div cl                          .ins
        div 0 [si]                      .ins
        div 0 [di] word                 .ins
        div 0 [bp]                      .ins
        div 0 [bp] word                 .ins
        div bingo                       .ins
        div $1234 [bp]                  .ins
        div $23 [bx] word               .ins
        div $1234 [bx]                  .ins
        div bingo word                  .ins
\
        idiv al                         .ins
        idiv ax                         .ins
        idiv cx                         .ins
        idiv cl                         .ins
        idiv 0 [si]                     .ins
        idiv 0 [di] word                .ins
        idiv 0 [bp]                     .ins
        idiv 0 [bp] word                .ins
        idiv bingo                      .ins
        idiv $1234 [bp]                 .ins
        idiv $23 [bx] word              .ins
        idiv $1234 [bx]                 .ins
        idiv bingo word                 .ins
\
        imul al                         .ins
        imul ax                         .ins
        imul cx                         .ins
        imul cl                         .ins
        imul 0 [si]                     .ins
        imul 0 [di] word                .ins
        imul 0 [bp]                     .ins
        imul 0 [bp] word                .ins
        imul bingo                      .ins
        imul $1234 [bp]                 .ins
        imul $23 [bx] word              .ins
        imul $1234 [bx]                 .ins
        imul bingo word                 .ins
\
        in al, # $23                    .ins
        in ax, # $123                   .ins
        in al, dx                       .ins
        in ax, dx                       .ins
\
        inc al                          .ins
        inc ax                          .ins
        inc cx                          .ins
        inc cl                          .ins
        inc 0 [si]                      .ins
        inc 0 [di] word                 .ins
        inc 0 [bp]                      .ins
        inc 0 [bp] word                 .ins
        inc bingo                       .ins
        inc $1234 [bp]                  .ins
        inc $23 [bx] word               .ins
        inc $1234 [bx]                  .ins
        inc bingo word                  .ins
\
        int $21                         .ins
        int 3                           .ins
\
        into                            .ins
        iret                            .ins
        ja  here                        .ins
        jnbe here                       .ins
        jae here                        .ins
        jnb here                        .ins
        jb here                         .ins
        jnae here                       .ins
        jbe here                        .ins
        jna here                        .ins
        jc here                         .ins
        jcxz here                       .ins
        je here                         .ins
        jz here                         .ins
        jg here                         .ins
        jnle here                       .ins
        jge here                        .ins
        jnl here                        .ins
        jl here                         .ins
        jnge here                       .ins
        jle here                        .ins
        jng here                        .ins
\
        jmp bingo                       .ins
        jmp ax                          .ins
        jmp dx                          .ins
        jmp [] bingo                    .ins
        jmp far ?cs: bingo              .ins
        jmp [] far bingo                .ins
        jmp far [] bingo                .ins
\
        JNC here                        .ins
        JNE here                        .ins
        JNZ here                        .ins
        JNO here                        .ins
        JNS here                        .ins
        JNP here                        .ins
        JPO here                        .ins
        JO here                         .ins
        JP here                         .ins
        JPE here                        .ins
        JS here                         .ins
\
        lds ax, 0 [bx]                  .ins
        lds ax, $35 [bp]                .ins
        lds cx, 0 [si]                  .ins
        lds dx, $35 [di]                .ins
\
        lea ax, 0 [bx+di]               .ins
        lea ax, $35 [bp]                .ins
        lea cx, 0 [si]                  .ins
        lea dx, $35 [di+bp]             .ins
\
        les ax, 0 [bx+di]               .ins
        les ax, $35 [bp]                .ins
        les cx, 0 [si]                  .ins
        les dx, $35 [di+bp]             .ins
\
        lock                            .ins
        lods                            .ins
        lods word                       .ins
\
        loop here                       .ins
        loope here                      .ins
        loopz here                      .ins
        loopnz here                     .ins
        loopne here                     .ins
\
        mov ax, bx                      .ins
        mov di, si                      .ins
        mov bh, cl                      .ins
        mov si, bingo                   .ins
        mov bl, bingo                   .ins
        mov bingo ax                    .ins
        mov bingo ch                    .ins
        mov bingo # $123                .ins
        mov bingo # $23                 .ins
        mov bingo # -64                 .ins
        mov bingo # $23 WORD            .ins
        mov bingo # 0 WORD              .ins
        mov di, # 1234                  .ins
        mov di, # 123                   .ins
        mov cl, # 123                   .ins
        mov bx, $23 [bp]                .ins
        mov bl, $23 [bp]                .ins
        mov bl, $23 [si]                .ins
        mov bl, 0 [si]                  .ins
        mov $23 [bp+si], cx             .ins
        mov $23 [bp+si], cl             .ins
        mov bx, 0 [bp]                  .ins
        mov bl, 0 [si]                  .ins
        mov 0 [bp+si], cx               .ins
        mov 0 [bp+si], cl               .ins
        mov ax, # $1234                 .ins
        mov al, # $34                   .ins
        mov ax, bingo                   .ins
        mov al, bingo                   .ins
        mov bingo cx                    .ins
        mov bingo ch                    .ins
        mov bingo ax                    .ins
        mov bingo al                    .ins
        mov bingo ah                    .ins
        mov ds, $23 [si]                .ins
        mov ds, 0 [si]                  .ins
        mov ds, bingo                   .ins
        mov ds, $23 [bp+si]             .ins
        mov ds, 0 [bp]                  .ins
        mov ds, dx                      .ins
        mov ds, ax                      .ins
        mov $23 [si], ds                .ins
        mov 0 [si], ds                  .ins
        mov bingo ds                    .ins
        mov $23 [bp+si], ds             .ins
        mov 0 [bp], ds                  .ins
        mov dx, ds                      .ins
        mov ax, ds                      .ins
        mov $23 [bp+si], # $25          .ins
        mov $23 [bp+si], # $25 word     .ins
        mov [bp+si], # $25              .ins
        mov [bp+si], # $25 word         .ins
        mov $471 # 0                    .ins
        mov 0 [bx], al                  .ins
        mov 0 [bp], al                  .ins
\
        movs                            .ins
        movs word                       .ins
\
        mul al                          .ins
        mul ax                          .ins
        mul cx                          .ins
        mul cl                          .ins
        mul 0 [si]                      .ins
        mul 0 [di] word                 .ins
        mul 0 [bp]                      .ins
        mul 0 [bp] word                 .ins
        mul bingo                       .ins
        mul $1234 [bp]                  .ins
        mul $23 [bx] word               .ins
        mul $1234 [bx]                  .ins
        mul bingo word                  .ins
\
        neg al                          .ins
        neg ax                          .ins
        neg cx                          .ins
        neg cl                          .ins
        neg 0 [si]                      .ins
        neg 0 [di] word                 .ins
        neg 0 [bp]                      .ins
        neg 0 [bp] word                 .ins
        neg bingo                       .ins
        neg $1234 [bp]                  .ins
        neg $23 [bx] word               .ins
        neg $1234 [bx]                  .ins
        neg bingo word                  .ins
\
        nop                             .ins
\
        not al                          .ins
        not ax                          .ins
        not cx                          .ins
        not cl                          .ins
        not 0 [si]                      .ins
        not 0 [di] word                 .ins
        not 0 [bp]                      .ins
        not 0 [bp] word                 .ins
        not bingo                       .ins
        not $1234 [bp]                  .ins
        not $23 [bx] word               .ins
        not $1234 [bx]                  .ins
        not bingo word                  .ins
\
        or ax, bx                       .ins
        or di, si                       .ins
        or bh, cl                       .ins
        or si, bingo                    .ins
        or bl, bingo                    .ins
        or bingo ax                     .ins
        or bingo ch                     .ins
        or bingo # $123                 .ins
        or bingo # $23                  .ins
        or bingo # -64                  .ins
        or bingo # $23 WORD             .ins
        or di, # 1234                   .ins
        or di, # 123                    .ins
        or cl, # 123                    .ins
        or bx, $23 [bp]                 .ins
        or bl, $23 [bp]                 .ins
        or bl, $23 [si]                 .ins
        or $23 [bp+si], cx              .ins
        or $23 [bp+si], cl              .ins
        or bx, 0 [bp]                   .ins
        or bl, 0 [si]                   .ins
        or 0 [bp+si], cx                .ins
        or 0 [bp+si], cl                .ins
        or ax, # $1234                  .ins
        or al, # $34                    .ins
        or $23 [bp+si], # $25           .ins
        or $23 [bp+si], # $25 word      .ins
        or [bp+si], # $25               .ins
        or [bp+si], # $25 word          .ins
\
        out # $23 al                    .ins
        out # $123 ax                   .ins
        out dx, al                      .ins
        out dx, ax                      .ins
\
        pop ax                          .ins
        pop di                          .ins
        pop 0 [si]                      .ins
        pop 0 [bp]                      .ins
        pop bingo                       .ins
        pop bingo [bp+si]               .ins
        pop bingo [bp]                  .ins
        pop ds                          .ins
        pop es                          .ins
\
        push ax                         .ins
        push di                         .ins
        push 0 [si]                     .ins
        push 0 [bp]                     .ins
        push bingo                      .ins
        push bingo [bp+si]              .ins
        push bingo [bp]                 .ins
        push ds                         .ins
        push es                         .ins
\
        rcl 0 [si], cl                  .ins
        rcl 0 [si], cl word             .ins
        rcl al, # 1                     .ins
        rcl al, cl                      .ins
        rcl ax, # 1                     .ins
        rcl ax, cl                      .ins
        rcl $34 [di], cl                .ins
        rcl $34 [di], cl word           .ins
        rcl $34 [bp], cl                .ins
        rcl $34 [bp], cl word           .ins
        rcl $34 [bp+si], cl             .ins
        rcl $34 [bp+si], cl word        .ins
        rcl bingo # 1                   .ins
        rcl bingo # 1 word              .ins
        rcl bingo cl                    .ins
        rcl bingo cl word               .ins
        rcl dx, # 1                     .ins
        rcl dx, cl                      .ins
        rcl dh, # 1                     .ins
        rcl cl, cl                      .ins
\
        rcr 0 [si], cl                  .ins
        rcr 0 [si], cl word             .ins
        rcr al, # 1                     .ins
        rcr al, cl                      .ins
        rcr ax, # 1                     .ins
        rcr ax, cl                      .ins
        rcr $34 [di], cl                .ins
        rcr $34 [di], cl word           .ins
        rcr $34 [bp], cl                .ins
        rcr $34 [bp], cl word           .ins
        rcr $34 [bp+si], cl             .ins
        rcr $34 [bp+si], cl word        .ins
        rcr bingo # 1                   .ins
        rcr bingo # 1 word              .ins
        rcr bingo cl                    .ins
        rcr bingo cl word               .ins
        rcr dx, # 1                     .ins
        rcr dx, cl                      .ins
        rcr dh, # 1                     .ins
        rcr cl, cl                      .ins
\
        rep                             .ins
        repe                            .ins
        repz                            .ins
        repne                           .ins
        repnz                           .ins
\
        ret                             .ins
        ret far                         .ins
        ret far 2                       .ins
        retf                            .ins
        retf 2                          .ins
\
        rol 0 [si], cl                  .ins
        rol 0 [si], cl word             .ins
        rol al, # 1                     .ins
        rol al, cl                      .ins
        rol ax, # 1                     .ins
        rol ax, cl                      .ins
        rol $34 [di], cl                .ins
        rol $34 [di], cl word           .ins
        rol $34 [bp], cl                .ins
        rol $34 [bp], cl word           .ins
        rol $34 [bp+si], cl             .ins
        rol $34 [bp+si], cl word        .ins
        rol bingo # 1                   .ins
        rol bingo # 1 word              .ins
        rol bingo cl                    .ins
        rol bingo cl word               .ins
        rol dx, # 1                     .ins
        rol dx, cl                      .ins
        rol dh, # 1                     .ins
        rol cl, cl                      .ins
\
        ror 0 [si], cl                  .ins
        ror 0 [si], cl word             .ins
        ror al, # 1                     .ins
        ror al, cl                      .ins
        ror ax, # 1                     .ins
        ror ax, cl                      .ins
        ror $34 [di], cl                .ins
        ror $34 [di], cl word           .ins
        ror $34 [bp], cl                .ins
        ror $34 [bp], cl word           .ins
        ror $34 [bp+si], cl             .ins
        ror $34 [bp+si], cl word        .ins
        ror bingo # 1                   .ins
        ror bingo # 1 word              .ins
        ror bingo cl                    .ins
        ror bingo cl word               .ins
        ror dx, # 1                     .ins
        ror dx, cl                      .ins
        ror dh, # 1                     .ins
        ror cl, cl                      .ins
\
        sahf                            .ins
\
        sal 0 [si], cl                  .ins
        sal 0 [si], cl word             .ins
        sal al, # 1                     .ins
        sal al, cl                      .ins
        sal ax, # 1                     .ins
        sal ax, cl                      .ins
        sal $34 [di], cl                .ins
        sal $34 [di], cl word           .ins
        sal $34 [bp], cl                .ins
        sal $34 [bp], cl word           .ins
        sal $34 [bp+si], cl             .ins
        sal $34 [bp+si], cl word        .ins
        sal bingo # 1                   .ins
        sal bingo # 1 word              .ins
        sal bingo cl                    .ins
        sal bingo cl word               .ins
        sal dx, # 1                     .ins
        sal dx, cl                      .ins
        sal dh, # 1                     .ins
        sal cl, cl                      .ins
\
        shl 0 [si], cl                  .ins
        shl 0 [si], cl word             .ins
        shl al, # 1                     .ins
        shl al, cl                      .ins
        shl ax, # 1                     .ins
        shl ax, cl                      .ins
        shl $34 [di], cl                .ins
        shl $34 [di], cl word           .ins
        shl $34 [bp], cl                .ins
        shl $34 [bp], cl word           .ins
        shl $34 [bp+si], cl             .ins
        shl $34 [bp+si], cl word        .ins
        shl bingo # 1                   .ins
        shl bingo # 1 word              .ins
        shl bingo cl                    .ins
        shl bingo cl word               .ins
        shl dx, # 1                     .ins
        shl dx, cl                      .ins
        shl dh, # 1                     .ins
        shl cl, cl                      .ins
\
        sar 0 [si], cl                  .ins
        sar 0 [si], cl word             .ins
        sar al, # 1                     .ins
        sar al, cl                      .ins
        sar ax, # 1                     .ins
        sar ax, cl                      .ins
        sar $34 [di], cl                .ins
        sar $34 [di], cl word           .ins
        sar $34 [bp], cl                .ins
        sar $34 [bp], cl word           .ins
        sar $34 [bp+si], cl             .ins
        sar $34 [bp+si], cl word        .ins
        sar bingo # 1                   .ins
        sar bingo # 1 word              .ins
        sar bingo cl                    .ins
        sar bingo cl word               .ins
        sar dx, # 1                     .ins
        sar dx, cl                      .ins
        sar dh, # 1                     .ins
        sar cl, cl                      .ins
\
        sbb ax, bx                      .ins
        sbb di, si                      .ins
        sbb bh, cl                      .ins
        sbb si, bingo                   .ins
        sbb bl, bingo                   .ins
        sbb bingo ax                    .ins
        sbb bingo ch                    .ins
        sbb bingo # $123                .ins
        sbb bingo # $23                 .ins
        sbb bingo # -64                 .ins
        sbb bingo # $23 WORD            .ins
        sbb di, # 1234                  .ins
        sbb di, # 123                   .ins
        sbb cl, # 123                   .ins
        sbb bx, $23 [bp]                .ins
        sbb bl, $23 [bp]                .ins
        sbb bl, $23 [si]                .ins
        sbb $23 [bp+si], cx             .ins
        sbb $23 [bp+si], cl             .ins
        sbb bx, 0 [bp]                  .ins
        sbb bl, 0 [si]                  .ins
        sbb 0 [bp+si], cx               .ins
        sbb 0 [bp+si], cl               .ins
        sbb ax, # $1234                 .ins
        sbb al, # $34                   .ins
        sbb $23 [bp+si], # $25          .ins
        sbb $23 [bp+si], # $25 word     .ins
        sbb [bp+si], # $25              .ins
        sbb [bp+si], # $25 word         .ins
\
        scas                            .ins
        scas word                       .ins
\
        shr 0 [si], cl                  .ins
        shr 0 [si], cl word             .ins
        shr al, # 1                     .ins
        shr al, cl                      .ins
        shr ax, # 1                     .ins
        shr ax, cl                      .ins
        shr $34 [di], cl                .ins
        shr $34 [di], cl word           .ins
        shr $34 [bp], cl                .ins
        shr $34 [bp], cl word           .ins
        shr $34 [bp+si], cl             .ins
        shr $34 [bp+si], cl word        .ins
        shr bingo # 1                   .ins
        shr bingo # 1 word              .ins
        shr bingo cl                    .ins
        shr bingo cl word               .ins
        shr dx, # 1                     .ins
        shr dx, cl                      .ins
        shr dh, # 1                     .ins
        shr cl, cl                      .ins
\
        stc                             .ins
        std                             .ins
        sti                             .ins
        stos                            .ins
        stos word                       .ins
\
        sub ax, bx                      .ins
        sub di, si                      .ins
        sub bh, cl                      .ins
        sub si, bingo                   .ins
        sub bl, bingo                   .ins
        sub bingo ax                    .ins
        sub bingo ch                    .ins
        sub bingo # $123                .ins
        sub bingo # $23                 .ins
        sub bingo # -64                 .ins
        sub bingo # $23 WORD            .ins
        sub di, # 1234                  .ins
        sub di, # 123                   .ins
        sub cl, # 123                   .ins
        sub bx, $23 [bp]                .ins
        sub bl, $23 [bp]                .ins
        sub bl, $23 [si]                .ins
        sub $23 [bp+si], cx             .ins
        sub $23 [bp+si], cl             .ins
        sub bx, 0 [bp]                  .ins
        sub bl, 0 [si]                  .ins
        sub 0 [bp+si], cx               .ins
        sub 0 [bp+si], cl               .ins
        sub ax, # $1234                 .ins
        sub al, # $34                   .ins
        sub $23 [bp+si], # $25          .ins
        sub $23 [bp+si], # $25 word     .ins
        sub [bp+si], # $25              .ins
        sub [bp+si], # $25 word         .ins
\
        test ax, bx                     .ins
        test di, si                     .ins
        test bh, cl                     .ins
        test si, bingo                  .ins
        test bl, bingo                  .ins
        test di, # 1234                 .ins
        test di, # 123                  .ins
        test cl, # 123                  .ins
        test bx, $23 [bp]               .ins
        test bl, $23 [bp]               .ins
        test bl, $23 [si]               .ins
        test bx, 0 [bp]                 .ins
        test bl, 0 [si]                 .ins
        test ax, # $1234                .ins
        test al, # $34                  .ins
\
        xchg 0 [si], dx                 .ins
        xchg 0 [bp], cx                 .ins
        xchg 0 [bp+si], di              .ins
        xchg 0 [si], dl                 .ins
        xchg 0 [bp], ch                 .ins
        xchg 0 [bp+si], bl              .ins
        xchg ax, dx                     .ins
        xchg ax, bingo                  .ins
        xchg $123 [si], dx              .ins
        xchg $23 [bp], cx               .ins
        xchg $54 [bp+si], di            .ins
        xchg $87 [si], dl               .ins
        xchg $987 [bp], ch              .ins
        xchg $987 [bp+si], bl           .ins
        xchg bingo di                   .ins
        xchg bingo al                   .ins
        xchg si, di                     .ins
        xchg bl, dh                     .ins
\
        xor ax, bx                      .ins
        xor di, si                      .ins
        xor bh, cl                      .ins
        xor si, bingo                   .ins
        xor bl, bingo                   .ins
        xor bingo ax                    .ins
        xor bingo ch                    .ins
        xor bingo # $123                .ins
        xor bingo # $23                 .ins
        xor bingo # -64                 .ins
        xor bingo # $23 word            .ins
        xor di, # 1234                  .ins
        xor di, # 123                   .ins
        xor cl, # 123                   .ins
        xor bx, $23 [bp]                .ins
        xor bl, $23 [bp]                .ins
        xor bl, $23 [si]                .ins
        xor $23 [bp+si], cx             .ins
        xor $23 [bp+si], cl             .ins
        xor bx, 0 [bp]                  .ins
        xor bl, 0 [si]                  .ins
        xor 0 [bp+si], cx               .ins
        xor 0 [bp+si], cl               .ins
        xor ax, # $1234                 .ins
        xor al, # $34                   .ins
        xor $23 [bp+si], # $25          .ins
        xor $23 [bp+si], # $25 word     .ins
        xor [bp+si], # $25              .ins
        xor [bp+si], # $25 word         .ins
        xor -2 [bp+si], # 5             .ins
        xor -2 [bp+si], # 5 word        .ins
end-code

depth
#if     cr beep .( WARNING: The stack should have been empty!) cr .s
#else   cr .( Done) cr
#then

