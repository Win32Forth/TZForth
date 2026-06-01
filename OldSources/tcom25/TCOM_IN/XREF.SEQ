\\ XREF.SEQ      The start of a cross reference program for SAMA



{
        .options /opt /noinit

needs \tcom\tpoint.seq

65536. pointer headseg

0 value head_segment
0 value symcnt
0 value headcnt
2 value headptr

        64 constant hashmax     \ legal values are 2, 4, 8, 16, 32, 64 or 128
hashmax 1- constant hashmask

hashmax 2* array hashptrs

: head,         ( n1 -- )       \ lay n1 into symbol space, bump head pointer
                headseg headptr !L
                2 +!> headptr ;

code hash       ( str-addr voc-ptr -- thread )
                MOV DI, BX
                LOAD_BX
                XCHG DI, BX
                MOV AX, 1 [DI]          \ Get first and second chars
                SHL AL, # 1             \ Shift first char left one
                ADD AL, AH              \ Plus second char
                SHL AX, # 1             \ The sum shifted left one again
                ADD AL, 0 [DI]          \ Plus count byte
                AND AX, # HASHMASK
                SHL AX, # 1
                ADD BX, AX
                RET             END-CODE

: l>name        ( a1 -- a2 )
                4 + ;

: name>l        ( a1 -- a2 )
                4 - ;

M: >data        ( a1 -- a2 )
                2+ ;

\               +0      +2      +4       +5
\ Header:       [ link ][ data ][ count ][ name ]

: $header       ( a1 -- )       \ make a new header for name a1
                dup count upper
                dup c@ 31 min over c!           \ clip to 31 characters
                headptr over hashptrs hash dup @ head, ( link  ) ! ( current )
                here head,                      \ data field of header
                ?ds: swap dup c@  1+ >r         \ yh cs str
                headseg headptr r@ cmovel       \ copy str
                r> +!> headptr                  \ adj header end pointer
                incr> headcnt ;

                                \ find string a1, return f1=true if found
                                \ nfa = "data" as described above
: $find         ( a1 -- symaddr true | a1 false )
                dup count upper
                headseg save!> sseg
                dup hashptrs hash @ ?dup
                if      begin   headseg over @L >r
                                2dup l>name over c@ 1+ comp 0=
                                if      r>drop
                                        restore> sseg
                                        nip true
                                        EXIT    \ ************ EXIT HERE
                                then    drop
                                r> ?dup 0=
                        until
                then
                restore> sseg
                false   ;

: xref_init     ( -- )          \ initialization needed for SYMBOL.SEQ
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize the margins
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                hashptrs hashmax 2* erase
                2 !> headptr                    \ must not start at zero
                headseg 0= abort" Failed to allocate Symbol memory!"
                headseg !> head_segment
                headseg     0 32768 0 LFILL
                headseg 32768 32768 0 LFILL
                ;



L: ,            ( n1 -- )
                here !
                2 allot ;       compiler executes> ,-d target

0 value xrefcnt

: xref_create   ( a1 -- )
\                dup 1+ c@
\                dup  '0' '9' between
\                over 'A' 'Z' between or
\                swap 'a' 'z' between or
\                over c@ 1 > or
                dup c@          \ 11/06/92 14:40 tjz added
                if      dup $header 0 , loadline @ 1- 0max ,
                then    drop ;

: +xref         ( a1 -- )      \ a1=symbol address
                headseg swap >data @L
                begin   dup @ ?dup
                while   nip
                repeat  here swap ! 0 , loadline @ 1- 0max , ;

: xref_symbol   ( a1 -- )
                incr> xrefcnt
                xrefcnt 127 and 0=
                if      ." ." ?cr
                then
                $find
                if      +xref
                else    xref_create
                then    ;

256 array param(s)buf
 32 array parambuf
 32 array labelbuf

: do_1param     ( -- )
                parambuf c@ 0= ?exit
                $2020 parambuf count + !                \ blank terminate
                parambuf xref_symbol
                parambuf off ;

: process_param(s) ( -- )
                parambuf off
                param(s)buf count
                begin   bl skip
                        2dup   bl scan
                        2over ',' scan dmax
                        2dup 2>r nip -
                        parambuf place
                        do_1param
                        2r> 1 /string dup 0=
                until   2drop ;

: process_label ( -- )
                labelbuf count + c@ ':' = labelbuf c+!  \ remove ':' if there
                $2020 labelbuf count + !                \ blank terminate
                process_opcode ;

: process_opcode ( -- )
                labelbuf c@ 0= ?exit
                labelbuf xref_symbol ;

: %xref         ( -- )          \ cross reference the current file
                begin   lineread
                        dup c@ over 1+ c@ 8 = swap 0= or 0=
                        here $F801 u< and
        [long]  while   crlf>bl's count
                        13 /string
                        over dup c@ bl = swap 1+ c@ bl <> and
                        if      1 /string
                        then
                        over c@ upc
                        dup  '0' '9' between
                        swap 'A' 'F' between or \ if hex character in column
        [long]     if   12 /string              \ strip upto column 25
                        2dup ';' scan nip -             \ discard after ';'
                        2dup '\' scan nip -             \ or '\'
                        begin   2dup '(' scan ?dup
                        while   2swap 2drop 1 /string
                        repeat  drop
                        dup
        [long]          if      over c@ bl <>           \ check for ref?
                                if      2dup 2dup
                                        bl scan nip -   \ parse out a word
                                        labelbuf place  \ put at here
                                        process_label
                                        bl scan
                                then    bl skip 2dup
                                        bl scan 2dup 2>r nip -
                                        labelbuf place
                                        process_opcode
                                        2r> bl skip
                                        param(s)buf place
                                        process_param(s)
                        else    2drop
                        then    ?keypause
                   else 2drop
                   then
                repeat  drop ;

handle xrefhndl

: xref          ( -<filename>- )
                bl word count xrefhndl place
                " LST" ">$ xrefhndl $>ext
                xrefhndl $file
                if      cr
                        cr ."  Couldn't open file: " xrefhndl count type
                        79 sp>col
                        cr
                        cr ."  This file is needed when building a Cross Reference Listing!  "
                        79 sp>col
                        cr ."  Be sure you are compiling or assembling with the /LST option. "
                        79 sp>col
                        cr abort
                then    %xref
                here $F800 u>
                if      cr ." Stopped symbol collection early, out of memory"
                then    ;

: .id           ( symaddr -- )
                headseg swap l>name countl here placel
                here count type space ;

: .xref.name    ( symaddr -- )
                cr space dup>r .id 18 sp>col    \ display the name
                headseg r@ >data @L
                begin   #out @ 70 >
                        if      cr space r@ .id 18 sp>col
                        then
                        dup 2+ @ 7 u.r
                        @ ?dup 0=
                until   r>drop ;

$4000.  POINTER SORT-PTRS       \ 16K bytes for sorting EQU's and labels.
CREATE GAP      2 ,             \ Used to speed-up sort
CREATE -SWITCH  0 ,             \ Indicates if an exchange occurs in sorting
CREATE SORT-CNT 0 ,             \ Number of elements to be sorted

CODE HEAD-COMP       ( nfa1 nfa2 -- -1 | 0 | 1 )  \ Compare two heads
\ Compare two names in head space.  If equal, return 0.
\ If str1 < str2, return -1.  If str1 > str2, return 1 .
                MOV DI, BX
                LODSW
                MOV DX, SI
                MOV SI, AX
                PUSH DS
                PUSH ES
                MOV ES, &> HEAD_SEGMENT
                MOV DS, &> HEAD_SEGMENT
                MOV CL, 0 [SI]
                MOV CH, 0 [DI]
                AND CX, # $1F1F
                CMP CL, CH
              > IF      MOV CL, CH              /nostack1
                        MOV BX, # 1
                ELSE    CMP CL, CH
                      < IF      MOV BX, # -1    /nostack1
                        ELSE    MOV BX, # 0
                        THEN
                THEN
                SUB CH, CH
                INC DI
                INC SI
                REPZ CMPSB
            0<> IF                              /nostack1
                     0< IF      MOV CX, # -1    /nostack1
                        ELSE    MOV CX, # 1
                        THEN
                ELSE    MOV CX, BX
                THEN
                POP ES
                POP DS
                MOV SI, DX
                MOV BX, CX
                RET             END-CODE

: ?SWITCH   ( offset -- )               \ Possibly switch two pointers
        sort-ptrs swap 2dup gap @ + @L >r
        2dup @L r>
        2dup head-comp 1 =
        IF      swap >r >r 2dup r> -rot !L
                gap @ + r> -rot !L
                -switch off
        ELSE    2drop 2drop
        THEN ;

: SORT1   ( -- )                        \ Sort a sequence of head names
        sort-cnt @ gap @ - dup 2 <
        IF      drop exit
        THEN    0
        DO      i ?switch
        2 +LOOP ;

code largest    ( a1 n1 --- a2 n2 )
                mov cx, bx      \ count of array to search
                load_bx         \ starting address of array
                mov ax, # 0     \ starting highest value = 0
                mov dx, bx      \ highest value addr = start address
          0 $:  cmp 0 [bx], ax
             u> if      mov dx, bx              /nostack1
                        mov ax, 0 [bx]
                then
                add bx, # 2     \ bump to next element
                loop 0 $
                mov bx, dx
                save_bx
                mov bx, ax
                ret             end-code

: GET-SORT-PTRS   ( -- )      \ Move vocabulary names into sort buffer area
        0 sort-cnt !
        hashptrs here 200 + hashmax 2* cmove
        BEGIN   here 200 + hashmax largest dup
        WHILE   dup l>name sort-ptrs sort-cnt @ !L
                2 sort-cnt +!
                headseg swap @L swap !
        REPEAT  2drop ;

: sortxref      ( -- )
        get-sort-ptrs
        sort-cnt @ gap !
        BEGIN   gap @ dup 2 + 2/ 2/ - 2 umax $0fffe and gap !
                -switch on sort1
                -switch @ gap @ 2 = and
                ." ." ?cr
        UNTIL   ;

: .xref         ( -- )          \ Print a sequence of names
                at?
                sort-cnt @ 0
        [long]  ?DO     i 63 and 0=
                        if      save> #out
                                save> #line
                                false save!> printing
                                at ." ." ?cr at?
                                restore> printing
                                restore> #line
                                restore> #out
                        then
                        sort-ptrs i @L name>l .xref.name
                        ?keypause
        [long]  2 +LOOP cr cr at ;

1024 array xref_buf
   0 value xref_cnt

: xref_flush    ( -- )
                xref_cnt 0= ?exit
                xref_buf xref_cnt xrefhndl hwrite drop
                off> xref_cnt ;

: xref_emit     ( c1 -- )
                printing @
                if      xref_cnt 1023 >
                        if      xref_flush
                        then
                        xref_buf xref_cnt + c!
                        incr> xref_cnt
                        incr> #out
                else    dosemit
                then    ;

: xref_crlf     ( -- )
                $0D emit $0A emit
                #out off #line incr ;

: MAIN          ( -- )
                xref_init
                #tib @ 0<>
        [long]  if      cr ." Building Cross Reference in Memory"
                        xref
                        cr ." Sorting  Cross Reference List"
                        sortxref
                        cr ." Writing  Cross Reference List to Disk..."
                        " XRF" ">$ xrefhndl $>ext
                        xrefhndl hcreate abort" Failed to create .XRF file"
                        ['] xref_emit is emit
                        ['] xref_crlf is cr
                        off> xref_cnt
                        printing on .xref printing off
                        xref_flush
                        xrefhndl hclose drop
                        ." Done!"
                else    cr ." No filename specified"
                then    cr ;

