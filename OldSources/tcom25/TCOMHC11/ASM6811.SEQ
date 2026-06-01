\\ ASM6811.SEQ            6811 Assembler               by Tom Zimmer

------------------------------------------------------------------------

  This assembler is based on the ASM86 and 6805 assemblers.

  The ASM86 assembler is based on the assembler written by Jerry Boutelle
for the SAMSUNG SAM8 microcontroller and subsequently implemented by Robert
Smith for the SAMSUNG 56000 micro controller.

  This assembler was originally based on PASM.SEQ. PASM was developed by
Tom Zimmer and Robert Smith for the F-PC Forth system.


------------------------------------------------------------------------
  Use "SET6811" to select this 6811 assembler.

  Use "SET8086"  to re-select the 8086 assembler.

{

false directive \asmdebug       \ controls whether debugging stuf is loaded

\ \asmdebug needs dis6811.seq

warning off                     \ we have many re-definitions

HEADERS

only forth also definitions vocabulary ASM6811 assembler also

' ASM6811 ALIAS [ASM6811] IMMEDIATE

HEADERLESS

: INIT-APRIOR   ( -- )
                0 ['] drop a;!             \ init with harmless operation
                aprior 4 + 2@ aprior 2! ;

: DOASM6811   ( -- )   \ initial setup of 6811 assembler by CODE
                @> run =: arunsave
                init-aprior
                lihere =: linestrt
                ll-global? 0=
                IF
\- init_labels          llab-init       \ initialize all local labels
                                        \ if used on F-PC
\+ init_labels          init_labels     \ initialize only first 40 labels
                                        \ if used in TCOM
                THEN also ASM6811 ;

: SETASM6811  ( -- )  \ assemble 6811 code
                ['] DOASM6811 is setassem clear_labels ;

SETASM6811

\ define SET8086 only if its NOT already defined.

\- set8086 : SET8086 ( -- ) \ assemble 8086 code
\- set8086         ['] doassem is setassem clear_labels ;

only forth also assembler also ASM6811 definitions also

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

only forth also ASM6811 definitions also


}       The following constants define the individual operands that
        are possible.
{

57 constant opbval              \ the operand base value

opbval  3 + dup constant _NULL  \ no operand (a funny code to detect)
        3 + dup constant _WORD
        3 + dup constant _BYTE
        3 + dup constant _IMM
        3 + dup constant _X
        3 + dup constant _Y
drop

              4 constant max_operands   \ upto 4 operands in this processor
max_operands 2* constant max_opbytes
max_operands 1+ 2*
               array operands   \ room for MAX_OPERANDS
                                \ plus a verification code
             0 value opoff      \ operand offset

: operand!      ( n1 -- )
                operands opoff + c!  incr> opoff ;

: operand0      ( -- )
                                        \ fill with _NULL for MAX_OPBYTES
                operands max_opbytes _null fill
                off> opoff ;

0 value optable

: opdef:      ( -<name op op op op>- )  \ define an legal operand set
                create  max_operands 0
                do      ' execute c,    \ compile the operands
                loop    does>
                        body> optable - 2/ ;
                                        \ returns CFA of the operand set

here !> optable         \ pointer to start of operand table
here 0 ,                \ length of operands

\ 23 valid operand sets for the 6811

opdef:  INHERENT            _null   _null   _null   _null   \ ret
opdef:  IMM                 _imm    _null   _null   _null   \
opdef:  ABYTE               _byte   _null   _null   _null   \
opdef:  AWORD               _word   _null   _null   _null   \
opdef:  XONLY               _x      _null   _null   _null   \
opdef:  BYTE,X              _byte   _x      _null   _null   \
opdef:  YONLY               _y      _null   _null   _null   \
opdef:  BYTE,Y              _byte   _y      _null   _null   \
opdef:  BYTE,BYTE           _byte   _byte   _null   _null   \
opdef:  X,BYTE              _x      _byte   _null   _null   \
opdef:  BYTE,X,BYTE         _byte   _x      _byte   _null   \
opdef:  Y,BYTE              _y      _byte   _null   _null   \
opdef:  BYTE,Y,BYTE         _byte   _y      _byte   _null   \
opdef:  BYTE,BYTE,BYTE      _byte   _byte   _byte   _null   \
opdef:  BYTE,BYTE,WORD      _byte   _byte   _word   _null   \
opdef:  X,BYTE,BYTE         _x      _byte   _byte   _null   \
opdef:  X,BYTE,WORD         _x      _byte   _word   _null   \
opdef:  BYTE,X,BYTE,BYTE    _byte   _x      _byte   _byte   \
opdef:  BYTE,X,BYTE,WORD    _byte   _x      _byte   _word   \
opdef:  Y,BYTE,BYTE         _y      _byte   _byte   _null   \
opdef:  Y,BYTE,WORD         _y      _byte   _word   _null   \
opdef:  BYTE,Y,BYTE,BYTE    _byte   _y      _byte   _byte   \
opdef:  BYTE,Y,BYTE,WORD    _byte   _y      _byte   _word   \


here over - swap !      \ fill in length of operand table to this END POINT

                        \ next define the bad combination of operands
opdef:  BADOP           _null   _null   _null   _null   \ can't ever get here

false \asmdebug drop true       \ debugging verson in high level
#IF

: @.op          ( a1 -- a2 )
                count opbval 3 + - 3 / 5 * ['] _null + >name.id ;

: .optable      ( -- )
                save> base hex
                optable length max_opbytes - bounds
                do      cr decimal
                        i optable - 2/ 3 u.r space
                           hex
                        i optable - 2/ 4 u.r ." h  "
                        i >name.id 30 sp>col
                        i >body
                        max_operands 0
                        do      @.op
                        loop    drop
                        50 ms ?keypause
 max_operands 3 +                       \ operands plus CFA size
                +loop
                cr operands
                max_operands 0
                do      @.op
                loop    drop
                restore> base ;

: findopt       ( -- optype ) \ find operand code for this set of operands
                false save!> caps
                _null operand!          \ add an extra verification marker
                cr ." Source: " outbuf count 2- type
                cr ." Looking for: "
                operands
                max_operands 0
                do      @.op
                loop    drop
                operands max_operands optable length search
                if      optable + 2+    \ return the valid operand set BODY
                        cr ." Found      : " dup
                        max_operands 0
                        do      @.op
                        loop    drop
                        body>
                        ."  of type: " dup h. dup >name .id
                        optable - 2/
                else    drop badop      \ return the BAD operand flag
                then
                restore> caps
                ?keypause ;

: .i            ( -<inst_name>- )       \ display an instruction
                ' cr ." Instruction: " dup >name.id
                >body @ >body length +xseg
                swap count dup ." operand_cnt: " . 0
                save> base hex
                do      cr
                         4 sp>col count 2* optable +
                        dup c@ ( 8086 CALL ) $E8 <> 1 and + >name.id
                        16 sp>col over i 4 *
                        6 +  \ ** THIS IS NOT MAX_OPERANDS ***
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
                                        \ skip CFA and LENGTH WORD
        0 $:    sub bx, bx              \ preclear bx
        1 $:    mov al, 0 [bx+di]       \ get first byte of current op set
                cmp al, 0 [bx+si]       \ do they match
                je 2 $                  \ if match, then go bump to next word
                add si, # max_operands 3 +
                                        \ else add 6 bytes to next table entry
                cmp si, cx              \ end reached
                jl 0 $                  \ back for next try
                mov ax, # badop         \ if at end, then return bad op set
                jmp 3 $                 \ goto the exit routine
        2 $:    add bx, # 1             \ bump BX to next byte
                cmp bx, # max_operands  \ each entry is 3 bytes long
                jl 1 $                  \ if not at end of op set
                mov ax, bx              \ found it, get offset to op set
                add ax, si              \ plus op set base
                sub ax, # max_operands 3 + \ back to CFA of valid op set
                sub ax, &> optable      \ subtract table base
                shr ax, # 1             \ Shift right one bit
        3 $:    mov si, dx              \ recover saved SI
                1push                   \ push the result
                end-code
SETASM6811
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

                  WORD       WORD         WORD       WORD
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
SETASM6811

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
\asmdebug       ."  cg1A "
        ic, ;

: cg1B  ( opcode -- )                   \ no operand word instruction
\asmdebug       ."  cg1B "
        split ic, oc, ;

: cg2A  ( byte mask opcode -- )         \ byte mask
\asmdebug       ."  cg2A "
        ic, swap offset_8, offset_8, ;

: cg2B  ( x mask opcode -- )            \ x mask
\asmdebug       ."  cg2B "
        ic, 0 offset_8, offset_8, drop ;

: cg2C  ( index x mask opcode -- )      \ index x mask
\asmdebug       ."  cg2C "
        ic, nip swap offset_8, offset_8, ;

: cg2D  ( y mask opcode -- )            \ y mask
\asmdebug       ."  cg2D "
        split ic, oc, 0 offset_8, offset_8, drop ;

: cg2E  ( index y mask opcode -- )      \ index y mask
\asmdebug       ."  cg2E "
        split ic, oc, nip swap offset_8, offset_8, ;

: cg3A  ( imm opcode -- )               \ immediate
\asmdebug       ."  cg3A "
        ic, dup 0 FFh between 0=
        if      " Byte Immediate out of range" "err
        then    oc, ;

: cg3AA ( imm opcode -- )               \ immediate word
\asmdebug       ."  cg3A "
        ic, o, ;

: cg3B  ( word opcode -- )              \ word
\asmdebug       ."  cg3B "
        ic, offset_16, ;

: cg3C  ( byte opcode -- )              \ byte
\asmdebug       ."  cg3C "
        ic, offset_8, ;

: cg3D  ( byte x opcode -- )            \ byte,x
\asmdebug       ."  cg3D "
        nip ic, offset_8, ;

: cg3E  ( byte x opcode -- )            \ byte,y
\asmdebug       ."  cg3E "
        nip split ic, oc, offset_8, ;

: cg3F  ( x opcode -- )                 \ x
\asmdebug       ."  cg3F "
        nip ic, 0 offset_8, ;

: cg3G  ( y opcode -- )                 \ y
\asmdebug       ."  cg3G "
        nip split ic, oc, 0 offset_8, ;

: cg3H  ( imm opcode -- )               \ immediate
\asmdebug       ."  cg3H "
        split ic, oc, oc, ;

: cg3I  ( word opcode -- )              \ word
\asmdebug       ."  cg3I "
        split ic, oc, offset_16, ;

: cg3J  ( byte opcode -- )              \ byte
\asmdebug       ."  cg3J "
        split ic, oc, offset_8, ;

: cg4A  ( byte opcode -- )              \ branch byte
\asmdebug       ."  cg4A "
        ic, relative_8, ;

: cg5A  ( byte opcode -- )              \ byte or word compiles word
\asmdebug       ."  cg5A "
        ic, offset_16, ;

: cg5B  ( a opcode -- )                 \ A
\asmdebug       ."  cg5B "
        ic, drop ;

: cg5C  ( x opcode -- )                 \ X
\asmdebug       ."  cg5D "
        nip ic, 0 offset_8, ;

: cg5D  ( byte x opcode -- )            \ byte,x
\asmdebug       ."  cg5D "
        nip ic, offset_8, ;

: cg5E  ( x opcode -- )                 \ Y
\asmdebug       ."  cg5E "
        nip split ic, oc, 0 offset_8, ;

: cg5F  ( byte x opcode -- )            \ byte,y
\asmdebug       ."  cg5F "
        nip split ic, oc, offset_8, ;

: cg6A  ( byte mask rel opcode -- )     \ byte mask rel
\asmdebug       ."  cg6A "
        ic, >r swap offset_8, offset_8, r> relative_8, ;

: cg6B  ( x mask rel opcode -- )        \ x mask rel
\asmdebug       ."  cg6B "
        ic, >r 0 offset_8, offset_8, drop r> relative_8, ;

: cg6C  ( index x mask rel opcode -- )  \ index x mask rel
\asmdebug       ."  cg6C "
        ic, >r nip swap offset_8, offset_8, r> relative_8, ;

: cg6D  ( y mask rel opcode -- )        \ y mask rel
\asmdebug       ."  cg6D "
        split ic, oc, >r 0 offset_8, offset_8, drop r> relative_8, ;

: cg6E  ( index y mask rel opcode -- )  \ index y mask rel
\asmdebug       ."  cg6E "
        split ic, oc, >r nip swap offset_8, offset_8, r> relative_8, ;

}               ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                º 6811 instructions º
                ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼

{

HEADERS

i{ inherent   $1B   cg1A }i: ABA
i{ inherent   $3A   cg1A }i: ABX
i{ inherent   $183A cg1B }i: ABY
i{ inherent   $48   cg1A }i: ASLA
i{ inherent   $58   cg1A }i: ASLB
i{ inherent   $05   cg1A }i: ASLD
i{ inherent   $47   cg1A }i: ASRA
i{ inherent   $57   cg1A }i: ASRB
i{ inherent   $11   cg1A }i: CBA
i{ inherent   $0C   cg1A }i: CLC
i{ inherent   $0E   cg1A }i: CLI
i{ inherent   $4F   cg1A }i: CLRA
i{ inherent   $5F   cg1A }i: CLRB
i{ inherent   $0A   cg1A }i: CLV
i{ inherent   $43   cg1A }i: COMA
i{ inherent   $53   cg1A }i: COMB
i{ inherent   $19   cg1A }i: DAA
i{ inherent   $4A   cg1A }i: DECA
i{ inherent   $5A   cg1A }i: DECB
i{ inherent   $34   cg1A }i: DES
i{ inherent   $09   cg1A }i: DEX
i{ inherent   $1809 cg1B }i: DEY
i{ inherent   $03   cg1A }i: FDIV
i{ inherent   $02   cg1A }i: IDIV
i{ inherent   $4C   cg1A }i: INCA
i{ inherent   $5C   cg1A }i: INCB
i{ inherent   $31   cg1A }i: INS
i{ inherent   $08   cg1A }i: INX
i{ inherent   $1808 cg1B }i: INY
i{ inherent   $48   cg1A }i: LSLA
i{ inherent   $58   cg1A }i: LSLB
i{ inherent   $05   cg1A }i: LSLD
i{ inherent   $44   cg1A }i: LSRA
i{ inherent   $54   cg1A }i: LSRB
i{ inherent   $04   cg1A }i: LSRD
i{ inherent   $3D   cg1A }i: MUL
i{ inherent   $40   cg1A }i: NEGA
i{ inherent   $50   cg1A }i: NEGB
i{ inherent   $01   cg1A }i: NOP
i{ inherent   $36   cg1A }i: PSHA
i{ inherent   $37   cg1A }i: PSHB
i{ inherent   $3C   cg1A }i: PSHX
i{ inherent   $183C cg1B }i: PSHY
i{ inherent   $32   cg1A }i: PULA
i{ inherent   $33   cg1A }i: PULB
i{ inherent   $38   cg1A }i: PULX
i{ inherent   $1838 cg1B }i: PULY
i{ inherent   $49   cg1A }i: ROLA
i{ inherent   $59   cg1A }i: ROLB
i{ inherent   $46   cg1A }i: RORA
i{ inherent   $56   cg1A }i: RORB
i{ inherent   $3B   cg1A }i: RTI
i{ inherent   $39   cg1A }i: RTS
i{ inherent   $10   cg1A }i: SBA
i{ inherent   $0D   cg1A }i: SEC
i{ inherent   $0F   cg1A }i: SEI
i{ inherent   $0B   cg1A }i: SEV
i{ inherent   $CF   cg1A }i: STOP
i{ inherent   $3F   cg1A }i: SWI
i{ inherent   $16   cg1A }i: TAB
i{ inherent   $06   cg1A }i: TAP
i{ inherent   $17   cg1A }i: TBA
i{ inherent   $00   cg1A }i: TEST
i{ inherent   $07   cg1A }i: TPA
i{ inherent   $4D   cg1A }i: TSTA
i{ inherent   $5D   cg1A }i: TSTB
i{ inherent   $30   cg1A }i: TSX
i{ inherent   $1830 cg1B }i: TSY
i{ inherent   $35   cg1A }i: TXS
i{ inherent   $1835 cg1B }i: TYS
i{ inherent   $3E   cg1A }i: WAI
i{ inherent   $8F   cg1A }i: XGDX
i{ inherent   $188F cg1B }i: XGDY


i{ imm          $89 cg3A
   abyte        $99 cg3C
   aword        $B9 cg3B
   byte,x       $A9 cg3D
   byte,y     $18A9 cg3E
   yonly      $18A9 cg3G
   xonly        $A9 cg3F }i: ADCA

i{ imm          $C9 cg3A
   abyte        $D9 cg3C
   aword        $F9 cg3B
   byte,x       $E9 cg3D
   byte,y     $18E9 cg3E
   yonly      $18E9 cg3G
   xonly        $E9 cg3F }i: ADCB

i{ imm          $8B cg3A
   abyte        $9B cg3C
   aword        $BB cg3B
   byte,x       $AB cg3D
   byte,y     $18AB cg3E
   yonly      $18AB cg3G
   xonly        $AB cg3F }i: ADDA

i{ imm          $CB cg3A
   abyte        $DB cg3C
   aword        $FB cg3B
   byte,x       $EB cg3D
   byte,y     $18EB cg3E
   yonly      $18EB cg3G
   xonly        $EB cg3F }i: ADDB

i{ imm          $C3 cg3AA
   abyte        $D3 cg3C
   aword        $F3 cg3B
   byte,x       $E3 cg3D
   byte,y     $18E3 cg3E
   yonly      $18E3 cg3G
   xonly        $E3 cg3F }i: ADDD

i{ imm          $84 cg3A
   abyte        $94 cg3C
   aword        $B4 cg3B
   byte,x       $A4 cg3D
   byte,y     $18A4 cg3E
   yonly      $18A4 cg3G
   xonly        $A4 cg3F }i: ANDA

i{ imm          $C4 cg3A
   abyte        $D4 cg3C
   aword        $F4 cg3B
   byte,x       $E4 cg3D
   byte,y     $18E4 cg3E
   yonly      $18E4 cg3G
   xonly        $E4 cg3F }i: ANDB

i{ abyte        $78 cg5A
   aword        $78 cg5A
   xonly        $68 cg5C
   yonly      $1868 cg5E
   byte,y     $1868 cg5F
   byte,x       $68 cg5D }i: ASL

i{ abyte        $77 cg5A
   aword        $77 cg5A
   xonly        $67 cg5C
   yonly      $1867 cg5E
   byte,y     $1867 cg5F
   byte,x       $67 cg5D }i: ASR

i{ abyte        $24 cg4A
   aword        $24 cg4A }i: BCC

i{ byte,byte     $15 cg2A
   x,byte        $1D cg2B
   y,byte      $181D cg2D
   byte,y,byte $181D cg2E
   byte,x,byte   $1D cg2C }i: BCLR

i{ abyte        $25 cg4A
   aword        $25 cg4A }i: BCS

i{ abyte        $27 cg4A
   aword        $27 cg4A }i: BEQ

i{ abyte        $2C cg4A
   aword        $2C cg4A }i: BGE

i{ abyte        $2E cg4A
   aword        $2E cg4A }i: BGT

i{ abyte        $22 cg4A
   aword        $22 cg4A }i: BHI

i{ abyte        $24 cg4A
   aword        $24 cg4A }i: BHS

i{ imm          $85 cg3A
   abyte        $95 cg3C
   aword        $B5 cg3B
   byte,x       $A5 cg3D
   byte,y     $18A5 cg3E
   yonly      $18A5 cg3G
   xonly        $A5 cg3F }i: BITA

i{ imm          $C5 cg3A
   abyte        $D5 cg3C
   aword        $F5 cg3B
   byte,x       $E5 cg3D
   byte,y     $18E5 cg3E
   yonly      $18E5 cg3G
   xonly        $E5 cg3F }i: BITB

i{ abyte        $2F cg4A
   aword        $2F cg4A }i: BLE

i{ abyte        $25 cg4A
   aword        $25 cg4A }i: BLO

i{ abyte        $23 cg4A
   aword        $23 cg4A }i: BLS

i{ abyte        $2D cg4A
   aword        $2D cg4A }i: BLT

i{ abyte        $2B cg4A
   aword        $2B cg4A }i: BMI

i{ abyte        $26 cg4A
   aword        $26 cg4A }i: BNE

i{ abyte        $2A cg4A
   aword        $2A cg4A }i: BPL

i{ abyte        $20 cg4A
   aword        $20 cg4A }i: BRA

i{ byte,byte,byte     $13 cg6A
   byte,byte,word     $13 cg6A
   x,byte,byte        $1F cg6B
   x,byte,word        $1F cg6B
   y,byte,byte      $181F cg6D
   y,byte,word      $181F cg6D
   byte,y,byte,byte $181F cg6E
   byte,y,byte,word $181F cg6E
   byte,x,byte,word   $1F cg6C
   byte,x,byte,byte   $1F cg6C }i: BRCLR

i{ abyte        $21 cg4A
   aword        $21 cg4A }i: BRN

i{ byte,byte,byte     $12 cg6A
   byte,byte,word     $12 cg6A
   x,byte,byte        $1E cg6B
   x,byte,word        $1E cg6B
   y,byte,byte      $181E cg6D
   y,byte,word      $181E cg6D
   byte,y,byte,byte $181E cg6E
   byte,y,byte,word $181E cg6E
   byte,x,byte,word   $1E cg6C
   byte,x,byte,byte   $1E cg6C }i: BRSET

i{ byte,byte     $14 cg2A
   x,byte        $1C cg2B
   y,byte      $181C cg2D
   byte,y,byte $181C cg2E
   byte,x,byte   $1C cg2C }i: BSET

i{ abyte        $8D cg4A
   aword        $8D cg4A }i: BSR

i{ abyte        $28 cg4A
   aword        $28 cg4A }i: BVC

i{ abyte        $29 cg4A
   aword        $29 cg4A }i: BVS

i{ abyte        $7F cg5A
   aword        $7F cg5A
   xonly        $6F cg5C
   yonly      $186F cg5E
   byte,y     $186F cg5F
   byte,x       $6F cg5D }i: CLR

i{ imm          $81 cg3A
   abyte        $91 cg3C
   aword        $B1 cg3B
   byte,x       $A1 cg3D
   byte,y     $18A1 cg3E
   yonly      $18A1 cg3G
   xonly        $A1 cg3F }i: CMPA

i{ imm          $C1 cg3AA
   abyte        $D1 cg3C
   aword        $F1 cg3B
   byte,x       $E1 cg3D
   byte,y     $18E1 cg3E
   yonly      $18E1 cg3G
   xonly        $E1 cg3F }i: CMPB

i{ abyte        $73 cg5A
   aword        $73 cg5A
   xonly        $63 cg5C
   yonly      $1863 cg5E
   byte,y     $1863 cg5F
   byte,x       $63 cg5D }i: COM

i{ imm        $1A83 cg3H
   abyte      $1A93 cg3J
   aword      $1AB3 cg3I
   byte,x     $1AA3 cg3E
   byte,y     $CDA3 cg3E
   yonly      $CDA3 cg3G
   xonly      $1AA3 cg3G }i: CPD

i{ imm          $8C cg3AA
   abyte        $9C cg3C
   aword        $BC cg3B
   byte,x       $AC cg3D
   byte,y     $CDAC cg3E
   yonly      $CDAC cg3G
   xonly        $AC cg3F }i: CPX

i{ imm        $188C cg3H
   abyte      $189C cg3J
   aword      $18BC cg3I
   byte,x     $1AAC cg3E
   byte,y     $18AC cg3E
   yonly      $18AC cg3G
   xonly      $1AAC cg3G }i: CPY

i{ abyte        $7A cg5A
   aword        $7A cg5A
   xonly        $6A cg5C
   yonly      $186A cg5E
   byte,y     $186A cg5F
   byte,x       $6A cg5D }i: DEC

i{ imm          $88 cg3A
   abyte        $98 cg3C
   aword        $B8 cg3B
   byte,x       $A8 cg3D
   byte,y     $18A8 cg3E
   yonly      $18A8 cg3G
   xonly        $A8 cg3F }i: EORA

i{ imm          $C8 cg3A
   abyte        $D8 cg3C
   aword        $F8 cg3B
   byte,x       $E8 cg3D
   byte,y     $18E8 cg3E
   yonly      $18E8 cg3G
   xonly        $E8 cg3F }i: EORB

i{ abyte        $7C cg5A
   aword        $7C cg5A
   xonly        $6C cg5C
   yonly      $186C cg5E
   byte,y     $186C cg5F
   byte,x       $6C cg5D }i: INC

i{ abyte        $7E cg3B
   aword        $7E cg3B
   byte,x       $6E cg3D
   byte,y     $186E cg3E
   yonly      $186E cg3G
   xonly        $6E cg3F }i: JMP

i{ abyte        $9D cg3C
   aword        $BD cg3B
   byte,x       $AD cg3D
   byte,y     $18AD cg3E
   yonly      $18AD cg3G
   xonly        $AD cg3F }i: JSR

i{ imm          $86 cg3A
   abyte        $96 cg3C
   aword        $B6 cg3B
   byte,x       $A6 cg3D
   byte,y     $18A6 cg3E
   yonly      $18A6 cg3G
   xonly        $A6 cg3F }i: LDAA

i{ imm          $C6 cg3A
   abyte        $D6 cg3C
   aword        $F6 cg3B
   byte,x       $E6 cg3D
   byte,y     $18E6 cg3E
   yonly      $18E6 cg3G
   xonly        $E6 cg3F }i: LDAB

i{ imm          $CC cg3AA
   abyte        $DC cg3C
   aword        $FC cg3B
   byte,x       $EC cg3D
   byte,y     $18EC cg3E
   yonly      $18EC cg3G
   xonly        $EC cg3F }i: LDD

i{ imm          $8E cg3AA
   abyte        $9E cg3C
   aword        $BE cg3B
   byte,x       $AE cg3D
   byte,y     $18AE cg3E
   yonly      $18AE cg3G
   xonly        $AE cg3F }i: LDS

i{ imm          $CE cg3AA
   abyte        $DE cg3C
   aword        $FE cg3B
   byte,x       $EE cg3D
   byte,y     $CDEE cg3E
   yonly      $CDEE cg3G
   xonly        $EE cg3F }i: LDX

i{ imm        $18CE cg3H
   abyte      $18DE cg3J
   aword      $18FE cg3I
   byte,x     $1AEE cg3E
   byte,y     $18EE cg3E
   yonly      $18EE cg3G
   xonly      $1AEE cg3G }i: LDY

i{ abyte        $78 cg5A
   aword        $78 cg5A
   xonly        $68 cg5C
   yonly      $1868 cg5E
   byte,y     $1868 cg5F
   byte,x       $68 cg5D }i: LSL

i{ abyte        $74 cg5A
   aword        $74 cg5A
   xonly        $64 cg5C
   yonly      $1864 cg5E
   byte,y     $1864 cg5F
   byte,x       $64 cg5D }i: LSR

i{ abyte        $70 cg5A
   aword        $70 cg5A
   xonly        $60 cg5C
   yonly      $1860 cg5E
   byte,y     $1860 cg5F
   byte,x       $60 cg5D }i: NEG

i{ imm          $8A cg3A
   abyte        $9A cg3C
   aword        $BA cg3B
   byte,x       $AA cg3D
   byte,y     $18AA cg3E
   yonly      $18AA cg3G
   xonly        $AA cg3F }i: ORAA

i{ imm          $CA cg3A
   abyte        $DA cg3C
   aword        $FA cg3B
   byte,x       $EA cg3D
   byte,y     $18EA cg3E
   yonly      $18EA cg3G
   xonly        $EA cg3F }i: ORAB

i{ abyte        $79 cg5A
   aword        $79 cg5A
   xonly        $69 cg5C
   yonly      $1869 cg5E
   byte,y     $1869 cg5F
   byte,x       $69 cg5D }i: ROL

i{ abyte        $76 cg5A
   aword        $76 cg5A
   xonly        $66 cg5C
   yonly      $1866 cg5E
   byte,y     $1866 cg5F
   byte,x       $66 cg5D }i: ROR

i{ imm          $82 cg3A
   abyte        $92 cg3C
   aword        $B2 cg3B
   byte,x       $A2 cg3D
   byte,y     $18A2 cg3E
   yonly      $18A2 cg3G
   xonly        $A2 cg3F }i: SBCA

i{ imm          $C2 cg3AA
   abyte        $D2 cg3C
   aword        $F2 cg3B
   byte,x       $E2 cg3D
   byte,y     $18E2 cg3E
   yonly      $18E2 cg3G
   xonly        $E2 cg3F }i: SBCB

i{ abyte        $97 cg3C
   aword        $B7 cg3B
   byte,x       $A7 cg3D
   byte,y     $18A7 cg3E
   yonly      $18A7 cg3G
   xonly        $A7 cg3F }i: STAA

i{ abyte        $D7 cg3C
   aword        $F7 cg3B
   byte,x       $E7 cg3D
   byte,y     $18E7 cg3E
   yonly      $18E7 cg3G
   xonly        $E7 cg3F }i: STAB

i{ abyte        $DD cg3C
   aword        $FD cg3B
   byte,x       $ED cg3D
   byte,y     $18ED cg3E
   yonly      $18ED cg3G
   xonly        $ED cg3F }i: STD

i{ abyte        $9F cg3C
   aword        $BF cg3B
   byte,x       $AF cg3D
   byte,y     $18AF cg3E
   yonly      $18AF cg3G
   xonly        $AF cg3F }i: STS

i{ abyte        $DF cg3C
   aword        $FF cg3B
   byte,x       $EF cg3D
   byte,y     $CDEF cg3E
   yonly      $CDEF cg3G
   xonly        $EF cg3F }i: STX

i{ abyte      $18DF cg3J
   aword      $18FF cg3I
   byte,x     $1AEF cg3E
   byte,y     $18EF cg3E
   yonly      $18EF cg3G
   xonly      $1AEF cg3G }i: STY

i{ imm          $80 cg3A
   abyte        $90 cg3C
   aword        $B0 cg3B
   byte,x       $A0 cg3D
   byte,y     $18A0 cg3E
   yonly      $18A0 cg3G
   xonly        $A0 cg3F }i: SUBA

i{ imm          $C0 cg3A
   abyte        $D0 cg3C
   aword        $F0 cg3B
   byte,x       $E0 cg3D
   byte,y     $18E0 cg3E
   yonly      $18E0 cg3G
   xonly        $E0 cg3F }i: SUBB

i{ imm          $83 cg3AA
   abyte        $93 cg3C
   aword        $B3 cg3B
   byte,x       $A3 cg3D
   byte,y     $18A3 cg3E
   yonly      $18A3 cg3G
   xonly        $A3 cg3F }i: SUBD

i{ abyte        $7D cg5A
   aword        $7D cg5A
   xonly        $6D cg5C
   yonly      $186D cg5E
   byte,y     $186D cg5F
   byte,x       $6D cg5D }i: TST

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

$00 _x   operand X
$00 _y   operand Y
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

