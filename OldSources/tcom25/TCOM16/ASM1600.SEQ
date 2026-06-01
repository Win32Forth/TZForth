\\ ASM1600.SEQ            1600 Assembler               by Tom Zimmer

------------------------------------------------------------------------

  This assembler is based on the assembler written by Jerry Boutelle for
the SAMSUNG SAM8 microcontroller and subsequently by Robert Smith for the
SAMSUNG 56000 micro controller.

  This assembler was originally based on PASM.SEQ. PASM was developed by
Tom Zimmer and Robert Smith for the F-PC Forth system.

12/17/92 08:10
  Additional modifications by Tom Zimmer to make the valid operand list
easier to setup and maintain.

------------------------------------------------------------------------

  Use "SETASM1600" to select the 1600 assembler.

  Use "SET8086"  to re-select the 80x86 assembler.

{

warning off                \ we have many re-definitions

HEADERS

only forth also definitions vocabulary ASM1600 assembler also

' ASM1600 ALIAS [ASM1600] IMMEDIATE

HEADERLESS

: INIT-APRIOR   ( -- )
                0 ['] drop a;!             \ init with harmless operation
                aprior 4 + 2@ aprior 2! ;

: DOASSEM1600   ( -- )   \ initial setup of 1600 assembler by CODE
                @> run =: arunsave
                init-aprior
                lihere =: linestrt
                ll-global? 0=
                IF
\- init_labels          llab-init       \ initialize all local labels
                                        \ if used on F-PC
\+ init_labels          init_labels     \ initialize only first 40 labels
                                        \ if used in TCOM
                THEN also ASM1600 ;

: SETASM1600    ( -- )  \ assemble 1600 code
                ['] DOASSEM1600 is setassem clear_labels ;

SETASM1600

\ define SET8086 only if its NOT already defined.

\- set8086 : SET8086 ( -- ) \ assemble 8086 code
\- set8086         ['] doassem is setassem clear_labels ;

only forth also assembler also ASM1600 definitions also

\ some alias headers so we don't have to redefine these words in
\ the new target assembler.

HEADERS

' $             alias $
' $:            alias $:
' c,            alias c,
' ,             alias ,
' here          alias here
' end-code      alias end-code  immediate
' end-code      alias c;        immediate

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

' OFFSET_16,   ALIAS ASM,        \ a normal ","  in this assembler

#ELSE

: "errmsg       ( cfa a1 n1 -- )
                cr type drop abort ;

: c!-e          ( n1 offset -- )
                2drop ;

' assembler alias [assembler] immediate

: asm,          ( n1 -- )
                [ forth ]
                save> base hex
                40 sp>col ." [" 0 <# # # # # #> type ." ]"
                restore> base ;

#THEN

only forth also ASM1600 definitions also


}
         The following constants define the individual operands that
         are possible.  These symbols are preceded with underscore to
         avoid renaming numbers or other Forth words.
{

$E97A constant _NULL    \ no operand (a funny code to detect)
    1 constant _WR      \ internal register operand
    2 constant _(RI)    \ indirect register pointer to RAM memory
    3 constant _((RI))  \ indirect register pointer to ROM memory
    4 constant _WORD    \ direct address, or Immediate word
    5 constant _BYTE    \ ram address, Short immediate, or B
    6 constant _RI      \ ram address pointer
    7 constant _CC      \ condition code
    8 constant _F       \ Flag code
    9 constant _OP      \ opcode

16 array operands       \ room for seven operands plus a verification code
 0 value opoff          \ operand offset

: operand!      ( n1 -- )
                operands opoff + !  2 +!> opoff ;

: operand0      ( -- )
                _null operands !        _null operands 2+ !
                _null operands 4 + !    _null operands 6 + !
                off> opoff ;

: opdefine      ( n1 -<name op op op>- )        \ define an legal operand set
                create ,
                ' execute ,     \ three operands legal
                ' execute ,
                ' execute ,
                    _null ,     \ marker for legal operand set verification
                does> @ ;

create optable here 0 ,

     0 opdefine NO-OPR      _null   _null   _null   \ ret
     1 opdefine CC,BYTE     _cc     _byte   _null   \ BRA N,1234
     2 opdefine CC,WORD     _cc     _word   _null   \ BRA N,1234
     3 opdefine CC,OP       _cc     _op     _null   \ MOD ALWAYS,SHL
     4 opdefine F,OP        _F      _op     _null   \ MOD F,SETOP
     5 opdefine BYTE,WR     _byte   _wr     _null   \ LD 23,A
     6 opdefine WORD,WR     _word   _wr     _null   \ LD $123,A
     7 opdefine RI,WR       _ri     _wr     _null   \ LD R5,X
     8 opdefine RI,BYTE     _ri     _byte   _null   \ LD R5,57
     9 opdefine (RI),WORD   _(ri)   _word   _null   \ LD (R4),1234
    10 opdefine (RI),BYTE   _(ri)   _byte   _null   \ LD (R4),234
    11 opdefine (RI),WR     _(ri)   _wr     _null   \ LD (R2+),X
    12 opdefine (RI),(RI),B _(ri)   _(ri)   _byte   \ MLD (R5+),(R1+),0
    13 opdefine WR,BYTE     _wr     _byte   _null   \ ADD A,34
    14 opdefine BYTE        _byte   _null   _null   \ ADDI 23
    15 opdefine WR,((RI))   _wr     _((ri)) _null   \ LD STACK,((R5+))
    16 opdefine WR,(RI)     _wr     _(ri)   _null   \ LD Y,(R5)
    17 opdefine WR,WORD     _wr     _word   _null   \ LD Y,3333
    18 opdefine WR,RI       _wr     _ri     _null   \ LD X,R2
    19 opdefine WR,WR       _wr     _wr     _null   \ LD X,Y
    20 opdefine WR,(RI),B   _wr     _(ri)   _byte   \ MLD STACK,(R1),1

here over - swap !              \ fill in length of operand table

-1 constant _BAD                \ bad combination of operands

: .optable      ( -- )
                save> base hex
                optable length 13 - bounds
                do      cr i optable - 3 + 4 u.r space
                        i >name.id 18 sp>col
                        i >body dup @ 5 u.r 2+
                                dup @ 5 u.r 2+
                                dup @ 5 u.r 2+
                                dup @ 5 u.r 2+
                                dup @ 5 u.r 2+
                                drop
            13 +loop
                restore> base ;

: findopt       ( -- optype ) \ find operand code for this set of operands
                false save!> caps
                $E97A operand!          \ fill in verification marker
\        operands 10 dump
                operands 8 optable length search
                if      optable +       \ return the valid operand set
\        dup 10 dump
                        @
\        ." Returns type: " dup .
                else    drop _bad       \ return the BAD operand flag
                then
                restore> caps ;

0 value ?got-inst       \ have we got an instruction yet
0 value A-SM            \ assembler stack mark

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
        operand0
        on> ?got-inst ;

}                 ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                  º error handling º
                  ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

defer IS-BAD                   \ defer for other forms of error handling

: _IS-BAD ( -- )
        init-aprior
        0 " Invalid OPERAND" "errmsg ;

' _is-bad is is-bad

: ?asmerr       ( f1 a1 n1 -- )
                rot
                if      0 -rot "errmsg
                else    2drop
                then    ;

}
                    ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                    º  extension byte generation º
                    ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

: EXTC! ( <n> <offset> -- )
        here + c!-e ;           \ put extension byte into extention segment

: EB0 ( -- )
      $10 0 extc! ;

: EB1 ( -- )
        $30 0 extc! $32 1 extc! ;

: EB2 ( -- )
        $01 0 extc! $01 1 extc! $01 2 extc! $01 3 extc! ;

: EB3 ( -- )
        $30 0 extc! ;

: EB4 ( -- )
        ; \ no extent bytes generated, handled by the code generator

: EB5 ( -- )
      $10 0 extc! $20 1 extc! ;

: EB6 ( -- )
      $10 0 extc! $20 2 extc! ;

: EXT-BYTES ( <n> -- )
        dup 0 6 between 0=
        if      0 " Extention byte index INVALID!" "errmsg
                drop 0                  \ force it to a valid index
        then    exec: eb0 eb1 eb2 eb3 eb4 eb5 eb6 ;

}
                   ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                   º machine code generation º
                   ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼


The following abbreviations are used in the stack diagrams of
the code generation words that follow:

<b#>             bit number
<cc>             condition code
<da>             direct address
<dst>            destination register
<ia>             indirect address
<opc/opc>        two opcodes, one in each byte
<opc/opc/opc>    three opcode, two in the upper nibbles and one in lower byte
<opc>            one opcode
<r>              the register of a DJNZ instruction
<ra>             relative address
<src>            source register
<wr>             working register

{

: ?aonly        ( n1 -- )
                $30 <> " Only 'A' is a valid destination" ?asmerr ;

: ?rarange      ( n1 -- )
                0 $1FF between 0= " Ram Address Range error" ?asmerr ;

: ?readonly     ( n1 -- )
                dup $70 = " The P register is READ ONLY"        ?asmerr
                      0=  " The FFFF register is READ ONLY"     ?asmerr ;

: cg2   ( <dst> <src> <opc> -- )        \ a,ra
        rot ?aonly over ?rarange swap $1FF and or asm, ;

: cg3   ( <dst> <src> <opc> -- )        \ a,ri
        rot ?aonly swap or asm, ;

: cg4   ( <dst> <src> <opc> -- )        \ a,wr
        rot ?aonly swap $10 / or asm, ;

: cg5   ( <dst> <src> <opc> -- )        \ a,imm
        rot ?aonly asm, asm, ;

: cg6   ( <src> <opc> -- )              \ simm
        over 0 $FF between 0= " Short Immediate out of range" ?asmerr
        swap $FF and or asm, ;

: cg7   ( <dst> <src> <opc> -- )        \ cc,da
        rot or asm, asm, ;

: cg8   ( <dst> <src> <opc> -- )        \ ra,a
        swap ?aonly over ?rarange swap $1FF and or asm, ;

\ : cg9   ( <dst> <src> <opc> -- )        \ wr,(a)
\         nip over ?readonly or asm, ;

: cg10  ( <dst> <src> <opc> -- )        \ wr,ri
        or over ?readonly or asm, ;

: cg11  ( <dst> <src> <opc> -- )        \ wr,wr
        >r over ?readonly                       \ check for read only dest reg
        over $F0 and over = " Can't move from/to the same register" ?asmerr
        over $100 and                           \ (a)?
        if      r>drop
                $F0 and $4A00 or asm,           \ LD wr,(a)
        else    $10 / or r> or asm,             \ LD wr,wr
        then    ;

: cg12  ( <dst> <src> <opc> -- )        \ wr,imm
        rot dup ?readonly or asm, asm, ;

: cg13  ( <dst> <src> <opc> -- )        \ ri,simm
        or
                                                \ while leaving bits 0 & 1,
        swap dup 3 and swap $40 / or $100 * or  \ shift bit 8 down to bit 2
        asm, ;

: cg14  ( <dst> <src> <opc> -- )        \ (r1),imm
        rot or asm, asm, ;

: cg15  ( <dst> <src> <b> <opc> -- )    \ (rj),(ri),b
        swap 1 and $100 * or                    \ mask in 'B'
        swap
        dup $0C and     " Indexing is not allowed" ?asmerr
        dup $100 and    " Only R0-3 valid for Source" ?asmerr
        $3 and or                               \ mask in Ri
        swap
        dup $0C and     " Indexing is not allowed" ?asmerr
        dup $100 and 0= " Only R4-7 valid for Destination" ?asmerr
        $3 and $10 * or                    \ mask in Rj
        asm, ;

: cg16  ( <dst> <src> <b> <opc> -- )    \ wr,(ri),b
        swap 1 and $100 * or                    \ mask in 'B'
        swap $3 and or                          \ mask in Ri
        over ?readonly
        or                                      \ mask in wr
        asm, ;

: cg17  ( <dst> <src> <opc> -- )        \ cc,Op
        over $10 and " Invalid Operand for MOD cc,Op" ?asmerr
        or or asm, ;

: cg18  ( <dst> <src> <opc> -- )        \ F,Op
        over $10 and 0= " Invalid Operand for MOD F,Op" ?asmerr
        swap $0F and or asm, drop ;

: cg19  ( <opc> -- )                    \ ret
        asm, ;

: ext/cg ( <opc> <adr> <extent code> -- ) \ generate extension bytes before
                                          \ generating an instruction
        ext-bytes execute ;

set8086

}
     The internal structure of op-code definitions is somewhat complex.
     The following diagram shows code space and list space for the assembler
     word  ADC :
              ÚÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿
  List space: ³  SCANOPT  ³ ptr-to-cnt³   $A9     ³    $00    ³  CG01     ³
              ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄ´
                    ^           |     ³  $D0AA    ³    $00    ³  CGxx     ³
                    |           |     ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÙ
              ÚÄÄÄÄÄÄÄÄÄÄ¿      |
              ³  +XSEG   ³      |
              ÀÄÄÄÄÄÄÄÄÄÄÙ      |_______
                    |_________          |
                              |         V
  (Headerless : def)     ÚÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿
  Code space: JMP DOCOL  ³  pointer  ³ byte cnt  ³   r,ir    ³  rr,rr    ³
               ^         ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÙ
               |______________
                              |
  ADC definition in      ÚÄÄÄÄÄÄÄÄÄÄÄ¿
  code space: JMP DOVAR  ³  pointer  ³
                         ÀÄÄÄÄÄÄÄÄÄÄÄÙ

{

code scanopt    ( optype -- )   \ scan the operand types of an instruction
                                \ and execute the corresponding code gen
                pop ax
                cmp ax, # _bad
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
                repnz scasb             \ scan for matching byte
                jnz 1 $                 \ no match found
                mov es, dx              \ restore ES
                sub bx, cx              \ cvt to item number
                shl bx, # 1             \ mult by 2
                mov cx, bx
                shl bx, # 1             \ mult by 4
                add bx, cx              \ mult by 6
                add bx, si              \ to start of opcodes
                mov cx, es: 0 [bx]      \ get the opcode
                push cx                 \ to stack
                mov cx, es: 4 [bx]      \ get the code generator address
                push cx                 \ to stack
                mov cx, es: 2 [bx]      \ get the extension byte code
                push cx                 \ to stack
                mov es, 2 [rp]          \ load es & si from above definition
                mov si, 0 [rp]
                add rp, # 4             \ discard them from return stack
                mov ax, # ' ext/cg      \ execution address
                jmp ax  end-code        \ go execute the code generator
setASM1600

}

         The following words are used to define machine code instructions.
         These words build a sequence of legal operand types list space
         and a corresponding list of instruction opcodes, extension byte
         codes and code generator addresses in code space. When an
         instruction is executed, the generated operand type is compared,
         by scanopt above, with the sequence of bytes in list space. If a
         match is found the corresponding code generator is executed. If
         no match occurs the operands do not match the instruction and
         the word IS-BAD is executed.

{


HEADERLESS

false value IN_WORD!ED \ true if in_word captured in translation

HEADERS

' ; alias }i: immediate

: %i{          ( -- )
                compile findopt
                compile scanopt
                here dup x, 0 c,                \ lay in a null count
                begin   depth
                                '                       \ look up word
                                here c@ 0=              \ end of line
                                here 1+ c@ '\' = or     \ or comment ?
                        if      drop filltib            \ load next line
                                '
                                here c@ 0=
                                abort" End of file encountered"
                        then    dup ['] }i: <>         \ while not "}i:"
                while   execute c,
                        depth 1- <> abort" Op must return a value!"
                        1 over c+!
                        bl word ?uppercase
                        number drop x,         \ compile opcode
                        bl word ?uppercase
                        number drop x,         \ compile extension code
                        ' x,
                repeat  nip nip execute ;

: do-i          ( n1 -- )
                >r ?nos r>
                execute
                off> ?got-inst ;

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
                   off> ?got-inst
                   @                    \ save address of mnemonic data
                   ['] do-i a;!         \  and execution address in aprior
                   a;                   \ assemble previous instruction
                   in_word!ed 0=
                   IF >in_word @
                      !> asm->in        \ save in pointer for index file
                   THEN
                   inst-reset ;         \ reset for next instruction

}
                        ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                        º 1600 instructions º
                        ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼

{

HEADERS

i{      wr,byte     $8600 $0 cg2                \ a,ra  ra=$0000-$00FF
        wr,word     $8600 $0 cg2                \ a,ra  ra=$0100-$01FF
        wr,ri       $9200 $0 cg3                \ a,ri
        wr,(ri)     $8200 $0 cg3                \ a,(ri)
        wr,((ri))   $8A00 $0 cg3                \ a,((ri))
        wr,wr       $8000 $0 cg4  }i: ADD       \ a,wr

i{      wr,byte     $8800 $0 cg5                \ a,simm
        wr,word     $8800 $0 cg5                \ a,imm
        byte        $9800 $0 cg6  }i: ADDI

i{      wr,byte     $A600 $0 cg2                \ a,ra  ra=$0000-$00FF
        wr,word     $A600 $0 cg2                \ a,ra  ra=$0100-$01FF
        wr,ri       $B200 $0 cg3
        wr,(ri)     $A200 $0 cg3
        wr,((ri))   $AA00 $0 cg3
        wr,wr       $A000 $0 cg4  }i: AND

i{      wr,byte     $A800 $0 cg5                \ a,simm
        wr,word     $A800 $0 cg5                \ a,imm
        byte        $B800 $0 cg6  }i: ANDI

i{      cc,byte     $4C00 $0 cg7
        cc,word     $4C00 $0 cg7  }i: BRA

i{      cc,byte     $4800 $0 cg7
        cc,word     $4800 $0 cg7  }i: CALL

i{      wr,byte     $6600 $0 cg2                \ a,ra
        wr,word     $6600 $0 cg2                \ a,ra
        wr,ri       $7200 $0 cg3
        wr,(ri)     $6200 $0 cg3
        wr,((ri))   $6A00 $0 cg3
        wr,wr       $6000 $0 cg4  }i: CMP

i{      wr,byte     $6800 $0 cg5
        wr,word     $6800 $0 cg5
        byte        $7800 $0 cg6  }i: CMPI

i{      wr,byte     $E600 $0 cg2                \ a,ra
        wr,word     $E600 $0 cg2                \ a,ra
        wr,ri       $F200 $0 cg3
        wr,(ri)     $E200 $0 cg3
        wr,((ri))   $EA00 $0 cg3
        wr,wr       $E000 $0 cg4  }i: EOR

i{      wr,byte     $E800 $0 cg5
        wr,word     $E800 $0 cg5
        byte        $F800 $0 cg6  }i: EORI

i{      wr,byte     $0600 $0 cg2                \ a,ra  ra=$0000-$00FF
        wr,word     $0600 $0 cg2                \ a,ra  ra=$0100-$01FF
        byte,wr     $0E00 $0 cg8                \ ra,a  ra=$0000-$00FF
        word,wr     $0E00 $0 cg8                \ ra,a  ra=$0100-$01FF
        wr,ri       $1200 $0 cg10
        wr,(ri)     $0200 $0 cg10
        wr,((ri))   $0A00 $0 cg10
        wr,wr       $0000 $0 cg11
        ri,wr       $1400 $0 cg10
        (ri),wr     $0400 $0 cg10 }i: LD


i{      wr,byte     $0800 $0 cg12
        wr,word     $0800 $0 cg12
        ri,byte     $1800 $0 cg13
        (ri),byte   $0C00 $0 cg14
        (ri),word   $0C00 $0 cg14 }i: LDI

i{      (ri),(ri),b $B600 $0 cg15
        wr,(ri),b   $A400 $0 cg16 }i: MLD

i{      cc,op       $9000 $0 cg17
        F,op        $9400 $0 cg18 }i: MOD

i{      (ri),(ri),b $9600 $0 cg15
        wr,(ri),b   $8400 $0 cg16 }i: MPYA

i{      (ri),(ri),b $3600 $0 cg15
        wr,(ri),b   $2400 $0 cg16 }i: MPYS

i{      wr,byte     $C600 $0 cg2                \ a,ra
        wr,word     $C600 $0 cg2                \ a,ra
        wr,ri       $D200 $0 cg3
        wr,(ri)     $C200 $0 cg3
        wr,((ri))   $CA00 $0 cg3
        wr,wr       $C000 $0 cg4  }i: OR

i{      wr,byte     $C800 $0 cg5
        wr,word     $C800 $0 cg5
        byte        $D800 $0 cg6  }i: ORI

i{      no-opr      $0065 $0 cg19 }i: RET

i{      wr,byte     $2600 $0 cg2        \ a,ra
        wr,word     $2600 $0 cg2        \ a,ra
        wr,ri       $3200 $0 cg3
        wr,(ri)     $2200 $0 cg3
        wr,((ri))   $2A00 $0 cg3
        wr,wr       $2000 $0 cg4  }i: SUB

i{      wr,byte     $2800 $0 cg5
        wr,word     $2800 $0 cg5
        byte        $3800 $0 cg6  }i: SUBI

}                  ÉÍÍÍÍÍÍÍÍÍÍ»
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

\ working register operands      (values when in destination field)

$00 _wr operand FFFF    $10 _wr operand X       $20 _wr operand Y
$30 _wr operand A       $40 _wr operand ST      $50 _wr operand STACK
$60 _wr operand PC      $70 _wr operand P       $80 _wr operand EXT0
$90 _wr operand EXT1    $A0 _wr operand EXT2    $B0 _wr operand EXT3
$C0 _wr operand EXT4    $D0 _wr operand EXT5    $E0 _wr operand EXT6
$F0 _wr operand EXT7   $130 _wr operand (A)

\ Flag operand

$00  _f operand F

\ Connected and disconnected flags

$00 constant C
$01 constant D

\ pointer register operands

$000 _ri operand R0             $001 _ri operand R1
$002 _ri operand R2             $003 _ri operand R3
$100 _ri operand R4             $101 _ri operand R5
$102 _ri operand R6             $103 _ri operand R7

$000 _(ri) operand (R0)         $001 _(ri) operand (R1)
$002 _(ri) operand (R2)         $003 _(ri) operand (R3|00)
$100 _(ri) operand (R4)         $101 _(ri) operand (R5)
$102 _(ri) operand (R6)         $103 _(ri) operand (R7|00)

$000 _((ri)) operand ((R0))     $001 _((ri)) operand ((R1))
$002 _((ri)) operand ((R2))     $003 _((ri)) operand ((R3|00))
$100 _((ri)) operand ((R4))     $101 _((ri)) operand ((R5))
$102 _((ri)) operand ((R6))     $103 _((ri)) operand ((R7|00))

$00C _(ri) operand (R0+)        $00D _(ri) operand (R1+)
$00E _(ri) operand (R2+)        $00F _(ri) operand (R3|11)
$10C _(ri) operand (R4+)        $10D _(ri) operand (R5+)
$10E _(ri) operand (R6+)        $10F _(ri) operand (R7|11)

$00C _((ri)) operand ((R0+))    $00D _((ri)) operand ((R1+))
$00E _((ri)) operand ((R2+))    $00F _((ri)) operand ((R3|11))
$10C _((ri)) operand ((R4+))    $10D _((ri)) operand ((R5+))
$10E _((ri)) operand ((R6+))    $10F _((ri)) operand ((R7|11))

$008 _(ri) operand (R0-)        $009 _(ri) operand (R1-)
$00A _(ri) operand (R2-)        $00B _(ri) operand (R3|10)
$108 _(ri) operand (R4-)        $109 _(ri) operand (R5-)
$10A _(ri) operand (R6-)        $10B _(ri) operand (R7|10)

$008 _((ri)) operand ((R0-))    $009 _((ri)) operand ((R1-))
$00A _((ri)) operand ((R2-))    $00B _((ri)) operand ((R3|10))
$108 _((ri)) operand ((R4-))    $109 _((ri)) operand ((R5-))
$10A _((ri)) operand ((R6-))    $10B _((ri)) operand ((R7|10))

$004 _(ri) operand (R0+!)       $005 _(ri) operand (R1+!)
$006 _(ri) operand (R2+!)       $007 _(ri) operand (R3|01)
$104 _(ri) operand (R4+!)       $105 _(ri) operand (R5+!)
$106 _(ri) operand (R6+!)       $107 _(ri) operand (R7|01)

$004 _((ri)) operand ((R0+!))   $005 _((ri)) operand ((R1+!))
$006 _((ri)) operand ((R2+!))   $007 _((ri)) operand ((R3|01))
$104 _((ri)) operand ((R4+!))   $105 _((ri)) operand ((R5+!))
$106 _((ri)) operand ((R6+!))   $107 _((ri)) operand ((R7|01))

\ condition code operands

$000 _cc operand ALWAYS  $020 _cc operand USR0=0  $030 _cc operand USR1=0
$040 _cc operand LINK=0  $050 _cc operand Z=0     $060 _cc operand OV=0
$070 _cc operand N=0     $120 _cc operand USR0=1  $130 _cc operand USR1=1
$140 _cc operand LINK=1  $150 _cc operand Z=1     $160 _cc operand OV=1
$170 _cc operand N=1

\ Op code operands

$12 _op operand RESL    $13 _op operand SETL    $14 _op operand RESIE
$15 _op operand SETIE   $18 _op operand RESOP   $19 _op operand SETOP
$00 _op operand ROR     $01 _op operand ROL     $02 _op operand SHR
$03 _op operand SHL     $04 _op operand INC     $05 _op operand DEC
$06 _op operand NEG     $07 _op operand ABS

only forth definitions also

decimal

warning on       \ re-enable the redefinition warning flag

