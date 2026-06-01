\\ BINEDIT.SEQ          A Binary file Editor              by Tom Zimmer

{

.options /opt /noinit

needs \tcom\tpoint.seq

$10000. pointer binedit.seg             \ segment to hold file being edited
      0 value   binedit.len             \ length of file being edited
      0 value   binedit.org             \ original file length
$10000. pointer binedit2.seg            \ segment to hold file being edited

64 array input_buf
16 array #input_buf

: vemit         ( c1 -- )
                ( 127 and bl max ) sp@ 1 type drop ;

: #hex"         ( n1 n2 -- a1 n3 )      \ convert n1 to hex string a1,n2
                save> base hex
                0 <# swap 0 do # loop #>
                restore> base ;

: hex2          ( n1 -- )       2 #hex" type ;
: hex4          ( n1 -- )       4 #hex" type ;

: emptykbd      ( -- )
                begin   key?
                while   key drop
                repeat  ;

: newcolor      ( bg fg | name -- )     \ make a new color set
                create c, c,
                does> count >fg c@ >bg ;

\       BG      FG               NAME
\       ==      ======           =========
        blue    ltgray  newcolor bgcolor
        cyan    black   newcolor fldcolor
        black   ltgray  newcolor wincolor
        yellow  black   newcolor curcolor
        ltgray  black   newcolor darkcolor
        red     white   newcolor warncolor

: get_anumber   ( x y d1 bgclr fgclr -- d1 f1 ) \ f1 = true for success
                savecursor cursor-on >fg >bg
                2over 2>r
                #input_buf 16 blank
                <# #s #> #input_buf place
                on> autoclear
                #input_buf 5 lineeditor >r
                $2020 #input_buf count + !
                #input_buf count upper
                #input_buf number? r> and
                2r> at #input_buf count 5 min 5 over - spaces type space
                restcursor ;

256 array svbuf
256 array buf

handle 2ndhndl

0 value mem_st
0 value binseg
0 value mem_col
0 value mem_row
0 value col_save
0 value row_save
0 value mem_changed?
0 value fil_changed?
0 value changable?
0 value ascii?
0 value shrunk?
0 value change?
0 value txsave
0 value tysave
0 value ?2files
0 value ?2ndfile

: bhome         ( -- )
                txsave !> tx
                tysave !> ty
                tx 1+ ty 1+ dup =: bline at ;

: mem-at        ( -- )
                tx 9 + mem_col 2/ 3 * +
                ty 3 + mem_row        + at ;

: mem-cursor    ( -- )
                tx 9 + mem_col 2/ 3 * + mem_col 1 and +
                ty 3 + mem_row + at ;

: ascii-cursor  ( -- )
                tx 59 + mem_col 2/ +
                ty  3 + mem_row + at ;

: ?hex?         ( n1 -- )
                0= ascii? 0= and
                if      darkcolor
                then    ;

: ?ascii?       ( n1 -- )
                0= ascii? and
                if      darkcolor
                then    ;

: mem-getline   ( -- )
                binseg mem_st mem_row u2/ $20 * + ?ds: buf $20 cmovel ;

: .mem-pos      ( -- )          \ display the current memory position
                58 1 at fldcolor space
                mem_st mem_row $10 * + mem_col 2/ + hex4 space
                wincolor ;

: +memdump_scr  ( n1 --- )
                +!> mem_st
                bgcolor 2 2 at
                changable?
                if      ."     EDIT: "
                else    ."   BROWSE: "
                then    wincolor space
                ?2ndfile
                if      2ndhndl
                else    seqhandle
                then    count type
                ."  of " binedit.len dup u. ." (" hex4 ." h) bytes"
                78 sp>col
                bhome bcr bcr
                9 0
                do      binseg mem_st i $20 * + ?ds: svbuf $20 cmovel
                        wincolor i ?hex?
                        pad off
                        2 spaces mem_st i $20 * + hex4
                        2 spaces svbuf
                        16 0
                        do      dup i + c@ 2 #hex" type space
                        loop    wincolor ." ³"
                        i ?ascii? 1 spaces
                        16 0
                        do      dup i + c@ vemit
                        loop    1 spaces wincolor bcr 8 spaces
                        32 16
                        do      dup i + c@ 2 #hex" type space
                        loop    ." ³ "
                        32 16
                        do      dup i + c@ vemit
                        loop    bcr drop
                        emptykbd
                loop    mem-getline
                ascii?
                if      bgcolor 43 23 at ."  ASCII "
                then    wincolor
                ascii? 0=
                if      bgcolor 43 23 at ."   HEX  "
                then    wincolor .mem-pos ;

: dump-address  ( -- )
                save> base hex
                tx 3 + ty 3 + mem_st 0 green black get_anumber
                if      drop !> mem_st
                else    2drop
                then    restore> base 0 +memdump_scr ;

: .modified     ( -- )
                2 1 at curcolor ."   MODIFIED  "
                wincolor ;

: mem-putline   ( -- )
                mem_changed?
                if      ?ds: buf binseg mem_st mem_row u2/ $20 * +
                        $20 cmovel
                        off> mem_changed?       \ clear modified flag
                        on> fil_changed?        \ set the file changed flag
                then    ;

: >mem-address  ( f1 -- )
                mem-putline
                if      binedit.len $FFF0 and !> mem_st   -256
                else    off> mem_st                     0
                then    +memdump_scr
                0 >mem-pos ;

: char-addr     ( -- a1 )
                buf mem_row 1 and $10 * mem_col 2/ + + ;

: mem-position  ( -- )          \ display current byte at cursor position
                savecursor curcolor
                ascii?
                if      ascii-cursor char-addr c@ vemit
                else    mem-at       char-addr c@ hex2  \ position cursor
                then    restcursor ;

: 0mem-position ( -- )          \ display current byte at cursor position
                savecursor
                mem_row 0=
                if      darkcolor
                else    wincolor
                then
                ascii?
                if      ascii-cursor char-addr c@ vemit
                else    mem-at       char-addr c@ hex2  \ position cursor
                then    restcursor ;

: +mem-row      ( n1 -- )       \ adjust current row by n1
                changable? 0=
                if      32 * +memdump_scr
                        exit
                then
                0mem-position                   \ erase highlight
                mem-putline
                mem_row + dup 0<
                if      drop
                        -32 +memdump_scr
                        1 !> mem_row
                        exit
                then    dup 17 >
                if      drop
                        32 +memdump_scr
                        16 !> mem_row
                else    !> mem_row
                then    mem-getline .mem-pos ;

: +mem-col      ( n1 -- )       \ adjust current col by n1
                changable? 0=
                if      drop    EXIT            \ leave if not editable
                then
                ascii?
                if      2*
                then
                0mem-position                   \ erase highlight
                mem_col dup>r + dup 0<
                if      drop
                        -1 +mem-row
                        30 !> mem_col
                        r>drop exit             \ discard old col & exit
                then    dup 31 >
                if      drop
                        1 +mem-row
                        off> mem_col
                else    !> mem_col
                        r@ mem_col >            \ if we are moving left
                        r@ 1 and 0= and         \ and we were in left col
                        ascii? 0= and           \ and NOT in ascii side
                        if      decr> mem_col   \ backup one more column
                        then
                then    r>drop .mem-pos ;

: +mem-scr      ( n1 -- )
                0mem-position           \ erase highlight
                mem-putline             \ save changes
                +memdump_scr            \ page up/down
                mem-getline ;           \ get new line

: >mem-pos      ( n1 -- )       \ move to page position n1
                mem-putline
                changable?
        if      0mem-position                   \ erase highlight
                0max $11F min $10 /mod !> mem_row 2* !> mem_col
                mem-getline .mem-pos
        else    0 !> mem_col
        then    ;

: change-ok?    ( -- f1 )       \ return true if it is ok to change file
                change? ?dup ?exit
                savecursor savescr warncolor
                15 5 70 11 box&fill
                bcr ."   WARNING:  This will modify the file!  "
                bcr
                bcr  2 spaces fldcolor
                ."    Press a key:    Y = Change     ESC = Cancel   "
                1000 1 tone
                0       begin   drop key upc dup 'Y' = over 27 = or
                        until   'Y' = dup !> change?
                restscr restcursor ;

: change-byte   ( n1 -- )       \ modify current byte of memory
                changable? 0=
                if      drop    EXIT
                then
                change-ok?
[long]  if      ascii? 0=
                if      mem_col 1 and
                        if            char-addr c@ $F0 and
                        else    $10 * char-addr c@ $0F and
                        then    +
                then    char-addr c!
                mem_st mem_row $10 * + mem_col 2/ +
                binedit.len umax !> binedit.len \ allow file extend
                on> mem_changed?                \ mark line changed flag
                on> fil_changed?                \ set the file changed flag
                mem-putline                     \ save any changes made
                1 +mem-col
                .modified
        then    0 +memdump_scr ;

: shrunk-ok?    ( -- f1 )       \ return true if it is ok to shrink
                shrunk? ?dup ?exit
                savecursor savescr warncolor
                15 5 70 11 box&fill
                bcr ."   WARNING: This will change the length of the file!  "
                bcr
                bcr  2 spaces fldcolor
                ."    Press a key:    Y = Change     ESC = Cancel   "
                1000 1 tone
                0       begin   drop key upc dup 'Y' = over 27 = or
                        until   'Y' = dup !> shrunk?
                restscr restcursor ;

: shrink-byte   ( -- )          \ reduce file size by one byte at cursor
                changable? 0=
                binedit.len 0= or ?EXIT         \ or length of file is zero
                mem-putline                     \ save any changes made
                shrunk-ok?
[long]  if      mem_st mem_row $10 * + mem_col 2/ + dup>r
                binedit.len u<=
           if   binseg r@ 2dup dup>r 1+ 2swap binedit.len r> - cmovel
                0 binseg binedit.len c!L   \ end byte to NULL
                decr> binedit.len               \ shorten length by one byte
                on> mem_changed?                \ mark line changed flag
                on> fil_changed?                \ set the file changed flag
                .modified
           then r>drop
        then    0 +memdump_scr ;                \ re-show screen

: expand-byte   ( -- )          \ increase file size by one byte at cursor
                changable? 0= ?EXIT
                mem-putline                     \ save any changes made
                shrunk-ok?
[long]  if      binseg mem_st mem_row $10 * + mem_col 2/ +
                2dup 2>r 2dup dup>r 1+ binedit.len r> - cmovel>
                ascii?                          \ of in ascii mode
                if      bl                      \ then make it a blank
                else    00                      \ else make it a NULL
                then    2r> c!L                 \ set the new byte value
                binedit.len 0 1. d+ $FFFF. dmin drop
                !> binedit.len                  \ increase length by one byte
                on> mem_changed?                \ mark line changed flag
                on> fil_changed?                \ set the file changed flag
                .modified
        then    0 +memdump_scr ;                \ re-show screen

: set-end       ( -- )          \ set file length to current cursor position
                changable? 0= ?exit
                mem-putline
                shrunk-ok?
        if      mem_st mem_row $10 * + mem_col 2/ + !> binedit.len
                on> fil_changed?                \ set the file changed flag
                .modified
        then    0 +memdump_scr ;

: changable?_toggle ( -- )
                ?2files ?exit
                mem-putline
                changable? dup
                if      mem_row !> row_save
                        mem_col !> col_save
                        0 >mem-pos
                        8 22 at fldcolor ."  F1=Order info      "
                else    row_save !> mem_row
                        col_save !> mem_col
                        8 22 at bgcolor  ."  F2=Set end address "
                then    0= !> changable?
                0 +memdump_scr  ;

: hex/ascii_toggle ( -- )
                mem-putline
                ascii? 0= !> ascii?
                0 +memdump_scr  ;

: findstring_again$     ( a1 n1 -- )
                binseg save!> sseg
                mem_st dup>r $FFF0 and $10 + !> mem_st
                binedit.len mem_st umin binedit.len mem_st over umin - search
                if      r>drop
                        dup mem_st +
                        dup $FFF0 and    !> mem_st
                            $000F and 2* !> mem_col
                else    r> !> mem_st
                        1000 1 tone
                then    drop
                restore> sseg ;

: findstring_again_HEX  ( -- )
                save> base hex
                pad off
                input_buf count
                begin   bl skip 2dup bl scan 2dup 2>r nip - here place
                        2r>
                        $2020 here count + !
                        here count upper
                        here number? nip
                while   pad count + c!
                        1 pad c+!
                repeat  drop
                false save!> caps
                pad count findstring_again$
                restore> caps
                restore> base ;

: find_difference       ( -- )
                ?2files 0= ?exit
                mem_st mem_col 2dup 2>r or
                if      mem_st mem_col 2/ + 1+
                        dup $FFF0 and    !> mem_st
                            $000F and 2* !> mem_col
                then    false
                binedit.len mem_st mem_col 2/ + umin    \ start length
                binedit.len mem_st mem_col 2/ + over umin -
                bounds
                ?do     binedit.seg i c@L binedit2.seg i C@L <>
                        if      drop i leave
                        then
                loop    dup
                if      2r> 2drop
                        dup $FFF0 and    !> mem_st
                        dup $000F and 2* !> mem_col
                else    2r> !> mem_col !> mem_st
                        1000 1 tone
                then    drop
                0 +memdump_scr mem-position ;

: findstring_again      ( -- )
                mem-putline
                ascii?
                if      input_buf count findstring_again$
                else    findstring_again_HEX
                then    0 +memdump_scr mem-position ;

: findstring    ( -- )          \ find a string of characters
                savescr tx  2+ ty 1+ at bgcolor
                ascii?
                if      ."  FIND ASCII: "
                else    ."    FIND HEX: "
                        tx  2+ ty 2+ at 13 spaces
                        ." Type a series of space seperated hex bytes"
                        77 sp>col
                then
                tx 15 + ty 1+ at >rev 77 sp>col
                on> autoclear
                tx 16 + ty 1+ input_buf 60 lineeditor
                restscr
                if      findstring_again
                then    ;

: swap_files    ( -- )
                ?2files 0= ?exit
                ?2ndfile 0= dup !> ?2ndfile
                if      binedit2.seg !> binseg
                else    binedit.seg !> binseg
                then    0 +memdump_scr mem-position ;

: binedit_screen ( -- )
                cls
                wincolor
                1 1 78 24 box&fill
                tx !> txsave
                ty !> tysave
                off> changable?         \ clear editable flag on entry
                savecursor fldcolor
                 2  1 at ."  UnMODIFIED "
                30  1 at ."  Binary File Editor "
                ?2files
if      3 22 at ."  F1=Order info   Ins/Del=Expand/Shrink   Alt-D=Find diff   Alt-F1=alt file "
else    3 22 at ."       F1=Order info        Ins/Del=Expand/Shrink   ESC=EDIT/BROWSE toggle  "
then
3 23 at ."      F10=Exit & save            F6=Find            TAB=HEX/ASCII   toggle  "
3 24 at ."  Alt-F10=Exit & discard     Alt-F6=Find again    Enter=Set address         "
                66  1 at ."  PgUp PgDn "
                78  4 at ." "
                78 21 at ." "
                restcursor bcr bgcolor
                ."  OFFSET  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F"
                ."  ³ 0123456789ABCDEF "
                0 +memdump_scr ;

: show_help     ( -- )
                savescr bgcolor
                8 3 72 20 box&fill
        bcr ."    BINEDIT is a public domain program, written in Forth and"
        bcr ."    compiled with the TCOM Forth Target COMpiler."
        bcr
        bcr ."    The FORTH development environment used to create BINEDIT"
        bcr ."    including source for TCOM, BINEDIT & 70 other example"
        bcr ."    programs is available for US$60 from:"
        bcr
        bcr ."     Tom Zimmer             Home (408) 263-8859  7pm-9pm pst"
        bcr ."     292 Falcato Drive      Work (415) 327-8800 10am-6pm pst"
        bcr ."     Milpitas, Ca. 95035"
        bcr ."     U.S.A.
        bcr
        bcr ."    Outside US orders add 20 dollars for bank fees and AIR postage."
        bcr
        bcr space fldcolor 14 spaces
                ." Press a key to return to BINEDIT " 71 sp>col
        18 3 at ."   A Binary File Editor written by Tom Zimmer  "
                key drop
                restscr
                0 +memdump_scr ;

: .binhelp      ( -- )
        cr ." Usage: BINEDIT {filename}"
        cr ."        Browse or edit the first 64k bytes of {filename}."
        cr
        cr ."    or: BINEDIT {filename} {filename2}"
        cr ."        Search for differences between two nearly identical files."
        cr      bye ;


: binedit_load  ( -<name>- )    \ load the file being edited
                read-write
                bl word c@ 0=
                if      .binhelp
                then
                here $file
                if      ." Couldn't open: " seqhandle count type
                        cr .binhelp
                then
                binedit.seg 0= abort" Couldn't allocate edit buffer"
                binedit.seg !> binseg
                binedit.seg     0 $8000 0 lfill
                binedit.seg $8000 $8000 0 lfill
                0 $FFFF seqhandle binedit.seg exhread
                dup !> binedit.len !> binedit.org
                bl word c@ 0= ?exit     \ leave if no second file specified
                here 2ndhndl $>handle
                2ndhndl hopen
                if      ." Couldn't open: " 2ndhndl count type
                        cr .binhelp
                then
                binedit2.seg 0= abort" Couldn't allocate second edit buffer"
                binedit2.seg     0 $8000 0 lfill
                binedit2.seg $8000 $8000 0 lfill
                0 $FFFF 2ndhndl binedit2.seg exhread drop
                2ndhndl hclose drop
                on> ?2files ;

: ?binedit_save ( c1 -- )
                196 =                           \ if exited with the F10 key
                fil_changed? and
[long]          if      binedit.len binedit.org <> dup
                        if      drop
                                seqhandle hclose drop
                                seqhandle hcreate
                        then    0=
                        if      0.0 seqhandle movepointer
                                0 binedit.len seqhandle
                                binedit.seg exhwrite drop
                                seqhandle hclose drop
                        else    beep
                                cr ."  Failed to create output file"
                        then
                then    ;

: binedit_init  ( -- )  \ Initialize the needed TCOM application facilities
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                VMODE.SET
                BLINKOFF                        \ disable background blinking
                $0 SET_MEMORY
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                ;

: binedit_keys  ( -- c1 )       \ handle the keyboard
                begin   emptykbd                \ discard extra keys
                        changable?
                        if      mem-position    \ show current byte
                                cursor-on
                                ascii?
                                if      ascii-cursor
                                else    mem-cursor
                                then    50 ms key
                                cursor-off
                        else    key
                        then    dup  196 <>
                                over 241 <> and
        [long]  while   case
        ( BACKSPACE )             8 of    -1 +mem-col bl change-byte
                                          -1 +mem-col           endof
        ( TAB )                   9 of  hex/ascii_toggle        endof
        ( Enter )                13 of  dump-address            endof
        ( ESC )                  27 of  changable?_toggle       endof
        ( F1 )                  187 of  show_help               endof
        ( F2 )                  188 of  set-end                 endof
        ( F6 )                  192 of  findstring              endof
        ( Home )                199 of     0 >mem-pos           endof
        ( Up )                  200 of    -1 +mem-row           endof
        ( PgUp )                201 of  -256 +mem-scr           endof
        ( left )                203 of    -1 +mem-col           endof
        ( right )               205 of     1 +mem-col           endof
        ( End )                 207 of   287 >mem-pos           endof
        ( Down )                208 of     1 +mem-row           endof
        ( PgDn )                209 of   256 +mem-scr           endof
        ( Ins )                 210 of  expand-byte             endof
        ( Del )                 211 of  shrink-byte             endof
        ( Alt-F6 )              237 of  findstring_again        endof
        ( Alt-F1 )              232 of  swap_files              endof
        ( Alt-D )               160 of  find_difference         endof
        ( ^End )                245 of  true >mem-address       endof
        ( ^Home )               247 of  false >mem-address      endof

                                ascii?
                                if      change-byte
                                else    upc
                                        dup '0' '9' between
                                            if  dup '0' -       change-byte
                                                0=
                                            then
                                        dup 'A' 'F' between
                                            if  dup 'A' - 10 +  change-byte
                                                0=
                                            then
                                            if          \ do nothing for now
                                            then
                                then
                        endcase
                repeat  mem-putline ;

: main          ( -- )
                binedit_init
                binedit_load
                savescr savecursor cursor-off
                binedit_screen
                binedit_keys ( -- c1 )
                restcursor restscr
                ( c1 -- ) ?binedit_save ;

