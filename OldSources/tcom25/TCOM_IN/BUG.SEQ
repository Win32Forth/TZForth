\\ DBG.SEQ          A CODE debugger for F-PC        by Tom Zimmer
.options /opt /noinit /lib+ /nostack

History

 01/26/92 21:02 tjz
        Added checking for ['], to keep the user from forgetting to nest
        into TT[']. Now BUG automatically puts a breakpoint beyond the
        following word that is being looked up if the user presses
        ENTER to simply execute TT['].


{

         handle file-name
     0    value obj-seg
     0    value sym-seg
     0    value cptr
     0    value #inst-bytes
     0    value #sym-records
     0    value ignore-library-code
     0    value sptop
     0    value rptop
 $FFFF constant maxobj
      2variable atsave
     0    value vmodesave
 false    value ?nofil
 false    value ?nosym
 false    value ?noinx
  true    value ?nobin
 false    value ?warned_no_file


: d-t@          ( a1 -- n1 )
                obj-seg swap @L flip ;

: d-tc@         ( a1 -- c1 )
                obj-seg swap c@L ;

: d-tc!         ( c1 a1 -- )
                obj-seg swap c!L ;

: 0.r           ( n1 -- )
                0 .r ;

: ?shiftkey     ( --- f1 ) 0 $417 c@l $03 and 0<> ;

\ some junk symbols needed to load disassembler

defer d-datac@

: ls-abort abort ;
: screen-output  ;
: help-them      ;

\ ********************************************************************
\                               SYMBOL FILE
\ ********************************************************************

0 value SYM-REC-PTR

$FF0 constant SYM-BUF-PAR       \ paragraphs to allot
                                \ WARNING: sym-buf-par should not be 64k/16!
                                \          not greater than: 65520/16
0 value SYM-SEG

sym-buf-par 16 * constant SYM-BUF-LEN
                                \ bytes in the buffer

48 constant SYM-BYTES/REC       \ bytes per symbol record

sym-buf-len 0 sym-bytes/rec um/mod nip constant SYM-RECS/BUF
                                \ records per buffer

sym-recs/buf sym-bytes/rec * constant SYM-BYTES/BUF
                                \ rounded bytes in the buffer

: ALLOC-SYM-MEMORY ( -- )
        sym-buf-par alloc 8 = abort" No memory for the symbol file"
        nip !> sym-seg ;                \ thanks for the memory

handle SYM-FILE-HANDLE

: CLOSE-SYM-FILE ( -- )
        sym-file-handle hclose drop ;

: OPEN-SYM-FILE ( -- f1 )       \ f1=true if opened ok
        file-name  sym-file-handle $>handle
        " SYM" ">$ sym-file-handle $>ext        \ get the file name
        sym-file-handle hopen 0= ;              \ leave if no syms available

: SYM-NAME>  ( -- <adr of symbol name in symbol segment> )
        sym-rec-ptr ;

: SYM-TYPE> ( -- <type of symbol> )
        sym-seg sym-rec-ptr 32 + c@l ;

: SYM-RES-ADR> ( -- <address of symbol> )
        sym-seg sym-rec-ptr 33 + @l ;

: SYM-IVAL> ( -- <initial value of symbol> )
        sym-seg sym-rec-ptr 35 + @l ;

: SYM-FILE#> ( -- <file code> )
        sym-seg sym-rec-ptr 37 + c@l ;

: SYM-FILE-OFF-HI> ( -- <offset of symbol> )
        sym-seg sym-rec-ptr 38 + c@l
        sym-seg sym-rec-ptr 39 + c@l
        $100 * + ;

: SYM-FILE-OFF-LOW> ( -- <offset of symbol> )
        sym-seg sym-rec-ptr 40 + c@l
        sym-seg sym-rec-ptr 41 + c@l
        $100 * + ;

: SYM-SIZE> ( -- <size of symbol> )
        sym-seg sym-rec-ptr 42 + @l ;

: READ-SYM-FILE ( -- )
        0 sym-bytes/buf sym-file-handle sym-seg exhread
        0 sym-bytes/rec um/mod nip 1 max !> #sym-records ;

0    value last-func-adr
6 constant FUNCTION-SYM-TYPE

: LAST_FUNC_SET ( -- )          \ set program entry point symbol
                0 #sym-records 1-
                do      i sym-bytes/rec * !> sym-rec-ptr
                        sym-type> function-sym-type =
                        sym-file#> 0> and
                        if      sym-res-adr> !> last-func-adr
                                leave
                        then
            -1 +loop    ;

: GET-SYM-FILE  ( -- )          \ read the symbol file if available
                off> ?nosym
                off> last-func-adr
                open-sym-file
                if      read-sym-file
                        close-sym-file
                        last_func_set
                else    1 !> #sym-records
                        sym-seg 0 48 0 lfill
                        on> ?nosym
                then    ;

0 value SYM-SEG-ADR

code A-FUNCTION-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
        push    es
        mov     ax, &> sym-seg
        mov     es, ax
        mov     ax, &> #sym-records
        mov     cx, # sym-bytes/rec
        mul     cx
        mov     dx, # function-sym-type
        xor     di, di
   1 $: cmp     bx, es: 33 [di]
        jne     2 $
        cmp     dl, es: 32 [di]
        jne     2 $
        mov     &> sym-rec-ptr di
        pop     es
        mov     bx, # -1
        ret
   2 $: add     di, cx
        cmp     ax, di
        jne     1 $
        pop     es
        xor     bx, bx
        ret
end-code

FALSE #if
      long_branch
: A-FUNCTION-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
        0 swap                          \ assume false
        #sym-records sym-bytes/rec * 0
        do dup
           sym-seg 33 i + @l =          \ get symbol resolve adr
           IF sym-seg 32 i + c@l           \ get symbol type
              function-sym-type =
              IF swap 0= swap
                 i !> sym-rec-ptr
                 leave
              THEN
           THEN sym-bytes/rec
        +loop drop ;
      short_branch
#then

1 constant CONSTANT-SYM-TYPE
2 constant 2CONSTANT-SYM-TYPE
4 constant VARIABLE-SYM-TYPE
5 constant VALUE-SYM-TYPE
7 constant DEFER-SYM-TYPE
8 constant TABLE-SYM-TYPE

code A-DATA-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
        push    es
        mov     ax, &> sym-seg
        mov     es, ax
        mov     ax, &> #sym-records
        mov     cx, # sym-bytes/rec
        mul     cx
        xor     di, di
   1 $: cmp     bx, es: 33 [di]
        jne     2 $
        mov     dl, es: 32 [di]
        cmp     dl, # constant-sym-type
        je      3 $
        cmp     dl, # variable-sym-type
        je      3 $
        cmp     dl, # value-sym-type
        je      3 $
        cmp     dl, # table-sym-type
        je      3 $
        cmp     dl, # defer-sym-type
        je      3 $
   2 $: add     di, cx
        cmp     ax, di
        jne     1 $
        pop     es
        xor     bx, bx
        ret
   3 $: mov     &> sym-rec-ptr di
        pop     es
        mov     bx, # -1
        ret
end-code

FALSE #if
      long_branch
: A-DATA-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
        0 swap                                  \ assume false
        #sym-records sym-bytes/rec * 0
        do dup
           sym-seg 33 i + @l =                  \ get symbol resolve adr
           IF sym-seg 32 i + c@l                \ get symbol type
              dup  constant-sym-type =          \ a constant in sym tab ?
              over variable-sym-type = or       \ a variable in sym tab ?
              over    value-sym-type = or       \ a value    in sym tab ?
              over    table-sym-type = or       \ a table    in sym tab ?
              swap    defer-sym-type = or       \ a defer    in sym tab ?
              IF swap 0= swap
                 i !> sym-rec-ptr
                 leave
              THEN
           THEN sym-bytes/rec
        +loop drop ;
      short_branch
#then

: .function-symbol  ( -- )
                sym-seg sym-name> countl 31 min 1 max here placel
                here count 9 min type ;

                \ find string a1 in symbol table
: a-function?   ( a1 -- targaddr true | a1 false )
                sym-seg save!> sseg
                0 swap                                  \ assume a failure
                #sym-records sym-bytes/rec * 0
                do      dup i over c@ 1+ caps-comp 0=   \ name matches
                        sym-seg 32 i + c@l              \ and
                        function-sym-type = and         \ sym type=function
                        if      drop 0=
                                sym-seg 33 i + @L
                                i !> sym-rec-ptr
                                leave
                        then    sym-bytes/rec
                +loop   swap
                restore> sseg ;

                \ find string a1 in symbol table
: a-data?       ( a1 -- targaddr true | a1 false )
                sym-seg save!> sseg
                0 swap                                  \ assume a failure
                #sym-records sym-bytes/rec * 0
                do      dup i over c@ 1+ caps-comp 0=   \ name matches
 [long]                 if        sym-seg 32 i + c@l      \ and DATA type symbol
                                dup  VARIABLE-SYM-TYPE  =
                                over VALUE-SYM-TYPE     = or
                                over DEFER-SYM-TYPE     = or
                                swap TABLE-SYM-TYPE     = or
                                if      drop 0=
                                        sym-seg 33 i + @L
                                        i !> sym-rec-ptr
                                        leave
                                then
                        then    sym-bytes/rec
                +loop   swap
                restore> sseg ;

\ **************************************************************************
\                       Index File
\ **************************************************************************

2variable inx-total
2variable inx-rec-off
  0 value #INX-RECORDS          \ the number of index records

0 value INX-REC-LOOKAHEAD?      \ true if the index record has been read

$1800 value INX-BUF-PAR         \ paragraphs to allot

0 value INX-SEG

6 constant INX-BYTES/REC        \ bytes per record

inx-buf-par 16 um* inx-bytes/rec um/mod nip $FFFC and value INX-RECS/BUF
                                \ records per buffer

handle INX-FILE-HANDLE

code  +inx-rec-off  ( n1 -- )       \ add a single number to double INX-REC-OFF
                mov ax, bx
                cwd
                add inx-rec-off 2+ ax
                adc inx-rec-off dx
                load_bx
                ret     end-code

code inx-rec-segoff ( -- seg off )
                save_bx
                mov ax, inx-rec-off
                mov dx, inx-rec-off 2+
                sub bx, bx
                shr ax, # 1     rcr dx, # 1     rcr bl, # 1
                shr ax, # 1     rcr dx, # 1     rcr bl, # 1
                shr ax, # 1     rcr dx, # 1     rcr bl, # 1
                shr ax, # 1     rcr dx, # 1     rcr bl, # 1
                add dx, &> inx-seg
                dec si
                dec si
                mov 0 [si], dx          \ move INX-SEG to stack
                shr bx, # 1
                shr bx, # 1
                shr bx, # 1
                shr bx, # 1
                ret             end-code

: INX-ADR>      ( -- <index address> )
                inx-rec-segoff @l ;

: INX-TYPE>     ( -- <index type> )
                inx-rec-segoff 2+ c@l
                2/ 2/ 2/ 2/ $f and ;

: INX-SRC-HI>   ( -- <high byte of index source pointer> )
                inx-rec-segoff 2+ c@l
                $f and ;

: INX-SRC-LOW>  ( -- <low word of index source pointer> )
                inx-rec-segoff 3 + @l ;

: %INX-FILE#>   ( -- <file code> )
                inx-rec-segoff 5 + c@l ;

: +INX          ( n1 -- )       \ bump the index record pointer forwrd or back
                inx-bytes/rec * +inx-rec-off
                inx-rec-off 2@ inx-bytes/rec um/mod nip inx-recs/buf =
                if      0.0 inx-rec-off 2!
                then    ;

: %+INST        ( n1 -- )
                >r
                begin   r@ +inx
                        inx-type> $07 and $02 $03 between
                        inx-rec-off 2@ d0= or
                until   r>drop ;

: READ-INX-FILE ( -- )
                0.0 inx-total 2!
                inx-recs/buf 0
                do      i inx-bytes/rec um*
                        2dup inx-file-handle movepointer
                        16 um/mod >r                       \ offset
                        inx-recs/buf 4 / inx-bytes/rec *   \ length
                        inx-file-handle                    \ handle
                        r>                                 \ seg(relative)
                        inx-seg +                          \ plus base seg
                        exhread dup                        \ read file
                        0 inx-total 2@ d+ inx-total 2!     \ adjust total
                        0= ?leave                          \ leave at filend
                        inx-recs/buf 4 /                   \ next group
               +loop
                inx-total 2@ inx-bytes/rec um/mod nip 1 umax !> #inx-records
                0.0 inx-file-handle movepointer ;

: ALLOC-INX-MEMORY ( -- )       \ allocate index memory, file must already
                                \ have been opened, so we can check length
                inx-seg ?dup                            \ if allocated,
                if      dealloc drop                    \ discard it
                        off> inx-seg                    \ reset the pointer
                then
                inx-file-handle endfile inx-bytes/rec 10 * 0 d+
                                                        \ bytes in index file
                2dup inx-bytes/rec um/mod nip !> inx-recs/buf
                                                        \ records in index
                16 um/mod nip 1+ !> inx-buf-par         \ paragraphs for index
                0.0 inx-file-handle movepointer         \ back to beginning
                inx-buf-par alloc 8 =                   \ allocate the memory
                if      cr abort" No memory for the index file"
                THEN    nip !> inx-seg ;                \ index file memory

: CLOSE-INX-FILE ( -- )
        inx-file-handle hclose drop ;

: OPEN-INX-FILE ( -- f1 )       \ open index file, f1=true if opened ok
        off> #inx-records
        file-name  inx-file-handle $>handle
        " inx" ">$ inx-file-handle $>ext        \ get the file name
        inx-file-handle hopen 0= ;

: GET-INX-FILE  ( -- )          \ read the index for our debugging file
                open-inx-file
                if      alloc-inx-memory        \ allocate index  memory
                        read-inx-file           \ read into first buffer
                        close-inx-file
                else    on> ?noinx
                then    0.0 inx-rec-off 2! ;

code a-inx?     ( a1 -- f1 )
                mov cx, &> #inx-records \ count of records to search
                push ds                 \ save DS for later restoral
                jcxz 4 $                \ if count is zero, leave
                mov ds, &> inx-seg      \ we are scanning through the index
                sub di, di              \ clear, to start of index array
        0 $:    cmp bx, 0 [di]          \ does address match index?
                je 1 $                  \ YES, goto type verification
        3 $:    add di, # $06           \ NO bump to bext record
                jc 5 $
                dec cx                  \ reduce count by one
                jne 0 $                 \ if not down to zero, try again
        4 $:    mov bx, # false         \ no match found, so leave
                pop ds                  \ restore DS
                ret                     \ return from routine
        5 $:    mov ax, ds              \ bump DS to tne next 64k segment
                add ax, # $1000
                mov ds, ax
                dec cx                  \ reduce count by one
                jne 0 $                 \ if not down to zero, try again
                mov bx, # false         \ no match found, so leave
                pop ds                  \ restore DS
                ret                     \ return from routine
        1 $:    mov al, 2 [di]          \ get the byte containing the type
                and al, # $70           \ mask to three bits of upper nibble
                cmp al, # $20           \ type 2 or 10
                je 2 $                  \ if it is, then exit with true
                cmp al, # $30           \ type 3 or 11
                jne 3 $                 \ go loop some more
        2 $:    mov dx, ds              \ get DS: into DX
                pop ds                  \ restore DS
                sub dx, &> inx-seg      \ subtract array base segment
                sub ax, ax              \ AX is the high word of double #
                shl dx, # 1     rcl ax, # 1
                shl dx, # 1     rcl ax, # 1
                shl dx, # 1     rcl ax, # 1
                shl dx, # 1     rcl ax, # 1
                add dx, di      adc ax, # 0
                mov inx-rec-off ax      \ set found index offset high
                mov inx-rec-off 2+ dx   \ set found index offset low
                mov bx, # true          \ leave with true flag
                ret     end-code

\ **************************************************************************
\ Load the disassembler, we need it in the debugger
\ **************************************************************************

fload samples\da86.seq

0 value ?logging

: ptype         ( a1 n1 -- )
                bounds
                ?do     i c@ pemit
                loop    ;

: inst          ( -- )
                cptr d-tc@ dis1
                instr_buf count 43 >type        \ display instruction
                #inst-bytes +!> cptr ;          \ point CPTR to next inst

\ **************************************************************************
\ variables to hold all needed registers
\ **************************************************************************

$00F2 constant execcnt
$00F4 constant forthret
$00F6 constant forthds
$00F8 constant int20save
$00FC constant int21save

variable debugip
variable debugcs
variable debugflags
variable debugax
variable debugbx        variable forthbx
variable debugcx
variable debugdx
variable debugbp        variable forthbp
variable debugsi        variable forthsi
variable debugdi        variable forthdi
variable debuges        variable forthes
variable debugss        variable forthss
variable debugsp        variable forthsp
variable debugds        \ variable forthds

\ **************************************************************************
\ words to allow setting the debugging registers
\ **************************************************************************

: reg!          ( a1 | <name> -- )      \ defining word to make register
                                        \ assignment words
                create , does> @ ! ;

debugcs    reg! =cs
debugip    reg! =ip
debugss    reg! =ss
debugsp    reg! =sp
debugds    reg! =ds
debuges    reg! =es
debugax    reg! =ax
debugbx    reg! =bx
debugcx    reg! =cx
debugdx    reg! =dx
debugsi    reg! =si
debugdi    reg! =di
debugbp    reg! =bp
debugflags reg! =fl

: reg@          ( a1 | <name> -- )      \ defining word to make register
                                        \ fetch words
                create , does> @ @ ;

debugcs reg@ cs-@
debugip reg@ ip-@
debugss reg@ ss-@
debugsp reg@ sp-@
debugds reg@ ds-@
debuges reg@ es-@
debugax reg@ ax-@
debugbx reg@ bx-@
debugcx reg@ cx-@
debugdx reg@ dx-@
debugsi reg@ si-@
debugdi reg@ di-@
debugbp reg@ bp-@

\ **************************************************************************
\ Some handy debugging utilities
\ **************************************************************************

            2variable ipinx
0               value btop
12              value dbtop
dbtop           value intop
intop 2/ 1-     value lstop
rows 2 -        value dbbot
0               value dbleft
59              value dbright
: dblines       dbbot intop 3 + - ;
0               value dboff
0               value dbto
0               value dbsave
0               value keysave
0               value spsave
true            value ?instructions
true            value ?registers
0               value to_point

: %>red         ( -- )    red >bg  white >fg ;
: %>blue        ( -- )   blue >bg ltgray >fg ;
: %>cyan        ( -- )   cyan >bg  black >fg ;
: %>green       ( -- )  green >bg  black >fg ;
: %>bblue       ( -- )   blue >bg  white >fg ;
: %>bcyan       ( -- )   cyan >bg  white >fg ;
: %>dkgray      ( -- ) dkgray >bg ltgray >fg ;

defer >red
defer >blue
defer >cyan
defer >green
defer >bblue
defer >bcyan
defer >dkgray

: color_set     ( -- )
                ['] %>red    is >red
                ['] %>blue   is >blue
                ['] %>cyan   is >cyan
                ['] %>green  is >green
                ['] %>bblue  is >bblue
                ['] %>bcyan  is >bcyan
                ['] %>dkgray is >dkgray ;

: lcd_set     ( -- )
                ['] >rev     is >red
                ['] >rev     is >blue
                ['] >bold    is >cyan
                ['] >bold    is >green
                ['] >rev     is >bblue
                ['] >ul      is >bcyan
                ['] >ul      is >dkgray ;

: h.4           ( n1 -- )       \ display n1 in four digit hex
                $10 save!> base
                0 <# # # # # #> space type space
                restore> base ;

: dbeeol        ( -- )
                58 sp>col ;

: .bytes        ( a1 n1 -- )
                0max bounds
                ?do     i d-tc@ 0 <# # # #> type space
                loop    ;

: "stack        ( a1 n1 -- )    \ display stack condition, wait for key
                2>r
                50 btop at >blue
                depth dup 0<
                if      >red
                then    ."  Stack: " . 2r> type space >norm key drop ;

: .stack        ( -- )          \ display stack condition
                depth 0= ?exit
                1 btop 23 + at
                >red ."  Stack: " depth 4 .r 0>
                if      dup 5 .r
                then    space >norm ;

\ **************************************************************************
\ Display current instruction followed by data stack
\ **************************************************************************

: #inst_byte@   ( n1 -- n2 )    \ return the offset n1 byte
                cs-@ swap ip-@ + c@L ;

: #inst_word@   ( n1 -- n2 )    \ return the offset n1 word
                cs-@ swap ip-@ + @L ;

: inst_byte@    ( -- n1 )       \ return the current instruction byte
                cs-@ ip-@ c@L ;

: inst_word@    ( -- n1 )       \ return the current isntruction word
                cs-@ ip-@ @L ;

0 value ?stkon
0 value ipprev
0 value ipprev2
0 value ipaddr
0 value ipnext
2variable curinst_src

: prh.4         ( n1 -- )
                0 <# # # # # #> ptype ;

: prcr          ( -- )
                $0D pemit $0A pemit ;

: pspaces       ( n1 -- )
                0
                ?do     bl pemit
                loop    ;

: prinst        ( -- )
                cptr d-tc@ dis1
                ?logging
        [long]  if      savecursor
                        $10 save!> base
                        ipaddr prh.4 bl pemit
                        restore> base
                        instr_buf count ptype
                        prcr 24 pspaces                 \ some spaces
                        "  CS:" ptype cs-@ prh.4
                        "  IP:" ptype ip-@ prh.4
                        "  DS:" ptype ds-@ prh.4
                        "  SI:" ptype si-@ prh.4
                        "  ES:" ptype es-@ prh.4
                        "  DI:" ptype di-@ prh.4
                        "  SS:" ptype ss-@ prh.4
                        prcr 24 pspaces                 \ some spaces
                        "  SP:" ptype sp-@ prh.4
                        "  BP:" ptype bp-@ prh.4
                        "  AX:" ptype ax-@ prh.4
                        "  BX:" ptype bx-@ prh.4
                        "  CX:" ptype cx-@ prh.4
                        "  DX:" ptype dx-@ prh.4
                        "  FL:" ptype debugflags @ prh.4
                        prcr
                        restcursor
                then
                instr_buf count 43 >type        \ display instruction
                #inst-bytes +!> cptr ;          \ point CPTR to next inst

: %inst         ( -- )          \ display one instruction
                ipaddr dup !> cptr !> ipprev
                cptr !> dbto
                cptr d-tc@ dis1
                #inst-bytes +!> cptr            \ point CPTR to next inst
                cptr !> ipnext ;

: .inst         ( -- )          \ display one instruction
                save> base hex
                ." Ý" >dkgray
                ipaddr a-function-symbol?
                if      .function-symbol
                then    11 sp>col
                ipaddr dup !> cptr !> ipprev
                ip-@ ipaddr =
                if      >rev
                        off> dbto
                else    dboff 0=
                        if      >green
                                cptr !> dbto
                        else    >norm
                        then
                then
                ipaddr h.4 prinst
                sym-file-save 0<
                if      44 sp>col
                else    42 sp>col
                        save> attrib
                        sym-file-save
                        if      >blue   ." S"
                        else    >red    ." L"
                        then
                        restore> attrib space
                then
                ?stkon 0=
                if      ipaddr cptr over - 5 min .bytes dbeeol
                then    >norm
                cptr !> ipnext
                restore> base ;

: ?same_src     ( -- f1 )       \ check to see if same source pointer
                1 %+inst
                inx-src-low> inx-src-hi> curinst_src 2@ d= ;

: .ninst        ( n1 -- )
                save> base hex
                ?same_src
                if      ." Ý" >dkgray
                else    ." ³"
                then
                cptr a-function-symbol?
                if      .function-symbol
                then    11 sp>col
                ip-@ cptr =
                if      drop >rev
                        cptr !> dbto
                else    1+ dboff =
                        if      cptr !> dbto >green
                        then
                then
                cptr dup>r h.4 inst 44 sp>col
                r>
                ?stkon 0=
                if      cptr over - 5 min .bytes dbeeol
                else    drop
                then    >norm
                restore> base ;

: .pinst        ( -- )
                save> base hex
                ." ³"
                ipprev 0= #inx-records 0> and
                if      inx-rec-off 2@ 2>r
                        -1 %+inst
                        inx-adr>
                        2r> inx-rec-off 2!
                else    ipprev
                then    dup>r !> cptr
                cptr    a-function-symbol?
                if      .function-symbol
                then    11 sp>col
                ip-@ cptr <>
                ip-@ ipaddr <> or
                if      ip-@ cptr =
                        if      >rev
                                cptr !> dbto
                        then    cptr h.4 inst
                then    44 sp>col r>
                ?stkon 0=
                if      cptr over - 5 min .bytes dbeeol
                else    drop
                then    >norm
                restore> base ;

0 value ?VGA
0 value ?EGA

: bugbox        ( n1 n2 n3 n4 -- )
                ?vga if vrows@ else 25 then
                save!> rows box restore> rows ;

: bugbox&fill   ( n1 n2 n3 n4 -- )
                ?vga if vrows@ else 25 then
                save!> rows box&fill restore> rows ;

\ **************************************************************************
\ Display the processor registers
\ **************************************************************************

: .regs         ( -- )
                ?registers 0= ?exit
                dbright 1+ dbtop 79 dbbot bugbox
                ."  CS" cs-@ h.4 ."  IP" ip-@ h.4 bcr
                ."  DS" ds-@ h.4 ."  SI" si-@ h.4 bcr
                ."  ES" es-@ h.4 ."  DI" di-@ h.4 bcr
                ."  SS" ss-@ h.4 ."  SP" sp-@ h.4 bcr
                        ."           BP" bp-@ h.4 bcr
                ."  AX" ax-@ h.4 ."  FL" debugflags @ h.4 bcr
                ."  BX" bx-@ h.4 9 spaces         bcr
                ."  CX" cx-@ h.4 ."  DX" dx-@ h.4 bcr
                ."  ----ODITsz-a-p-c"             bcr
                2 save!> base
                space
                debugflags @ 0 <# 16 0 do # loop #> type
                restore> base
                dbright 2+ dbtop at >blue
                ."  Registers alt-R " >norm ;

: .dstack_color ( n1 -- )
                si-@ + 4 + ds-@ sptop @L u>
                if      si-@ ds-@ sptop @L <=
                        if      >green
                        else    >red
                        then
                then    ;

: .rstack_color ( n1 -- )
                sp-@ + 2+ ds-@ rptop @L u>
                if      sp-@ ds-@ rptop @L <=
                        if      >green
                        else    >red
                        then
                then    ;

: .stacks       ( -- )          \ display debuggers data & return stack
                ?stkon 0= ?exit
                dbright 14 - intop dbright dbbot bugbox
                >blue ."  Data   val " >norm bcr
                space >bcyan ."  BX " >norm space
                si-@ ds-@ sptop @L =
                if      >green
                else    si-@ ds-@ sptop @L u>
                        if      >red
                        then
                then    bx-@ h.4 >norm space bcr
                ?ega if 06 else 08 then 0
                do           si-@ i +    h.4
                        i .dstack_color
                        ds-@ si-@ i + @L h.4 >norm space bcr
             2 +loop
                >blue ."  Return val " >norm bcr
                ?ega if 04 else 06 then 0
                do      sp-@ i +    h.4
                        i .rstack_color
                        ss-@ sp-@ i + @L h.4 >norm space bcr
             2 +loop
                dbright 13 - intop at >blue
                ."  STACK alt-S " >norm ;

\ **********************************************************************
\       Push a new value to targets Data stack, or pop a value off
\ **********************************************************************

: push_stack_value      ( -- )
                cursor-on
                save> base hex
                botat ." {Push value onto Stack} [HEX_value]: "
                query bl word ?uppercase number? nip
                if      si-@ 2- =si             \ bump stack down
                        bx-@ ds-@ si-@ !L       \ move bx to stack
                        =bx                     \ move value into bx (top)
                else    drop
                then    restore> base ;

: pop_stack_value       ( -- )
                si-@ 2+ ds-@ sptop @L u>        \ if stack is already empty
                if      beep                    \ then just beep
                else    ds-@ si-@ @L =bx        \ move second to BX (top)
                        si-@ 2+ =si             \ bump stack up
                then    ;

\ **********************************************************************
\       Display the source file
\ **********************************************************************

2048 constant fil-max
  64 constant b/fil
      0 value fil-buf
      0 value #fil
       handle fil-handle

2048 constant src-max
      0 value src-buf
      0 value src-off
      0 value src-len
     -1 value cur-file#
      0 value to-file#
      0 value ?show_watch
      0 value ?to_source
       handle src-handle
     79 value srcright

: to->source    ( -- )
                ipaddr a-inx?
                if      on> ?to_source
                        %inx-file#> 1 max !> to-file#
                then    ;

: +INST         ( n1 -- )
                #inx-records
                if      %+inst
                        inx-adr> !> ipaddr
                        to->source
                else    0<
                        if      ipaddr 1-
                        else    ipnext
                        then    !> ipaddr
                then    ;

: get-fil-file  ( -- )
                off> ?nofil
                off> #fil
                file-name  fil-handle $>handle
                " FIL" ">$ fil-handle $>ext        \ get the file name
                fil-handle hopen 0=
                if      fil-buf fil-max fil-handle hread
                        0 b/fil um/mod nip 1 max !> #fil
                        fil-handle hclose drop
                else    on> ?nofil
                then    ;

: ?open-src-file ( -- f1 )      \ f1=true=opened ok
                false                           \ default to failed
                #fil 0= ?exit
                to-file# 0= ?exit
                to-file# #fil u> ?exit
                drop                            \ false flag is not needed
                to-file# dup>r cur-file# =
                if      true
[long]          else    src-handle hclose drop
                        r@ 1- b/fil * fil-buf + 64 2dup bl scan nip -
                        src-handle ">handle
                        src-handle hopen 0=
                        if      lendset         \ set the end of file stuff
                                r@ !> cur-file#
                                true
                        else    src-handle >pathend" src-handle place
                                src-handle count + off
                                src-handle hopen 0= dup
                                if      lendset \ set the end of file stuff
                                        r@ !> cur-file#
                                then
                        then
                then    r>drop ;

: -/string      ( a1 n1 n2 -- a2 n3 )
                over umin dup>r - swap r> - swap ;

: >type         ( a1 n1 n2 -- ) \ type string a1,n1 upto column n2
                #out @ - 0max umin type ;

fload dblist.seq                \ browse support for the debugger

: ?find_position ( -- f1 )      \ find source in index, f1=true=found
                0.0 inx-rec-off 2!
                false
                listblk listlo um* listoff 2- 0max 0 d+
                #inx-records 0
[long]          ?do     2dup
                        inx-src-low> inx-src-hi> d<
                        inx-type> 7 and dup 2 = swap 3 = or and
                        %inx-file#> cur-file# = and
                        if      rot drop true -rot
                                inx-adr> !> ipaddr
                                leave
                        then
                        inx-bytes/rec +inx-rec-off
                loop    2drop ;

: set_srcbox    ( -- )
                0        !> tx                  \ mark X for BCR
                btop     !> ty                  \ mark Y for BCR
                tx 1+ ty 1+ dup !> bline at
                                                \ position cursor
                srcright !> bx                  \ right side of box
                ?instructions
                if      intop 1-
                else    dbbot
                then    !> by ;                 \ bottom of box

: leeol         ( -- )          \ erase to end of line
                srcright #out @ - 1- 0max 0 ?do ." Ä" loop ;

: .srcbox       ( -- )
                0 btop srcright dbbot bugbox&fill ;

: .srcname      ( -- )
                25 btop at >blue ."  Source: "
                src-handle >pathend" dup>r type 13 r> - spaces >norm ;

: .program      ( -- )
                1 btop at >blue ."  Program: "
                file-name count '?' scan nip    \ if name has '?', then error
                if red >bg space then
                file-name >pathend" dup>r type 13 r> - spaces >norm ;

: show_src      ( -- )
                ?open-src-file
                if      ?to_source
                        if      moveto_source
                                off> ?to_source
                        then    dolist .srcname
                else
                then    srcright 8 - 0max btop at >blue
                ."  Alt-Z " >norm ;

: .source       ( -- )          \ show the source window
                key? ?exit              \ don't enter on type ahead
                #inx-records
                if      set_srcbox
                        show_src
                then    .program ;

\ **************************************************************************
\ This is the single step "receiver". It saves the debugging registers
\ and restores F-PC's registers then goes back to Forth.
\ **************************************************************************

label int1      ( -- )          \ preserve all registers
                push ds
                push ax
                mov ax, cs: forthds
                mov ds, ax
                pop debugax
                pop debugds
                pop debugip
                pop debugcs
                pop ax
                and ax, # $FEFF         \ clear TF flag bit
                mov debugflags ax
                mov debugbx bx  mov bx, forthbx
                mov debugcx cx
                mov debugdx dx
                mov debugbp bp  mov bp, forthbp
                mov debugsi si  mov si, forthsi
                mov debugdi di  mov di, forthdi
                mov debuges es  mov es, forthes
                mov debugss ss  mov ss, forthss
                mov debugsp sp  mov sp, forthsp
                mov ax, cs: forthret
                cld             \ 04/24/93 21:31 ak Needed in case direction
                                \ flag is set improperly
                jmp ax          end-code

\ **************************************************************************
\ This is the PROGRAM TERMINATE receiver. If an INT20 is encountered, then
\ drop back into the program
\ Also keeps track of how many EXEC commands are performed, to if a program
\ being debugged shells to dos, it won't incorrectly terminate the program
\ when DOS returns to the program being debugged with an EXIT.
\ **************************************************************************

         variable terminated    \ did program terminate?

label int20     ( -- )          \ preserve all registers
                pushf
                cmp cs: execcnt # 0 word        \ if the shell count<>0, doit
                je 0 $
                dec cs: execcnt word
                popf
                jmp far cs: [] int20save        \ jump to normal interrupt 20
        0 $:    popf
                push ds
                push ax
                mov ax, cs: forthds
                mov ds, ax
                pop debugax
                pop debugds
                pop debugip
                pop debugcs
                pop ax
                and ax, # $FEFF         \ clear TF flag bit
                mov debugflags ax
                mov debugbx bx  mov bx, forthbx
                mov debugcx cx
                mov debugdx dx
                mov debugbp bp  mov bp, forthbp
                mov debugsi si  mov si, forthsi
                mov debugdi di  mov di, forthdi
                mov debuges es  mov es, forthes
                mov debugss ss  mov ss, forthss
                mov debugsp sp  mov sp, forthsp
                mov terminated # -1 word     \ turn on terminated flag
                mov ax, cs: forthret
                cld             \ 04/24/93 21:31 ak Needed in case direction
                                \ flag is set improperly
                jmp ax          end-code

label int21     ( -- )          \ capture interrupt 21, and test for AX=00
                pushf
                cmp ah, # 0                     \ AH=0 terminate?
                je 0 $
                cmp ah, # $4C                   \ AH=$4C terminate
                je 0 $
                cmp ax, # $4B00                 \ load and execute
                jne 1 $                         \ if it is
                inc cs: execcnt word            \ bump shell count
                popf
                jmp far cs: [] int21save        \ jump to normal interrupt 21
        2 $:    dec cs: execcnt word
        1 $:    popf
                jmp far cs: [] int21save        \ jump to normal interrupt 21
        0 $:    cmp cs: execcnt # 0 word        \ if the shell count<>0,
                jne 2 $                         \ then branch to decr it
                popf                            \ else stop everything
                jmp int20       end-code

\ **************************************************************************
\ Routines to save, set & restore the number one & three interrupt vectors.
\ **************************************************************************

2variable int1save               \ a place to save the interrupt one vector
2variable int1Bsave
2variable int23save
2variable int24save


code save_int#  ( n1 -- )      \ save the current contents of interrupt one
                push es
                mov ax, # $3500
                or al, bl
                int $21
                mov int1save bx
                mov int1save 2+ es      \ save old vector
                pop es
                load_bx                 \ refill BX
                ret             end-code

code save_ints  ( -- ) \ save the current contents of interrupt 20 & 21
                push es
                push bx
                mov ax, # $3520                 \ terminate interrupt
                int $21
                mov cs: int20save bx
                mov cs: int20save 2+ es
                mov ax, # $3521                 \ DOS functions
                int $21
                mov cs: int21save bx            \ special, in CS not DS
                mov cs: int21save 2+ es
                mov ax, # $351B                 \ BIOS control break
                int $21
                mov int1Bsave bx
                mov int1Bsave 2+ es
                mov ax, # $3523                 \ DOS control break
                int $21
                mov int23save bx
                mov int23save 2+ es
                mov ax, # $3524                 \ critical error handler
                int $21
                mov int24save bx
                mov int24save 2+ es
                pop bx
                pop es
                ret             end-code

code set_int#   ( n1 -- )      \ set interrupt one to our interrupt handler
                push es
                push ds
                mov ax, cs
                mov ds, ax
                mov dx, # int1
                mov ax, # $2500
                or al, bl
                int $21
                pop ds
                pop es
                load_bx                 \ refill BX
                ret             end-code

code set_ints   ( -- )  \ set interrupt 20 & 21 to our interrupt handler
                push es
                push ds
                push bx
                mov ax, cs
                mov ds, ax
                mov dx, # int20
                mov ax, # $2520
                int $21
                mov ax, cs
                mov ds, ax
                mov dx, # int21
                mov ax, # $2521
                int $21
                pop bx
                pop ds
                pop es
                ret             end-code

code rest_int#  ( n1 -- )      \ restore the contents of interrupt one
                push ds
                mov dx, int1save
                mov ds, int1save 2+
                mov ax, # $2500
                or al, bl
                int $21
                pop ds
                load_bx                 \ refill BX
                ret             end-code

code rest_ints  ( -- )  \ restore out important interrupt contents
                push bx
                mov cx, ds
                mov dx, cs: int20save
                mov ds, cs: int20save 2+
                mov ax, # $2520                 \ terminate interrupt
                int $21
                mov ds, cx
                mov dx, cs: int21save           \ special, in CS, not DS
                mov ds, cs: int21save 2+
                mov ax, # $2521                 \ DOS functions
                int $21
                mov ds, cx
                mov dx, int1Bsave
                mov ds, int1Bsave 2+
                mov ax, # $251B                 \ BIOS control break
                int $21
                mov ds, cx
                mov dx, int23save
                mov ds, int23save 2+
                mov ax, # $2523                 \ DOS control break
                int $21
                mov ds, cx
                mov dx, int24save
                mov ds, int24save 2+
                mov ax, # $2524                 \ critical error
                int $21
                mov ds, cx
                pop bx
                ret             end-code

\ **************************************************************************
\ initiate one single instruction step. Swaps registers, sets up the
\ hardware stack with processor status, code segment, and instruction
\ pointer then does an IRET to return to do a single step. The TF flag
\ is set in the status register to make the processor immediately perform
\ an INT1 after a single instruction has been executed. Execution then
\ returns to INT1 above, and consequently back to Forth.
\ **************************************************************************

code one_step   ( -- )          \ single step through one instruction as
                                \ already setup in the debugging registers
                pop cs: forthret
                mov forthsp sp
                mov forthss ss
                mov forthbp bp
                mov forthsi si
                mov forthdi di
                mov forthbx bx
                mov cs: forthds ds
                mov forthes es
                mov bx, debugbx
                mov cx, debugcx
                mov dx, debugdx
                mov bp, debugbp
                mov si, debugsi
                mov di, debugdi
                mov ss, debugss
                mov es, debuges
                mov sp, debugsp
                mov ax, debugflags
                or ax, # $100           \ set TF bit in flags
                push ax
                push debugcs
                push debugip
                mov ax, debugax
                mov ds, debugds
                iret            end-code

code one_break  ( -- )          \ go till the breakpoint we just installed
                pop cs: forthret
                mov forthsp sp
                mov forthss ss
                mov forthbp bp
                mov forthsi si
                mov forthdi di
                mov forthbx bx
                mov cs: forthds ds
                mov forthes es
                mov bx, debugbx
                mov cx, debugcx
                mov dx, debugdx
                mov bp, debugbp
                mov si, debugsi
                mov di, debugdi
                mov ss, debugss
                mov es, debuges
                mov sp, debugsp
                mov ax, debugflags
                and ax, # $FEFF         \ CLEAR TF bit in flags
                push ax
                push debugcs
                push debugip
                mov ax, debugax
                mov ds, debugds
                iret            end-code

\ **************************************************************************
\               User screen save and restore
\ **************************************************************************

8192 constant uscrmax
0 value uscr_buf

: >uscr         ( -- )          \ save screen to user screen buffer
                video-seg @ 0 ?ds: uscr_buf ( rows ) 25 cols 2* * cmovel ;

: uscr>         ( -- )
                ?ds: uscr_buf video-seg @ 0 ( rows ) 25 cols 2* * cmovel
                atsave 2@ nip 25 >=     \ scroll user screen up one line
                if      atsave 2@ drop 24 atsave 2!
                        video-seg @ cols 2* over 0 24 cols 2* * cmovel
                        0 24 at cols spaces
                        >uscr
                then    ;

: bugsavescr    ( -- )
                btop 0=
                if      savescr
                else    vrows@ save!> rows
                        savescr
                        restore> rows
                then    ;

: bugrestscr    ( -- )
                btop 0=
                if      restscr
                else    vrows@ save!> rows
                        restscr
                        restore> rows
                then    ;

: usersavescr   ( -- )
                btop 0=
                if      savescr
                else    25 save!> rows
                        savescr
                        restore> rows
                then    ;

: userrestscr   ( -- )
                btop 0=
                if      restscr
                else    25 save!> rows
                        restscr
                        restore> rows
                then    ;

: ipinx_set     ( -- )          \ set the source pointer for current inst
                ip-@ a-inx?
                %inx-file#> 0> and
                if      inx-src-low> inx-src-hi>
                else    0.0
                then    ipinx 2! ;

\ **************************************************************************
\ Set the single step interrupt, perform a single instruction step, and
\ then restore the single step interrupt.
\ **************************************************************************

: single_step   ( -- )                  \ perform one instruction step, and
                                        \ display registers with next
                                        \ instruction to be traced.
                terminated @ ?exit      \ clear terminated flag
                save_ints
                set_ints
                1 save_int#             \ save existing interrupt vector
                1 set_int#              \ set to out interrupt routine
                one_step                \ do a single step trace of one inst
                1 rest_int#             \ restore the interrupt vector
                rest_ints
                                        \ 06/11/92 tjz next line added *****
                cs-@ !> obj-seg         \ current code segment
                ip-@ !> ipaddr          \ set display address
                ipinx_set
                ;

: break_point   ( -- )                  \ break point to offset specified
                terminated @ ?exit              \ clear terminated flag
                bugsavescr
                uscr>
                atsave 2@ at
                dbto
                if          dbto d-tc@ !> dbsave
                        $CC dbto d-tc!          \ only break if not zero
                then
                save_ints
                set_ints
                3 save_int#
                3 set_int#
                one_break
                3 rest_int#
                rest_ints
                dbto                            \ if we set a breakpoint
                                \ 06/11/92 10:03 tjz ************
                                \ changed OBJ-SEG to CS-@ in the next line
                if      dbsave cs-@ dbto c!L    \ restore program byte
                        ip-@ 1- =ip             \ backup PC by one byte
                        off> dbto
                then
                off> dboff              \ reset break point offset
                                        \ 06/11/92 tjz next line added *****
                cs-@ !> obj-seg         \ current code segment
                ip-@ !> ipaddr          \ set display address
                ipinx_set
                at? atsave 2!
                >uscr
                ?vga
                if      vrows@ 43 <
                        if      set50/43
                        then    bugrestscr uscr>
                else    bugrestscr
                then    ;

\ **************************************************************************
\ show the current registers, and a series of instructions as they will
\ be executed.
\ **************************************************************************

true value ?srcon
true value ?update_regs

: botat         ( -- )
                0 dbbot 1+ 2dup at cols 1- sp>col at space ;

0 value watches
0 value watch_len
0 value #watches

: watchon       ( -- )
                off> ?show_watch
                watch_tgl ;

: .watch        ( -- )
                ?show_watch 0= ?exit
                #watches 0= ?exit
                60 btop 79 dbtop 1- bugbox&fill
                watches
                begin   dup c@
                while   count 2dup 12 min type 73 sp>col
                        + ds-@ over @ @L h.4 78 sp>col bcr
                        2+
                repeat  drop
                62 btop at >blue ."  Watches  alt-W " >norm ;

: watch_tgl     ( -- )
                off> ipprev
                #watches 0= ?exit
                ?show_watch 0= !> ?show_watch
                ?show_watch
                if      59 !> srcright
                        on> ?registers
                else    79 !> srcright
                then    .watch .regs .srcbox ;

: del_watch     ( -- )          \ delete last watch variable
                #watches 0= ?exit
                watches
                begin   dup count + 2+ dup @
                while   swap drop
                repeat  drop dup off watches - !> watch_len
                ?show_watch #watches 1 = and
                if      watch_tgl
                then
                #watches 1- 0max !> #watches ;

: add_watch     ( a1 a2 -- )    \ add target addr a1, string a2 to watch list
                dup c@ 5 + watch_len + 255 > ?exit     \ limit watches length
                #watches dbtop 3 - btop - >            \ limit to window full
                if      watches dup count 2+ dup>r + swap
                        watch_len r@ 1+ - cmove
                        watch_len r> 1+ - !> watch_len
                else    incr> #watches
                then
                watchon
                count watches watch_len + place         \ lay in string
                watches watch_len + c@ 1+ +!> watch_len \ bump length
                watches watch_len + ! 2 +!> watch_len   \ lay in address
                watches watch_len + off ;               \ null follows

: 0watch        ( -- )
                watches off
                off> watch_len
                off> #watches ;

: .insts        ( -- )
                ?instructions 0= ?exit
                blinkoff
                ?stkon
                if      dbleft intop dbright 15 - dbbot bugbox
                else    dbleft intop dbright      dbbot bugbox
                then
                decr> tx                \ reduce left box margin by one char
                decr> bline bcr         \ reposition at new left edge
                .pinst bcr
                .inst bcr
                inx-rec-off 2@ 2>r
                inx-src-low> inx-src-hi> curinst_src 2!
                dblines 0
                do      i .ninst bcr
                loop
                2r> inx-rec-off 2!
                dbleft 1+ intop at >blue
                ."  Function  Addr  Instruction        alt-I "
                ?stkon 0=
                if      ."     Data        "
                then    >norm ;

: .%hstack      ( n1 -- )       \ display upto the top 6 stack items
                0 swap  8 umin
                do      ds-@ si-@ i + @L h.4
            -2 +loop    bx-@ h.4 ;

: .hstack       ( -- )          \ display debuggers data stack
                ?stkon ?exit
                2 dbbot 1- at >cyan 2 spaces
                sptop
                if      ds-@ sptop @L si-@ - dup 2/ dup
                        ." [" 1 .r ." ] " dup 1 =
                        if      2drop bx-@ h.4
                        else    1 >
                                if      dup 4 - 0max .%hstack
                                then    drop
                        then
                else    6 .%hstack
                then
                srcright 14 - sp>col ." <- Stack TOP"
                srcright 1-   sp>col >norm ;

: show_debug    ( -- )
                ?srcon
                if      .source
                        .hstack
                else    .program
                        .dump
                then
                ?update_regs 0= ?exit
                .watch
                .regs
                .insts
                .stacks ;

: %show_debug    ( -- )
                ?stkon
                if      dbleft intop dbright 15 - dbbot bugbox
                else    dbleft intop dbright      dbbot bugbox
                then
                bcr .pinst bcr .inst bcr
                dblines 0
                do      i .ninst bcr
                loop    ;

create reglist                  \ the list of register variables
here            debugax , ," AX"
                debugbx , ," BX"
                debugcx , ," CX"
                debugdx , ," DX"
                debugbp , ," BP"
                debugsi , ," SI"
                debugdi , ," DI"
                debugcs , ," CS"
                debugds , ," DS"
                debuges , ," ES"
                debugss , ," SS"
                debugsp , ," SP"
                debugip , ," IP"
here swap - constant reglist_len

: a-reg?        ( a1 -- a2 | false )
                dup c@ 1+ reglist reglist_len search
                if      2- reglist + @
                else    drop false
                then    ;

: set_register  ( -- )
                cursor-on
                ip-@ >r
                save> base hex
                off> ipprev
                botat ." {Register/Memory set} [AX/DS:HEX_address  HEX_value]: "
                query bl word ?uppercase a-reg? ?dup
                if      bl word ?uppercase number? nip
                        if      swap !
                        else    2drop
                        then
[long]          else    here a-data? ?dup 0=
                        if      number? nip
                        then
                        if      bl word ?uppercase number? nip
                                if      ds-@ rot c!L
                                else    2drop beep
                                then
                        else    drop beep
                        then
                then    restore> base
                ip-@ dup !> cptr !> ipaddr
                cs-@     !> obj-seg
                ip-@ r> <>
                if      terminated off
                then    ;

\ **********************************************************************
\ **********************************************************************
\ **********************************************************************

 4 constant type-var
 5 constant type-val
 6 constant type-func
 7 constant type-def

\  3 value btop
23 value blines
 0 value bleft
59 value bright
 4 value bcols
 0 value cwidth
 0 value #ss            \ number of symbols shown
 0 value #stop          \ #symbols to skip at top
 0 value #scur          \ current symbol
32 array asym
 0 value asymptr
 0 value asymaddr
 0 value ?atend
 0 value ?showing

: ?func         ( n1 -- f1 )    \ f1=true if symbol type n1 is a "data" type
                type-func = ;

: ?data         ( n1 -- f1 )    \ f1=true if symbol type n1 is a "data" type
                dup type-var =
                over type-val = or
                swap type-def = or ;

defer ?symbol

: set_datbox    ( -- )
                bleft    !> tx                  \ mark X for BCR
                btop     !> ty                  \ mark Y for BCR
                tx 1+ ty 1+ dup !> bline at     \ position cursor
                bright !> bx                    \ right side of box
                blines btop + !> by             \ bottom of box
                bright bleft - 2- bcols / !> cwidth
                ;

: %show_data    ( -- )
                asym off
                off> #ss
                off> sym-rec-ptr
                set_datbox 1 spaces
                #sym-records dup 0
                ?do     sym-type> ?symbol
                        if      drop i
                                #ss #stop = ?leave
                                incr> #ss
                        then    sym-bytes/rec +!> sym-rec-ptr
                loop
                #sym-records swap
        [long]  ?do     sym-type> ?symbol
        [long]          if      sym-seg sym-name> countl 31 min here placel
                                save> attrib
                                #scur #ss =
                                if      here count asym place
                                        sym-rec-ptr !> asymptr
                                        sym-res-adr> !> asymaddr
                                        >cyan \ fldcolor
                                then
                                ?showing
                                if      here count cwidth 2- min type
                                        cwidth here c@ cwidth 2- min - spaces
                                then
                                restore> attrib
                                incr> #ss
                                #ss #stop - blines 1- bcols * >= ?leave
                                #ss bcols mod 0= ?showing and
                                if      bright sp>col
                                        bcr 1 spaces
                                then
                        then    sym-bytes/rec +!> sym-rec-ptr
                loop    ?showing
                if      bright sp>col
                then    ;

: find_data     ( -- )
                off> ?showing
                %show_data ;

: show_data     ( -- )
                on> ?showing
                %show_data ;

: up_sym        ( -- )
                #scur bcols - 0max !> #scur
                #scur #stop > ?exit
                #stop bcols - 0max !> #stop ;

: +scroll_sym   ( -- )
                #ss #stop - blines 1- bcols * < ?exit
                #stop bcols + !> #stop ;

: down_sym      ( -- )
                #scur bcols + #ss bcols - >=
                if      +scroll_sym
                        #scur bcols + #ss 1- min !> #scur
                else    #scur bcols + !> #scur
                then    ;

: -1_sym        ( -- )
                #scur 1- 0max !> #scur
                #scur #stop min bcols / bcols * !> #stop ;

: +1_sym        ( -- )
                #scur 1+ #ss >=
                if      #ss
                        +scroll_sym
                        find_data
                        #ss = !> ?atend
                        #scur 1+ #ss 1- min !> #scur
                else    #scur 1+ !> #scur
                        off> ?atend
                then    ;

: -pg_sym       ( -- )
                blines 2- 0
                do      up_sym
                        find_data
                loop    ;

: +pg_sym       ( -- )
                blines 2- 0
                do      down_sym
                        find_data
                loop    ;

: home_sym      ( -- )
                off> #ss
                off> #stop
                off> #scur
                off> ?atend ;

: .sym_header   ( -- )
                savecursor
                bleft btop at >bblue
                ."  ESC=cancel  Enter=browse the current function "
                ." ^<-> = Cols "
                bleft 3 + btop blines + at
                ."  Letter=Find the next symbol starting with letter "
                restcursor ;

: .sym_box      ( -- )
                bleft btop bright blines btop + box&fill ;

: +bcols        ( n1 -- )
                bcols + dup 2 max 7 min !> bcols
                dup 7 > swap 2 < or ?exit
                .sym_box
                bugsavescr savecursor >bcyan \ svcolor
                bleft 6 + btop 3 + at ."   One moment, adjusting Columns..  "
                #scur >r home_sym
                r> 0
                ?do     +1_sym
                        find_data
                loop
                restcursor bugrestscr
                show_data ;

: find_sym      ( c1 -- )
                dup '!' '~' between
        [long]  if      upc #scur >r true
                        begin   if      +1_sym
                                        ?atend
                                        if      home_sym
                                        then
                                then
                                key?                    \ if user pressed key
                                if      r@ !> #scur     \ mark to stop
                                        key drop        \ discard the key
                                then
                                find_data
                                asym 1+ c@ over <>
                                r@ 0max #scur 0max <> and
                        while   ?atend
                                if      home_sym
                                        false
                                else    true
                                then
                        repeat  drop
                        r> #scur =
                        if      beep
                        then    show_data
                else    drop
                then    ;

: show_syms     ( -- )
                begin   .sym_header
                        show_data
                        key
                        dup  $1B <>
                        over $0D <> and
        [long]  while   case
( home )                $C7 of  home_sym                endof
( up )                  $C8 of  up_sym                  endof
( down )                $D0 of  down_sym                endof
( left )                $CB of  -1_sym                  endof
( right )               $CD of  +1_sym                  endof
( Pgup )                $C9 of  -pg_sym                 endof
( Pgdn )                $D1 of  +pg_sym                 endof
( -> )                  244 of   1 +bcols               endof
( <- )                  243 of  -1 +bcols               endof
( Del )                 211 of  del_watch .watch        endof
                                find_sym
                        endcase
                repeat  $0D = ;

\ **********************************************************************

: show_data_syms ( -- )
                ['] ?data is ?symbol
                59 !> bright
                23 !> blines
                bugsavescr cursor-off
                .sym_box
        begin   .sym_header
                show_syms
        while   asymaddr asym add_watch .watch
        repeat  bugrestscr ;

: show_func_syms ( -- )
                ['] ?func is ?symbol
                79 !> bright
                24 !> blines
                bugsavescr cursor-off
                .sym_box
                .sym_header
                show_syms
                if      asym count here place
                        $2020 here count + !
                        here ?uppercase a-function?
                        if      !> ipaddr
                                on> ?srcon
                                to->source
                        else    drop beep
                        then
                then
                bugrestscr ;

: set_watch     ( -- )
                cursor-on
                off> ipprev
                botat
        ." {Watch} [name=add, Del=Delete, Ins=From_screen, Enter=Pick_list]: "
                key dup  27 = if drop                exit then  \ ESC
                    dup 210 = if drop scr_watch      exit then  \ INS
                    dup 211 = if drop del_watch      exit then  \ DEL
                    dup  13 = if drop show_data_syms exit then  \ Enter
                tib c!                                  \ lay in first char
                botat
                ." {Watch} Add Symbol: "                \ display message
                tib 31 1 #expect span @ #tib ! >in off  \ get rest of sym
                esc_flg @ 0=
                if      bl word c@
                        if      here ?uppercase a-data? \ found symbol,
                                ?dup 0=
                                if      save> base hex
                                        number? nip
                                        restore> base
                                then
                                if      here add_watch  \ then add one
                                else    drop beep       \ else beep user
                                then
                        then
                then    ;

: view_sym      ( -- )
                cursor-on
                off> ipprev
                botat ." {View at} [symbol, HEX_address or Enter=pick_list]: " space
                key dup  27 = if drop                exit then  \ ESC
                    dup  13 = if drop show_func_syms exit then  \ Enter
                tib c!                                  \ lay in first char
                tib 31 1 #expect span @ #tib ! >in off  \ get rest of sym
                esc_flg @ 0=
                if      save> base hex
                        bl word ?uppercase a-function?
                        if      !> ipaddr
                                on> ?srcon
                                to->source
                        else    number? nip
                                if      !> ipaddr
                                        on> ?srcon
                                else    drop beep
                                then
                        then    restore> base
                then    ;

: goto_addr     ( -- )          \ goto an address as entered by the user
                on> ?srcon
                cursor-on
                off> ipprev
                botat ." {Go until} symbol or HEX_address: "
                save> base hex
                query   bl word c@
                if      here ?uppercase a-function?
                        if      dup !> ipaddr !> dbto
                                break_point
                        else    number? nip
                                if      dup !> ipaddr !> dbto
                                        break_point
                                else    drop beep
                                then
                        then
                else    esc_flg @ 0=
                        if      break_point
                        then
                then    to->source
                restore> base ;

: up_addr       ( -- )          \ goto breakpoint of address on top of return
                                \ stack
                on> ?srcon
                off> ipprev
                ss-@ sp-@ @L dup !> ipaddr !> dbto
                break_point
                to->source ;

: prev_word     ( -- )
                inx-rec-off 2@
                inx-src-low> inx-src-hi>
                begin   inx-bytes/rec negate +inx-rec-off
                        2dup inx-src-low> inx-src-hi> d- or
                                                        \ different source
                        cs-@ inx-adr> c@L   $C3 = or    \ or RET
                        cs-@ inx-adr> c@L   $E9 = or    \ or JMP
                        %inx-file#>            0> and   \ and in source
                        inx-type> $07 and dup 2 =
                                         swap 3 = or and \ instruction type
                        inx-rec-off 2@        d0= or    \ or at start of inx
                until   2drop
                %inx-file#>     0=
                inx-rec-off 2@ d0= or
                if      2dup inx-rec-off 2!
                        beep
                then    2drop ;

: next_word     ( -- )
                inx-total 2@ inx-rec-off 2@ 0.1 d+ d< ?exit
                inx-rec-off 2@
                inx-src-low> inx-src-hi>
                begin   inx-bytes/rec +inx-rec-off
                        2dup inx-src-low> inx-src-hi>
                                               d- or    \ different source
                        cs-@ inx-adr> c@L   $C3 = or    \ or RET
                        cs-@ inx-adr> c@L   $E9 = or    \ or JMP
                        %inx-file#>            0> and   \ and in source
                        inx-type> $07 and dup 2 =
                                         swap 3 = or and \ instruction type
                        inx-total 2@ inx-rec-off 2@ d= or
                until   2drop
                %inx-file#> 0=
                inx-total 2@ inx-rec-off 2@ d= or
                if      2dup inx-rec-off 2!
                        beep
                then    2drop ;

: %sync         ( -- )
                inx-rec-off 2@
                ?find_position 0=
                if      2dup inx-rec-off 2!
                        beep
                then    2drop
                to->source ;

: sync_page     ( -- )
                on> ?srcon
                off> ipprev
                #inx-records 0= ?exit
                right_cur right_cur lleftw
                to_point lincur + save!> listoff
                %sync
                restore> listoff ;

: next_page     ( -- )
                on> ?srcon
                off> ipprev
                #inx-records 0= ?exit
                displaylines 0 do +1line loop
                %sync ;

: prev_page     ( -- )
                on> ?srcon
                off> ipprev
                #inx-records 0= ?exit
                displaylines 0 do -1line loop
                %sync ;

: up_scroll     ( -- )
                on> ?srcon
                off> ipprev
\                #inx-records 0= ?exit
                inx-rec-off 2@ or
                if      ?instructions
                        if      -1 +inst
                        else    prev_word
                                inx-adr> !> ipaddr
                                to->source
                        then
                else    -1 +inst
                then    ;

: down_scroll   ( -- )
                on> ?srcon
                off> ipprev
                ?instructions
                if      1 +inst
                else    next_word
                        inx-adr> !> ipaddr
                        to->source
                then    ;

: go_home       ( -- )                  \ move disassembly display to IP
                on> ?srcon
                off> ipprev
                off> dboff
                ip-@ !> ipaddr
                to->source
                inst-on ;

0 value daddr

: dump_aline    ( seg a1 -- seg a2 )
                dup 4 h.r ."  | "
                2dup 15 for 2dup c@l 3 h.r 1+ next
                ?show_watch 0=
                if      2drop
                        ."  ³ " 15 for 2dup c@l $7f and bl max emit 1+ next
                else    2swap 2drop
                then    ;

0 value dumpseg

true value ?ds_seg

: %dumper       ( a1 -- )
                dup !> daddr
                set_srcbox
                save> base hex
                dup $10 bounds  >blue ."  Offset "
                do      i $0F and 3 .r
                loop
                restore> base
                ?show_watch 0=
                if      8 spaces ." ASCII"
                then    srcright 1- sp>col >norm bcr
                ?ds_seg
                if      ds-@
                else    dumpseg
                then    swap
                displaylines 1- 0
                do      space dump_aline srcright sp>col bcr
                loop    2drop
                25 btop at >blue ."  Segment: "
                save> base hex
                ?ds_seg
                if      "  DS: "
                else    dumpseg 0 <# # # # # #>
                then    type 1 spaces
                srcright 8 - 0max btop at ."  Alt-Z " >norm
                restore> base ;

: .dump         ( -- )
                daddr %dumper ;

: dump_memory   ( -- )          \ show the source window
                cursor-on
                save> base hex
                botat ." {Dump at} [HEXseg HEXoffset] or [symbol or HEX_address]: "
                query bl word ?uppercase a-data? 0=
                if      number? 2drop
                else    on> ?ds_seg             \ switch back to DS:
                then    esc_flg @ 0=
                if      off> ?srcon
                        here c@ 0=
                        if      drop daddr $80 +
                        then    dup !> daddr
                        bl word c@
                        if      here ?uppercase a-data? 0=
                                if      number? 2drop
                                then
                                daddr !> dumpseg !> daddr
                                dumpseg ds-@ = !> ?ds_seg
                        then
                then    drop
                restore> base ;

: find_SP0      ( -- )
                off> sptop
                " SP0" ">$ a-data?
                if      !> sptop
                else    drop
                then
                off> rptop
                " RP0" ">$ a-data?
                if      !> rptop
                else    drop
                then    ;

\ **************************************************************************
\ Additional MINI help for the debugger.
\ **************************************************************************

: cursor_toggle ( n1 n2 -- )
                savecursor big-cursor
                2>r
                0
                begin   key? 0=
        [long]  while   1+ dup 1 and
                        if      dbleft 2r@ nip  + dbbot 1- at
                        else    dbleft 2r@ drop + dbbot 1- at
                        then    10 0
                                do      1 tenths
                                        key? ?leave
                                loop
                repeat  drop 2r> 2drop
                restcursor ;

: show_help     ( -- )
                bugsavescr
                off> ipprev
                dbleft btop dbright dbbot bugbox&fill
                >blue ."  Debugger commands: " >norm
                dbright 13 - sp>col >blue ."  ^=Ctrl key " >norm
        bcr ."     ^Enter  = step repeat until CALL or RET encountered"
        bcr ."      Enter  = step over CALL's or GO till break marker"
        bcr ."      Space  = single step one instruction (nest if CALL)"
        bcr ."     ^Ins    = Force Program counter to word at cursor"
        bcr ."      Ins    = Move break cursor to word at screen cursor"
        bcr ."     TAB/Del = Push/Pop one value to/from the Data Stack"
        bcr ."      Home   = Move display to current program counter"
        bcr ."      +/-    = Move for/back instruction (word if zoomed)"
        bcr ."      A      = set the Arguments for current program"
        bcr ."      B      = execute to here again"
        bcr ."      D      = Dump memory at symbol or HEX_address"
        bcr ."      G      = Go till hilighted line or HEX_address"
        bcr ."      Q      = Quit debugging and return to DOS"
        bcr ."      R      = Set a Register or memory to a HEX value"
        bcr ."      V      = View symbol or HEX_address"
        bcr ."      W      = Add or Delete a Watch variable"
        bcr ."   /PgUpDn = scroll up/down a line or page in the source"
        bcr ."   alt-D,I,S = Data/source, Instruction, Stack      TOGGLE"
        bcr ."   alt-U,W,Z = User_screen, Watch, source/data_Zoom TOGGLE"
        bcr ."   Alt-L     = Log insts & regs to printer          TOGGLE"
            >blue
        bcr ."  Press ESC to continue debugging, or SPACE for more help "
                dbleft 25 + btop at    >blue ."  BUG Help "       >norm
                7 37 cursor_toggle
                key $1B =
                if      bugrestscr exit
                then
                dbleft btop dbright dbbot bugbox&fill
            >blue
            ."  Additional commands:" >norm
        bcr
        bcr ."      F6/F   = Find instruction near user entered text"
        bcr ."      F9     = Browse to the source of word at cursor"
        bcr ."      F10    = Unbrowse source of word at cursor"
        bcr ."      L      = Load a new file into BUG"
        bcr ."      U      = Unnest, break at address on return stack"
        bcr ."      X      = Shell to DOS, returns with EXIT"
        bcr >blue
        bcr ."  Duplicate keys for debugger commands: " >norm
        bcr
        bcr ."      F2     = User_screen, Watch, source/data_Zoom TOGGLE"
        bcr ."      N      = Single step one instruction (nest if CALL)"
        bcr ."      S      = Stack/Data window                    TOGGLE"
        bcr ."      Z      = Zoom Source window                   TOGGLE"
        bcr
        bcr ."  Use SHIFT with the following keys for an auto repeat"
        bcr ."  of that key:  Enter - word step"
        bcr ."                Space - instruction step"
        bcr ."                B     - execute and break here again"
        bcr >blue
        bcr ."  Press ESC to continue debugging, or SPACE for more help "
        dbleft 25 + btop at ."  More Help "  >norm
                7 37 cursor_toggle
                key $1B =
                if      bugrestscr exit
                then
                dbleft btop dbright dbbot bugbox&fill
        bcr ."  The BUG debugger is written in Forth for use during"
        bcr ."  debug of programs compiled with the TCOM compiler."
        bcr ."  BUG was itself compiled with TCOM."
        bcr
        bcr ."  TCOM is a compiler for the Forth computer language. It"
        bcr ."  generates .COM programs for the MS-DOS operating system."
        bcr
        bcr ."  Applications compiled with TCOM can be as small at a few"
        bcr ."  bytes, or as large as 64k bytes. TCOM uses the 'tiny'"
        bcr ."  model, where application CODE and STATIC DATA must"
        bcr ."  together total no more than 64k bytes."
        bcr
        bcr ."  TCOM is an optimizing (for space and speed) compiler."
        bcr ."  It is a public domain program, and the source is"
        bcr ."  available for US$60 from the author:"
        bcr
        bcr ."    Tom Zimmer            Hm (408) 263-8859"
        bcr ."    292 Falcato Drive     Wk (415) 327-8800"
        bcr ."    Milpitas, Ca. 95035   Outside US add $20 for shipping"
        bcr
        bcr >blue
            ."   LAST help screen, Press ANY key to continue debugging  "
        dbleft 20 + btop at ."  TCOM Advertisement "  >norm
                2 26 cursor_toggle
                key drop
                bugrestscr ;

: step_inst     ( -- )          \ step through next instruction
                inst_byte@             $E8 =    \ or a CALL?
                inst_byte@             $CD = or \ or a INT?
                inst_word@ $38FF and $10FF = or \ or CALL reg16/mem16(intra)
                inst_word@ $38FF and $18FF = or \ or CALL mem16(intersegment)
                if      ipaddr a-inx?
                        if      1 +inst
                        else    ipnext !> ipaddr
                        then    ipaddr !> dbto
                        break_point
                else    single_step
                then    ;

: step_one      ( -- )          \ step through next instruction if not INT
                inst_byte@   $CD =      \ or a INT?
                if      ipaddr a-inx?
                        if      1 +inst
                        else    ipnext !> ipaddr
                        then    ipaddr !> dbto
                        break_point
                else    single_step
                then    ;

0 value [']addr

code inst_@rel>abs   ( --- a1 )
                push ds
                save_bx
                mov bx, debugip         \ set BX to target IP
                mov ds, debugcs         \ set DS to target CS
                add bx, 1 [bx]
                add bx, # 3
                pop ds
                ret     end-code

: ?[']          ( -- f1 )
                inst_byte@ $E8 =        \ call?
                inst_@rel>abs [']addr = and ;

: step_word     ( -- )
                ipaddr a-inx?
[long]          if      ?[']                    \ if we are sitting on a [']
                   if   ip-@ 6 + dup            \ then set BP at word after
                        !> ipaddr !> dbto       \ and force goto BP
                        break_point             \ go break point
[long]             else
                        inx-src-low> inx-src-hi>
                        begin   step_inst
                                ip-@ a-inx? >r
                                2dup inx-src-low> inx-src-hi>
                                                d- or   \ source greater
                                r>              0= or   \ or didn't find it
                                inst_byte@   $C3 = or   \ or RET
                                inst_byte@   $E9 = or   \ or JMP
                                key?               or   \ or a key pressed
                                terminated @       or   \ or program end
                                %inx-file#>     0= or   \ or library routine
                        until   2drop
                   then
                else    step_one
                then    off> dboff ;

: next_step     ( -- )
                terminated @ ?exit
                ip-@ ipaddr =
                if      step_word
                else    ipaddr !> dbto
                        break_point
                then    to->source
                ipaddr a-inx?
                if      %inx-file#> 0=
                        if      inst-on
                        then
                else    inst-on
                then    ;

: 1single_step  ( -- )
                step_one                        \ step one instruction
                off> dboff
                to->source                      \ show source if possible
                inst-on ;                       \ turn on instruction window

: to_func_end   ( -- )          \ step to end of current function
                off> dboff
                ip-@ ipaddr <>                  \ if not already here
                if      ipaddr !> dbto          \ then step to here
                        break_point
                then    step_word               \ at least one step
                begin   terminated @            \ while NOT terminated
                        inst_byte@   $C3 = or   \ or RET
                        inst_byte@   $E9 = or   \ or JMP
                        key?               or   \ or a key pressed
                        0=
                while   step_word
                        show_debug
                repeat  off> ipprev
                empty-kbd
                to->source ;

: run_to_here   ( -- )
                next_step
                up_scroll
                next_step ;

: PC_to_browse  ( -- )
                sync_page
                ipaddr =ip
\                to->source
                ipinx_set
\                inst-on
\                show_debug
                ;

: open-bin-file ( -- f1 )       \ open file, return f1=true on error
                file-name c@
                if      file-name handle>ext c@ '.' -
                        if      " COM" ">$ file-name $>ext
                        then    file-name $file
                else    on> ?warned_no_file
                        " ?NOFILE?.???" ">$ file-name $>handle
                        true
                then    ;

: .file-name-ext ( -- ) \ show filename without the extention
                file-name count 2dup '.' scan nip - type ;

: ?no_file_open ( -- )
                ?warned_no_file ?exit
                ?nobin 0= ?nosym 0= and ?noinx 0= and ?nofil 0= and ?exit
                bugsavescr savecursor cursor-off
                white >fg red >bg
                12 4 68 16 box&fill
                ?nobin
                if      bcr ."   Couldn't OPEN:  "
                else    bcr ."          Loaded:  "
                then    file-name count type bcr bcr
                ?nosym
                if      ."   Couldn't OPEN:  " .file-name-ext ." .SYM"
                then    bcr
                ?noinx
                if      ."   Couldn't OPEN:  " .file-name-ext ." .INX"
                then    bcr
                ?nofil
                if      ."   Couldn't OPEN:  " .file-name-ext ." .FIL"
                then    bcr bcr 4 spaces blue >bg yellow >fg
                ?nobin
                if      ."   ****** NO PROGRAM WAS LOADED TO DEBUG ****** "
                else    ."   **** SYMBOLIC DEBUGGING IS NOT AVAILABLE **** "
                then    red >bg white >fg
                bcr bcr 11 spaces blue >bg yellow >fg
                space   ."  Press <ESCape> to continue "
                24 4 at ."  ********** WARNING ********** "
                red >bg white >fg
                beep begin key 27 = until
                on> ?warned_no_file
                restcursor bugrestscr ;

128 array arguments

: load_file     ( | name -- )           \ debug file "name" f1=
                on> ?nobin                      \ mark as no file open
                off> ?warned_no_file
                bl word file-name $>handle      \ get the filename
                file-name count upper           \ uppercase filename
                obj-seg ?dup                    \ if object space is alloced
                if      dealloc drop            \ then release it
                        off> obj-seg            \ reset the pointer
                then
                get-sym-file                    \ read the symbol file
                get-inx-file                    \ and read the index file
                get-fil-file                    \ and read the .FIL file
                $FFFF alloc 2drop $2800 umax $1800 -
                alloc 8 =
                abort" Not enough memory, need at least 192k"
                !> obj-seg drop
                ?cs: 0 obj-seg 0 $100 cmovel    \ init first $100 bytes
                open-bin-file 0=
                if      file-name handle>ext 1+ c@ upc 'C' <>
                        if         0 maxobj
                        else    $100 maxobj $100 -
                        then    seqhandle obj-seg exhread drop
                                                \ read the file into memory
                        close-com-file
                        off> ?nobin
        [long]  else    obj-seg $100 $100 $90 lfill     \ 256 bytes of NOP's
                then
                0 word count arguments place
                ?ds: arguments obj-seg $80 arguments c@ 2+ $78 min cmovel
                                                        \ lay in arguments
                on> cur-file#
                on> ?srcon
                0watch
                home_sym
                find_SP0 ;

handle inhndl
handle outhndl

: "open_input   ( a1 n1 -- )
                dup 0=
                if      2drop exit
                then
                inhndl clr-hcb
                inhndl place
                inhndl hopen if beep EXIT then
                inhndl >hndle @ obj-seg $18 c!L ;       \ set input handle

: "open_output  ( a1 n1 -- )
                dup 0=
                if      2drop exit
                then
                outhndl clr-hcb
                over c@ '>' =
                if      1 /string
                        true
                else    false
                then    >r
                outhndl place
                r>
                if      read-write outhndl hopen if beep EXIT then
                             -1 -1 outhndl movepointer
                else               outhndl hcreate if beep EXIT then
                then    outhndl >hndle @ obj-seg $19 c!L ;

: lplacel       ( seg off len seg off -- )
                2>r dup 2r@ c!L 2r> 1+ rot cmovel ;

: +lplacel      ( seg off len seg off -- )
                2>r dup 2r@ c@L dup rot + 2r@ c!L 2r> rot + rot cmovel ;

: set_arguments ( -- )
                cursor-on
                botat ." {Arguments}: "
                arguments count 50 swap #expect span @ arguments c!
                esc_flg @ 0=
        [long]  if      ?ds: arguments count 2dup
                        '<' scan 2dup 2>r nip - obj-seg $80 lplacel
                        2r> 1 /string 2dup bl scan 2dup 2>r nip -
                        "open_input
                        ?ds: 2r> 2dup
                        '>' scan 2dup 2>r nip - obj-seg $80 +lplacel
                        2r> 1 /string 2dup bl scan 2dup 2>r nip -
                        "open_output
                        ?ds: 2r> obj-seg $80 +lplacel
\                       ?ds: arguments obj-seg $80 arguments c@ 2+ cmovel
                then    ;

: to_lastfunc   ( -- )
                last-func-adr ?dup
                if      !> ipaddr
                        off> ipprev
                        to->source
                        show_src
                then    ;

: init_[']      ( -- )          \ initialize [']ADDR to address of [']
                " TT[']" ">$ a-function?        \ lookup [']
                if      dup !> [']addr          \ and save in variable
                then    drop ;

: init_regs     ( -- )          \ initialize the processor registers
                $100 dup =ip dup =ax !> ipaddr
                obj-seg dup =cs dup =ds dup =ss =es
                $FFFE =sp
                off> dboff
                off> dbto
                off> ipprev
                on> ?stkon
                terminated off ;

: load_new_file ( -<name>- )
                cursor-on
                botat ." {Load new file to debug} filename: "
                query
                cls
                load_file
                .srcbox
                init_regs
                to_lastfunc
                init_['] ;

: doshell       ( -- )
                cls cr space
                >blue
                ."  Type EXIT to return to BUG " >norm cr
                here off here $sys drop ;

: dos_shell     ( -- )          \ shell to DOS for a commandline
                cursor-on
                off> ipprev
                bugsavescr
                ?vga
                if      set25 doshell set50/43
                else          doshell
                then
                bugrestscr ;

: user_screen   ( -- )          \ show user's screen till key press
                ?vga ?exit
                usersavescr
                uscr>           \ restore screen from user buffer
                atsave 2@ at    \ restore cursor from saved location
                key drop
                userrestscr ;

: inst_tgl      ( -- )
                off> ipprev
                ?instructions 0= dup !> ?instructions
                if      intop 1- btop - !> displaylines
                        on> ?registers
                else    dbbot 1- btop - 1- !> displaylines
                then    hiloff_set
                .srcbox .srcname .source ;

: zoom_src      ( -- )
                off> ipprev
                ?registers
                if      ?instructions
                        if      inst_tgl
                        then
                        ?show_watch
                        if      watch_tgl
                        then
                        off> ?registers
                        off> ?stkon
                else    ?instructions 0=
                        if      inst_tgl
                        then
                        ?show_watch 0=
                        if      watch_tgl
                        then
                        on> ?registers
                        on> ?stkon
                then    ;

: inst-on       ( -- )
                off> ipprev
                ?instructions 0=
                if      zoom_src
                then    ;

: reg_tgl       ( -- )
                off> ipprev
                ?registers 0= !> ?registers
                .srcbox .source ;

: stk_tgl       ( -- )
                off> ipprev
                ?stkon 0= !> ?stkon
                .srcbox .source ;

: logtoggle     ( -- )          \ toggle the state of execution logging
                ?printer.ready
                if      $0D pemit $0A pemit             \ print CRLF
                        ?logging dup 0= !> ?logging
                        if      $0C pemit               \ if turning off
                        then                            \ then formfeed
                else    beep
                        off> ?logging
                then    ;

: empty-kbd     ( -- )          \ discard keys waiting in keyboard buffer
                begin   key?
                while   key drop
                repeat  ;

: dodumpkey     ( c1 -- )       \ if no source shown, scroll dump area
                case
( PgUp )        $C9 of  $-80 ?instructions 0= if 2* then +!> daddr      endof
( PgDn )        $D1 of   $80 ?instructions 0= if 2* then +!> daddr      endof
( up arrow )    $C8 of  $-10                             +!> daddr      endof
( down arrow)   $D0 of   $10                             +!> daddr      endof
                        drop
                endcase ;

\ **************************************************************************
\ the main trace loop, walks through instructions until the ESC key is
\ pressed.
\ **************************************************************************

0 value quitting
0 value ?auto_repeat

: ?auto         ( n1 -- )
                ?shiftkey
                if      dup !> ?auto_repeat
                then    drop ;

: do_dbkey      ( c1 -- )
                on> ?update_regs
                dup>r
                case
( ^enter )      $0A of  to_func_end             endof
( enter )       $0D of  $0D ?auto next_step     endof   \ shifted=auto repeat
( space )       $20 of  $20 ?auto 1single_step  endof   \ shifted=auto repeat
( - )           '-' of  up_scroll               endof
( + )           '+' of  down_scroll             endof
( F1=help )     $BB of  show_help               endof
( Alt-B )       $B0 of  $B0 ?auto run_to_here   endof
( Alt-D )       $A0 of  ?srcon 0= !> ?srcon     endof
( Alt-W )       $91 of  watch_tgl               endof
( Alt-I )       $97 of  inst_tgl                endof
( Alt-L )       $A6 of  logtoggle               endof
( Alt-Q )       $90 of  on> quitting            endof
( Alt-R )       $93 of  reg_tgl                 endof
( Alt-S )       $9F of  stk_tgl                 endof
( Alt-U )       $96 of  user_screen             endof
( Alt-V )       $AF of  backto_25               endof
( Alt-Z )       $AC of  zoom_src                endof
( Home )        $C7 of  go_home                 endof
( ^PgUp )       $84 of  prev_page               endof
( ^PgDn )       $F6 of  next_page               endof
( Ins )         $D2 of  sync_page               endof
( ^Ins )        $92 of  PC_to_browse            endof
( F2 )          $BC of  user_screen             endof
( TAB )         $09 of  push_stack_value        endof
( Del )         $D3 of  pop_stack_value         endof
                upc             \ remaining tests are case insensitive
( Arguments )   'A' of  set_arguments           endof
( Break again ) 'B' of  'B' ?auto run_to_here   endof
( Dump )        'D' of  dump_memory             endof
( Go )          'G' of  goto_addr               endof
( Help )        'H' of  show_help               endof
( Load )        'L' of  load_new_file           endof
( Nest )        'N' of  1single_step            endof
( Quit )        'Q' of  on> quitting            endof
( register set) 'R' of  set_register            endof
( Stack toggle) 'S' of  stk_tgl                 endof
( Up a level)   'U' of  up_addr                 endof
( View sym )    'V' of  view_sym                endof
( Watch sym )   'W' of  set_watch               endof
( Shell DOS )   'X' of  dos_shell               endof
( Zoom Source ) 'Z' of  zoom_src                endof
                        off> ipprev
( all others )          drop
                        ?srcon
( Source browse funcs ) if      r@ dolistkey
                                ?instructions
                                ?show_watch or
                                if      off> ?update_regs
                                then
( Dump browse funcs )   else    r@ dodumpkey
                        then
                endcase r>drop ;

: steps         ( -- )
                cls
                uscr>           \ restore screen since we cleared it
                .srcbox
                to_lastfunc
                init_[']
                begin   cursor-off
                        show_debug
                        terminated @
                        if      >red botat
                                ."  ***** Program TERMINATED *****"
                                empty-kbd
                                off> ?auto_repeat
                        else    0 dbbot 1+ at >blue
                                ?instructions
                                if
."  F1=Help Alt-UserScrn SP=InstStep Ù=WordStep Dump Go Quit Reg Stack Watch View "
                                else
."  F1=Help  INS=move_break_to_cursor  F9=Browse_word +,-=move_break_cursor Quit   "
                                then
                        then    >norm
                        .stack
                        lincur listscroll - 0max 1+ 79 min
                        hiloff btop + at cursor-on big-cursor
                        ?no_file_open
                        ?auto_repeat
                        if      key?
                                if      key drop
                                        off> ?auto_repeat
                                        key
                                else    ?auto_repeat
                                then
                        else    key
                        then
                        norm-cursor
                        do_dbkey
                        quitting
                until   ;

\ **********************************************************************
\ Video mode primitives to allow setting 50 line mode on VGA displays
\ **********************************************************************

code vpage@     ( -- n1 )       \ get the current display mode
                save_bx
                mov ah, # $0F           \ determine the active page
                int $10
                mov bl, bh
                sub bh, bh              \ clear high part of page
                ret             end-code

code vpage!     ( n1 -- )       \ set the active display page
                mov al, bl
                mov ah, # $05           \ make page n1 active
                int $10
                load_bx
                ret             end-code

                                \ set the display scan lines
code scanline!  ( n1 -- )       \ n1=0=200 lines,1=350 lines, 2=400 lines
                mov al, bl
                mov ah, # $12           \ select the display scan lines
                mov bl, # $30           \ sub code $30
                int $10
                load_bx
                ret             end-code

code modereset  ( -- )
                                        \ perform mode set without changing mode
                mov ah, # $0F           \ determine the current mode
                int $10                 \ return mode in AL
                mov ah, # $00           \ set mode
                int $10
                ret             end-code

code char8x8!   ( n1 -- )       \ load block n1 of the 8X8 character set
                mov ax, # $1112         \ set to 8X8 character set
                int $10
                load_bx
                ret             end-code

code char8x14!  ( n1 -- )       \ load block n1 of the 8X14 character set
                mov ax, # $1111         \ set to 8X14 character set
                int $10
                load_bx
                ret             end-code

code char8x16!  ( n1 -- )       \ load block n1 of the 8X16 character set
                mov ax, # $1114         \ set to 8X16 character set
                int $10
                load_bx
                ret             end-code

code shape!     ( n1 n2 -- )    \ set the video cursor shape, start end
                                \ set to 1 bit 0 of Misc Info byte in
                                \ host mem to enable cursor emulation
                push ds
                sub ax, ax
                mov ds, ax              \ clear DS:
                mov al, $487            \ get physical byte $487
                or al, # $01            \ set bit 0
                mov $487 al             \ put the byte back to $487
                pop ds

                mov ch, bl
                lodsw
                mov cl, al
                mov ah, # $01
                int $10                 \ set the cursor
                push ds
                                \ reset to 0 bit 0 of Misc Info byte in
                                \ host memory to disable cursor emulation
                sub ax, ax
                mov ds, ax              \ clear DS:
                mov al, $487            \ get physical byte $487
                and al, # $FE           \ clear bit 0
                mov $487 al             \ put the byte back to $487
                pop ds
                load_bx
                ret             end-code

code underline! ( n1 -- )       \ set the underline row to n1
                mov dx, # $03D4         \ adjust the underline location
                mov al, # $14
                out dx, al
                inc dx
                mov al, bl              \ set underline to line n1
                out dx, al
                load_bx
                ret             end-code

: vrows@        ( -- n1 )
                0 $484 c@L 1+ 25 max ;

: set50/43      ( -- )          \ set 50 line mode for VGA, 43 for EGA
                vpage@
                0 vpage!
                2 scanline!
                modereset
                0 char8x8!
                0 6 shape!
                7 underline!
                vpage!
                vrows@ 25 <> !> ?vga
                vrows@ 43  = !> ?ega ;

: set25         ( -- )
                vpage@
                0 vpage!
                ?vga
                if      2 scanline!
                        modereset
                        0 char8x16!
                else    0 char8x14!
                then
                12 underline!
                vpage! ;

: backto_25     ( -- )
                ?vga ?ega or ?exit
                vmodesave vmode!
                >uscr
                off> ?vga
                off> ?ega ;

: ?/vga         ( -- )          \ /VGA display option
                off> ?vga
                >in @ bl word 1+ " /V" caps-comp 0=     \ /VGA
                if      drop
                        set50/43            \ try to set 50 line mode
                        ?vga                \ if we are successful, shift
                        if      25 !> btop  \ debugger down by 25 lines
                        else     0 !> btop  \ else go back to 25 line mode
                                set25
                        then
                else    >in !
                        0 !> btop
                then
                vrows@      !> rows
                vrows@  2-  !> dbbot
                vrows@ 13 - !> dbtop
                dbtop !> intop                  \ default for VGA
                ?ega
                if      vrows@ 11 - !> intop    \ backoff for EGA
                then
                intop 1- btop - !> displaylines
                hiloff_set ;

: ?/lcd         ( -- f1 )       \ /LCD display option
                >in @ bl word 1+ " /L" caps-comp 0=
                if      drop    true
                else    >in !   false
                then    ;

\ ***************************************************************************
\               Debug a TCOM compiled file
\ ***************************************************************************

: main          ( -- )
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                vmode.set                       \ init EMIT, TYPE & SPACES
                blinkoff
                fil-max       ds:alloc !> fil-buf
                src-max 100 + ds:alloc !> src-buf
                256           ds:alloc !> watches watches 256 erase
                listlimit     ds:alloc !> listbuf       \ text buffer
                uscrmax       ds:alloc !> uscr_buf      \ user screen buffer
                34            ds:alloc !> lfindbuf      \ search buffer
                lfindbuf off                    \ clear text find buffer
                $0000 SET_MEMORY                \ default to 64k code space
                alloc-sym-memory                \ allocate symbol memory
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                ?in_redirect
                ?out_redirect or
                abort" I/O redirection is not supported by BUG!"
                sym-file-handle clr-hcb
                inx-file-handle clr-hcb
                fil-handle      clr-hcb
                src-handle      clr-hcb
                0.0 ipinx 2!
                0 ?cs: execcnt !L               \ init EXEC counter to zero
\ cls cr cr ."  Here: " here h. ."  Memend: " memend @ h. cr
                at? 1- 0max atsave 2!
                >uscr
                ?/vga
                ?vmode dup !> vmodesave 7 = ?/lcd or
                if      lcd_set
                else    color_set
                then
                load_file
                init_regs
                steps
                ?vga if set25 then
                uscr>
                norm-cursor cursor-on 0 23 at ;

}

