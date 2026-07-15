\ TCOMNDX.SEQ   TCOM's Index file builder   by Tom Zimmer & Jerry Boutelle

only forth definitions assembler also host also compiler also forth also

\+ ?indexing    on> ?indexing   \ we are going to use the indexer

          0 value inxcnt        \ count of chars in index buffer
          0 value inxbuf
        outbuf !> inxbuf        \ initialize defered buffer pointer to
                                \ outbuf. May be changed by the translator
                                \ to point to some other buffer

    4096 constant inxmax
inxmax 0  pointer inxseg        \ index segment buffer

\ TCOM is defaulted to /INDEX in the compilers initialization routine in
\ COMPILE2.SEQ

: /index        ( -- )
                on> ?index
                /sym ;

' /index alias /ind
' /index alias /inx

: /indexoff     ( -- )
                off> ?index ;

' /indexoff alias /noindex
' /indexoff alias /noinx

\ **********************************************************************
\ Listing control, shells to an external program to generate the listing
\ **********************************************************************

0 value ?withlib
0 value ?nolib

: /lst          ( -- )          \ generate listing
                /debug
                on> ?lst
                /index ;

' /lst alias /list
' /lst alias /listing

: /nolist       ( -- )
                /clean
                off> ?lst ;

' /nolist alias /nolst

: /lstlib       ( -- )          \ generate listing, with full library
                /lst
                on> ?withlib ;

: /lstnolib     ( -- )          \ generate listing, without library
                /lst
                on> ?nolib ;

I: %make_listing ( -- )          \ build a listing file
                [ hidden ]
                closeall
                ."  Invoking .LST generator.. [press Ctrl-Break to cancel]"
                mypathhndl count        pad  place      \ program path
                " ls86 "                pad +place      \ batch file
                image.name >pathend"    pad +place      \ append file
                ?withlib                                \ user wants lib?
        if      "  /lib"                pad +place      \ append "/LIB"
        then    ?nolib                                  \ user wants NO lib?
        if      "  /nolib"              pad +place      \ append "/nolib"
        then    cr space pad count type cr
                pad $sys drop                           \ make listing
                at? at cr ;

' %make_listing is make_listing         \ link into compiler

I: %compress.COM ( -- )          \ build a listing file
                [ hidden ]
                closeall
                ."  Invoking .COM compressor.. [press Ctrl-Break to cancel]"
                mypathhndl count        pad  place      \ program path
                " lz /e "               pad +place      \ batch file
                image.name >pathend"    pad +place      \ append file
                cr space pad count type cr
                pad $sys drop                           \ compress .COM
                at? at cr ;

' %compress.COM is compress.com

\ **********************************************************************

I: ifield        ( n1 n2 -- n3 )         \ compile time
                ( a1 -- a2 )
                create over c, +        \ compile offset & increment to next
                does> c@ + ;            \ adjust a1 to field address a2

0                       \ starting at field offset zero (0),
  2 ifield >targaddr    \ target address field
  3 ifield >srcoff/type \ Combined source file offset and type nibble
  1 ifield >srcfile#    \ source file number in .FIL file
constant ibuf_len       \ length of index record buffer

ibuf_len array index_buf \ -- uses stack value for total length of fields

handle indexhndl         \ index file handle

I: inxflush      ( -- )
                ?index 0= ?exit
                inxcnt 0= ?exit
                0 inxcnt indexhndl inxseg exhwrite inxcnt <>
                if      indexhndl hclose drop           \ if not, close
                        off> ?index                     \ disable index
                        0 " Index file write error" "errmsg     \ issue error
                then    off> inxcnt ;

I: inxwrite      ( a1 n1 -- )    \ write string to index buffer
                inxcnt over + inxmax u>
                if      inxflush
                then    inxmax umin >r
                ?cs: swap inxseg inxcnt r@ cmovel r> +!> inxcnt ;

I: ?index_make   ( -- f1 )       \ open index file if needed. f1=true=ok
                indexhndl >hndle @ 0<
                if      image.name indexhndl $>handle
                        " INX" ">$ indexhndl $>ext
                        indexhndl hcreate
                        if      0 " Failed to create {filename.INX}!" "errmsg
                                false
                        else    true
                        then
                else    true
                then    ;

I: ?index_close  ( -- )          \ close index on exit from Forth
                defers byefunc
                indexhndl >hndle @ 0< ?exit
                inxflush
                indexhndl hclose drop ;

' ?index_close is byefunc

I: #del_index    ( n1 -- )       \ delete n1 previous index records
                >r inxflush
                indexhndl curpointer    \ -- d1         total file length
\ cr ." Deleting.." r@ . 2dup h. h.
                r> ibuf_len * 0         \ -- d1 d2      distance to backup
                d- 0.0 dmax             \ -- d3         backup min of 0
\ 2dup h. h.
                indexhndl movepointer ;               \ move to new file end

\ **********************************************************************
\ Special word to clear the extention byte of targets that use extention
\ bytes.
\ **********************************************************************

DEFER EXT>0     ' DROP IS EXT>0         \ initally just discard parameter

\ This word backs up the compiled output n1 bytes, and n2 instructions.

I: del_b/i       ( n1 n2 -- )    \ backup n1 bytes, and n2 instructions
                swap abs dup negate %ALLOT-T    \ discard bytes
                EXT>0                           \ zero out extention bytes
                LIHERE =: LINESTRT              \ re-align "here"
                #del_index  ;                   \ delete index records

\ **********************************************************************
\ Type NIBBLEs for first byte index records
\ **********************************************************************

0 constant notype
1 constant othertype
2 constant insttype
3 constant calltype
4 constant bytetype
5 constant wordtype
6 constant stringtype
7 constant endtype

    notype $08 + constant branchtype
 othertype $08 + constant :othertype
  insttype $08 + constant :insttype     \ limited to 4 bits
  calltype $08 + constant :calltype     \ limited to 4 bits
  bytetype $08 + constant codebytetype
  wordtype $08 + constant codewordtype
stringtype $08 + constant :stringtype
   endtype $08 + constant starttype

: index!        ( n1 a1 -- )    \ given type n1 a nibble and a1 the target
                                \ address, \ merge with the current file
                                \ offset and set in buffer
                ?index 0= if 2drop exit then
\ cr ." Indexing.." inxcnt 0 indexhndl curpointer d+ h. h. dup h. over h.
                >r
                ?index_make
        if      >r
                filepointer 2@          \ get the current file offset
                inxbuf c@ 0 d-          \ subtract current line length
                r@ insttype =           \ if instruction type
                r@ calltype = or        \ or CALL type
                r@ wordtype = or        \ make C, & , use same file offset
                r@ bytetype = or        \ for all of a series of C,'s or ,'s.
                if      asm->in         \ use assembler value for >IN
                        r@ wordtype =    \ if word, or byte, then bump by
                        r@ bytetype = or \ one to make sure we are not
                        if      1+       \ at the line start
                        then
                else    >in_word @      \ else use WORD's value for >IN
                then    0 d+            \ add the offset into this line
                0.0 dmax                \ above zero
                $0F and                 \ mask high byte to lower nibble
                r> $0F and $10 * +      \ add in type nibble
                           index_buf >srcoff/type       \ result into buf
                           swap over c! 1+ !            \ three bytes
                r@         index_buf >targaddr !        \ targ addr to buf
                curfil#    index_buf >srcfile# c!       \ cur file# to buf
                index_buf ibuf_len inxwrite             \ write one record
        else    drop
        then    r>drop ;

\ **********************************************************************
\ since the following two words change IC, and CC, to use C,-T, they
\ must be installed at application compile startup time by TARGET-INIT
\ **********************************************************************

: xIC,          ( b1 -- )               \ index an instruction first byte
                state @
                if      :insttype here-t index!
                else     insttype here-t index!
                then    %c,-t ;

: xCC,          ( b1 -- )               \ index an instruction first byte
                here-t =: prev-call-addr
                state @
                if      :calltype here-t index!
                else     calltype here-t index!
                then    %c,-t ;

: xDB,          ( b1 -- )               \ index an instruction first byte
                codebytetype here-t index!
                %c,-t ;

' XDB, IS DB,

: xDW,          ( w1 -- )               \ index an instruction first byte
                codewordtype here-t index!
                %,-t ;

' XDW, IS DW,

\ -1 value last_dataaddr

: xC,-D         ( b1 -- )               \ index an DATA BYTE
\               here-d last_dataaddr <>
\               if
                        bytetype here-d index!
\               then
                defers c,-d
\               here-d !> last_dataaddr
                ;

' xc,-d is c,-d

: x,-D          ( n1 -- )               \ index an DATA WORD
\               here-d last_dataaddr <>
\               if
                        wordtype here-d index!
\               then
                defers ,-d
\               here-d !> last_dataaddr
                ;

' x,-d is ,-d

: xS,-D         (  -- )               \ index an DATA STRING
                stringtype here-d index!
                defers s,-d
                endtype here-d index! ;

' xs,-d is s,-d

\ : xALLOT-D      ( n1 -- )               \ index an DATA ALLOT
\                 dup
\                 case
\                         1 of  bytetype   here-d index!  endof
\                         2 of  wordtype   here-d index!  endof
\                               stringtype here-d index!
\                               drop
\                 endcase
\                 defers allot-d ;
\                endtype here-d index! ;
\
\ ' xallot-d is allot-d

: %switching_files ( -- )       \ mark in index whenever we switch files
                othertype here-t index! ;

' %switching_files is switching_files

: xsegment_end    ( -- )        \ mark the end of previous segment
                endtype here-t index! ;

' xsegment_end is segment_end

: xsegment_start  ( -- )        \ mark the start of this segment
                starttype here-t index! ;

' xsegment_start is segment_start

: branch_mark   ( -- )          \ mark start of a branch operation
                branchtype here-t index! ;

\ **********************************************************************
\ The following four words here are redefined to allow building a symbol
\ table in a different format than is provided.
\
\ .SYM  The symbol file (one per project) generated by the compiler. The
\       symbol file holds the following information in a fixed 48 byte
\       record:
\
\       bytes           field
\       ------------------------------------------------------------
\       32     Symbol name as a count byte and upto 31 ascii characters
\        1     Symbol type byte (constant, variable, function, macro..)
\        2     Resolution address or high word of double constant
\        2     initial value, or low word for double constant
\        1     file # of source file
\        4     double offset into source file where symbol was defined
\        2     size field of symbol in bytes
\        2     segment number for relocatable segments
\        2     scope information (internal/external/public)
\
\ **********************************************************************

0                       \ starting at field offset zero (0),
 32 ifield >symname     \ symbol name as a counted string
  1 ifield >symtype     \ symbol type for TCOM (macro, function, variable..)
  2 ifield >symresaddr  \ symbols resolution address
  2 ifield >symvalue    \ symbols initial value if a VALUE or CONSTANT
  1 ifield >symfile#    \ source file number in .FIL file
  4 ifield >symoffset   \ source file offset in bytes
  2 ifield >symsize     \ size in bytes of data symbol
  2 ifield >symseg#     \ symbol segment number
  2 ifield >symscope
constant sym_len        \ length of symbol record buffer

I: %header      ( -- )          \ write header for debugger symbol file
                ;

I: %footer      ( -- )          \ write footer for debugger symbol file
                                \ footer is a special end record to notify
                                \ the compiler when the symbol file is later
                                \ loaded, where the new CODE origin should
                                \ be when prepending a previous compile.
                ?sym 0= ?exit
                symbuf sym_len erase            \ zero out symbol and name
                code_total symbuf >symscope !   \ set the total CODE bytes
                data_total symbuf >symoffset !  \ set the total DATA bytes
                symbuf sym_len symbwrite ;      \ write this special symbol

I: %symwrite    ( a1 -- a1 )    \ a1 = CFA of symbol
                ?sym 0= ?exit
                dup >name
                [ ' NO-NAME >name ] literal = ?exit     \ don't bother writing
                                                        \ headerless symbols
                dup>r
                symbuf sym_len erase                            \ clear buffer
\+ yseg         yseg @ r@ >name dup>r
\+ yseg         ?cs: symbuf >symname r> yc@ 31 and 1+ cmovel
\+ headseg      r@ >name +headorg 6
\+ headseg      ?cs: symbuf >symname 2over c@l 31 and 1+ cmovel
                symbuf >symname dup c@ 31 and swap c!           \ clean count
\+ yseg         symbuf >symname count + 1-
\+ yseg         dup c@ 127 and swap c!                          \ clean hibit
                r@ >dtype   c@         symbuf >symtype   c!     \ set sym type
                r@ >resaddr  @         symbuf >symresaddr !     \ resolved adr
                r@ >dtype c@ {v} =                              \ if a value
                if      r@ >dinitial @                          \ get initl val
                else    0                                       \ else zero
                then                   symbuf >symvalue   !     \ initial val
                r@ >dsize    @
                r@ >dtype c@ {t} =              \ if table, use extra fetch
                if      @       then   symbuf >symsize    !     \ data size
                r@ lib_end u<                                   \ in library?
                if      0              symbuf >symfile#  c!     \ NULL source
                        0.0            symbuf >symoffset 2!     \ pointers!
                else    r@ >dtype c@
                         dup {d} =      \ variable, 2variable, array,
                                        \ create or handle
                        over {e} = or   \ defered word
                        swap {t} = or   \ table
                   if   r@ >dinitial c@
                                       symbuf >symfile#  c!
                        r@ >dinitial 1+ 2@
                                       symbuf >symoffset 2!
                   else curfil#        symbuf >symfile#  c!     \ src file#
                        filepointer 2@
                        outbuf c@ 0 d- 0.0 dmax
                        >in_word @ 0 d+                         \ src offset
                                       symbuf >symoffset 2!
                   then
                then    r>drop
                symbuf sym_len symbwrite ;                      \ write symbol

' %header     is symheader      \ install the defered
' %footer     is symfooter      \ symbol table building
' %symwrite   is symwrite       \ words.

\ **********************************************************************
\ Append source file information to symbol record in compilers memory
\ **********************************************************************

: %file_data,   ( -- )          \ include source infromation in symbol
                curfil# c,                      \ source file number
                filepointer 2@                  \ next line start
                inxbuf c@ 0 d-                  \ minus current line
                >in_word @ 0 d+ , , ;           \ plus word's  offset

' %file_data, is file_data,

\ **********************************************************************
\ Include CONSTANTS in the symbol file
\ **********************************************************************

I: %index_constant ( a1 -- )
                ?sym 0= if drop exit then
                >r
                symbuf sym_len erase                    \ clear buffer
\+ yseg         yseg @ r@ >name dup>r
\+ yseg         ?cs: symbuf >symname r> yc@ 31 and 1+ cmovel
\+ headseg      r@ >name +headorg 6
\+ headseg      ?cs: symbuf >symname 2over c@l 31 and 1+ cmovel
                symbuf >symname dup c@ 31 and swap c!           \ clean count
\+ yseg         symbuf >symname count + 1-
\+ yseg         dup c@ 127 and swap c!                          \ clean hibit
                r@ >dtype   c@         symbuf >symtype   c!   \ set sym type
                r@ >resaddr  @         symbuf >symresaddr !   \ resolved adr
                r@ >dtype   c@
                 dup {2c} =                                   \ if dbl const
                swap {v}  = or                                \ or value
                if      r@ >dinitial @ symbuf >symvalue   !   \ initial val
                then
                curfil#                symbuf >symfile#  c!   \ src file#
                filepointer 2@                                \ next line
                outbuf c@ 0 d- 0.0 dmax                       \ sub line len
                >in_word @ 0 d+                               \ add line off
                                       symbuf >symoffset 2!
                r@ >dsize    @         symbuf >symsize    !   \ data size
                symbuf sym_len symbwrite                      \ write sym
                r>drop ;

' %index_constant is index_constant

only forth also definitions

