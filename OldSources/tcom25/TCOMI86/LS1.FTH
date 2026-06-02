\\ LIST1.SEQ            TCOM Listing Generator         by Jerry Boutelle
   =====================================================================

        This program produces a listing file for a program that has
        been compiled with TCOM.

Revision history:

 12/04/91 17:03:17.19 tjz
        Added a display of the total code and data bytes in target file.
        This information is obtained from the special NULL symbol record.
        See TCOMNDX.SEQ in the compiler for more information on this.

 12/09/91 16:52:31.05 tjz
        Modified >OPR-COL to guarantee there would be at least one space
        following the instruction just displayed, even if a very long
        label had forced the display over to beyond the destination column
        being passed to >OPR-COL.  >OPR-COL is used by both LS8 & LS56
        after displaying the instruction, to move to the operand column.

 01/15/92 17:13:11.65 tjz
        Added CODE-WORD-TYPE and CODE-BYTE-TYPE, as replacements for
        :WORD-TYPE and :BYTE-TYPE which are not used by the compiler. These
        types are 12 & 13 in the index record type table. They are used to
        display a byte or word from target space when a DB ow DW is used to
        define bytes or words into CODE space on a 8086.

 02/06/92 17:10 tjz
        Added error checking code to "%GET-FIL-NAME" to check that the
        index record source file number is not greater than the number of
        files in the .FIL file.

 02/13/92 09:55 tjz
        Changed FIRST-INX-SEG and SECOND-INX-SEG from EMM-POINTER words
        to POINTER words.

 04/15/92 13:44 tjz
        Modified .1SYMBOL to put a ":" into the display for symbols that
        are subroutines.  This makes them easier to identify in the
        symbol table.

{

\fpc    ' :             alias ::
\fpc    ' (type)        alias %type
\fpc    ' if            alias if_L    immediate
\fpc    ' while         alias while_L immediate
\fpc    ' ?do           alias ?do_L   immediate
\fpc    ' +loop         alias +loop_L immediate
\fpc    ' loop          alias loop_L  immediate
\fpc    ' ?cs:          alias ?ds:

}
                       ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
                       ³ Code memory access³
                       ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

{

0 value CPTR \ the instruction code pointer

                \tcom   0 value OBJ-SEG      \ segment address of object data
\- obj-seg      \fpc    10000. pointer obj-seg
\- ext-seg      \fpc    10000. pointer ext-seg

DEFER D-DATAC@          \ target data byte fetch word

: D-TC@ ( <target address> -- <target byte> )
        obj-seg swap c@l ;

: D-T@ ( <target address> -- <target word> )
        obj-seg swap @l flip ;

: +CPTR ( -- )
        incr> cptr ;

: NTW ( -- <next target word> )
      +cptr cptr d-t@ +cptr ;

}

                       ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
                       ³List file optput control³
                       ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

{

 7 constant PC-COL

13 constant DIS-ASM-COL

25 constant SRC-COL

33 constant INST-COL

41 constant OPER-COL

: >opr-col ( -- )
        space                 \ 12/09/91 16:34:36.76 tjz
                              \ we need at least one space after instruction
        oper-col sp>col ;

: SCREEN-OUTPUT ( -- )
        ['] (emit)  is emit
        ['] %type   is type
        ['] crlf    is cr ;

defer FILE-OUTPUT
\fpc ' noop is file-output

0 value LINE#

32 constant #SRC-FILES                  \ the maximum number of source files
                                        \ allowed in the .fil file
create SRC-LINE#-TABLE                  \ holds the highest read line in
        #src-files 2* allot             \ a source file

0 value SRC-LINE#-PTR                   \ address of line# of file being read

0 value MSG-LINE

0 value ERROR-PRINTED

: 0.R ( n l -- ) \ Output as a signed single number
                 \ right justified with zeros on the left
        >r 0 <# r> 1- 0max 0 ?do # loop # #> type ;

defer .LINE#

: .PROGRAM-COUNTER ( -- )
        pc-col sp>col
        hex
        cptr
        4 0.r ;

: PREAMBLE ( -- )
        .line#
        .program-counter ;

\ === source file =======================================================

64 constant FILE-NAME-LENGTH

create FILE-NAME file-name-length 1+ allot \ holds listing file name

64 constant FIL-NAME-LEN

create SRC-FILE-NAME fil-name-len 1+ allot

handle FIL-FILE-HANDLE

: CLOSE-FIL-FILE ( -- )
        fil-file-handle hclose drop ;

defer CLOSE-FILES
\fpc ' noop is close-files

: LS-ABORT ( -- )
        close-files                             \ close files
        cursor-on
        decimal
        abort ;

0 value CR-NEEDED?      \ need a cr after "creating list file ..." ?

: DO-CR? ( -- )
        cr-needed?
        IF cr
           false !> cr-needed?
        THEN ;

: OPEN-FIL-FILE ( -- )
        close-fil-file
        " fil" ">$ file-name $>ext              \ get the file name
        file-name fil-file-handle $>handle
        fil-file-handle hopen
        IF screen-output
           do-cr?
           ." Couldn't open file name file, extension: .fil"
           ls-abort
        THEN ;

create SRC-OFFSET-TABLE                 \ holds the highest read offset in
        #src-files 8 * allot            \ a source file

0 value SRC-OFFSET                      \ address of offset of line being read

: SRC-LOW-OFFSET                        \ for open file
     src-offset 4 + ;

0 value SRC-FILE#                       \ source file number, index to .fil

defer .ERRORS

defer inx-file#>

defer print-upto-index-record

: COPY-TO-END   ( -- )
        BEGIN lineread c@
        WHILE 1 src-line#-ptr +!
          false !> error-printed
          preamble
          src-col sp>col
          outbuf crlf>bl's count type cr \ copy rest of file
          .errors
        REPEAT ;

0 value CREATING-LISTING?

: CLOSE-SRC-FILE ( -- )
        creating-listing?
        src-file# inx-file#> > and
        IF copy-to-end
        THEN
        seqhandle hclose drop ;

defer get-fil-name

\tcom long_branch
: OPEN-SRC-FILE ( -- )
        inx-file#>                              \ is there really a file ?
        IF src-file# inx-file#> <>              \ is the source file open ?
           IF close-src-file
              inx-file#>
              get-fil-name
              src-file-name $file               \ open the source file
              IF screen-output
                 do-cr?
                 ." Couldn't open source file: "
                 src-file-name count type cr
                 ls-abort
              THEN
              inx-file#> dup !> src-file#
              8 * src-offset-table +
              dup !> src-offset                 \ update pointer to src off
              2@ seqhandle
              movepointer                       \ position to last read
              ibreset
              inx-file#> 2* src-line#-table +
              !> src-line#-ptr                  \ update pointer to src line#
              creating-listing?
              IF preamble src-col sp>col
                 ." +++++++ Compiling line "
                 decimal src-line#-ptr @ 1+ .
                 ." from " src-file-name count upper
                 src-file-name count type cr
              THEN false !> error-printed
           THEN
        THEN ;
\tcom short_branch

\ ==== index file ====================================================

0 value INX-REC-PTR             \ the address of the an index record in
                                \ either of the index record buffers

0 value INX-REC-LOOKAHEAD?      \ true if the index record has been read

\tcom $100 constant INX-BUF-PAR  \ paragraphs to allot
\- inx-buf-par \fpc  $1c ( $ff0 ) constant INX-BUF-PAR  \ paragraphs to allot
                                 \ WARNING: inx-buf-par should not be 64k/16!
                                 \          not greater than: 65520

\tcom 0 value TCOM-INX-SEG

\tcom : TCOM-INX-SEG-SUBROUTINE TCOM-INX-SEG ;

defer INX-SEG

\- first-inx-seg  \fpc  inx-buf-par 16 *d pointer first-inx-seg
\- second-inx-seg \fpc  inx-buf-par 16 *d pointer second-inx-seg

inx-buf-par 16 * constant INX-BUF-LEN   \ bytes in the buffer

6 constant INX-BYTES/REC                \ bytes per record

                                        \ records per buffer
inx-buf-len 0 inx-bytes/rec um/mod nip constant INX-RECS/BUF

                                        \ rounded bytes in the buffer
inx-recs/buf inx-bytes/rec * constant INX-BYTES/BUF

handle INX-FILE-HANDLE

: INX-ADR> ( -- <index address> )
        inx-seg inx-rec-ptr @l ;

: INX-TYPE> ( -- <index type> )
        inx-seg inx-rec-ptr 2+ c@l
        2/ 2/ 2/ 2/ $f and ;

: INX-SRC-HI> ( -- <high byte of index source pointer> )
        inx-seg inx-rec-ptr 2+ c@l
        $f and ;

: INX-SRC-LOW> ( -- <low word of index source pointer> )
        inx-seg inx-rec-ptr 3 + @l ;

: %INX-FILE#> ( -- <file code> )
        inx-seg inx-rec-ptr 5 + c@l ;

: READ-INX-FILE ( -- )
        0 inx-bytes/buf inx-file-handle inx-seg
        exhread drop
        rwerr @
        IF screen-output
           do-cr?
           ." an inx file read failed !"
           ls-abort
        THEN ;

: ALLOC-INX-MEMORY ( -- )
\fpc    first-inx-seg drop ;                   \ ems for first inx seg
\tcom   inx-buf-par alloc 8 =
\tcom   if screen-output
\tcom      do-cr?
\tcom      ." No memory for the index file"
\tcom      ls-abort
\tcom   THEN nip !> tcom-inx-seg ;              \ thanks for the memory

\fpc : ALLOC-SECOND-INX-MEMORY ( -- )
\fpc    second-inx-seg drop ;                   \ ems for second inx seg

0 value #INX-RECORDS                            \ the number of index records

0 value INX-REC-COUNTER                         \ counts index records

\fpc 0 value FIRST-INX-SEG?                     \ true if using first segment

: CLOSE-INX-FILE ( -- )
        inx-file-handle hclose drop ;

: OPEN-INX-FILE ( -- )
        close-inx-file
        " inx" ">$ file-name $>ext              \ get the file name
        file-name inx-file-handle $>handle
        inx-file-handle hopen
        IF screen-output
           do-cr?
           ." Couldn't open index file, extension: .inx"
           ls-abort
        THEN
        inx-file-handle endfile
\fpc    2dup inx-bytes/buf 0 2dup d+ d>
\fpc    IF screen-output
\fpc       do-cr?
\fpc       ." Index file to large"
\fpc       ls-abort
\fpc    THEN
        inx-bytes/rec um/mod 1 umax
        !> #inx-records drop                    \ compute the file size
        0.0 inx-file-handle movepointer
        alloc-inx-memory
\fpc    ['] first-inx-seg is inx-seg
\fpc    true !> first-inx-seg?
\tcom   ['] tcom-inx-seg-subroutine is inx-seg
        read-inx-file                           \ read into first buffer
\fpc    #inx-records inx-recs/buf u>
\fpc    IF save> inx-seg
\fpc       alloc-second-inx-memory
\fpc       ['] second-inx-seg is inx-seg        \ point at second segment
\fpc       read-inx-file                        \ read into second buffer
\fpc       restore> inx-seg
\fpc    THEN
        0 !> inx-rec-ptr
        -1 !> inx-rec-counter ;

0 value #SYM-RECORDS            \ needed by SPINNER

0 value spinval

2variable starting_time

: .REMAINING    ( -- )          \ display remaining time in minutes:seconds
                space
                gettime t>b starting_time 2@ d- b>sec   \ seconds elapsed
                dup>r
                spinval u2/ 1000 *d
                #inx-records #sym-records + u2/ um/mod nip      \ % complete
                1000 100 rot */ 100 */ r> - 0max
                60 /mod swap 0 <# # # ':' hold 2drop 0 # # #> type
                ."  min:sec remaining " ;

: SPINNER ( -- )
        spinval 63 and incr> spinval ?EXIT      \ leave mostly
        save> #out
        at?
        screen-output
        save> base decimal
        #inx-records 15000 u>
        IF ." [" spinval u2/ 1000 *d
           #inx-records #sym-records + u2/ um/mod nip
           1000 min 0 <# # '.' hold #s #> type ." %]"
        ELSE ." [" spinval 100 #inx-records #sym-records + */
           100  min 1 .r ." %]"
        THEN
\        #inx-records #sym-records + u2/ 10 / spinval <
\        #inx-records 3000 u> and
\        IF      .remaining
\        THEN
        restore> base
        file-output
        at
        restore> #out ;

: NEXT-INX-RECORD ( -- )
        spinner
        inx-rec-counter 0>=
        IF inx-rec-lookahead?
           IF false !> inx-rec-lookahead?               \ don't advance
           ELSE 1 +!> inx-rec-counter
              inx-bytes/rec +!> inx-rec-ptr             \ bump pointer
              inx-rec-ptr inx-bytes/buf u>=
\fpc          first-inx-seg? and
              IF 0 !> inx-rec-ptr                       \ back to beginning
\fpc             second-inx-seg is inx-seg              \ switch buffers
\fpc             false !> first-inx-seg?                \ indicate switch
\tcom            read-inx-file                          \ refill buffer
              THEN
           THEN
        ELSE 0 !> inx-rec-counter
        THEN ;

0 value line-printed

: GET-SRC-LINE ( -- )
        lineread c@ 0                   \ get the next source line
        1 src-line#-ptr +!
        false !> error-printed
        src-offset 2@                   \ get the old line's right offset
        2dup src-low-offset 2!          \ this is the new line's left offset
        d+ src-offset 2!                \ compute and save new right offset
        false !> line-printed ;         \ the new line has not been printed

: PRINT-SRC-LINE ( -- )
        preamble
        src-col sp>col
        outbuf crlf>bl's count type cr
        true !> line-printed
        .errors ;

\tcom long_branch
: %PRINT-UPTO-INDEX-RECORD ( -- ) \ print upto ( not including ) the source
                                  \ line of the current index record
        inx-file#> 0= ?exit             \ is the indx rec file numb non-zero ?
        inx-src-low> inx-src-hi>        \ get the src offset of the index rec
        2dup src-low-offset 2@          \ get the src line's left offset
        d> >r                           \ is index off greater than src left ?
        2dup src-offset 2@              \ get the src line's right offset
        d< r> and                       \ and indx off less that src right ?
        line-printed
        and                             \ and has the line been printed ?
        IF 2drop exit                   \ exit, no need to reprint the line
        THEN
        BEGIN get-src-line              \ the the next source line
           outbuf c@ 0=                 \ is the line null, the end of file ?
           IF 2drop exit                \ exit, the file is exausted
           THEN 2dup src-offset 2@
           d>                           \ is indx off greater than src left ?
        WHILE print-src-line
        REPEAT 2drop ;                  \ rid index record offset
\tcom short_branch

\tcom long_branch
: PRINT-TO-INDEX-RECORD ( -- ) \ print to ( including ) the source line
                               \ of the current index record
        print-upto-index-record
        line-printed ?exit
        print-src-line ;

: LST-HELP ( -- )
        do-cr?
        ." filename [/lst]        - to produce a listing file" cr ;

: LIB-HELP ( -- )
        do-cr?
        ."          [/ll|/lib]    - to include library source" cr
        ."          [/nll|/nolib] - to exclude library source" cr ;

: FULL-HELP ( -- ) \ display help
        lst-help
        lib-help ;

\ the symbolic name of the command tail switches
1 constant LST-SWITCH
2 constant LST-LIBRARY-SWITCH
3 constant NO-LST-LIBRARY-SWITCH

3 constant #/SWITCHES

0 value /SWITCH                                 \ holds /switch index code

: HELP-THEM ( -- )
        /switch 0max #/switches min
        exec: full-help lst-help full-help full-help ;

\ ==== file file =====================================================

0 value FIL-REC-PTR

64 constant FIL-BYTES/REC

10 constant FIL-RECS/BUF

fil-recs/buf fil-bytes/rec * constant FIL-BYTES/BUF

fil-bytes/buf constant FIL-BUF-LEN

\tcom long_branch
: %GET-FIL-NAME ( <file file code> -- ) \ .fil is open
        ?dup                            \ get the file code from the index
        IF dup #src-files >             \ is file# larger than # source files?
           IF screen-output
              do-cr?
              . ." is too many source files, target addr=" inx-adr> h. cr
              ls-abort
           THEN dup>r 1- fil-name-len um*
           fil-file-handle
           movepointer                  \ position fil file to file name
           src-file-name 1+
           fil-name-len
           fil-file-handle
           hread fil-name-len <>
           IF screen-output
              do-cr?
              ." Index file# "
              r@ . ." is greater than the number of files in the .FIL file."
              cr ls-abort
           THEN r>drop
           src-file-name 1+
           fil-name-len 0
           DO dup i + c@ bl =           \ the name really has to be there
              IF i leave
              THEN
           LOOP nip src-file-name c!   \ place length of the file name
        THEN ;
\tcom short_branch

: RESET-FIL-FILE ( -- )
        0 0 fil-file-handle
        movepointer ;                   \ move to the start of the file

create FIL-NAMES FIL-BYTES/BUF allot

0 value #FIL-RECORDS

: READ-FIL-FILE ( -- )
        fil-names fil-bytes/buf fil-file-handle
        hread
        rwerr @
        IF screen-output
           do-cr?
           ." an fil file read failed !"
           ls-abort
        ELSE 0 fil-bytes/rec um/mod nip !> #fil-records
        THEN ;

0 value FIL-NAME-COUNTER

0 value MSG-FILE

64 array temp.fil       \ big enough for file with path

: NAME-.FIL     ( n1 -- a1 )
                fil-bytes/rec * fil-names + 64 2dup bl scan nip -
                temp.fil place
                temp.fil >pathend" temp.fil place
                temp.fil ;

\tcom long_branch
: SEARCH-FIL-NAMES ( -- <bool> ) \ string at here, returns true if found
           0                            \ assume false
           #fil-records 0
           DO  i name-.fil here dup c@ 1+ caps-comp 0=
              IF i fil-name-counter + 1+ !> msg-file
                 0= leave
              THEN
           LOOP ;
\tcom short_branch

\ === message file =======================================================

32 constant #ERROR-MSGS

0 value MSG-FILE-PTR

create ERROR-LINES-TABLE  #error-msgs 2* allot

create ERROR-FILES-TABLE  #error-msgs 2* allot

create ERROR-MSGPTR-TABLE #error-msgs 2* allot

\- msg-file-handle      bhandle MSG-FILE-HANDLE

: CLOSE-MSG-FILE ( -- )
        msg-file-handle bclose drop ;

: OPEN-MSG-FILE ( -- )
        " msg" ">$ file-name $>ext              \ get the file name
        file-name msg-file-handle $>bhandle
        msg-file-handle bopen
        IF screen-output
           help-them
           ." Couldn't open msg file, extension: .msg"
           ls-abort
        THEN ;

: GET-MSG-FILE ( --)
        reset-fil-file                  \ move to first record of the fil file
        0 !> fil-name-counter
        BEGIN read-fil-file
           #fil-records
        WHILE
           search-fil-names
           IF exit
           THEN #fil-records +!> fil-name-counter
        REPEAT 0 !> msg-file ;

: GET-MSG-LINE-NUMBER ( -- )
        save> base decimal
        bl here count + c!                      \ append a blank to number
        here number? 2drop !> msg-line          \ convert number
        restore> base ;

create MSG-LINE-BUF 81 allot

0 value MSG-LINE-PTR

\tcom long_branch
: NEXT-MSG-RECORD ( -- )
        BEGIN msg-file-ptr !> msg-line-ptr
           msg-file-handle blineread ?dup
        WHILE dup +!> msg-file-ptr
           dup msg-line-buf c!
           ?ds: msg-line-buf 1+ rot 80 min
           cmovel msg-line-buf 1+ " *error*"
           compare 0=                        \ be negative, look at errors
           IF msg-line-buf crlf>bl's
              count bl scan bl skip             \ skip "*error*"
              2dup '(' scan 2dup 2>r nip -      \ parse filename upto "("
              here place                        \ put at here counted
              get-msg-file
              2r> 1 /string 2dup ')' scan nip - \ parse out line #
              here place                        \ put it at here counted
              get-msg-line-number
              EXIT
           THEN
        REPEAT 2drop
        -1 !> msg-line ;                      \ at end of message file
\tcom short_branch

0 value #errors

\tcom long_branch
: BUILD-MSG-TABLES ( -- )
        0 !> msg-file-ptr
        #error-msgs 0
        DO next-msg-record
           msg-line -1 = ?LEAVE
           msg-line error-lines-table i 2* + !
           msg-file error-files-table i 2* + !
           msg-line-ptr error-msgptr-table
           i 2* + !
           i 1+ !> #errors
        LOOP ;
\tcom short_branch
\ ==== symbol file ===================================================

0 value SYM-REC-PTR

$FF0 constant SYM-BUF-PAR \ paragraphs to allot
                                \ WARNING: sym-buf-par should not be 64k/16!
                                \          not greater than: 65520/16
\tcom   0 value SYM-SEG
\- sym-seg \fpc    sym-buf-par 16 *d pointer sym-seg

sym-buf-par 16 * constant SYM-BUF-LEN   \ bytes in the buffer

48 constant SYM-BYTES/REC               \ bytes per record

                                        \ records per buffer
sym-buf-len 0 sym-bytes/rec um/mod nip constant SYM-RECS/BUF

                                        \ rounded bytes in the buffer
sym-recs/buf sym-bytes/rec * constant SYM-BYTES/BUF

: ALLOC-SYM-MEMORY ( -- )
\fpc    sym-seg drop exit ;
\tcom   sym-buf-par alloc 8 =
\tcom   if screen-output
\tcom      do-cr?
\tcom      ." No memory for the symbol file"
\tcom      ls-abort
\tcom   THEN nip !> sym-seg ;                   \ thanks for the memory

handle SYM-FILE-HANDLE

: CLOSE-SYM-FILE ( -- )
        sym-file-handle hclose drop ;

: OPEN-SYM-FILE ( -- )
        close-sym-file
        " sym" ">$ file-name $>ext              \ get the file name
        file-name sym-file-handle $>handle
        sym-file-handle hopen
        IF screen-output
           help-them
           ." Couldn't open symbol file, extension: .sym"
           ls-abort
        THEN sym-file-handle endfile sym-bytes/buf 0 d>
        IF screen-output
           do-cr?
           ." Symbol file is to large, using first "
           sym-bytes/buf 0 sym-bytes/rec um/mod nip u. ." symbols" cr
           file-output
        THEN 0.0 sym-file-handle movepointer ;

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

0 value SYM-INDEX

: READ-SYM-FILE ( -- )
        0 sym-bytes/buf sym-file-handle sym-seg
        exhread
        rwerr @
        IF screen-output
           do-cr?
           ." a sym file read failed !"
           ls-abort
        ELSE 0 sym-bytes/rec um/mod nip dup !> #sym-records
           !> sym-index
        THEN ;

6 constant FUNCTION-SYM-TYPE

0 value SYM-SEG-ADR

code A-FUNCTION-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
\fpc    pop     bx
        push    es
\tcom   mov     ax, &> sym-seg
\fpc    mov     ax, ' sym-seg-adr >body
        mov     es, ax
\tcom   mov     ax, &> #sym-records
\fpc    mov     ax, ' #sym-records >body
        mov     cx, # sym-bytes/rec
        mul     cx
        mov     dx, # function-sym-type
        xor     di, di
   1 $: cmp     bx, es: 33 [di]
        jne     2 $
        cmp     dl, es: 32 [di]
        jne     2 $
\tcom   mov     &> sym-rec-ptr di
\fpc    mov     ' sym-rec-ptr >body di
        pop     es
\tcom   mov     bx, # -1
\tcom   ret
\fpc    mov     ax, # -1
\fpc    1push
   2 $: add     di, cx
        cmp     ax, di
        jne     1 $
        pop     es
\tcom   xor     bx, bx
\tcom   ret
\fpc    xor     ax, ax
\fpc    1push
end-code

0 #if
\tcom long_branch
: A-FUNCTION-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
        0 swap                          \ assume false
        #sym-records sym-bytes/rec * 0
        do dup
           sym-seg 33 i + @l =          \ get symbol resolve adr
           IF sym-seg 32 i + c@l           \ get symbol type
              function-sym-type =
              IF swap not swap
                 i !> sym-rec-ptr
                 leave
              THEN
           THEN sym-bytes/rec
        +loop drop ;
\tcom short_branch
#then

1 constant CONSTANT-SYM-TYPE
2 constant 2CONSTANT-SYM-TYPE
4 constant VARIABLE-SYM-TYPE
5 constant VALUE-SYM-TYPE
7 constant DEFER-SYM-TYPE
8 constant TABLE-SYM-TYPE

code A-DATA-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
\fpc    pop     bx
        push    es
\tcom   mov     ax, &> sym-seg
\fpc    mov     ax, ' sym-seg-adr >body
        mov     es, ax
\tcom   mov     ax, &> #sym-records
\fpc    mov     ax, ' #sym-records >body
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
\tcom   xor     bx, bx
\tcom   ret
\fpc    xor     ax, ax
\fpc    1push
\tcom 3 $:  mov     &> sym-rec-ptr di
\fpc  3 $:  mov     ' sym-rec-ptr >body di
        pop     es
\tcom   mov     bx, # -1
\tcom   ret
\fpc    mov     ax, # -1
\fpc    1push
end-code

0 #if
\tcom long_branch
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
              IF swap not swap
                 i !> sym-rec-ptr
                 leave
              THEN
           THEN sym-bytes/rec
        +loop drop ;
\tcom short_branch
#then

code +A-DATA-SYMBOL? ( <target adr> -- <bool> ) \ true if in symbol table
\fpc    pop     bx
        push    es
\tcom   mov     ax, &> sym-seg
\fpc    mov     ax, ' sym-seg-adr >body
        mov     es, ax
\tcom   mov     ax, &> #sym-records
\fpc    mov     ax, ' #sym-records >body
        mov     cx, # sym-bytes/rec
        mul     cx
\tcom   mov     di, &> sym-rec-ptr              \ load current pointer
\fpc    mov     di, ' sym-rec-ptr >body         \ ditto for F-PC
        cmp     ax, di                          \ are we at symbol limit
        je      4 $                             \ if we are, then exit
        jmp     2 $                             \ else go increment pointer
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
   4 $: pop     es
\tcom   xor     bx, bx
\tcom   ret
\fpc    xor     ax, ax
\fpc    1push
\tcom 3 $:  mov     &> sym-rec-ptr di
\fpc  3 $:  mov     ' sym-rec-ptr >body di
        pop     es
\tcom   mov     bx, # -1
\tcom   ret
\fpc    mov     ax, # -1
\fpc    1push
end-code

\ ==== list file =====================================================

\- lst-file-handle      bhandle LST-FILE-HANDLE

: CLOSE-LST-FILE ( -- )
        creating-listing?
        IF lst-file-handle bflush
        THEN lst-file-handle bclose drop ;

: OPEN-LST-FILE ( -- )
        creating-listing?
        IF " lst" ">$ file-name $>ext              \ get the file name
           file-name lst-file-handle $>bhandle
           lst-file-handle
           bcreate                              \ create a new file for list
           IF screen-output
              do-cr?
              ." Couldn't open list file"
              ls-abort
           THEN
        THEN ;

\ : OPEN-LST-FILE ( -- )
\         " lst" ">$ file-name $>ext              \ get the file name
\         file-name lst-file-handle $>bhandle
\         lst-file-handle
\         creating-listing?
\         IF bcreate                              \ create a new file for list
\         ELSE bopen                              \ open existing file
\         THEN
\         IF screen-output
\            do-cr?
\            ." Couldn't open list file"
\            ls-abort
\         THEN ;

\ ====================================================================

\fpc : EXBWRITE ( <adr> <cnt> <handle> <seg> -- )
\fpc         nip             \ rid handle
\fpc         -rot typel ;

0 value ERROR-LINE-POS

: ERROR-LINE? ( -- <bool> )
        error-lines-table #errors src-line#-ptr @ scanw nip dup
        IF #errors swap - 2*                \ word to byte offset
           dup error-files-table + @
           src-file# =
           IF -1 over error-lines-table + ! \ mangle error line number
                                            \ so it will not be found again
              error-msgptr-table + @
              !> error-line-pos true
           ELSE drop false
           THEN
        ELSE drop false
        THEN ;

: %.ERRORS ( -- )
        error-printed 0=
        IF BEGIN error-line?
           WHILE error-line-pos 0 msg-file-handle bmovepointer
              msg-file-handle blineread rot >r
              lst-file-handle r> exbwrite          \ write the error message
              true !> error-printed
           REPEAT
        THEN ;

: %.LINE# ( -- )
        line#
        decimal
        5 u.r
        1 +!> line# ;

: h.\   ( n -- )
        base @ >r hex (u.) type r> base ! ;

: .DA1 ( -- )
        ntw dup a-function-symbol?
        IF drop
           sym-name> 1+ sym-seg over 1- c@l
           lst-file-handle sym-seg
           exbwrite
        ELSE h.\
        THEN ;

: .IM ( <im> -- )
        ." #"
        h. ;
\         dup a-data-symbol?                           \ in symbol table ?
\         IF drop
\            sym-name> 1+ sym-seg over 1- c@l
\            lst-file-handle sym-seg
\            exbwrite
\         ELSE h.
\         THEN ;

: .IML ( -- )
        ." #"
        ntw h. ;
\         ntw dup a-data-symbol?          \ in symbol table ?
\         IF drop
\            sym-name> 1+
\            sym-seg over 1- c@l
\            lst-file-handle sym-seg
\            exbwrite
\         ELSE h.
\         THEN ;

: LST-EMIT ( <char> -- )
        incr> #out
        sp@ 1 lst-file-handle bwrite drop ;

: LST-TYPE ( <adr> <count> -- )
        dup +!> #out
        lst-file-handle bwrite ;

: LST-CR ( -- )
        off> #out                       \ reset column to zero
        $0A0D sp@ 2 lst-file-handle bwrite drop ;

\tcom : %FILE-OUTPUT ( -- )
\tcom   ['] lst-emit   is emit
\tcom   ['] lst-type   is type
\tcom   ['] lst-cr     is cr ;

2variable LAST-SEG-OFF  \ src offset of last segment index rec

: SOURCE-CATCHUP ( -- )
        inx-adr> !> cptr
        print-to-index-record ;

defer disasm

: .function-symbol ( -- )
        sym-name> 1+ sym-seg
        over 1- c@l
        dup +!> #out
        lst-file-handle sym-seg
        exbwrite                     \ label a line with function name
        space ;

: INST ( -- ) \ disassemble a single instruction at the code pointer
        cptr a-function-symbol?
        if      .function-symbol
        then    cptr d-tc@              \ get the opcode of the instruction
        inst-col sp>col                 \ move the the instruction column
        disasm ;                        \ disassemble the instruction

: .BYTES ( <n> -- )
        1- 0 max 3 min
        dup >r
        0
        ?DO                              \ space before to conform with MDF
           cptr i + d-datac@ 2 0.r space \ print a byte
        LOOP
        cptr r> + d-datac@ 2 0.r ;       \ print last byte

: .IBYTES ( <n> -- )
        1- 0 max 3 min
        dup >r
        0
        ?DO                              \ space before to conform with MDF
           cptr i + d-tc@ 2 0.r space    \ print a byte
        LOOP
        cptr r> + d-tc@ 2 0.r ;          \ print last byte

0 value EXCESS-BYTES

7 constant SEGMENT-END-TYPE             \ other index file record type

2variable string-offset

6 constant stringtype                   \ index file type

: .THROUGH-DIS-ASM ( -- )
        inx-type>
        inx-src-low> inx-src-hi>        \ get the src offset of the index rec
        BEGIN next-inx-record           \ skip records with same src offset
           2dup
           inx-src-low> inx-src-hi> d= 0=
           inx-type> segment-end-type = or
        UNTIL
        rot stringtype =
        line-printed 0= and
        IF print-src-line
        ELSE 2drop
           inx-src-low> inx-src-hi>     \ get the src offset of the index rec
        THEN string-offset 2!
        true !> inx-rec-lookahead?
        preamble
        dis-asm-col sp>col
        inx-adr> cptr -
        hex
        0 !> excess-bytes
        dup 4 >
        IF dup 4 - !> excess-bytes      \ excess bytes to be printed later
        THEN
        .BYTES ;

: .EXCESS-BYTES ( -- )
        save> cptr
        3 0                             \ three lines max
        DO excess-bytes 0<=
           IF leave
           THEN 4 +!> cptr
           preamble
           dis-asm-col sp>col
           excess-bytes .bytes cr
           -4 +!> excess-bytes          \ four bytes per line
        LOOP
        restore> cptr ;

: .EXCESS-INST  ( -- )
        save> cptr
        cptr excess-bytes - !> cptr     \ backup from inst end to excess bytes
        3 0                             \ three lines max
        DO excess-bytes 0<=
           IF leave
           THEN
           preamble
           dis-asm-col sp>col
           excess-bytes .ibytes cr
           -4 +!> excess-bytes          \ four bytes per line
            4 +!> cptr
        LOOP restore> cptr ;

defer .inst-bytes

0 value ignore-library-code

0 value #inst-bytes             \ the number of bytes in current inst

: ?.EXCESS-INST  ( -- )
        #inst-bytes 4 >
        IF #inst-bytes 4 -
           !> excess-bytes
           .excess-inst
        THEN ;

: INSTRUCTION-TYPE
        inx-adr> !> cptr
        print-upto-index-record
        ignore-library-code
        IF inx-file#> 0= ?exit
        THEN preamble
        dis-asm-col sp>col
        .inst-bytes
        src-col sp>col
        inx-file#>
        IF      cptr a-function-symbol?
                IF      .function-symbol
                THEN    inst-col sp>col
                outbuf crlf>bl's count $20 skip type cr
                true !> line-printed
        ELSE    inst cr
        THEN
        ?.excess-inst
        .errors ;

: CODE-BYTE-TYPE ( -- )
        inx-adr> !> cptr
        print-upto-index-record
        ignore-library-code
        IF inx-file#> 0= ?exit
        THEN preamble
        dis-asm-col sp>col
        1 .ibytes
        src-col sp>col
        inx-file#>
        IF inst-col sp>col
           outbuf crlf>bl's count $20 skip type cr
           true !> line-printed
        ELSE cr
        THEN    ;

: CODE-WORD-TYPE ( -- )
        inx-adr> !> cptr
        print-upto-index-record
        ignore-library-code
        IF inx-file#> 0= ?exit
        THEN preamble
        dis-asm-col sp>col
        2 .ibytes
        src-col sp>col          \ 09/10/92 16:33 tjz &&&&&&&&&&&&&&&&&&&
        cptr a-data-symbol?
        if      .function-symbol true else
        cptr a-function-symbol?
        if      .function-symbol true else
        cptr d-t@ flip a-function-symbol?
        if      inst-col sp>col
                .function-symbol false else
                                 true
        then
        then
        then
        inx-file#> and
        IF inst-col sp>col
           outbuf crlf>bl's count $20 skip type
           true !> line-printed
        THEN    cr ;

: BYTE-TYPE ( -- )
        inx-adr> !> cptr
        print-upto-index-record
        .through-dis-asm
        line-printed 0=
        IF src-col sp>col
           outbuf crlf>bl's count type
           true !> line-printed
        THEN cr
        .excess-bytes ;

: WORD-TYPE ( -- )
        inx-adr> !> cptr
        print-upto-index-record
        .through-dis-asm
        line-printed 0=
        IF src-col sp>col
           outbuf crlf>bl's count type
           true !> line-printed
        THEN cr
        .excess-bytes ;

: STRING-TYPE ( -- )
        inx-adr> !> cptr
        print-upto-index-record
        ignore-library-code
        IF inx-file#> 0= ?exit
        THEN .through-dis-asm
        cptr    a-data-symbol?          \ in symbol table ?
        IF src-col sp>col
           sym-name> 1+
           sym-seg over 1- c@l
           lst-file-handle sym-seg
           exbwrite
        THEN
        inst-col sp>col
        cptr d-datac@ decimal 1 u.r ',' emit
        '"' emit
        cptr 1+ cptr d-datac@ excess-bytes 4 + min bounds
        ?do     i d-datac@ emit
        loop
        '"' emit cr
        true !> line-printed
        .excess-bytes ;

: DO-:OTHER     ( -- )
        print-to-index-record ;

: DO-:INSTRUCTION ( -- )
        inx-adr> !> cptr
        print-to-index-record
        ignore-library-code
        IF inx-file#> 0= ?exit
        THEN preamble
        dis-asm-col sp>col
        .inst-bytes
        src-col sp>col
        inst cr
        ?.excess-inst
        .errors ;

: DO-SEGMENT-START ( -- )
        print-upto-index-record
        inx-adr> !> cptr
        inx-src-low> inx-src-hi>        \ get the src offset of the index rec
        last-seg-off 2!
        line-printed ?exit
        print-src-line ;

: DO-SEGMENT-END ( -- ) ;


: DO-INX-TYPE ( -- )
        inx-type>
        exec:
        noop                            \  0 notype
        source-catchup                  \  1 othertype
        instruction-type                \  2 insttype
        instruction-type                \  3 calltype
        byte-type                       \  4 bytetype
        word-type                       \  5 wordtype
        string-type                     \  6 stringtype
        do-segment-end                  \  7 segment end
        noop                            \  8 branchtype not needed by LS1
        do-:other                       \  9 :othertype
        do-:instruction                 \ 10 :instruction
        do-:instruction                 \ 11 :call
        code-byte-type                  \ 12 codebytetype
        code-word-type                  \ 13 codewordtype
        string-type                     \ 14 :stringtype
        do-segment-start ;              \ 15 segment start

22 constant max-symbol-len

0 value symbols/line

$ff constant unres-sym-type
$06 constant func-sym-type

: .1SYMBOL ( -- )               \ display one symbol, with possible line wrap
           sym-type> unres-sym-type =
           IF ." ????"
           ELSE sym-res-adr> 4 u.r
           THEN
           sym-type> func-sym-type =
           if           ." :"
           else         ."  "
           then
           sym-name> 1+ sym-seg over 1- c@l dup >r
           max-symbol-len min
           lst-file-handle sym-seg
           exbwrite
           max-symbol-len r> - 0 max spaces
           1 +!> symbols/line
           symbols/line 3 =                     \ three symbols per line
           IF cr 0 !> symbols/line
           THEN ;

48 array LOW-SYM-BUF

create ZZ'S ," ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"

\tcom long_branch
: SYM-NEXT-LOWEST ( -- n1 )     \ find the next lowest symbol
        sym-seg save!> sseg             \ set the search segment
        zz's count low-sym-buf place    \ init buffer to very high
        0 #sym-records 0
        ?DO     i sym-bytes/rec * !> sym-rec-ptr
                low-sym-buf 1+ sym-name> 1+ 31 comp 0>
                sym-seg sym-name> @L 0<> and
                if      sym-seg sym-rec-ptr ?ds: low-sym-buf 32 cmovel
                        drop i                          \ get the sym
                then
        LOOP    restore> sseg ;

: .-line        ( -- )          \ print a 72 character dashed line
                9 0 do  ." --------" loop  ;

: .SYMBOL-TABLE ( -- )
        save> base
        0 !> symbols/line
        cr 8 emit .-line
        cr decimal #sym-records u. ." Symbols " cr cr hex
        #sym-records 0
        ?DO     spinner
                sym-next-lowest
                sym-bytes/rec * !> sym-rec-ptr
                low-sym-buf zz's dup c@ 1+ comp 0= ?leave
                .1symbol
                ?ds: zz's dup>r sym-seg sym-rec-ptr r> c@ 1+ cmovel
        LOOP    cr cr
        ." Total CODE bytes compiled:"
        sym-seg #sym-records sym-bytes/rec *   2- @L
        dup hex 5 u.r ."  (hex)" decimal 6 u.r ."  (decimal)"
        sym-seg #sym-records sym-bytes/rec * 10 - @L ?dup
        if      cr ." Total DATA bytes compiled:"
                dup hex 5 u.r ."  (hex)" decimal 6 u.r ."  (decimal)"
        then
        restore> base
        cr cr ;
\tcom short_branch

\ === object memory =====================================================
\- maxobj       \tcom   65000 constant maxobj
                \fpc    10000 constant maxobj

: ALLOC-OBJ-MEMORY ( -- )
\fpc    obj-seg drop exit ;
\tcom   maxobj paragraph alloc 8 =      \ 32k for object file
\tcom   IF screen-output
\tcom      do-cr?
\tcom      ." No memory for the object file"
\tcom      ls-abort
\tcom   THEN nip !> obj-seg ;                   \ thanks for the memory

: ALLOC-MEMORY ( -- )
        alloc-obj-memory
        alloc-sym-memory ;

: OPEN-FILES ( -- )
        inx-file-handle clr-hcb         \ clear all handle control blocks
        sym-file-handle clr-hcb
        fil-file-handle clr-hcb
        open-fil-file
        open-sym-file
        open-msg-file
        open-lst-file ;

: %CLOSE-FILES ( -- )
        close-inx-file
        close-fil-file
        close-sym-file
        close-msg-file
        close-lst-file ;

defer LOAD-OBJ-FILE
\fpc ' noop is load-obj-file

: INITIALIZE ( -- )
        alloc-memory                    \ mem for object and symbols
        load-obj-file                   \ load file into obj mem
        open-files                      \ let's be open about our files
        read-sym-file                   \ load the symbol table
        sym-seg !> sym-seg-adr
        open-inx-file                   \ load the index file
        file-output                     \ direct output to list file
        src-offset-table
        #src-files 8 * erase            \ initialize the source file offsets
        src-line#-table
        #src-files 2* erase             \ initialize the for file line#s
        false !> error-printed
        0 !> src-file#                  \ no source file open yet
        false !> inx-rec-lookahead?     \ no look ahead has occured
        0 !> sym-index                  \ no symbols records read yet
        build-msg-tables                \ build the error message tables
        1 !> line#                      \ line number starts at one
        0 !> #out
        true !> line-printed
        0.0 last-seg-off 2!
        ['] %.line# is .line#
        ['] %.errors is .errors
        ['] %print-upto-index-record is print-upto-index-record ;

: DO-LST ( -- )
        ."  Creating listing file..."
        true !> cr-needed?
        true !> creating-listing?
        initialize
        cr
        BEGIN
           next-inx-record
           #inx-records inx-rec-counter 1+ -
\fpc       ?keypause
\tcom      broken @ 0= and              \ or until Ctrl-Break pressed
        WHILE open-src-file
           do-inx-type
        REPEAT
\tcom   broken @
\fpc    false                           \ if F-PC, exit normally
        if      cr ."   .LST generation canceled by user!" cr cr
                screen-output
                do-cr?
                   ."   .LST generation canceled by user!"
        else    copy-to-end
                close-src-file
                .symbol-table
                #inx-records #sym-records + !> spinval
                64 0 do spinner loop
                screen-output
        then    file-output ;

: DO-/SWITCH ( -- ) \ do the function indicated by the command tail switch
        /switch 0<
        IF screen-output
           help-them
           ." invalid switch"
           ls-abort
        THEN
        /switch #/switches min
        exec: do-lst do-lst noop noop ; \ note: listing done without switch

: GET-TAIL-FILE-NAME ( -- ) \ get the next parameter in the command tail
                            \ as a file name
        here dup c@ 1+
        file-name-length min
        file-name swap
        cmove ;

create /SWITCHES                \ the valid command tail switches
here                    \tcom /nostack1
lst-switch                   c, ," /LST"
lst-library-switch    $80 or c, ," /LIB"
lst-library-switch    $80 or c, ," /LL"
no-lst-library-switch $80 or c, ," /NOLIB"
no-lst-library-switch $80 or c, ," /NLL"

here swap - constant /SWITCHES-LEN

0 value #TAIL-PARAMS            \ number of parameters in the command tail

: GET-TAIL-WORD ( -- <adr> )
        bl word
        dup c@
        IF incr> #tail-params
        THEN ;

: GOT-TAIL-FILE? ( -- ) \ has a file name be specified in the command tail ?
        file-name c@ 0=
        IF screen-output
           help-them
           ." no filename given"
           ls-abort
        THEN ;

: #TAIL-PARAMS? ( <n> -- ) \ are there too many parameters to a switch
        #tail-params <
        IF screen-output
           help-them
           ." to many parameters"
           ls-abort
        THEN ;

: VALIDATE-/SWITCH ( -- ) \ validate the parameters to a switch
        /switch
        CASE
           lst-switch  OF got-tail-file?
                          2 #tail-params? ENDOF
           ( else ) drop
        ENDCASE ;

: LST-LIBRARY ( -- )
        false !> ignore-library-code ;

: NO-LST-LIBRARY ( -- )
        true !> ignore-library-code ;

: DO-IMMED-/SWITCH ( <switch> -- )
        0max #/switches min
        exec: noop noop lst-library no-lst-library ;


: ?/SWITCH ( -- ) \ is the word at here a program switch ?
        here dup c@ 1+ /switches
        /switches-len search
        IF 1- /switches + c@               \ get /switch index
           dup $80 and
           IF $7f and do-immed-/switch
           ELSE !> /switch
           THEN
        ELSE drop -1                       \ flag a bad switch
           !> /switch
        THEN ;

: PARSE-COMMAND-TAIL ( -- ) \ get the parametes from the dos command line
        0 !> /switch
        0 !> file-name
        0 !> #tail-params
        get-tail-word c@ 0=
        IF screen-output
           full-help
           ls-abort
        THEN  here
        BEGIN c@
        WHILE here 1+ c@ '/' =
           IF ?/switch
           ELSE get-tail-file-name
           THEN get-tail-word
        REPEAT ;

: PRODUCE-LISTING ( -- )
\tcom   dos_to_tib                              \ get the command tail
        false !> cr-needed?
        gettime t>b starting_time 2!            \ initialize starting time
        #tib @                                  \ a command tail
        IF parse-command-tail
           validate-/switch                     \ check for switch errors
           do-/switch                           \ execute the switch
        ELSE
           help-them                            \ no cmd tail, display help
        THEN ;




