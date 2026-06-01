\\ ASMS8.SEQ              SAM8 Assembler               by Jerry Boutelle

  This assembler is based on PASM.SEQ. PASM was developed by Tom Zimmer
and Robert Smith for the F-PC Forth system.

  The syntax of this assembler is very similar to the Zilog assembler
syntax, the MAJOR EXCEPTION is SPACES are used to delimit operands
following an instruction. Here are some examples of the proper syntax:

        ADC R12 R14             LDC R7 $31 (RR12)
        ADC R11 @R13            LDC $23 (RR10) R9
        ADC $23 254             LD  440 (R1) R12
        ADC $23 R3              DJNZ R3 label
        ADC R4 $23              CALL $2EFF
        ADC P2 @R P3            JP GT label
        ADC P2 @R4              PUSHUD @R2 R $D3
        ADC R1 @R P3            MULT R2 @R3
        ADC P2 # $EF            BTJRF label R6 # 3
        ADC R12 # $EF           DIV R $02 @R $D3

  All instructions, except Rotate Right, use the instruction mnemonics
assigned by Zilog; The Rotate Right instruction is coded as: ROR.

  The working registers, addresses $c0-cf, can be specified as "r0"-"r15"
or "@r0"-"@r15" for indirect references. The remaining registers can
specified by preceding the register number with a "r" or "@r" for an
indirect reference, for example: "r $34" or "@r $51". Register pair
references are made as "rr2" or "@rr2" for indirect references. Register
pair references need no have double r's. i.e. rr1=r1.

  Immediate data is preceded with a: "#".

  Use "SETASMS8" to select the SAM8 assembler.

  Use "SET8086"  to re-select the 80x86 assembler.
{

HEADERLESS

\ a code word, for speed, before we start the assembler proper

code $10* ( <n> -- <n*$10> ) \ Logical shift left by 4 bit positions.
                pop ax
                shl ax, # 1     shl ax, # 1
                shl ax, # 1     shl ax, # 1
                1push           end-code

defined to-screen nip
#if
: 0.R ( n l -- ) \ Output as a signed single number
                 \ right justified with zeros on the left
        >r 0 <# r> 1- 0max 0 ?do # loop # #> type ;
#then
warning off                \ we have many re-definitions

HEADERS

only forth also definitions vocabulary asms8 assembler also

' asms8 ALIAS [ASMS8] IMMEDIATE

HEADERLESS

defer inst-reset \ move this down if this works ???? ####

: INIT-APRIOR ( -- )
        0 ['] drop a;!             \ init with harmless operation
        aprior 4 + 2@ aprior 2! ;

: DOASSEMS8  ( -- ) \ initial setup of sam8 assembler by CODE xxx
        @> run =: arunsave
\        ['] run-a; is run
        init-aprior
        lihere =: linestrt
        ll-global? 0=
        IF
\- init_labels llab-init                \ initialize all local labels
                                        \ if used on F-PC
\+ init_labels init_labels              \ initialize only first 40 labels
                                        \ if used in TCOM
        THEN also asms8 ;

: SETASMS8 ( -- ) \ assemble sam8 code
        ['] doassems8 is setassem clear_labels ;

SETASMS8

\ define SET8086 only if its NOT already defined.

\- set8086 : SET8086 ( -- ) \ assemble 8086 code
\- set8086         ['] doassem is setassem clear_labels ;

only forth also assembler also asms8 definitions also

\ some alias headers so we don't have to redefine these words in
\ the new target assembler.

defined to-screen nip forth 0= asms8
#if

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
' tc@           alias tc@
' tc!           alias tc!
' t!            alias t!
' ic,           alias ic,
' cc,           alias cc,
' oc,           alias oc,
' o,            alias o,

compiler also

' "errmsg       alias "errmsg

#else

' ic,           alias ic,
' cc,           alias cc,
' oc,           alias oc,
' o,            alias o,

: "errmsg ( <cfa> <stradr> -- )
        cr type abort ;

#then

only forth also asms8 definitions also

}

         The following constants define the individual operands that
         are possible. These symbolic names follow the syntax given in
         Table 5-3. of the Z8 Family Design Handbook p. 496. These
         symbols are preceded with underscore to avoid renaming
         numbers or other Forth words.

{

 0 constant _R             \ general or working register operand
 1 constant _(R)           \ indexed register operand
 2 constant _IR            \ indirect general or working register operand
 3 constant _DA            \ direct address
 4 constant _IM            \ immediate byte
 5 constant _IML           \ immediate word
 6 constant _CC            \ condition code
 7 constant _NULL          \ no operand

0 value    SRC             \ holds source register code
0 value    DST             \ holds destination register code

defer >DST/SRC             \ store the destination or source reg code

: SRC! ( <n> -- )          \ store register code into destination
        !> src ;           \ next operand is src

: DST! ( <n> -- )          \ store register code into destination
        !> dst
        ['] src! is >dst/src ;

' dst! is >dst/src

: >SRC ( -- )
        ['] src! is >dst/src ;

}

         The following constants define the legal combination of
         individual operands, given above, that are possible with SAM8
         instructions.

{
                                     \ code example
                                     \ ------------
 0 constant NO-OPR                   \ ccf
 1 constant CC,DA                    \ jp lt 1234
 2 constant CC,R                     \ jp lt 12
 3 constant DA_                      \ call 1234
 4 constant DA(R),R                  \ ldc 1234 (rr3) r1
 5 constant DA,R                     \ ldc 1234 r1
 6 constant DA,R,IM                  \ btjrf 1234 r1 # 7
 7 constant IM_                      \ call # 58
 8 constant IR_                      \ dec @r 34
 9 constant IR,IM                    \ ld @r 67 # 45
10 constant IR,R                     \ ld @r1 r2
11 constant R_                       \ call 12
12 constant R(R),R                   \ ld 50 (r1) r2
13 constant R,DA                     \ djnz r1 1234
14 constant R,DA(R)                  \ ldc r1 1234 (rr3)
15 constant R,IM                     \ adc r1  # 12
16 constant R,IML                    \ ldw rr6 # 1234
17 constant R,IM,R                   \ band r1 # 2 r2
18 constant R,IR                     \ adc r1 @r0
19 constant R,IR,DA                  \ cpije r1 @r2 1234
20 constant R,IR,R                   \ cpije r1 @r2 12
21 constant R,R                      \ adc r1 r0
22 constant R,R(R)                   \ ld r1 50 (r2)
23 constant R,R,IM                   \ band r1 r2 # 3

}

         The following constants give names to operand combinations are
         invalid or are combined while accumulating a valid combination.

{

24 constant BAD
25 constant CC_
26 constant DA(R)
27 constant R(R)

}

         The following syntax trees show the valid combinations of SAM8
         operands and the constants, as given above, that represent a parse
         of the tree.

                        syntax trees

                            null
                             |
                             0

                             cc
                            /  \
                           da    r
                           |     |
                           1     2

                             da
                         /   |    \
                        3    (r)    r
                              |   /  \
                              r  5   im
                              |      |
                              4      6

                             im
                             |
                             7

                             ir
                        /    |   \
                       8     im   r
                             |    |
                             9    10

                             r
   /     /     /          /    \       \             \
  11   (r)    da        im     iml      ir            r
        |    /   \      /  \    |     /  |  \     /   |   \
        r   13   (r)  15   r    17   18  da  r   21   (r) im
        |         |        |             |   |         |  |
        12        14       16            19  20        22 23



         The following table is used to parse the operands of SAM8
         instructions. This table is entered with the current operand type
         and the current operand to get the new operand type. The operand
         type is shown in the left hand column. The current operand is shown
         in the top row. The operand type starts as no-opr. Using the table
         in this manner parses the syntax trees given above to arrive at
         valid or invalid operand combinations for the SAM8 instructions.

{

7 constant ent/row

: c,s ( <nn> <nn-1>... <n1> <n> -- )
        0 swap 1-
        DO i roll c, -1
        +LOOP ;

: E/RC,S ( -- )
        ent/row c,s ;

create syntax-tree

         \                  operand-type
         \   _r      _(r)    _ir     _da     _im     _iml    _cc

( NO-OPR )   r_      bad     ir_     da_     im_     bad     cc_   e/rc,s
( CC,DA  )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( CC,R   )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( DA_    )   da,r    da(r)   bad     bad     bad     bad     bad   e/rc,s
( DA(R,R )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( DA,R   )   bad     bad     bad     bad     da,r,im bad     bad   e/rc,s
( DA,R,IM)   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( IM_    )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( IR_    )   ir,r    bad     bad     bad     ir,im   bad     bad   e/rc,s
( IR,IM  )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( IR,R   )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R_     )   r,r     r(r)    r,ir    r,da    r,im    r,iml   bad   e/rc,s
( R(R,R  )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R,DA   )   bad     r,da(r) bad     bad     bad     bad     bad   e/rc,s
( R,DA(R )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R,IM   )   r,im,r  bad     bad     bad     bad     bad     bad   e/rc,s
( R,IML  )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R,IM,R )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R,IR   )   r,ir,r  bad     bad     r,ir,da bad     bad     bad   e/rc,s
( R,IR,DA)   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R,IR,R )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R,R    )   bad     r,r(r)  bad     bad     r,r,im  bad     bad   e/rc,s
( R,R(R  )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( R,R,IM )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( BAD    )   bad     bad     bad     bad     bad     bad     bad   e/rc,s
( CC_    )   cc,r    bad     bad     cc,da   bad     bad     bad   e/rc,s
( DA(R   )   da(r),r bad     bad     bad     bad     bad     bad   e/rc,s
( R(R    )   r(r),r  bad     bad     bad     bad     bad     bad   e/rc,s

0 value operand-type

set8086
code get-operand-type ( <current operand> -- )
        mov ax, ' operand-type >body
        mov bx, # ent/row
        mul ax, bx                      \ mult operand type by entries/row
        pop bx
        add ax, bx                      \ add the current operand
        add ax, # ' syntax-tree >body
        mov di, ax
        xor ah, ah
        mov al, 0 [di]
        mov ' operand-type >body ax     \ store a new operand type
        next end-code
setasms8

0 value ?got-inst       \ have we got an instruction yet
0 value A-SM            \ assembler stack mark

defer    8-BIT          \ operand form for an 8 bit number
defer   16-BIT          \ operand form for a 16 bit number

' _r   is  8-bit

' _iml is 16-bit

: ?NOS ( ? -- ? ) \ is there a number on the stack ?
        sp@ a-sm - abs 2/ dup 1- swap 0
        ?DO dup i - 1+ pick       \ look at deepest on stack first
           $ff u>                 \ is this stack entry > 255 ?
           IF   16-bit            \ yes, its a 16 bit number
           ELSE  8-bit            \ no,  its a  8 bit number
           THEN get-operand-type
           >src                   \ next operand is src operand
        LOOP drop
        sp@ !> a-sm ;             \ store assembler stack mark

: _INST-RESET ( -- ) \ reset assembler for next instruction
        sp@ !> a-sm                  \ store assembler stack mark
        _null !> src                 \ clear source code
        _null !> dst                 \ clear source code
        ['] dst! is >dst/src         \ first operand is dst
        ['] _r  is  8-bit            \ default to  8 bit number is register
        ['] _da is 16-bit            \ default to 16 bit number is direct adr
        no-opr !> operand-type       \ set operand type to no operands
        on> ?got-inst ;

' _inst-reset is inst-reset

}                 ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                  º error handling º
                  ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

defer IS-BAD                   \ defer for other forms of error handling

: _IS-BAD ( -- )
        init-aprior
        0 " Generates an invalid instruction" "errmsg ;

' _is-bad is is-bad

defer ?ASM-ERROR            \ defer for other forms of error handling

: _?ASM-ERROR ( <bool> <error number> -- <?> )
        swap
        IF init-aprior
           CASE
               0 OF 0 " Too many operands"              "errmsg ENDOF
               1 OF 0 " Invalid operands"               "errmsg ENDOF
               2 OF 0 " Invalid bit number"             "errmsg ENDOF
               3 OF 0 " Indirect address must be even"  "errmsg ENDOF
               4 OF 0 " Src reg must be working reg"    "errmsg ENDOF
               5 OF 0 " Dst reg must be working reg"    "errmsg ENDOF
               6 OF 0 " Bits 1 and/or 0 are set"        "errmsg ENDOF
\               7 OF 0 " Invalid page"                   "errmsg ENDOF
               8 OF 0 " Invalid src reg"                "errmsg ENDOF
               9 OF 0 " Invalid dst reg"                "errmsg ENDOF
              10 OF 0 " Invalid page"                   "errmsg ENDOF
              11 OF 0 " Relative branch out of range"   "errmsg ENDOF
              12 OF 0 " Indirect address out of range"  "errmsg ENDOF
              13 OF 0 " Src reg must be even"           "errmsg ENDOF
              14 OF 0 " Dst reg must be even"           "errmsg ENDOF
              15 OF 0 " Src reg must be odd"            "errmsg ENDOF
              16 OF 0 " Dst reg must be odd"            "errmsg ENDOF
              17 OF 0 " Non-micrcontroller instruction" "errmsg ENDOF
              18 OF 0 " Src Regs 0 and 1 not allowed"   "errmsg ENDOF
              19 OF 0 " Dst Regs 0 and 1 not allowed"   "errmsg ENDOF
              drop is-bad
           ENDCASE
        ELSE drop
        THEN ;

' _?asm-error is ?asm-error

}
                    ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                    º  extension byte generation º
                    ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

defined to-screen nip forth 0= asms8
#if

: EXTC! ( <n> <offset> -- )
        here + c!-e ;           \ put extension byte into extention segment

#else

: EXTC! ( <n> <offset> -- )
        2drop ;

#then

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

: EXT-BYTES ( <n> -- )
        exec: eb0 eb1 eb2 eb3 eb4 ;

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
<x>              byte index
<xl>             word index

{

: REG|REG ( <wr> <wr> -- <wr/wr> ) \ combine working regs into byte
        $10* + $CC0 - ;

: ?B# ( <b#> -- <b#> ) \ insure 0 <= bit number <= 7
        dup 7 u> 2 ?asm-error ;

: ?WR ( <src|dst> -- <bool> ) \ is register a working register ?
        $c0 $cf between ;

: ?R2-R15 ( <src|dst> -- <bool> ) \ is working reg between b2 and r15 ?
        $c2 $cf between ;

: SRC-WR-ONLY ( <src> -- <src> ) \ insure src reg is a working register
        dup ?wr not 4 ?asm-error ;

: DST-WR-ONLY ( <dst> -- <dst> ) \ insure dst reg is a working register
        dup ?wr not 5 ?asm-error ;

: ?GR ( <src|dst> -- <bool> ) \ is register a general register ?
        dup ?wr not swap $100 u< and ;

: ?B10 ( <src> -- ) \ are bits 1 and 0 not set in srpx operand?
        2 and 6 ?asm-error ;

: SRC-EVEN ( <src> -- <src> ) \ insure src register is an even register
\       dup 1 and 13 ?asm-error ;
        $fe and ;

: DST-EVEN ( <dst> -- <dst> ) \ insure dst register is an even register
\       dup 1 and 14 ?asm-error ;
        $fe and ;

: SRC-ODD ( <src> -- <src> ) \ insure src register is an odd register
\       dup 1 and 0= 15 ?asm-error ;
        1 or ;

: DST-ODD ( <dst> -- <dst> ) \ insure dst register is an odd register
\       dup 1 and 0= 16 ?asm-error ;
        1 or ;

defined to-screen nip forth 0= asms8
#if

assembler

' OFFSET_16,   ALIAS ASM,        \ a normal ","  in this assembler
' OC,          ALIAS ASMC,       \ a normal "C," in this assembler

' RELATIVE_8, ALIAS ASMRELC,

: ASMABS, ( <adr> -- )          \ addresses are stored LOW/HIGH in memory
        [assembler] flip offset_16, ;

asms8

\ : CALC-REL ( <adr> -- <rel offset> ) \ calculate relative offset for SAM8
\         here 1+ - dup -128 127 between 0= 11 ?asm-error ;
\
\ : ASMRELC, ( <adr> -- ) \ assemble a relative byte
\         calc-rel asmc, ;

#else

: ASMC, ( <n> -- ) \ assemble a byte
        base @ >r hex 2 0.r space r> base ! ;

: CALC-REL ( <adr> -- <rel offset> ) \ calculate relative offset for SAM8
        here 1+ - dup -128 127 between not 11 ?asm-error ;

: ASMRELC, ( <adr> -- ) \ assemble a relative byte
        calc-rel ." r" asmc, ;

: ASM, ( <n> -- ) \ assemble a word
        base @ >r hex 4 0.r space r> base ! ;

' asmc, alias IC,

' asmc, alias OC,

: ASMABS, ( <adr> -- ) \ assemble an absolute address
        ." a" flip asm, ; \ SAM8 has opposite byte order

#then

true value ASSEMBLE-LDE-INSTRUCTIONS \ conditionally compile LDE instruction
                                    \ generation code. The SAM8
                                    \ Microcontroller will not allow using the
                                    \ LDE instructions

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

\ : ic, asmc, ; \ for now ####
\ : cc, asmc, ; \ for now ####

: cg00 ( <opc> -- )
        ic, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³     dst    ³     OPC    ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg01 ( <dst> <opc/opc> -- )
        over ?gr
        IF eb0 ic, asmc,
        ELSE eb3 U16/ U16/ swap $10* + ic,
        THEN ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     dst    ³     src    ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg02 ( <dst> <src> <opc> -- )
        ic, src-wr-only src-even swap dst-wr-only reg|reg asmc, ;

assemble-lde-instructions
#if
: cg03 ( <dst> <src> <opc> -- )
        ic, src-wr-only src-odd swap dst-wr-only reg|reg asmc, ;
#else
: cg03 ( <dst> <src> <opc> -- )
        1 17 ?asm-error ;
#then

: cg04 ( <dst> <src> <opc> -- )
        ic, src-wr-only swap dst-wr-only reg|reg asmc, ;

: cg05 ( <dst> <src> <opc/opc> -- )
        U16/ U16/ cg04 ;

: cg06 ( <dst> <src> <opc> -- )
        ic, swap reg|reg asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     src    ³     dst    ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg07 ( <dst> <src> <opc> -- )
        ic, swap dst-even swap src-wr-only reg|reg asmc, ;

assemble-lde-instructions
#if
: cg08 ( <dst> <src> <opc> -- )
        ic, swap dst-wr-only dst-odd swap reg|reg asmc, ;
#else
: cg08 ( <dst> <src> <opc> -- )
        1 17 ?asm-error ;
#then

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg09 ( <dst> <opc> -- )
        ic, asmc, ;

: cg09.0 ( <dst> <opc> -- )
        cc, asmc, ;

: cg10 ( <ia> <opc> -- )
        cc, dup 1 and 3 ?asm-error
        dup 0 254 between not 12 ?asm-error asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³           src           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{
: cg11 ( <src> <opc> -- )
        ic, asmc, ;

: cg12 ( <src> <opc> -- )
        ic, dup ?b10 asmc, ;

: cg13 ( <src> <opc> -- )
        ic, dup ?b10 2 or asmc, ;

: cg14 ( <src> <opc> -- )
        ic, dup ?b10 1 or asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÂÄÄÄ¿
      ³           OPC           ³ ³     dst    ³    b   ³ 0 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÙ
{

: cg15 ( <dst> <b#> <opc> -- )
        ic, ?b# 2* swap dst-wr-only $10* + asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÂÄÄÄ¿
      ³           OPC           ³ ³     dst    ³    b   ³ 1 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÙ
{

: cg16 ( <dst> <b#> <opc> -- )
        ic, ?b# 2* 1 or swap dst-wr-only $10* + asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³     r      ³    OPC     ³ ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg17 ( <r> <dst> <opc> -- )
        rot dst-wr-only $10* + ic, asmrelc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³    cc      ³    OPC     ³ ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg18 ( <cc> <ra> <opc> -- )
        rot $10* + ic, asmrelc, ;

: cg19 ( <ra> <opc> -- )
        $80 or ic, asmrelc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³    dst     ³    OPC     ³ ³           src           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg20 ( <dst> <src> <opc/opc/opc> -- )
       U16/ U16/ $f and rot $f and $10* + ic, asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³    src     ³    OPC     ³ ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg21 ( <dst> <src> <opc/opc/opc> -- )
     U16/ U16/ U16/ swap $f and $10* + ic, asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           src           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg22 ( <dst> <src> <opc> -- )
        ic, swap asmc, asmc, ;

: cg23 ( <dst> <src> <opc> -- )
        >r over ?wr
        IF r> cg20
        ELSE r> cg22
        THEN ;

: cg24 ( <src> <opc> -- )
        ic, $df asmc, dup $f1 and 10 ?asm-error asmc, ;
}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³           src           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg25 ( <dst> <src> <opc> -- )
        ic, asmc, asmc, ;

: cg26 ( <dst> <src> <opc> -- )
        >r over ?gr
           over ?gr or
        IF r> cg25
        ELSE r> 2- cg06
        THEN ;

: cg27 ( <dst> <src> <opc/opc/opc> -- )
        >r over ?wr
        IF r> cg20 exit
        THEN dup ?wr
        IF r> cg21 exit
        THEN
        r> cg25
        ;

: cg28 ( <dst> <src> <opc/opc> -- )
        >r over ?wr
           over ?wr and
        IF r> cg05
        ELSE r> cg25
        THEN ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÂÄÄÄ¿
      ³           OPC           ³ ³     dst    ³    b   ³ 0 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           src           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg29 ( <dst> <src> <b#> <opc> -- )
        ic, ?b# 2* rot dst-wr-only $10* + asmc, asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÂÄÄÄ¿
      ³           OPC           ³ ³     src    ³    b   ³ 1 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg30 ( <dst> <b#> <src> <opc> -- )
        ic, swap ?b# 2* 1 or swap src-wr-only $10* + asmc, asmc, ;

: cg31 ( <dst> <src> <b#> <opc> -- )
        ic, ?b# 2* 1 or swap src-wr-only $10* + asmc, asmrelc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÂÄÄÄ¿
      ³           OPC           ³ ³     src    ³    b   ³ 0 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg32 ( <dst> <src> <b#> <opc> -- )
        ic, ?b# 2* swap src-wr-only $10* + asmc, asmrelc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     src    ³     dst    ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           RA            ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg33 ( <dst> <src> <ra> <opc> -- )
        ic, >r src-wr-only swap dst-wr-only swap reg|reg asmc,
        r> asmrelc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     dst    ³ src <> 0|1 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³            x            ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg34 ( <dst> <x> <src> <opc/opc> -- )
        ic, src-wr-only src-even        \ ** EVEN **
        dup 2 < 18 ?asm-error           \ don't allow regs 0 and 1
        rot dst-wr-only reg|reg
        asmc, asmc, ;

assemble-lde-instructions
#if
: cg35 ( <dst> <x> <src> <opc/opc> -- )
        ic, src-wr-only src-odd         \ ** ODD **
        dup 2 < 18 ?asm-error           \ don't allow regs 0 and 1
        rot dst-wr-only reg|reg
        asmc, asmc, ;
#else
: cg35 ( <dst> <x> <src> <opc/opc> -- )
        1 17 ?asm-error ;
#then

: cg36 ( <dst> <x> <src> <opc/opc> -- )
        ic, src-wr-only rot dst-wr-only reg|reg asmc, asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     src    ³ dst <> 0|1 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³            x            ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg37 ( <x> <dst> <src> <opc/opc> -- )
        ic, src-wr-only swap
        dst-wr-only dst-even            \ ** EVEN **
        dup 2 < 19 ?asm-error           \ don't allow regs 0 and 1
        swap reg|reg asmc, asmc, ;

assemble-lde-instructions
#if
: cg38 ( <x> <dst> <src> <opc/opc> -- )
        ic, src-wr-only swap
        dst-wr-only dst-odd             \ ** ODD **
        dup 2 < 19 ?asm-error           \ don't allow regs 0 and 1
        swap reg|reg asmc, asmc, ;
#else
: cg38 ( <x> <dst> <src> <opc/opc> -- )
        1 17 ?asm-error ;
#then

: cg39 ( <x> <dst> <src> <opc/opc> -- )
        ic, src-wr-only swap dst-wr-only
        swap reg|reg asmc, asmc, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³          dst(l)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          dst(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg40 ( <da> <opc> -- )
        cc, asm, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³     cc     ³   OPC      ³ ³          dst(l)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          dst(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg41 ( <cc> <da> <opc> -- )
     rot $10* + ic, asm, ;

: cg42 ( <da> <opc> -- )
        $80 or ic, asm, ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     dst    ³  <> 0 or 1 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          src(l)         ³ ³          src(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg43 ( <dst> <xl> <src> <opc> -- )
        ic, dup ?r2-r15 not 8 ?asm-error src-wr-only src-even
        rot reg|reg asmc, asmabs, ;

assemble-lde-instructions
#if
: cg44 ( <dst> <xl> <src> <opc> -- )
        ic, dup ?r2-r15 not 8 ?asm-error src-wr-only src-odd
        rot reg|reg asmc, asmabs, ;
#else
: cg44 ( <dst> <xl> <src> <opc> -- )
        1 17 ?asm-error ;
#then

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     src    ³  <> 0 or 1 ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          dst(l)         ³ ³          dst(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg45 ( <xl> <dst> <src> <opc> -- )
        ic, over ?r2-r15 not 9 ?asm-error swap dst-wr-only
        dst-even swap reg|reg asmc, asmabs, ;

assemble-lde-instructions
#if
: cg46 ( <xl> <dst> <src> <opc> -- )
        ic, over ?r2-r15 not 9 ?asm-error swap dst-wr-only
        dst-odd swap reg|reg asmc, asmabs, ;
#else
: cg46 ( <xl> <dst> <src> <opc> -- )
        1 17 ?asm-error ;
#then

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     src    ³     0      ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          dst(l)         ³ ³          dst(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg47 ( <dst> <src> <opc> -- )
        dst _null <> 1 ?asm-error
        ic, src-wr-only $c0 swap reg|reg asmc, asmabs, ;

: cg48 ( <dst> <src> <opc> -- )
        src _r <> 1 ?asm-error cg47 ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     dst    ³     0      ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          src(l)         ³ ³          src(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg49 ( <dst> <src> <opc> -- )
        ic, swap dst-wr-only $c0 swap reg|reg asmc, asmabs, ;

: cg50 ( <dst> <src> <opc> -- )
        src _null <> dst _r <> and 1 ?asm-error cg49 ;

: cg51 ( <dst> <src> <opc> -- )
        src _r =
        IF $10 + cg47
        ELSE src _null <> 1 ?asm-error cg49
        THEN ;

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     src    ³     1      ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          dst(l)         ³ ³          dst(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

assemble-lde-instructions
#if
: cg52 ( <dst> <src> <opc> -- )
        dst _null <> 1 ?asm-error
        ic, src-wr-only $c1 swap reg|reg asmc, asmabs, ;

: cg53 ( <dst> <src> <opc> -- )
        src _r <> 1 ?asm-error cg52 ;
#else
: cg53 ( <dst> <src> <opc> -- )
        1 17 ?asm-error ;
#then

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³     dst    ³     1      ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          src(l)         ³ ³          src(h)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

assemble-lde-instructions
#if
: cg54 ( <dst> <src> <opc> -- )
        ic, swap dst-wr-only $c1 swap reg|reg asmc, asmabs, ;

: cg55 ( <dst> <src> <opc> -- )
        src _null <> dst _r <> and 1 ?asm-error cg54 ;

: cg56 ( <dst> <src> <opc> -- )
        src _r =
        IF $10 + cg52
        ELSE src _null <> 1 ?asm-error cg54
        THEN ;
#else
: cg55 ( <dst> <src> <opc> -- )
        1 17 ?asm-error ;

: cg56 ( <dst> <src> <opc> -- )
        1 17 ?asm-error ;
#then

}
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³           OPC           ³ ³           dst           ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
      ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
      ³          src(h)         ³ ³          src(l)         ³
      ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
{

: cg57 ( <dst> <src> <opc> -- )
        ic, swap asmc, asm, ;

}
                        ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                        º  macro code generation º
                        ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

: cg58 ( <opc> -- ) \ generate code for macro: BNOP
        ic, $ff asmc, ;

: cg59 ( <opc> -- ) \ generate code for macro: EX1
        ic, $00 asmc, $1c asmc, $01 asmc, ;

: cg60 ( <opc> -- ) \ generate code for macro: EX2
        ic, $7f asmc, $00 asmc, $ff asmc, ;

: cg61 ( <opc> -- ) \ generate code for macro: JP@RR0
        ic, $c0 asmc, ;

: cg62 ( <opc> -- ) \ generate code for macro: NNOP
        ic, $ff asmc, ;

: cg63 ( <opc> -- ) \ generate code for macro: NOOP
        ic, ;

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

code scanopt     ( -- ) \ scan the operand types of an instruction
                        \ and execute the corresponding code generator
                mov ax, ' operand-type >body
                cmp ax, # bad
                jl  2 $
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
setasms8

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

\ 12/09/91 14:36:15.94 tjz ** duplicate to a later definition of ?TRANSLATE.
\ false value ?TRANSLATE \ true if the line is to be translated

false value IN_WORD!ED \ true if in_word captured in translation

HEADERS

' ; alias }i: immediate

: %i{          ( -- )
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
\+ asm->in         in_word!ed 0=
\+ asm->in         IF >in_word @
\+ asm->in            !> asm->in        \ save in pointer for index file
\+ asm->in         THEN
                   inst-reset ;         \ reset for next instruction

}
                        ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                        º  SAM8 instructions º
                        ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

HEADERS

i{      r,r         $14 $0 cg26
        r,ir        $15 $0 cg26
        r,im        $16 $0 cg22  }i: ADC

i{      r,r          $4 $0 cg26
        r,ir         $5 $0 cg26
        r,im         $6 $0 cg22  }i: ADD

i{      r,r         $54 $0 cg26
        r,ir        $55 $0 cg26
        r,im        $56 $0 cg22  }i: AND

i{      r,r,im      $67 $0 cg29
        r,im,r      $67 $0 cg30  }i: BAND

i{      r,r,im      $17 $0 cg29  }i: BCP

i{      r,im        $57 $0 cg15  }i: BITC

i{      r,im        $77 $0 cg15  }i: BITR

i{      r,im        $77 $0 cg16  }i: BITS

i{      r,r,im       $7 $0 cg29
        r,im,r       $7 $0 cg30  }i: BOR

i{      r,r,im      $37 $0 cg32
        da,r,im     $37 $0 cg32  }i: BTJRF

i{      r,r,im      $37 $0 cg31
        da,r,im     $37 $0 cg31  }i: BTJRT

i{      r,r,im      $27 $0 cg29
        r,im,r      $27 $0 cg30  }i: BXOR

i{      r_          $f6 $0 cg40
        da_         $f6 $0 cg40
        ir_         $f4 $0 cg09.0
        im_         $d4 $0 cg10  }i: CALL

i{      no-opr      $ef $3 cg00  }i: CCF

i{      r_          $b0 $0 cg09
        ir_         $b1 $0 cg09  }i: CLR

i{      r_          $60 $0 cg09
        ir_         $61 $0 cg09  }i: COM

i{      r,r         $a4 $0 cg26
        r,ir        $a5 $0 cg26
        r,im        $a6 $0 cg22  }i: CP

i{      r,ir,r      $c2 $0 cg33
        r,ir,da     $c2 $0 cg33  }i: CPIJE

i{      r,ir,r      $d2 $0 cg33
        r,ir,da     $d2 $0 cg33  }i: CPIJNE

i{      r_          $40 $0 cg09
        ir_         $41 $0 cg09  }i: DA

i{      r_           $0 $0 cg09
        ir_          $1 $0 cg09  }i: DEC

i{      r_          $80 $0 cg09
        ir_         $81 $0 cg09  }i: DECW

i{      no-opr      $8f $3 cg00  }i: DI

i{      r,r         $94 $0 cg25
        r,ir        $95 $0 cg25
        r,im        $96 $0 cg25  }i: DIV

i{      r,r          $a $0 cg17
        r,da         $a $0 cg17  }i: DJNZ

i{      no-opr      $9f $3 cg00  }i: EI

i{      no-opr      $1f $3 cg00  }i: ENTER

i{      no-opr      $2f $3 cg00  }i: EXIT

i{      no-opr      $6f $0 cg00  }i: IDLE

i{      r_          $e20 $4 cg01
        ir_         $21  $0 cg09 }i: INC

i{      r_          $a0 $0 cg09
        ir_         $a1 $0 cg09  }i: INCW

i{      no-opr      $bf $3 cg00  }i: IRET

i{      r_           $d $0 cg42
        da_          $d $0 cg42
        cc,r         $d $0 cg41
        cc,da        $d $0 cg41
        ir_         $30 $0 cg09  }i: JP

i{      r_           $b $0 cg19
        da_          $b $0 cg19
        cc,r         $b $0 cg18
        cc,da        $b $0 cg18  }i: JR

i{      r,r       $98e4 $0 cg27
        r,ir      $c7e5 $0 cg28
        ir,r      $d7f5 $0 cg28
        r,im       $ce6 $0 cg23
        ir,im       $d6 $0 cg22
        r,r(r)      $87 $0 cg36
        r(r),r      $97 $0 cg39  }i: LD

i{      r,r,im      $47 $0 cg29
        r,im,r      $47 $0 cg30  }i: LDB

i{      r,ir        $c3 $0 cg02
        ir,r        $d3 $0 cg07
        r,r(r)      $e7 $0 cg34
        r(r),r      $f7 $0 cg37
        r,da(r)     $a7 $0 cg43
        da(r),r     $b7 $0 cg45
        da,r        $b7 $0 cg48
        r,da        $a7 $0 cg50
        r,r         $a7 $0 cg51  }i: LDC

i{      r,ir        $e2 $0 cg02  }i: LDCD

i{      r,ir        $e3 $0 cg02  }i: LDCI

i{      ir,r        $f2 $0 cg07  }i: LDCPD

i{      ir,r        $f3 $0 cg07  }i: LDCPI

i{      r,ir        $c3 $0 cg03
        ir,r        $d3 $0 cg08
        r,r(r)      $e7 $0 cg35
        r(r),r      $f7 $0 cg38
        r,da(r)     $a7 $0 cg44
        da(r),r     $b7 $0 cg46
        da,r        $b7 $0 cg53
        r,da        $a7 $0 cg55
        r,r         $a7 $0 cg56  }i: LDE

i{      r,ir        $e2 $0 cg03  }i: LDED

i{      r,ir        $e3 $0 cg03  }i: LDEI

i{      ir,r        $f2 $0 cg08  }i: LDEPD

i{      ir,r        $f3 $0 cg08  }i: LDEPI

i{      r,r         $c4 $0 cg25
        r,ir        $c5 $0 cg25
        r,im        $c6 $0 cg57
        r,iml       $c6 $0 cg57  }i: LDW

i{      r,r         $84 $0 cg25
        r,ir        $85 $0 cg25
        r,im        $86 $0 cg25  }i: MULT

i{      no-opr       $f $3 cg00  }i: NEXT

i{      no-opr      $ff $3 cg00  }i: NOP

i{      r,r         $44 $0 cg26
        r,ir        $45 $0 cg26
        r,im        $46 $0 cg22  }i: OR

i{      r_          $50 $0 cg09
        ir_         $51 $0 cg09  }i: POP

i{      r,ir        $92 $0 cg25  }i: POPUD

i{      r,ir        $93 $0 cg25  }i: POPUI

i{      r_          $70 $0 cg11
        ir_         $71 $0 cg11  }i: PUSH

i{      ir,r        $82 $0 cg22  }i: PUSHUD

i{      ir,r        $83 $0 cg22  }i: PUSHUI

i{      no-opr      $cf $3 cg00  }i: RCF

i{      r_          $d5 $0 cg09
        im_         $d5 $0 cg09  }i: RDR

i{      no-opr      $af $3 cg00  }i: RET

i{      r_          $90 $0 cg09
        ir_         $91 $0 cg09  }i: RL

i{      r_          $10 $0 cg09
        ir_         $11 $0 cg09  }i: RLC

i{      r_          $e0 $0 cg09
        ir_         $e1 $0 cg09  }i: ROR

i{      r_          $c0 $0 cg09
        ir_         $c1 $0 cg09  }i: RRC

i{      no-opr      $4f $3 cg00  }i: SB0

i{      no-opr      $5f $3 cg00  }i: SB1

i{      r,r         $34 $0 cg26
        r,ir        $35 $0 cg26
        r,im        $36 $0 cg22  }i: SBC

i{      no-opr      $df $3 cg00  }i: SCF

i{      im_         $e6 $0 cg24  }i: SPG

i{      r_          $d0 $0 cg09
        ir_         $d1 $0 cg09  }i: SRA

i{      im_         $31 $0 cg12  }i: SRP

i{      im_         $31 $0 cg13  }i: SRP0

i{      im_         $31 $0 cg14  }i: SRP1

i{      no-opr      $7f $3 cg00  }i: STOP

i{      r,r         $24 $0 cg26
        r,ir        $25 $0 cg26
        r,im        $26 $0 cg22  }i: SUB

i{      r_          $f0 $0 cg09
        ir_         $f1 $0 cg09  }i: SWAP

i{      r,r         $64 $0 cg26
        r,ir        $65 $0 cg26
        r,im        $66 $0 cg22  }i: TCM

i{      r,r         $74 $0 cg26
        r,ir        $75 $0 cg26
        r,im        $76 $0 cg22  }i: TM

i{      no-opr      $3f $3 cg00  }i: WFI

i{      r,r         $b4 $0 cg26
        r,ir        $b5 $0 cg26
        r,im        $b6 $0 cg22  }i: XOR

\ system instruction macros

i{      no-opr      $4f $1 cg58  }i: BNOP

i{      no-opr       $c $2 cg59  }i: EX1

i{      no-opr      $8d $2 cg60  }i: EX2

i{      no-opr      $30 $0 cg61  }i: JP@RR0

i{      no-opr      $ff $1 cg62  }i: NNOP

i{      no-opr      $ff $3 cg63  }i: NOOP

}                  ÉÍÍÍÍÍÍÍÍÍÍ»
                   º operands º
                   ÈÍÍÍÍÍÍÍÍÍÍ¼
{

I: OPERAND ( -- )
        CREATE
         c,                         \ store actual operand value
         c,                         \ store register value
        DOES>
         >r ?nos                    \ see if there is a number on stack
         r@ c@ dup                  \ get the operand code
         >dst/src                   \ operand code to src or dst
         get-operand-type           \ store the actual operand
         r> 1+ c@                   \ get register value
         sp@ !> a-sm                \ store assembler stack mark
         ;

\ working register operands

$c0 _r operand  R0   $c1 _r operand  R1   $c2 _r operand  R2
$c3 _r operand  R3   $c4 _r operand  R4   $c5 _r operand  R5
$c6 _r operand  R6   $c7 _r operand  R7   $c8 _r operand  R8
$c9 _r operand  R9   $ca _r operand R10   $cb _r operand R11
$cc _r operand R12   $cd _r operand R13   $ce _r operand R14
$cf _r operand R15

\ working register pair operands

$c0 _r operand  RR0   $c1 _r operand  RR1   $c2 _r operand  RR2
$c3 _r operand  RR3   $c4 _r operand  RR4   $c5 _r operand  RR5
$c6 _r operand  RR6   $c7 _r operand  RR7   $c8 _r operand  RR8
$c9 _r operand  RR9   $ca _r operand RR10   $cb _r operand RR11
$cc _r operand RR12   $cd _r operand RR13   $ce _r operand RR14
$cf _r operand RR15

\ index register operands

$c0 _(r) operand  (R0)   $c1 _(r) operand  (R1)   $c2 _(r) operand  (R2)
$c3 _(r) operand  (R3)   $c4 _(r) operand  (R4)   $c5 _(r) operand  (R5)
$c6 _(r) operand  (R6)   $c7 _(r) operand  (R7)   $c8 _(r) operand  (R8)
$c9 _(r) operand  (R9)   $ca _(r) operand (R10)   $cb _(r) operand (R11)
$cc _(r) operand (R12)   $cd _(r) operand (R13)   $ce _(r) operand (R14)
$cf _(r) operand (R15)

\ index register pair operands

$c0 _(r) operand  (RR0)   $c1 _(r) operand  (RR1)   $c2 _(r) operand  (RR2)
$c3 _(r) operand  (RR3)   $c4 _(r) operand  (RR4)   $c5 _(r) operand  (RR5)
$c6 _(r) operand  (RR6)   $c7 _(r) operand  (RR7)   $c8 _(r) operand  (RR8)
$c9 _(r) operand  (RR9)   $ca _(r) operand (RR10)   $cb _(r) operand (RR11)
$cc _(r) operand (RR12)   $cd _(r) operand (RR13)   $ce _(r) operand (RR14)
$cf _(r) operand (RR15)

\ indirect working register operands

$c0 _ir operand  @R0   $c1 _ir operand  @R1   $c2 _ir operand  @R2
$c3 _ir operand  @R3   $c4 _ir operand  @R4   $c5 _ir operand  @R5
$c6 _ir operand  @R6   $c7 _ir operand  @R7   $c8 _ir operand  @R8
$c9 _ir operand  @R9   $ca _ir operand @R10   $cb _ir operand @R11
$cc _ir operand @R12   $cd _ir operand @R13   $ce _ir operand @R14
$cf _ir operand @R15

\ indirect working register pair operands

$c0 _ir operand  @RR0   $c1 _ir operand  @RR1   $c2 _ir operand  @RR2
$c3 _ir operand  @RR3   $c4 _ir operand  @RR4   $c5 _ir operand  @RR5
$c6 _ir operand  @RR6   $c7 _ir operand  @RR7   $c8 _ir operand  @RR8
$c9 _ir operand  @RR9   $ca _ir operand @RR10   $cb _ir operand @RR11
$cc _ir operand @RR12   $cd _ir operand @RR13   $ce _ir operand @RR14
$cf _ir operand @RR15

\ condition code operands

$00 _cc operand F     $06 _cc operand Z     $07 _cc operand C
$08 _cc operand T     $0F _cc operand NC    $02 _cc operand LE
$09 _cc operand GE    $0E _cc operand NE    $0F _cc operand UGE
$0B _cc operand UGT   $05 _cc operand MI    $0D _cc operand PL
$03 _cc operand ULE   $07 _cc operand ULT   $0C _cc operand NOV
$06 _cc operand EQ    $01 _cc operand LT    $0A _cc operand GT
$04 _cc operand OV    $0E _cc operand NZ

I: #_ ( -- <n> ) \ set attribute of number to immediate
        _im                        \ immediate attribute
        ['] _r is 8-bit ;          \ reset attribute to register

: # ( [n] -- [n] ) \ expect an immediate
        ?nos                       \ see if there is a number on stack
        ['] #_   is  8-bit         \ set  8-bit number to an 8 bit immediate
        ['] _iml is 16-bit ;       \ set 16-bit number to a 16 bit immediate

: R ( -- ) \ expect a register
        ?nos                       \ see if there is a number on stack
        ['] _r is 8-bit ;          \ set 8-bit number to an indirect reg

\ ' r alias rr

: RR ( -- ) \ either expect a register or start a rotate right instruction
        ?got-inst 0=               \ if we don't have an instruction,
                                   \ then treat as an error condition
        if      0 " Use ROR for rotate right" "errmsg
        then    R ;

I: WR-8-BIT ( <r#> -- <wr#> <n> )  \ set attribute of number to register
        $c0 +                      \ change reg num into work reg num
        _r                         \ register attribute
        ['] _r is 8-bit ;          \ reset attribute to register

: WR ( -- ) \ expect a working register in range 0 to 15
        ?nos                       \ see if there is a number on stack
        ['] wr-8-bit is 8-bit ;    \ set 8-bit number to an indirect reg

' wr alias wrr

I: @WR-8-BIT ( <r#> -- <wr#> <n> ) \ set attribute of number to indrect reg
        $c0 +                      \ change reg num into work reg num
        _ir                        \ indirect register attribute
        ['] _r is 8-bit ;          \ reset attribute to register

: @WR ( -- ) \ expect an indirect register in range 0 to 15
        ?nos                       \ see if there is a number on stack
        ['] @wr-8-bit is 8-bit ;    \ set 8-bit number to an indirect reg

' @wr alias @wrr

I: @R-8-BIT ( -- <n> ) \ set attribute of number to indirect register
        _ir                        \ indirect register attribute
        ['] _r is 8-bit ;          \ reset attribute to register

: @R ( -- ) \ expect an indirect register
        ?nos                       \ see if there is a number on stack
        ['] @r-8-bit is 8-bit ;    \ set 8-bit number to an indirect reg

' @r alias @rr

}                     ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»
                      º SAM8 directives º
                      ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼
{

HEADERLESS

false value ?TRANSLATE \ true if the line is to be translated

false value ?TRANS-ASMBSAM \ true for translation of asmbsam assembler code

defer DO-ASMBSAM

defer DON'T-DO-ASMBSAM

HEADERS

defined to-screen nip forth 0= asms8
#if

HOST DEFINITIONS ALSO

#else
\ : [forth] ;
#then

: .TRANSLATE ( -- )
        setasms8 setassem
        [FORTH]
        true !> ?translate ;

' .translate alias .trans
' .translate alias .transon

: .NO-TRANSLATE ( -- )
        [FORTH]
        false !> ?translate ;

' .no-translate alias .notrans
' .no-translate alias .transoff

: .ASMBSAM ( -- ) \ translate asmbsam assembley language
        [FORTH]
        true !> ?trans-asmbsam
        do-asmbsam ;

: .NO-ASMBSAM ( -- ) \ don't translate asmbsam assembley language
        [FORTH]
        false !> ?trans-asmbsam
        don't-do-asmbsam ;

\ 12/09/91 14:35:54.85 tjz
\ : CHIP ( -- ) \ simulate ASMBSAM chip directive
\         bl word drop ; \ ignore: SS8.MDF

only forth definitions also

decimal

warning on       \ re-enable the redefinition warning flag

