\\ D.SEQ        Display files in each directory for a filespec
.options /opt /noinit           \ compiler options for D
***************************************************************************
                            Advertisement
***************************************************************************

  D was written in Forth, and compiled using the TCOM optimizing compiler
on the F-PC Forth system. D is public domain, as is F-PC, and TCOM. To
obtain the latest version of F-PC, and TCOM send $60.00 to this address:

                       Tom Zimmer
                       292 Falcato Drive
                       Milpitas, Ca. 95035

                               Home (408) 263-8859
                               Work (408) 432-4643

  F-PC and TCOM are shipped on two 1.2 meg "AT" 5 1/4 inch floppy disks. If
you need another format, be sure to specify the format and include $5.00
for additional handling.

***************************************************************************
                      D Description & Usage
***************************************************************************

  This utility sums all the files in each directory, and displays a list
of directories and sums for your disk. It is used as follows:

                D <file_spec> <enter>

  You can also type in D alone, and it will display the current directory

                D <enter>

  The Ding process can be paused by pressing the space bar, and can
be terminated with ESC.

  DOS I/O re-direction is allowed, so the following:

                D *.SEQ >DFOUND.LST <enter>

  This will build a file containing a list of all the .SEQ files
in your directories on the current disk into a file called DFOUND.LST.

  Only the first 700 files in a directory will be shown, although
you can change the constant MAXFILES and recompile D to increase of
decrease this limit.

***************************************************************************
                          Compiling D
***************************************************************************

  You can re-compile this source file into D.COM with the following DOS
commandline:

                TCOM D <enter>

***************************************************************************
                         Program Code Begins
***************************************************************************

{

\ fload allspecs.seq

   700 constant maxfiles        \ only hold upto 700 filenames in list
                                \ from any given directory.
        2variable bytes_srch    \ accumulator for number of bytes searched
          0 value files_srch    \ accumulator for number of files searched
        128 array spec_buf      \ a place to hold the file specs
        128 array cmd$          \ command line string
         -1 value ?sorted
          0 value ?pause
          0 value ?names
          0 value ?count

: do_1file      ( n1 -- )       \ open search and close one file
                dup >fadr 1+ c@l '.' =
                if      drop exit
                then    >fadr dir>pad >r
                spec_buf seqhandle $>handle
                seqhandle >pathend
                dup seqhandle 1+ - r@ + seqhandle c! r> cmove
                seqhandle count + off
                seqhandle hopen 0=
        [long]  if      seqhandle >pathend"
                        14 over - spaces type space
                        seqhandle endfile 2dup bytes_srch D+!
                        ?names 0=
                        if      2dup 9 ud,.r space
                        then    2drop
                        #out @ 70 >
                        if      cr
                                ?pause ?dup
                                if      -23 <
                                        if      ." Press a key to continue"
                                                key 27 = if bye then cr
                                                -1 !> ?pause
                                        else    decr> ?pause
                                        then
                                then
                        then
                        incr> files_srch
                then
                seqhandle hclose drop           \ close the file
                seqhandle clr-hcb ;             \ clear the handle

: $do_1spec     ( a1 -- )       \ do all files in a filespec
                files_srch >r                   \ previous file count
                bytes_srch 2@ 2>r               \ previous sum count
                count spec_buf place            \ put in spec buffer
                spec_buf count + 1- c@ '\' =    \ if spec ends in \
                if      " *.*" spec_buf +place  \ then append *.*
                then
                spec_buf count '.' scan nip 0=
                if      " .*" spec_buf +place   \ add .* to name given
                then
                spec_buf ?uppercase $getdir     \ read the directory files.
                ?count
                if      #fls +!> files_srch
                        cr #fls 3 u,.r ."  files and directories found in "
                        spec_buf count type
                        2r> 2drop
                        r>drop
                        EXIT                    \ leave here
                then
                cr
                ?sorted
                if      #fls 100 >
                        if      ." One moment, sorting directory names..."
                                cr
                        then    sortdir
                then    cr
                #fls 0
                ?do     i do_1file              \ sum all file bytes
                        ?keypause
                loop    cr bytes_srch 2@ 2r> d- 10 ud,.r
                ."  in " files_srch r> - dup 1 u,.r ."  files"
                ."  of " spec_buf count type 2 spaces
                #fls swap - 1 u,.r ."  directories found"
                ;

: searchallof   ( | file_specs --- )    \ Do search all matching file_specs.
                begin   bl word dup c@
                while   $do_1spec
                repeat  drop ;

: ?in-empty     ( --- f1 )      \ is anything left in input stream?
                >in @ bl word c@ 0= swap >in ! ;

: ?esc_bye      ( -- )          \ leave if user pressed ESC
                esc_flg @ if ABORT then ;

: def-spec      ( -- )
                ?in-empty                   \ if nothing following
                if      " *.*" ">$ $>tib    \ default to "*.*",
                then    ;                   \ ALL files

: .order-info   ( -- )
                cls
cr ." D.COM is a public domain example program written in Forth by Tom Zimmer."
cr ." D.COM was compiled with the TCOM Optimizing Forth Target COMpiler."
cr
cr ." If you would like to have the source for D and other TCOM example programs,"
cr ." send a check for US$60 to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for D and"
cr ." other TCOM example programs on 3.5 inch 1.44 meg disks."
cr
cr ." Example programs include:
cr
cr ."   ZLIST file viewer       SZ    small editor      VED    Virtual Editor"
cr ."   LOOK  file searcher     ZTREE disk space util   TIMEIT elapse timer"
cr ."   CLOCK Roman num clock   TETRA a game            VMODE  video mode set"
cr
cr ." and many others, plus F-PC, the FULL Forth system on which TCOM is built."
cr ." This package totals almost five megabytes installed, with full source."
cr              ;

: .info         ( -- )
        ." Tom Zimmer's Directory display utility V1.2 03/16/93 -- ESC=cancel  SPACE=pause"
                cr ." Usage: D {/option {..}} {file_spec {file_spec {...}}} {/option {..}} <Enter>"
                cr ." Options: /? = program information    /N = list names only"
                cr ."          /P = pause on each page     /U = unsorted directory"
                cr ."          /O = list options only      /C = count files only"
                cr      ;

: "option?      ( a1 n1 -- f1 )
                here 1+ -rot caps-comp 0= ;

: ?/-options    ( -- )
                cmd$ off
                begin   bl word c@
        [long]  while   case true
                                " /?" "option? of .order-info bye endof
                                " /U" "option? of    off> ?sorted endof
                                " /P" "option? of  -10 !> ?pause  endof
                                " /N" "option? of     on> ?names  endof
                                " /C" "option? of     on> ?count  endof
                                " /O" "option? of             bye endof
                                drop
                                here count cmd$ +place
                                "  "       cmd$ +place
                        endcase
                repeat  cmd$ $>tib ;

: D             ( \directory file_spec --- ) \ Sum file sizes in directories
                DECIMAL                 \ always select decimal
                CAPS ON                 \ ignore cAsE
                ?DS: SSEG !             \ init search segment
                DOSIO_INIT              \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY        \ default to 64k code space
                DOS_TO_TIB              \ move command tail to TIB
                COMSPEC_INIT            \ initialize shelling to DOS
                maxfiles =: maxdir      \ up to "maxfiles" directory entries
                dirinit                 \ initialize directory words
                diralloc                \ allocate directory name space
                dirseg                  \ if allocated properly, non-zero
                0.0 bytes_srch 2!
                off> files_srch
        if      20000 =: iblen          \ make read buffer larger
                lineread_init           \ initialize fast file reader
                .info
                ?/-options              \ check for dir options
                def-spec                \ default file specification
                searchallof             \ search everything
                                        \ then report summary of search
                cr files_srch 1 u,.r    \ show files processed
                ."  Files found"
                ?count 0=
                if      ." ; " bytes_srch 2@ 1 ud,.r ."  Total file bytes."
                else    ."  total"
                then    cr
                dirrelease              \ release directory name space
        else    cr ." Couldn't allocate enough memory"
        then    ;

}

