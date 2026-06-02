\\ CSUM.SEQ              Calculate a Checksum for a file

        A little program to add all the bytes in a file to gether and
        display a sum in the HEX number base.

{
     handle chndl
1024 constant cmax      \ the max size of the character buffer
   0 value cbuf         \ a pointer to the checksum character buffer
 2variable csum         \ the checksum of the file

: sumbuf        ( n1 -- )
                cbuf swap bounds
                ?do     i c@ 0 csum 2@ d+ csum 2!
                loop    ;

: main          ( -<filename>- )
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                cmax ds:alloc !> cbuf
                0.0 csum 2!
                bl word chndl $>handle
                chndl hopen
                abort" You must specify a file that can be opened!"
                ."  Summing: " chndl count type
                begin   cbuf cmax chndl hread ?dup
                while   sumbuf
                repeat  chndl hclose drop
                cr ." Checksum: " hex csum 2@
                <# # # # # ',' hold # # # # #> type ;

