\\ TEXTFORM.SEQ          Text Formatter                 by Tom Zimmer
.options /opt /noinit

  This file implements a relatively simple text formatter.  This
formatter was written to generate the TCOM Users Manual from a text
description file. The list of supported . (dot) commands follows:

        .\                      start a comment line, remainder ignored
        .bxbottom               the bottom of a boxed area
        .bxtop # #              start the top of a box at left col, right col
        .chapter <filename>     Include a chapter with <filename>
        .cj                     center justify
        .contents               outputs the Table of Contents page(s) here
        .c[ <contents_entry>    creates an entry in the Table of Contents
        .date # text"           display the date in form # followed by text"
                                form # 0=M/D/Y, 1=Y-M-D, 2=D.M.Y
                                       4=M/D/Y, 5=Y-M-D, 6=D.M.Y with time
                                Date is preceeded by "text"
        .fend                   footer end
        .figures                outputs the Figures page(s) here
        .fstart                 footer start
        .f[ <figure_entry>      creates an entry in the Figures page
        .gutter                 page gutter for book format
        .hend                   header end
        .hl                     display a horizontal line
        .hl2                    display a horizontal double line
        .hstart                 header start
        .indent #               indent for first paragraph line
        .index                  output the INDEX page(s) here
        .i[ <index_entry>       becomes an index entry for current page
        .lj                     left justify
        .lm     #               set left margin
        .lm! lm# lm_value       set lm# (1-4) to lm_value (0-40)
        .lm1                    set left margin to left margin one
        .lm2                    set left margin to left margin two
        .lm3                    set left margin to left margin three
        .lm4                    set left margin to left margin four
        .lpp    #               set lines per page
        .page                   insert a page break here
        .page?  #               page break if less than # lines left
        .pageeven               page break if even page
        .pageodd                page break of odd page
        .pagetop                page if not top of page
        .pg                     display page number
        .rj                     right justify
        .rm     #               set right margin
        .spg    #               set page number
        .table                  outputs the Tables page(s) here
        .title                  the embeded title of the document
        .toline #               vertical align to the line specified
        .t[ <table_entry>       creates an entry in the Tables page
        .wrapoff                turn word wrap off
        .wrapon                 turn word wrap on

  Future versions may support some or all of the following commands:

        .cpl    #               set characters per line
        .vlend                  end vertical line
        .vlstart #              display a vertical line a column

  This program is compiled on TCOM, and generates TEXTFORM.COM which is
around 14k bytes.

{

fload \tcom\tpoint.seq          \ pointer memory allocation support
fload \tcom\tfileio.seq         \ buffered file I/O support

 4096. pointer contents_seg     \ segment to hold contents entries
 4096. pointer figure_seg       \ segment to hold figure entries
65536. pointer index_seg        \ segment to hold index entries
 4096. pointer table_seg        \ segment to hold table entries

bhandle chapthndl               \ handle to hold current chapter name
bhandle readhndl                \ we are reading from this file
bhandle wrthndl                 \ we are writing the results to this file
bhandle wrt2hndl                \ second handle for split output files

0 value ??[             \ getting lines from INDEX, CONTENTS, TABLE, FIGURE?
0 value ?+footer        \ footer accumulation flag
0 value ?+header        \ header accumulation flag
0 value ?[-ptr          \ value that holds the pointer offset variable
0 value ?[-sorting      \ are we worting the entries?
0 value ?[_seg          \ value that holds the segment value
0 value ?boxing         \ are we building a box around text?
0 value ?center         \ center justify flag
0 value ?chapter        \ are we reading from a chapter file?
0 value ?contents       \ are generating the table of contents?
0 value ?double         \ double space lines?
0 value ?index          \ are we displaying the index?
0 value ?right          \ right justify flag
0 value ?wrap           \ word wrap flag
0 value bxtl            \ box top left
0 value bxtr            \ box top right
0 value column          \ output column
0 value footerlines     \ lines in footer
0 value gutter          \ page gutter size in spaces for book format
0 value h/f-ptr         \ header/footer pointer for text append
0 value headerlines     \ lines in header
0 value indent          \ first line of paragraph indent, + or -
0 value leftmargin      \ the left margin of document
0 value line-counter    \ count of line read
0 value linesperpage    \ the number of lines on a page
0 value pagenumber      \ the current page number
0 value rightmargin     \ the right margin of document
0 value row             \ output row
0 value ?split          \ are we using a split output file?
0 value wrapsave        \ a place to save word wrap state
0 value writehndl       \ pointer to current write handle

variable contents-ptr   \ point into contents segment
variable figure-ptr     \ point into figure segment
variable index-ptr      \ point into index segment
variable table-ptr      \ point into table segment

variable index-letter

4 array leftmargins     \ an array of margin values

1024 array footerbuf    \ buffer for footer text
1024 array headerbuf    \ buffer for header text
 256 array tfbuf        \ buffer for current output line
 256 array readbuf      \ buffer for current input  line
  32 array prev_buf1    \ previous word buffer for indexer

create "cr"     $0D c, $0A c,

: .file-position ( -- )
                ." After readine line: " line-counter u.
                cr ." file: " ?chapter
                if      chapthndl
                else    readhndl
                then    dup >bhandle count type
                ."  at offset: " bcurpointer d.
                        ?chapter
                if      chapthndl
                else    readhndl
                then    dup bcurpointer 2>r
                10 0
                do      cr dup blineread
                        readbuf placel
                        readbuf count 2- 0max type
                loop    2r> rot bmovepointer ;

: footerbuf0    ( -- )  \ clear the footer buffer
                footerbuf 1024 erase
                off> footerlines ;

: headerbuf0    ( -- )  \ clear the header buffer
                headerbuf 1024 erase
                off> headerlines ;

: lm!           ( n1 n2 -- )    \ store left margin value n1 into margin n2
                1- leftmargins + c! ;

: lplace        ( a1 len seg off -- )   \ place string from here to seg
                2>r ?ds: -rot 2r> rot >r 2dup r@ -rot c!L 1+ r> cmovel ;

: get-#         ( -- n1 )       \ get a number from the input stream
                bl word number? nip 0=
                if      cr readbuf count type
                        cr ." **** Command is missing a parameter ****"
                        cr .file-position
                then    ;

: tfflush       ( -- )
                tfbuf count writehndl bwrite
                tfbuf off ;

: tftype        ( a1 n1 -- )
                dup +!> column tfbuf +place ;

: writeODD      ( -- )
                wrthndl !> writehndl ;

: writeEVEN     ( -- )
                wrt2hndl !> writehndl ;

: ?swapfiles    ( -- )
                ?split
                if      tfflush                 \ flush current buffer data
                        pagenumber 1 and        \ if page is ODD
                        if      writeODD
                        else    writeEVEN
                        then
                then    ;

create spc's    ,"                 "

: tfspaces      ( n1 -- )
                16 /mod 0
                ?do     spc's 1+ 16   tftype
                loop    spc's 1+ swap tftype ;

: tfcr          ( -- )  \ text formatter carraige return
                tfbuf count -trailing nip tfbuf c!      \ remove trailing bl's
                ?boxing
                if      tfbuf count + bxtr 4 + tfbuf c@ - 0max blank
                        tfbuf c@ bxtr 1+ max tfbuf c!
                        '³' tfbuf 1+ bxtr + c!
                        '³' tfbuf 1+ bxtl + c!
                then    "cr" 2 tftype
                pagenumber 1 and                \ if an odd page
                gutter 0> and                   \ and gutter is non-zero
                if      gutter tfspaces         \ then output the gutter
                then
                tfflush
                incr> row
                off> column ;

: column0       ( -- )  \ perform a cr if we aren't at column zero
                ?+header ?+footer or ?exit      \ leave if in header or footer
                column
                if      tfcr
                then    ;

: tofooter      ( -- )  \ move vertically down to the footer area of page
                begin   row linesperpage footerlines - <
                while   tfcr
                repeat  ;

: page.left     ( a1 -- a1 )
                dup 1+ c@ tfspaces              \ output left margin spaces
                pagenumber 0 <# #s #> tftype ;  \ and page number

: page.right    ( a1 -- a1 )
                >r pagenumber 0 <# #s #>        \ convert page to text
                r@ 2+ c@ over - 0max            \ right margin - text width
                tfspaces                        \ output the spaces
                tftype r> ;                     \ and the text

: page.center   ( a1 -- a1 )
                >r pagenumber 0 <# #s #>        \ convert page to text
                r@ 2+ c@ r@ 1+ c@ -             \ right margin - left margin
                2/ over 2/ - 0max               \ divided by 2 - text len/2
                r@ 1+ c@ +                      \ plus left margin
                tfspaces                        \ output the spaces
                tftype r> ;                     \ then the text

: leftedge      ( -- n1 )       \ the left edge of the page for the
                                \ first line of a paragraph
                leftmargin indent + 0max ;

: line.left     ( a1 -- a1 )
                dup 1+ c@ tfspaces ;

: line.right    ( a1 -- a1 )
                gutter 0=                       \ if gutter is zero
                pagenumber 1 and or             \ or page is ODD
\ **
\ ** We are on the previous page in header, so the test is for even, not odd.
\ **
                if                              \ then use right justification
                        >r r@ 2+ c@             \ right margin
                        r@ 3 + c@               \ following string length
                        - 0max                  \ calc difference length
                        tfspaces r>             \ output the spaces
                else                            \ else use left justifycation
                        line.left
                then    ;

: line.center   ( a1 -- a1 )
                >r r@ 2+ c@ r@ 1+ c@ -          \ right margin - left margin
                2/ r@ 3 + c@ 2/ - 0max          \ divided by 2 - text len/2
                r@ 1+ c@ +                      \ plus left margin
                tfspaces r> ;                   \ output the spaces

: do.specials   ( a1 n1 -- a1 ) \ perform the special function in head/foot
                255 over c@ - 0max 5 min
                exec:   page.left       page.right      page.center
                        line.left       line.right      line.center ;

: do.header     ( -- )
                headerbuf
                begin   dup c@
                while   dup c@ 130 <
                        if      count 2dup tftype tfcr
                                +
                        else    do.specials
                                3 +             \ fixed length specials
                        then
                repeat  drop ;

: do.footer     ( -- )
                column0
                tofooter
                footerbuf
                begin   dup c@
                while   dup c@ 132 <
                        if      count 2dup tftype tfcr
                                +
                        else    do.specials
                                3 +             \ fixed length specials
                        then
                repeat  drop ;

: +line-to-head/foot ( a1 n1 -- )
                leftmargin  h/f-ptr 1+ c!       \ left  margin for justify
                rightmargin h/f-ptr 2+ c!       \ right margin for justify
                ?center
                if      250 h/f-ptr c!          \ center code
                else    ?right
                        if      251 h/f-ptr c!  \ right justify code
                        else    252 h/f-ptr c!  \ left justify code
                        then
                then    3  +!>  h/f-ptr         \ bump by 3 byte
                h/f-ptr place
                h/f-ptr count + !> h/f-ptr
                ?+header
                if      incr> headerlines
                else    incr> footerlines
                then    ;

: +page-to-head/foot ( -- )     \ insert the page function into head/foot
                leftmargin  h/f-ptr 1+ c!       \ left  margin for justify
                rightmargin h/f-ptr 2+ c!       \ right margin for justify
                ?center
                if      253 h/f-ptr c!          \ center code
                else    ?right
                        if      254 h/f-ptr c!  \ right justify code
                        else    255 h/f-ptr c!  \ left justify code
                        then
                then    3  +!>  h/f-ptr         \ bump by 3 byte
                ?+header
                if      incr> headerlines
                else    incr> footerlines
                then    ;

: ?[_sortin     ( -- a1 )       \ adjust INDEX-PTR to position for new string
                ?[_seg save!> sseg
                0
                begin   here 1+ over 3 + here c@ compare 0>
                        over ?[_seg swap 3 + c@L 0<> and
                while   ?[_seg over 2+ c@L + 3 +
                repeat  ?[-ptr @ umin
                restore> sseg ;

: do.?[         ( -- )          \ create an entry for current page in a table
                tib #tib @ >in @ /string 2dup bl skip nip - >in +! drop
                                                        \ skip leading blanks
                0 word drop                             \ get the line to here
                ?[-ptr @ >r
                ?[-sorting
        if      ?[_sortin dup ?[-ptr @ <>
                if      ?[_seg over ?[-ptr @ over -       \ -- seg offset len
                        >r 2dup here c@ 3 + + r> cmoveL>  \ move data
                        dup ?[-ptr !
                then    drop
        then    pagenumber ?[_seg ?[-ptr @ !L
                2 ?[-ptr +!
                here count ?[_seg ?[-ptr @ lplace
                r> ?[-ptr !
                here c@ 3 + ?[-ptr +!                   \ n1 --
                ;

\ **********************************************************************
\       ****** Start of User callable Formatter Functions ******
\ **********************************************************************

: do.\          ( -- )  \ start a comment line, remainder ignored
                0 word drop ;           \ Just discard the line

: do.bxbottom   ( -- )  \ the bottom of a boxed area
                column0
                off> ?boxing
                bxtl 0max tfspaces " À" tftype
                bxtr bxtl - 1- 0max 0
                ?do     " Ä" tftype
                loop    " Ù" tftype
                tfcr ;

: do.bxtop      ( -- )  \ start the top of a box at left col, right col
                get-# get-# 2dup min !> bxtl max !> bxtr
                ( -- )  \ draw the box top
                column0
                off> ?boxing
                bxtl 0max tfspaces " Ú" tftype
                bxtr bxtl - 1- 0max 0
                ?do     " Ä" tftype
                loop    " ¿" tftype
                tfcr on> ?boxing ;

: do.c[         ( -- )  \ create an table of contents entry for current page
                contents-ptr 4000 u> abort" Contents table Overflow!"
                contents-ptr !> ?[-ptr
                contents_seg !> ?[_seg
                off> ?[-sorting
                do.?[ ;

: do.chapter    ( -- )
                ?chapter abort" Nesting of Chapters is not allowed!"
                bl word chapthndl $>bhandle
                chapthndl bopen
                if      cr tib #tib @ type
                        true abort" Couldn't open Chapter file"
                then    on> ?chapter ;

: do.cj         ( -- )  \ center justify on
                on> ?center
                off> ?right
                column0 ;

: do.contents   ( -- )  \ display the index records
                column0
                on> ?double             \ double space contents lines
                on> ??[
                on> ?contents           \ we are doing the contents
                ?wrap !> wrapsave       \ preserve wrap state for later
                off> ?wrap              \ turn off word wrap
                off> contents-ptr       \ reset the contents pointer to start
                contents-ptr !> ?[-ptr
                contents_seg !> ?[_seg ;

: do.cpl        ( -- )  \ set characters per line
                get-# drop ;

: do.set-form   ( n1 -- )       \ set the date form type
                3 and exec: m/d/y  y-m-d  d.m.y  noop ;

: do.date       ( n1 -<text">- )        \ display the date using form n1
                column0
                get-# dup>r do.set-form
                leftmargin tfspaces
                >in incr                \ discard one leading space after n1
                '"' word count tftype
                getdate form-date count tftype
                r> 4 and
                if      2 tfspaces
                        gettime form-time count drop 5 tftype
                then    tfcr    ;

: do.fend       ( -- )  \ footer end
                off> ?+footer
                off> ?+header ;

: do.f[         ( -- )  \ create an figure entry for current page
                figure-ptr 4000 u> abort" FIGURE Overflow!"
                figure-ptr !> ?[-ptr
                figure_seg !> ?[_seg
                on> ?[-sorting
                do.?[ ;

: do.figure     ( -- )  \ display the index records
                on> ??[
                ?wrap !> wrapsave       \ preserve wrap state for later
                off> ?wrap              \ turn off word wrap
                off> figure-ptr         \ reset the figure pointer to start
                figure-ptr !> ?[-ptr
                figure_seg !> ?[_seg ;

: do.fstart     ( -- )  \ define the footer start contents
                on> ?+footer
                off> ?+header
                footerbuf !> h/f-ptr
                footerbuf0 ;

: do.gutter     ( -- )  \ set the gutter size for document in spaces
                get-# 16 min !> gutter ;

: do.hend       ( -- )  \ define the header end
                off> ?+header
                off> ?+footer ;

: do.hl         ( -- )  \ display a horizontal line between margins
                ?+header ?+footer or
        [long]  if      rightmargin h/f-ptr c!                  \ set count
                        h/f-ptr 1+ leftmargin blank             \ left margin
                        h/f-ptr leftmargin 1+ +                 \ address
                        rightmargin leftmargin -                \ length
                        0max 'Ä' fill                           \ fill line
                        h/f-ptr count + !> h/f-ptr              \ bump ptr
        [long]  else    column0
                        leftmargin tfspaces
                        rightmargin leftmargin - 0max 0
                        ?do     " Ä" tftype
                        loop    tfcr
                then    ;

: do.hl2        ( -- )  \ display a horizontal line between margins
                ?+header ?+footer or
        [long]  if      rightmargin h/f-ptr c!                  \ set count
                        h/f-ptr 1+ leftmargin blank             \ left margin
                        h/f-ptr leftmargin 1+ +                 \ address
                        rightmargin leftmargin -                \ length
                        0max 'Í' fill                           \ fill line
                        h/f-ptr count + !> h/f-ptr              \ bump ptr
        [long]  else    column0
                        leftmargin tfspaces
                        rightmargin leftmargin - 0max 0
                        ?do     " Í" tftype
                        loop    tfcr
                then    ;

: do.hstart     ( -- )  \ define the header start contents
                on> ?+header
                off> ?+footer
                headerbuf !> h/f-ptr
                headerbuf0 ;

: do.i[         ( -- )  \ create an index entry for current page
                index-ptr 65000 u> abort" INDEXER Overflow!"
                index-ptr !> ?[-ptr
                index_seg !> ?[_seg
                on> ?[-sorting
                do.?[ ;

: do.indent     ( -- )  \ set the indent for the first line of a paragraph
                get-# !> indent ;

: do.index      ( -- )  \ display the index records
                on> ??[
                on> ?index
                ?wrap !> wrapsave       \ preserve wrap state for later
                off> ?wrap              \ turn off word wrap
                off> index-ptr          \ reset the index pointer to start
                index-ptr !> ?[-ptr
                index_seg !> ?[_seg ;

: do.lj         ( -- )  \ left justify
                off> ?center
                off> ?right
                column0 ;

: do.lm         ( -- )  \ set left margin
                get-# !> leftmargin
                column0 ;

: do.lm!        ( -- )  \ set one of the four left margin values
                get-#                   \ the margin number
                get-#                   \ the margin value
                over 1  4 between       \ margin number is 1 to 4
                over 0 40 between and   \ limit margin value to 0 to 40
                if      swap lm!                \ store margin value
                else    2drop
                        cr ."  Illegal margin parameters in this line"
                        cr readbuf count type
                        cr .file-position
                then    ;

: do.lm1        ( -- )  \ set left margin to margin 1
                leftmargins c@ !> leftmargin
                column0 ;

: do.lm2        ( -- )  \ set left margin to margin 2
                leftmargins 1+ c@ !> leftmargin
                column0 ;

: do.lm3        ( -- )  \ set left margin to margin 3
                leftmargins 2+ c@ !> leftmargin
                column0 ;

: do.lm4        ( -- )  \ set left margin to margin 4
                leftmargins 3 + c@ !> leftmargin
                column0 ;

: do.lpp        ( -- )  \ set lines per page
                get-# !> linesperpage ;

: do.page       ( -- )          \ perform a new-page fucntion
                do.footer               \ display the footer
                " " tftype             \ move to top of page
                1 !> row                \ reset the page row number
                incr> pagenumber        \ next page
                ?swapfiles              \ swap output files?
                do.header               \ display the header
                prev_buf1 off ;         \ clear index first word saver

: do.pagetop    ( -- )          \ if not top of page, then page break
                row headerlines >
                if      do.page
                then    ;

: do.pageodd    ( -- )          \ do a page if current page is ODD
                pagenumber 1 and
                if      do.page
                then    ;

: do.pageeven   ( -- )          \ do a page if current page is EVEN
                pagenumber 1 and 0=
                if      do.page
                then    ;

: do.page?      ( -<n1>- )      \ perform a new-page if less than n1 lines
                                \ remaining before footer reached
                get-# row + footerlines + linesperpage >=
                if      do.page
                then    ;

: do.pg         ( -- )  \ display page number
                ?+header ?+footer or
                if      +page-to-head/foot
                else    ?center
                        if      rightmargin page.center
                        else    ?right
                                if      rightmargin page.right
                                else    leftmargin  page.left
                                then
                        then
                then    ;

: do.rj         ( -- )  \ right justify
                on> ?right
                off> ?center
                column0 ;

: do.rm         ( -- )  \ set right margin
                get-# !> rightmargin ;

: do.spg        ( -- )  \ set page number
                get-# !> pagenumber ;

: do.t[         ( -- )  \ create an table entry for current page
                table-ptr 4000 u> abort" TABLE Overflow!"
                table-ptr !> ?[-ptr
                table_seg !> ?[_seg
                on> ?[-sorting
                do.?[ ;

: do.table      ( -- )  \ display the index records
                column0
                on> ?double             \ double space table lines
                on> ??[
                ?wrap !> wrapsave       \ preserve wrap state for later
                off> ?wrap              \ turn off word wrap
                off> table-ptr          \ reset the table pointer to start
                table-ptr !> ?[-ptr
                table_seg !> ?[_seg ;

: do.title      ( -- )  \ the embeded title of the document
                0 word drop ;           \ just discard the title for now

: do.toline     ( -- )  \ vertical align to the line specified
                get-# row - 0max 0
                ?do     tfcr
                loop    ;

: do.vlend      ( -- )  \ end vertical line
                ;

: do.vlstart    ( -- )  \ display a vertical line a column
                ;

: do.wrapoff    ( -- )  \ turn word wrap off
                off> ?wrap ;

: do.wrapon     ( -- )  \ turn word wrap on
                on> ?wrap ;

create commands         \ the supported command function list
        ' do.\          , ," .\        "
        ' do.bxbottom   , ," .bxbottom "
        ' do.bxtop      , ," .bxtop    "
        ' do.chapter    , ," .chapter  "
        ' do.cj         , ," .cj       "
        ' do.contents   , ," .contents "
        ' do.cpl        , ," .cpl      "
        ' do.c[         , ," .c[       "
        ' do.date       , ," .date     "
        ' do.fend       , ," .fend     "
        ' do.figure     , ," .figures  "
        ' do.figure     , ," .figure   "
        ' do.fstart     , ," .fstart   "
        ' do.f[         , ," .f[       "
        ' do.gutter     , ," .gutter   "
        ' do.hend       , ," .hend     "
        ' do.hl         , ," .hl       "
        ' do.hl2        , ," .hl2      "
        ' do.hstart     , ," .hstart   "
        ' do.indent     , ," .indent   "
        ' do.index      , ," .index    "
        ' do.i[         , ," .i[       "
        ' do.lj         , ," .lj       "
        ' do.lm         , ," .lm       "
        ' do.lm!        , ," .lm!      "
        ' do.lm1        , ," .lm1      "
        ' do.lm2        , ," .lm2      "
        ' do.lm3        , ," .lm3      "
        ' do.lm4        , ," .lm4      "
        ' do.lpp        , ," .lpp      "
        ' do.page       , ," .page     "
        ' do.page?      , ," .page?    "
        ' do.pageeven   , ," .pageeven "
        ' do.pageodd    , ," .pageodd  "
        ' do.pagetop    , ," .pagetop  "
        ' do.pg         , ," .pg       "
        ' do.rj         , ," .rj       "
        ' do.rm         , ," .rm       "
        ' do.spg        , ," .spg      "
        ' do.table      , ," .tables   "
        ' do.table      , ," .table    "
        ' do.title      , ," .title    "
        ' do.toline     , ," .toline   "
        ' do.t[         , ," .t[       "
        ' do.vlend      , ," .vlend    "
        ' do.vlstart    , ," .vlstart  "
        ' do.wrapoff    , ," .wrapoff  "
        ' do.wrapon     , ," .wrapon   "

here commands - constant cmdbytes       \ length of command array

: do.command    ( a1 n1 -- )    \ find and perform the command
                #tib ! 'tib !           \ set for interpretation
                >in off                 \ reset to line start
                begin   here off
                        bl word c@              \ got some text
                        here 1+ c@ ';' <> and   \ and isn't a comment
        [long]  while   here 1+ c@ '.' =        \ must start with a '.' (dot)
                        if      here count 1+ commands cmdbytes search
                                if      dup commands + 3 - @ execute
                                else    cr ." Unrecognized '.' command"
                                        cr tib #tib @ type
                                        cr .file-position beep
                                then    drop
                        then
                repeat  ;

: do.lastpage   ( -- )          \ output the last footer, and a formfeed
                do.footer
                " " tftype             \ move to top of page
                tfflush ;

: ?new.page     ( -- )          \ is it time for a new page?
                row linesperpage footerlines - >=
                if      do.page                 \ if so, then do a new page
                then    ;

: do.paragraph  ( -- )          \ force one blank line in output
                column0
                ?new.page
                tfcr ;

: line-to-output ( a1 n1 -- )   \ send the line to the output
                ?wrap                                   \ word wrap on?
        [long]  if      column 0=                       \ and at column 0
                        if      leftedge tfspaces       \ output LM
                        then
                        bl skip         \ delete blanks at start of line
                        begin   2dup bl scan 2dup 2>r nip -
                                dup column + rightmargin >=
                                if      tfcr            \ if at right margin
                                        ?new.page       \ check for new page
                                        leftmargin tfspaces     \ output LM
                                then
                                2dup + 1- c@ '.' = \ -- f1   end of sentence?
                                1 and 1+           \ -- 1|2  2 spaces on sent
        ( a1 n1 1|2 -- )        -rot tftype        \ output the word
        ( 1|2 -- )              2r> 2dup bl skip 2dup 2>r       \ and spaces
        ( 1|2 a1 n1 a2 n2 -- )  nip - rot max tfspaces drop
                                2r> ?dup 0=                     \ till line
                        until   drop                            \ is empty
        [long]  else    column0                 \ else assure column 0
                        leftmargin tfspaces     \ output left margin
                        tftype tfcr             \ then line and a CR
        [long]  then    ;

: process-aline ( -- )          \ process the counted line in READBUF
                readbuf
                $2020 over count 2 max + 2- !           \ crlf to blanks
                dup c@ 1 max 1- over c!                 \ reduce length by one
                count dup 1 >                           \ not a blank line
                if      over c@ '.' =                   \ dot command?
                        ??[ 0= and                      \ and not indexing
                        if      do.command              \ then do the command
                        else    ?+header ?+footer or
                                if      +line-to-head/foot
                                else    line-to-output  \ else output the line
                                then
                        then
                else                                    \ if line blank then
                        ?+header ?+footer or
                        if      +line-to-head/foot
                        else    2drop
                                do.paragraph            \ mark as a paragraph
                        then
                then    ;

: %read1line    ( -- f1 )       \ read a line from main file
                readhndl blineread dup  \ got a length non-zero?
                if      readbuf placel  \ then place the line in buf
                        true            \ return true, got a line
                        incr> line-counter
                else    nip nip         \ else return false nogood
                then    ;

                                \ read a line for processing
: read1line     ( -- f1 )       \ returns f1=true if we read a line ok
                ?chapter                                \ from a chapter?
                if      chapthndl blineread dup         \ then get it
                        if      readbuf placel
                                true
                                incr> line-counter
                        else    2drop drop
                                off> ?chapter           \ if empty, get
                                chapthndl bclose drop
                                %read1line              \ main file line
                        then
                else    %read1line                      \ not chaptering
                then    ;                               \ then get main file

: ?.first_letter ( -- )
                readbuf 1+ c@ index-letter c@ <>
                if      row 5 + footerlines + linesperpage >=
                        if      do.page
                        then    tfcr leftedge tfspaces  \ output LM
                        readbuf 1+ 1 tftype
                        tfcr
                        tfcr
                        readbuf 1+ c@ index-letter c!
                then    ;

: ?blank-word1  ( -- )          \ blank out first word if same as last line
                ?contents ?exit
                prev_buf1 1+
                readbuf count 2dup bl scan nip - 1+
                dup>r comp 0=                   \ compare words, prev and new
                if      readbuf 1+ r@ blank             \ blank new word
                else    readbuf 1+ r@ 31 min            \ clip length
                        prev_buf1 place                 \ get   new word
                then    r>drop ;

: get-?[-entry  ( -- f1 )  \ f1=true if got a line
                readbuf 1+ rightmargin leftmargin - 5 + blank
                readbuf 1+ rightmargin leftmargin - 7 - 0max '.' fill
                                                \ prefill with "." chars
                ?[_seg ?[-ptr @ @L >r           \ get the line number
                2 ?[-ptr +!                     \ bump past line number
                ?[_seg ?[-ptr @ countl
                dup 1+ ?[-ptr +!                \ bump to next ?[ entry
                readbuf placel                  \ place in READBUF
                readbuf c@ 0=                   \ if ?[ empty
                if      off> ??[                \ reset ??[
                        off> ?double            \ and double line spacing
                        off> ?index             \ clear indexing flag
                        off> ?contents
                        read1line               \ get a src line
                        wrapsave !> ?wrap
        [long]  else    rightmargin leftmargin - 5 - 0max readbuf c!
                                                \ set line length to full
                        r@ 0 <# #s #> 5 over - 0max readbuf c+!
                                                \ right justify
                        readbuf +place          \ drop in page number
                        2 readbuf c+!           \ allow room for CRLF
                                                \ even though they aren't
                        true                    \ there
                        ?index
                        if      ?.first_letter
                        then
                        ?blank-word1   \ blank first word if same as prev line
                then    r>drop ;

: init-formatter ( -- )         \ initialize various formatter operations
                off>  ?center           \ center justify flag
                off>  ?right            \ right justify flag
                on>   ?wrap             \ word wrap flag
                off>  contents-ptr      \ reset contents pointer
                off>  figure-ptr        \ reset figure pointer
                off>  index-ptr         \ reset index pointer
                off>  table-ptr         \ reset table pointer
                 1 !> row               \ starting at row one
                 5 !> leftmargin        \ the left margin of document
                66 !> linesperpage      \ the number of lines on a page
                 1 !> pagenumber        \ the current page number
                76 !> rightmargin       \ the right margin of document
                footerbuf0              \ zero out the footer and header
                headerbuf0
                tfbuf off               \ clear the line buffer
                contents_seg 0= abort" Failed to allocate contents memory"
                contents_seg 0 4096 0 lfill     \ clear the buffer
                  figure_seg 0= abort" Failed to allocate figure memory"
                  figure_seg 0 4096 0 lfill     \ clear the buffer
                   index_seg 0= abort" Failed to allocate Indexers memory"
                   index_seg     0 32767 0 lfill \ clear the buffer
                   index_seg 32768 32767 0 lfill \ clear the buffer
                   table_seg 0= abort" Failed to allocate table memory"
                   table_seg 0 4096 0 lfill     \ clear the buffer
                ?split
                if      readhndl >bhandle wrthndl $>bhandle
                        " PRO" ">$ wrthndl >bhandle $>ext
                        wrthndl bcreate
                        abort" Failed to create output file1"
                        readhndl >bhandle wrt2hndl $>bhandle
                        " PRE" ">$ wrt2hndl >bhandle $>ext
                        wrt2hndl bcreate
                        abort" Failed to create output file2"
                else    readhndl >bhandle wrthndl $>bhandle
                        " PRN" ">$ wrthndl >bhandle $>ext
                        wrthndl  bcreate
                        abort" Failed to create output file"
                then    ;

: get-aline     ( -- f1 )       \ get a lline to process, retunr true if ok
                ?double
                if      tfcr    then            \ start a new line
                ??[                             \ if displaying ?[,
                if      get-?[-entry            \ get entry
                        exit                    \ leave if get ?[ line
                then
                                                \ if not others,
                read1line ;                     \ then get a main line

: do.help       ( -- )
   cr ."  *** NO valid filename was specified ***"
   cr
   cr ."  USAGE:  TEXTFORM [filename<.TXT>] </SPLIT> [enter]"
   cr
   cr ."  Reads:     <filename.TXT>, a text file containing format commands"
   cr ."  Generates: <filename.PRN>, a formatted version of <filename.TXT>"
   cr
   cr ."  Using </Split>, cuases TEXTFORM to:
   cr ."  Generate:  <filename.PRO>, for ODD  pages of <filename.TXT>"
   cr ."  and        <filename.PRE>, for EVEN pages of <filename.TXT>"
   cr
   cr ."    TEXTFORM.COM is a relatively simple text formatter.  This"
   cr ."  formatter was written to generate the TCOM Users Manual from"
   cr ."  a text description file. Written by Tom Zimmer."
   cr
   cr ."  Press [enter] for a list of supported . (dot) commands,"
   cr ."          or"
   cr ."        [ESC]   to terminate the program"
   cr            key 27 = ?exit
   cr
   cr ."  .\                   start a comment line which is ignored"
   cr ."  .bxbottom            the bottom of a boxed area"
   cr ."  .bxtop # #           start the top of a box at left col, right col"
   cr ."  .chapter <filename>  Include a chapter with <filename>"
   cr ."  .cj                  center justify"
   cr ."  .c[ <contents_entry> creates an entry in the Table of Contents"
   cr ."  .contents            outputs the Table of Contents page(s) here"
   cr ."  .date # text         display the date in form # followed by text"
   cr ."                       form # 0=M/D/Y, 1=Y-M-D, 2=D.M.Y"
   cr ."                              4=M/D/Y, 5=Y-M-D, 6=D.M.Y with time"
   cr ."                       Date (and time) are preceeded by text"
   cr ."  .f[ <figure_entry>   creates an entry in the Figures page"
   cr ."  .figures             outputs the Figures page(s) here"
   cr ."  .fend                footer end"
   cr ."  .fstart              footer start"
   cr ."  .gutter              Page gutter size for book printing"
   cr ."  .hend                header end"
   cr ."  .hl                  display a horizontal line"
   cr ."  .hl2                 display a horizontal double line"
   cr ."  .hstart              header start"
   cr ."  .i[ <index_entry>    becomes an index entry for current page"
   cr ."  .indent #            indent for first paragraph line"
   cr ."  .index               output the INDEX page(s) here"
   cr ."  .lj                  left justify"
   cr ."  .lm     #            set left margin"
   cr ."  .lm! lm# lm_value    set lm# (1-4) to lm_value (0-40)"
   cr ."  .lm1 - .lm4          set left margin to left margin one, two .. four"
   cr ."  .lpp    #            set lines per page"
   cr ."  .page                insert a page break here"
   cr ."  .pg                  display page number"
   cr ."  .rj                  right justify"
   cr ."  .rm     #            set right margin"
   cr ."  .spg    #            set page number"
   cr ."  .t[ <table_entry>    creates an entry in the Tables page"
   cr ."  .table               outputs the Tables page(s) here"
   cr ."  .title               the embeded title of the document"
   cr ."  .toline #            vertical align to the line specified"
   cr ."  .wrapoff             turn word wrap off"
   cr ."  .wrapon              turn word wrap on"
   cr
   cr ."     Lines not starting with '.', are processed as text and wrapped"
   cr ."   within the specified margins when '.wordwrap' is turned on."
   cr
   cr ."   ************************************************************"
   cr
   cr ."   You can send this help to the printer by entering:
   cr
   cr ."         TEXTFORM >PRN  [enter] [enter]"
   cr ''  emit  ;

: ?/Split       ( -- )          \ /Split
                off> ?split
                >in @ bl word 1+ " /S" caps-comp 0=
                if      drop    on> ?split
                else    >in !
                then    ;

: main          ( -- )
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                " TXT" defext place             \ default file extention
                bl word readhndl $>bhandle      \ get input filename
                                                \ check its not a .PRN file
                readhndl >bhandle handle>ext " .PRN" compare 0=
                abort" Output file is .PRN, can't use .PRN for input file!"
                readhndl >bhandle ?def.ext      \ supply .TXT if not given
                readhndl bopen
                if      do.help                 \ show user how to use
                        bye                     \ and leave
                then
                ?/split                         \ split output files?
                init-formatter
                ." Processing file: " readhndl  >bhandle count type cr
                ?split
        if      ." Into Printfile1: "  wrthndl  >bhandle count type cr
                ." also Printfile2: "  wrt2hndl >bhandle count type cr
        else    ." Into  Printfile: "  wrthndl  >bhandle count type cr
        then    writeODD
                begin   get-aline
                        broken @ 0= and         \ allow Ctrl-Break to abort
                while   process-aline
                        ?new.page
                repeat   drop
                broken @
                if      ." Aborting..."
                then
                do.lastpage
                readhndl bclose drop
                wrthndl  bflush
                wrthndl  bclose drop
                ?split
                if      wrt2hndl bflush
                        wrt2hndl bclose drop
                then    ."  DONE " ;


