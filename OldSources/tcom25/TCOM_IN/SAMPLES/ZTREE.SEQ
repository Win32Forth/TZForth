\\ ZTREE.SEQ    Display a sum of files in each directory for a filespec
.options /opt /noinit /tailoptoff       \ compiler options for ZTREE
***************************************************************************
                            Advertisement
***************************************************************************

  ZTREE was written in Forth, and compiled using the TCOM optimizing compiler
on the F-PC Forth system. ZTREEis public domain, as is F-PC, and TCOM. To
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
                      ZTREE Description & Usage
***************************************************************************

  This utility sums all the files in each directory, and displays a list
of directories and sums for your disk. It is used as follows:

                ZTREE <\directory> <file_spec> <enter>

  You can also type in ZTREE alone, and it will sum up your entire drive.

                ZTREE <enter>

  The ZTREEing process can be paused by pressing the space bar, and can
be terminated with ESC.

  DOS I/O re-direction is allowed, so the following:

                ZTREE \ *.SEQ >ZFOUND.LST <enter>

  This will build a file containing all the sum of all the .SEQ files
in each of your directories on the current disk into a file called
ZFOUND.LST.

  Only the first 700 files in a directory will be summed, although
you can change the constant MAXFILES and recompile ZTREE to increase of
decrease this limit.

***************************************************************************
 02/16/93 12:19 tjz     ***** NEW FEATURE *****
***************************************************************************
  CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION
  CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION

  ******** USE THIS COMMAND FEATURE WITH EXTREME CAUTION !!!!!! *********

  CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION
  CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION CAUTION
***************************************************************************

  ZTREE can now be used to clear out (DELETE) an entire directory tree or
drive of files.  A new command line option /DELETE_ALL is followed by two
parameters, a top or starting directory, and a filespec (possibly including
a directory) of files to delete from the directories at or below the
starting directory.

        Example usage:  ZTREE /DELETE_ALL C:\ *.BAK

  In the above example, all .BAK files in every directory on drive C:
will be deleted.  ZTREE prompts at each directory containing the .BAK
files, for whether the delete should occur.  The default is NO, but you
can press:  Y for yes, Q for quit, or Z for zap all directories, and don't
prompt anymore.

  CAUTION:  Use much care when pressing the 'Z' (zap all) option at the
            delete prompt, no further prompting is done, and the delete
            will proceed to delete all matching files till no more files
            are found that match the filespec given.

  A running summary count of the files deleted from each directory is
shown and a total count of all deleted files is displayed at the
end of the program run.

***************************************************************************
                          Compiling ZTREE
***************************************************************************

  You can re-compile this source file into ZTREE.COM with the following DOS
commandline:

                TCOM ZTREE <enter>

***************************************************************************
                         Program Code Begins
***************************************************************************

{

\ include profile.seq             \ include this line to run profiler

fload allspecs.seq

     0    value ?show-files
     0    value ?since-only
     0    value ?total-only
     0    value ?del-all
     0    value ?zap-all
     0    value ?no-pause
     0    value ?*.*
   700 constant maxfiles        \ only hold upto 700 filenames in list
                                \ from any given directory.
      2variable bytes_srch      \ accumulator for number of bytes searched
        0 value files_srch      \ accumulator for number of files searched
      128 array spec_buf        \ a place to hold the file specs
        0 value since-date      \ date past when we want to see files

code getfdt     ( handle# -- file-time file-date )
                                                \ handle# -> bx
                mov ah, # $057                  \ Function 57 -> ah
                mov al, # 0                     \ 0 -> al for "get"
                int $21                         \ gets the time & date
                dec si
                dec si
                mov 0 [si], cx                  \ the time to the stack
                mov bx, dx                      \ the date over it
                ret      end-code

: fgetdate      ( handle -- date )         \ get the file data & time
                >hndle @ getfdt nip ;

: ?since-check  ( -- f1 )       \ check for file since in effect, or all
                ?since-only
                if      seqhandle fgetdate      \ get the file date
                        since-date u>=          \ newer than since date?
                else    true
                then    ;

: do-since      ( -<mm/dd/yy>- )        \ get a date from commandline
                tib #tib @ >in @ /string 2dup bl skip bl scan nip - 2dup
                begin   '/' scan dup
                while   over bl swap c!         \ change '/' to a blank
                repeat  2drop
                begin   '-' scan dup
                while   over bl swap c!         \ change '/' to a blank
                repeat  2drop
                bl word number? 2drop $0F and         $20 *    \ month
                bl word number? 2drop $1F and               +  \ day
                bl word number? 2drop $7F and 80 -   $200 * +  \ year
                !> since-date
                on> ?show-files         \ we want to see which files
                on> ?since-only ;

: do_1file      ( n1 -- )       \ open search and close one file
                dup >fadr 1+ c@l '.' =
                if      drop exit
                then    >fadr dir>pad >r
                spec_buf seqhandle $>handle
                seqhandle >pathend
                dup seqhandle 1+ - r@ + seqhandle c! r> cmove
                seqhandle count + off
                seqhandle hopen 0=
                if
                    ?since-check
                    if  seqhandle endfile
                        ?show-files
                        if      cr 2dup 24 ud,.r space seqhandle count type
                        then
                        bytes_srch D+!
                        incr> files_srch
                    then
                then
                seqhandle hclose drop           \ close the file
                seqhandle clr-hcb ;             \ clear the handle

: $do_1spec     ( a1 | -- )             \ do all files in a filespec
                bytes_srch 2@ 2>r               \ previous sum count
                count spec_buf place            \ put in spec buffer
                spec_buf ?uppercase $getdir     \ read the directory files.
                ?del-all
[long]  if      2r> 2drop
                ?since-only abort" Can't use /SINCE with /DELETE"
                #fls 0= ?EXIT                   \ do, only if there are files
                ?no-pause 0=                    \ found in this directory.
                if      cr ." DELETE: " spec_buf count type
                then
                ?zap-all                        \ if not waiting for user
                if      'Z' true                \ then continue not waiting
                        ?no-pause 0=
                        if      ."  (press a key to abort)" 5 tenths
                        then    key? abort" DELETE_ALL aborted by user!"
                else                            \ else prompt for decision
                        ."  [Y/N/Q=abort/Z=delete_all] (N)?"
                        key upc dup 'Y' =       \ if user pressed Y=yes
                               over 'Z' = or
                then
        [long]  if      'Z' = !> ?zap-all       \ don't even pause for user
                        " DEL "         pad  place
                        spec_buf count  pad +place
                        ?*.*
                        if      " echo Y>ztree.y" ">$ $sys drop
                                " <ztree.y" pad +place
                        then
                        cr pad $sys drop
                        #fls 3 u,.r ."  Files deleted from: "
                        spec_buf dup count rot >pathend" nip - type
                        #fls +!> files_srch
                else    'Q' =
                        if      cr
                                true abort" Aborted /DELETE_ALL"
                        then
                then
[long]  else    #fls 0
                ?do     i do_1file              \ sum all file bytes
                        ?keypause
                loop    bytes_srch 2@ 2r> d- 2dup d0= 0=
                ?total-only 0= and
                if      cr 2dup 10 ud,.r
                        ."  in " #fls 3 u,.r ."  files"
                        ."  of " spec_buf >pathend" nip
                        spec_buf count rot - 1- 1 max type
                then    2drop                   \ display directory name
        then    ;

: pad+\spec     ( -- )
                pad count + 1- c@ '\' <>
                if      " \" pad +place
                then    bl word count over c@ '\' =
                if      1 /string
                then    pad +place ;

: $do_1set      ( a1 -- )
                >in @ >r
                begin   >in @ #tib @ <
                while   dup count pad place pad+\spec
                        pad $do_1spec
                repeat  drop r> >in ! ;

: searchallof   ( | file_specs --- )    \ Do search all matching file_specs.
                0 =: files_srch
                ." Building directory list.."
                getdirs
                cr ." Scanning directories.."
                begin   nextdir
                        dup c@
                while   $do_1set
                repeat  drop cr ;

: ?in-empty     ( --- f1 )      \ is anything left in input stream?
                >in @ bl word c@ 0= swap >in ! ;

: ?esc_bye      ( -- )          \ leave if user pressed ESC
                esc_flg @ if ABORT then ;

: get-global    ( -- )
                bl word count dup
                if      2dup '\' scan nip 0=            \ no \ found
                        ?del-all 0= and                 \ and not deleting
                        if      ">$ $>tib               \ put back in TIB
                                " \" startdir place     \ use root directory
                        else    2dup startdir place
                        then
                else    " \" startdir place
                then    2drop
                ?in-empty                   \ if nothing following
                if      " *.*" ">$ $>tib    \ default to "*.*",
                        ?del-all            \ don't allow default of *.*
        abort" Must give a seperate STARTING \DIRECTORY and FILE_SPEC to delete!"
                else    ?del-all
                        if      >in @
                                bl word 1+ " *.*" comp 0= !> ?*.*
                                >in !
                        then
                then    ;                   \ ALL files

: "option?      ( a1 n1 -- f1 )
                here 1+ -rot caps-comp 0= ;

: ?/-options    ( -- )
        begin   >in @                   \ incase we need to restore >IN
                bl word 1+ c@ '/' =     \ is first char a '\'
[long]  while   drop                    \ then discard >IN
                true                    \ put true on stack for error checking
                                \ should we display files since date only?
                " /s"           "option? if     do-since        0= then
                                \ should we display totals only?
                " /t"           "option? if     on> ?total-only 0= then
                                \ should we display the files as found?
                " /f"           "option? if     on> ?show-files 0= then
                                \ should we delete all of the files?
                " /delete_all"  "option? if     on> ?del-all    0= then
                                \ should we delete all of the files?
                " /delete_now"  "option? if     on> ?del-all
                                                on> ?zap-all
                                                on> ?no-pause   0= then
                abort" Unrecognized option"
        repeat  >in ! ;

: .info         ( -- )
        ." Tom Zimmer's TREE utility V2.3 03/15/93 -- ESC=cancel,  SPACE=pause"
                cr ." Use: ZTREE                 \dir file_spec(s) <Enter> (display total by dir)"
                cr ."  or: ZTREE /since 03/10/93 \dir file_spec(s) <Enter> (files since date)"
                cr ."  or: ZTREE /files          \dir file_spec(s) <Enter> (display files in dir)"
                cr ."  or: ZTREE /totals         \dir file_spec(s) <Enter> (display totals only)"
                cr ."  or: ZTREE /delete_all     \dir file_spec(s) <Enter> (querys at each dir)"
                cr ."  or: ZTREE /delete_NOW     \dir file_spec(s) <Enter> (NO STOP, WATCH OUT!)"
                cr      ;

: ztree         ( \directory file_spec --- ) \ Sum file sizes in directories
                DECIMAL                 \ always select decimal
                CAPS ON                 \ ignore cAsE
                ?DS: SSEG !             \ init search segment
                DOSIO_INIT              \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY        \ default to 64k code space
                DOS_TO_TIB              \ move command tail to TIB
                COMSPEC_INIT            \ initialize shelling to DOS
                ?in-empty               \ if nothing following command
                if      .info
                then
                maxfiles =: maxdir      \ up to "maxfiles" directory entries
                dirinit                 \ initialize directory words
                diralloc                \ allocate directory name space
                dirseg 0=               \ if allocated properly, non-zero
                abort" Couldn't allocate enough memory"
                20000 =: iblen          \ make read buffer larger
                lineread_init           \ initialize fast file reader
                ?/-options              \ test and detect any options
                get-global              \ search all directories?
\+ prostart     prostart
                searchallof             \ search everything
\+ proend       proend
                                        \ then report summary of search
                cr files_srch 1 u,.r    \ show files processed
                ?*.*
                if      " DEL ztree.y" ">$ $sys drop
                then
                ?del-all
                if      ."  Files deleted."
                else    ."  Files found; "
                        bytes_srch 2@ 1 ud,.r ."  Total file bytes."
                then    cr
                dirrelease              \ release directory name space
                ;

}

