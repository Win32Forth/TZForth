\ HEXSAVE.SEQ   save target image as a HEX file

ONLY FORTH ALSO COMPILER ALSO HOST ALSO FORTH DEFINITIONS

\ headerless

            0 value hexsum
        32 constant bytes/hexline  \ max bytes in a intel hex line
      8192 constant hexmax         \ maximum buffer contents
hexmax 2+ 0 pointer hexseg
            0 value hexlen         \ length of data in hex prewrite buffer

: hexflush      ( -- )
                0 hexlen                        \ from buffer for length
                targethndl hexseg exhwrite hexlen -
                                                \ write the buffer to file
                if      >console
                        cr ." Error while saving CODE to HEX file."
                        255 #bye
                then    off> hexlen ;           \ reset the buffer length

: hexwrite      ( a1 n1 -- )    \ a buffered write of the hex file data
                >r hexlen r@ + hexmax >                 \ if buffer too full
                if      hexflush                        \ then flush it
                then    ?cs: swap                       \ prefix with CS:
                hexseg 0 hexlen + r@ cmoveL             \ append to buffer
                r> +!> hexlen ;                         \ update buffer len

create lineend $0D c, $0A c,

: grabend       ( n -- ) \ grab n and add to string at pad
                lineend 2 pad +place ;

: "grab         ( a n -- ) \ grab string a,n and add to string at pad
                pad +place ;

create heas_buf 0 , 0 ,

code heas"      ( n1 -- a1 n1 ) \ Exchange the high and low halves of a BYTE
                pop dx          and dx, # $0FF
                add ' hexsum >body dx word              \ accumulate checksum
                mov ax, dx
                shr ax, # 1     shr ax, # 1
                shr ax, # 1     shr ax, # 1
                cmp ax, # 9
                j<= 1 $         add ax, # $37
                j   2 $
        1 $:                    add ax, # $30
        2 $:    mov heas_buf al
                mov ax, dx
                and ax, # $0F
                cmp ax, # 9
                j<= 3 $         add ax, # $37
                j   4 $
        3 $:                    add ax, # $30
        4 $:    mov heas_buf 1+ al
                mov dx, # heas_buf
                mov ax, # 2
                2push           end-code

: #grab         ( n -- a c ) \ number conversion to 2 digit ASCII
                heas" pad +place ;

: write-hexline ( -- ) \ write one line from pad to the HEX file
                pad count hexwrite
                pad off ;

0 value target-addr
0 value seg-length

: build-hexline0 ( -- ) \ send code as a hex line
        base @ >r  hex
        pad off                 \ build HEX line at pad
        off> hexsum
        " :" "grab              \ start with a :
        seg-length bytes/hexline umin           \ clip to one line
        dup>r #grab                             \ byte count for this line
        target-addr split #grab
                          #grab                 \ target address
                      $20 #grab                 \ type 20 for code bytes
        ( bytes/hexline ) r@ 0 DO
                seg-code target-addr c@L        \ get a code byte
                #grab                           \ put in hex line
                incr> target-addr               \ next image address
\                decr> seg-length
\                seg-length 0= ?leave
             LOOP
        r> negate +!> seg-length                \ reduce remaining length
        hexsum negate $0ff and #grab            \ put in the checksum
        grabend                                 \ put in an end-of-line
        r> base !
        write-hexline  ;

: build-hexline1 ( -- ) \ send extension bytes as a hex line
        base @ >r  hex
        pad off                                 \ build HEX line at pad
        off> hexsum
        " :" "grab                              \ start with a :
        seg-length bytes/hexline umin
        dup>r #grab                             \ byte count for this line
        target-addr split #grab
                          #grab                 \ target address
                      $22 #grab                 \ type 22 for ext bytes
        ( bytes/hexline ) r@ 0 DO
                seg-ext target-addr c@L         \ get an extention byte
                #grab                           \ put in hex line
                incr> target-addr               \ next image address
\                decr> seg-length
\                seg-length 0= ?leave
             LOOP
        r> negate +!> seg-length                \ reduce remaining length
        hexsum negate $0ff and  #grab           \ put in the checksum
        grabend                                 \ put in an end-of-line
        r> base !
        write-hexline  ;

\ : nspy        cr ." byte now is "
\         seg-ext  target-addr $43 + c@L . \ get an extention byte
\         seg-ext  target-addr $40 + c@L . \ get an extention byte
\       ;

: SAVE-HEX  \ write the contents of the hex file
        base @ >r  hex
        off> hexlen
        segments
        begin   @ dup while \ for each segment
                dup 2+ @                        \ get segment start
                dup !> target-addr over 4 + @   \ get segment end
                over umax                       \ end must be above start
                swap - dup
                if      target-addr               5 u.r
                        dup !> seg-length dup     8 u.r
                        dup target-addr + 1- 0max 7 u.r 4 spaces
                        #out @ 64 >
                        if      cr
                        then
                then
                0 ?do   target-addr seg-length       \ save adr and count
                        build-hexline0               \ send code
                        !> seg-length !> target-addr \ restore adr and count
                        build-hexline1               \ send ext bytes
                 bytes/hexline +loop            \ write the segment
                repeat
        drop
\       pad off
\       " :00000001FF" "grab grabend            \ add ending line
\       write-hexline
        hexflush                                \ rest of buffer to disk
        r> base !  ;

: %save-image.hex ( | -- )
                [compiler]
                seqhandle image.name   $>handle " HEX" ">$ image.name $>ext
                ?nosave ?exit
                image.name targethndl $>handle
                targethndl hcreate                      \ make image.hex
                if      cr ." Error while creating HEX file."
                        255 #bye
                then
                ."  -- End of variables -- $" here-d h. cr
                ."  -- Program Segments --" cr
                3 0
                do      ."  Start  Length   End    "
                loop    cr
                SAVE-HEX
                targethndl hclose drop          \ close the file
                #out @
                if      cr
                then    ."  Created - " targethndl count type
                cr at? atsave 2! ;

' %SAVE-IMAGE.HEX IS SAVE-IMAGE.COM

\ headers

