\\ ASM6805.SEQ            6805 Assembler               by Tom Zimmer

------------------------------------------------------------------------

  This assembler is based on the ASM86 assembler.

  The ASM86 assembler is based on the assembler written by Jerry Boutelle
for the SAMSUNG SAM8 microcontroller and subsequently implemented by Robert
Smith for the SAMSUNG 56000 micro controller.

  This assembler was originally based on PASM.SEQ. PASM was developed by
Tom Zimmer and Robert Smith for the F-PC Forth system.


------------------------------------------------------------------------
  Use "SET6805" to select this 6805 assembler.

  Use "SET8086"  to re-select the 8086 assembler.

{

false directive \asmdebug       \ controls whether debugging stuf is loaded

\asmdebug needs dis6805.seq

warning off                     \ we have many re-definitions

HEADERS

only forth also definitions vocabulary ASM6805 assembler also

' ASM6805 ALIAS [ASM6805] IMMEDIATE

HEADERLESS

: INIT-APRIOR   ( -- )
                0 ['] drop a;!             \ init with harmless operation
                aprior 4 + 2@ aprior 2! ;

: DOASM6805   ( -- )   \ initial setup of 6805 assembler by CODE
                @> run =: arunsave
                init-aprior
                lihere =: linestrt
                ll-global? 0=
                IF
\- init_labels          llab-init       \ initialize all local labels
                                        \ if used on F-PC
\+ init_labels          init_labels     \ initialize only first 40 labels
                                        \ if used in TCOM
                THEN also ASM6805 ;

: SETASM6805  ( -- )  \ assemble 6805 code
                ['] DOASM6805 is setassem clear_labels ;

SETASM6805

\ define SET8086 only if its NOT already defined.

\- set8086 : SET8086 ( -- ) \ assemble 8086 code
\- set8086         ['] doassem is setassem clear_labels ;

only forth also assembler also ASM6805 definitions also

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
' relative_8,   alias relative_8,

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

only forth also ASM6805 definitions also


}       The following constants define the individual operands that
        are possible.
{

57 constant opbval              \ the operand base value

opbval  3 + dup constant _NULL  \ no operand (a funny code to detect)
        3 + dup constant _WORD
        3 + dup constant _BYTE
        3 + dup constant _IMM
        3 + dup constant _EXT
        3 + dup constant _A
        3 + dup constant _X
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

\ 13 valid operand sets for the 6805

opdef:  INHERENT        _null   _null   _null   \ ret
opdef:  IMM             _imm    _null   _null   \
opdef:  ABYTE           _byte   _null   _null   \
opdef:  AWORD           _word   _null   _null   \
opdef:  ABYTE,EXT       _byte   _ext    _null   \
opdef:  AWORD,EXT       _word   _ext    _null   \
opdef:  AONLY           _a      _null   _null   \
opdef:  XONLY           _x      _null   _null   \
opdef:  BYTE,X          _byte   _x      _null   \
opdef:  WORD,X          _word   _x      _null   \
opdef:  BYTE,X,EXT      _byte   _x      _ext    \
opdef:  WORD,X,EXT      _word   _x      _ext    \
opdef:  BYTE,BYTE       _byte   _byte   _null   \

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
SETASM6805
#THEN

0 value A-SM            \ assembler stack mark
0 value A-WD            \ assembler word flag

defer    8-BIT          \ operand form for an 8 bit number
defer   16-BIT          \ operand form for a 16 bit number

' _byte is  8-bit
' _word is 16-bit

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
        ['] _byte is  8-bit     \ default to  8 bit number is byte
        ['] _word is 16-bit     \ default to 16 bit number is direct adr
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
              ÚÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿
  List space: ³  SCANOPT  ³ ptr-to-cnt³   $A9     ³  CG01     ³
              ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄ´
                    ^           |     ³  $D0AA    ³  CGxx     ³
                    |           |     ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÙ
              ÚÄÄÄÄÄÄÄÄÄÄ¿      |
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
SETASM6805

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

: cg1A  ( opcode -- )                   \ no operand
        ic, ;

: cg2A  ( byte bit opcode -- )          \ byte bit
        swap 2* + ic, offset_8, ;

: cg3A  ( imm opcode -- )               \ immediate
        ic, oc, ;

: cg3B  ( word opcode -- )              \ word
        ic, offset_16, ;

: cg3C  ( byte opcode -- )              \ byte
        ic, offset_8, ;

: cg3D  ( byte x opcode -- )            \ byte,x
        nip over 0=                     \ if offset is zero
        if      $10 or ic, drop         \ optimize for offset zero
        else    ic, offset_8,
        then    ;

: cg3E  ( word x opcode -- )            \ word,x
        nip ic, offset_16, ;

: cg3F  ( x opcode -- )                 \ x
        ic, drop ;

: cg3G  ( word ext opcode -- )          \ word ext
        nip ic, offset_16, ;

: cg3H  ( word x ext opcode -- )        \ word,x ext
        nip nip ic, offset_16, ;

: cg4A  ( byte opcode -- )              \ branch byte
        ic, relative_8, ;

: cg5A  ( byte opcode -- )              \ byte
        ic, offset_8, ;

: cg5B  ( a opcode -- )                 \ A
        ic, drop ;

: cg5C  ( x opcode -- )                 \ X
        ic, drop ;

: cg5D  ( byte x opcode -- )            \ byte,x
        nip over 0=
        if      $10 or ic, drop
        else    ic, offset_8,
        then    ;

}               ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                º 6805 instructions º
                ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼

{

HEADERS

i{ inherent     $98 cg1A }i: CLC
i{ inherent     $9A cg1A }i: CLI
i{ inherent     $42 cg1A }i: MUL
i{ inherent     $9D cg1A }i: NOP
i{ inherent     $9C cg1A }i: RSP
i{ inherent     $80 cg1A }i: RTI
i{ inherent     $81 cg1A }i: RTS
i{ inherent     $99 cg1A }i: SEC
i{ inherent     $9B cg1A }i: SEI
i{ inherent     $8E cg1A }i: STOP
i{ inherent     $83 cg1A }i: SWI
i{ inherent     $97 cg1A }i: TAX
i{ inherent     $9F cg1A }i: TXA
i{ inherent     $8F cg1A }i: WAIT

i{ byte,byte    $11 cg2A }i: BCLR
i{ byte,byte    $10 cg2A }i: BSET

i{ imm          $A9 cg3A
   abyte        $B9 cg3C
   abyte,ext    $C9 cg3G
   aword        $C9 cg3B
   aword,ext    $C9 cg3G
   word,x       $D9 cg3E
   byte,x       $E9 cg3D
   word,x,ext   $D9 cg3H
   byte,x,ext   $D9 cg3H
   xonly        $F9 cg3F }i: ADC

i{ imm          $AB cg3A
   abyte        $BB cg3C
   aword        $CB cg3B
   abyte,ext    $CB cg3G
   aword,ext    $CB cg3G
   word,x       $DB cg3E
   byte,x       $EB cg3D
   word,x,ext   $DB cg3H
   byte,x,ext   $DB cg3H
   xonly        $FB cg3F }i: ADD

i{ imm          $A4 cg3A
   abyte        $B4 cg3C
   aword        $C4 cg3B
   abyte,ext    $C4 cg3G
   aword,ext    $C4 cg3G
   word,x       $D4 cg3E
   byte,x       $E4 cg3D
   word,x,ext   $D4 cg3H
   byte,x,ext   $D4 cg3H
   xonly        $F4 cg3F }i: AND

i{ abyte        $37 cg5A
   aonly        $47 cg5B
   xonly        $57 cg5C
   byte,x       $67 cg5D }i: ASR

i{ imm          $A5 cg3A
   abyte        $B5 cg3C
   aword        $C5 cg3B
   abyte,ext    $C5 cg3G
   aword,ext    $C5 cg3G
   word,x       $D5 cg3E
   byte,x       $E5 cg3D
   word,x,ext   $D5 cg3H
   byte,x,ext   $D5 cg3H
   xonly        $F5 cg3F }i: BIT

i{ abyte        $3F cg5A
   aonly        $4F cg5B
   xonly        $5F cg5C
   byte,x       $6F cg5D }i: CLR

i{ imm          $A1 cg3A
   abyte        $B1 cg3C
   aword        $C1 cg3B
   abyte,ext    $C1 cg3G
   aword,ext    $C1 cg3G
   word,x       $D1 cg3E
   byte,x       $E1 cg3D
   word,x,ext   $D1 cg3H
   byte,x,ext   $D1 cg3H
   xonly        $F1 cg3F }i: CMP

i{ abyte        $33 cg5A
   aonly        $43 cg5B
   xonly        $53 cg5C
   byte,x       $63 cg5D }i: COM

i{ imm          $A3 cg3A
   abyte        $B3 cg3C
   aword        $C3 cg3B
   abyte,ext    $C3 cg3G
   aword,ext    $C3 cg3G
   word,x       $D3 cg3E
   byte,x       $E3 cg3D
   word,x,ext   $D3 cg3H
   byte,x,ext   $D3 cg3H
   xonly        $F3 cg3F }i: CPX

i{ abyte        $3A cg5A
   aonly        $4A cg5B
   xonly        $5A cg5C
   byte,x       $6A cg5D }i: DEC

i{ imm          $A8 cg3A
   abyte        $B8 cg3C
   aword        $C8 cg3B
   abyte,ext    $C8 cg3G
   aword,ext    $C8 cg3G
   word,x       $D8 cg3E
   byte,x       $E8 cg3D
   word,x,ext   $D8 cg3H
   byte,x,ext   $D8 cg3H
   xonly        $F8 cg3F }i: EOR

i{ abyte        $3C cg5A
   aonly        $4C cg5B
   xonly        $5C cg5C
   byte,x       $6C cg5D }i: INC

i{ abyte        $BC cg3C
   aword        $CC cg3B
   abyte,ext    $CC cg3G
   aword,ext    $CC cg3G
   word,x       $DC cg3E
   byte,x       $EC cg3D
   word,x,ext   $DC cg3H
   byte,x,ext   $DC cg3H
   xonly        $FC cg3F }i: JMP

i{ abyte        $BD cg3C
   aword        $CD cg3B
   abyte,ext    $CD cg3G
   aword,ext    $CD cg3G
   word,x       $DD cg3E
   byte,x       $ED cg3D
   word,x,ext   $DD cg3H
   byte,x,ext   $DD cg3H
   xonly        $FD cg3F }i: JSR

i{ imm          $A6 cg3A
   abyte        $B6 cg3C
   aword        $C6 cg3B
   abyte,ext    $C6 cg3G
   aword,ext    $C6 cg3G
   word,x       $D6 cg3E
   byte,x       $E6 cg3D
   word,x,ext   $D6 cg3H
   byte,x,ext   $D6 cg3H
   xonly        $F6 cg3F }i: LDA

i{ imm          $AE cg3A
   abyte        $BE cg3C
   aword        $CE cg3B
   abyte,ext    $CE cg3G
   aword,ext    $CE cg3G
   word,x       $DE cg3E
   byte,x       $EE cg3D
   word,x,ext   $DE cg3H
   byte,x,ext   $DE cg3H
   xonly        $FE cg3F }i: LDX

i{ abyte        $38 cg5A
   aonly        $48 cg5B
   xonly        $58 cg5C
   byte,x       $68 cg5D }i: LSL

' LSL alias ASL

i{ abyte        $34 cg5A
   aonly        $44 cg5B
   xonly        $54 cg5C
   byte,x       $64 cg5D }i: LSR

i{ abyte        $30 cg5A
   aonly        $40 cg5B
   xonly        $50 cg5C
   byte,x       $60 cg5D }i: NEG

i{ imm          $AA cg3A
   abyte        $BA cg3C
   aword        $CA cg3B
   abyte,ext    $CA cg3G
   aword,ext    $CA cg3G
   word,x       $DA cg3E
   byte,x       $EA cg3D
   word,x,ext   $DA cg3H
   byte,x,ext   $DA cg3H
   xonly        $FA cg3F }i: ORA

i{ abyte        $39 cg5A
   aonly        $49 cg5B
   xonly        $59 cg5C
   byte,x       $69 cg5D }i: ROL

i{ abyte        $36 cg5A
   aonly        $46 cg5B
   xonly        $56 cg5C
   byte,x       $66 cg5D }i: ROR

i{ imm          $A2 cg3A
   abyte        $B2 cg3C
   aword        $C2 cg3B
   abyte,ext    $C2 cg3G
   aword,ext    $C2 cg3G
   word,x       $D2 cg3E
   byte,x       $E2 cg3D
   word,x,ext   $D2 cg3H
   byte,x,ext   $D2 cg3H
   xonly        $F2 cg3F }i: SBC

i{ abyte        $B7 cg3C
   aword        $C7 cg3B
   abyte,ext    $C7 cg3G
   aword,ext    $C7 cg3G
   word,x       $D7 cg3E
   byte,x       $E7 cg3D
   word,x,ext   $D7 cg3H
   byte,x,ext   $D7 cg3H
   xonly        $F7 cg3F }i: STA

i{ abyte        $BF cg3C
   aword        $CF cg3B
   abyte,ext    $CF cg3G
   aword,ext    $CF cg3G
   word,x       $DF cg3E
   byte,x       $EF cg3D
   word,x,ext   $DF cg3H
   byte,x,ext   $DF cg3H
   xonly        $FF cg3F }i: STX

i{ imm          $A0 cg3A
   abyte        $B0 cg3C
   aword        $C0 cg3B
   abyte,ext    $C0 cg3G
   aword,ext    $C0 cg3G
   word,x       $D0 cg3E
   byte,x       $E0 cg3D
   word,x,ext   $D0 cg3H
   byte,x,ext   $D0 cg3H
   xonly        $F0 cg3F }i: SUB

i{ abyte        $3D cg5A
   aonly        $4D cg5B
   xonly        $5D cg5C
   byte,x       $6D cg5D }i: TST

i{ abyte        $24 cg4A
   aword        $24 cg4A }i: BCC
i{ abyte        $25 cg4A
   aword        $25 cg4A }i: BCS
i{ abyte        $27 cg4A
   aword        $27 cg4A }i: BEQ
i{ abyte        $28 cg4A
   aword        $28 cg4A }i: BHCC
i{ abyte        $29 cg4A
   aword        $29 cg4A }i: BHCS
i{ abyte        $22 cg4A
   aword        $22 cg4A }i: BHI
i{ abyte        $24 cg4A
   aword        $24 cg4A }i: BHS
i{ abyte        $2F cg4A
   aword        $2F cg4A }i: BIH
i{ abyte        $2E cg4A
   aword        $2E cg4A }i: BIL
i{ abyte        $25 cg4A
   aword        $25 cg4A }i: BLO
i{ abyte        $23 cg4A
   aword        $23 cg4A }i: BLS
i{ abyte        $2C cg4A
   aword        $2C cg4A }i: BMC
i{ abyte        $2B cg4A
   aword        $2B cg4A }i: BMI
i{ abyte        $2D cg4A
   aword        $2D cg4A }i: BMS
i{ abyte        $26 cg4A
   aword        $26 cg4A }i: BNE
i{ abyte        $2A cg4A
   aword        $2A cg4A }i: BPL
i{ abyte        $20 cg4A
   aword        $20 cg4A }i: BRA
i{ abyte        $21 cg4A
   aword        $21 cg4A }i: BRN
i{ abyte        $AD cg4A
   aword        $AD cg4A }i: BSR

i{ byte,byte    $01 cg2A }i: BRCLR
i{ byte,byte    $00 cg2A }i: BRSET

}               ÉÍÍÍÍÍÍÍÍÍÍ»
                º operands º
                ÈÍÍÍÍÍÍÍÍÍÍ¼
{

I: OPERAND ( -- n1 )
        CREATE
         ,                              \ store actual operand value
         ,                              \ store register value
        DOES>   >r ?nos                 \ see if there is a number on stack
                r@ @ operand!           \ get the operand code
                r> 2+ @                 \ get register value
                sp@ !> a-sm  ;          \ store assembler stack mark

\ 16 bit register operands

$00 _a   operand A
$00 _x   operand X
$00 _ext operand EXTENDED
$00 _ext operand EXT
    ' noop alias MEM immediate

: #     ( n1 -- n1 ) \ expect an immediate
        ?nos                       \ see if there is a number on stack
        ['] _imm is  8-bit         \ set  8-bit number to an 8 bit immediate
        ['] _imm is  16-bit        \ set  16-bit number to a 16 bit immediate
        ;

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


end-code

depth
#if     cr beep .( WARNING: The stack should have been empty!) cr .s
#else   cr .( Done) cr
#then

