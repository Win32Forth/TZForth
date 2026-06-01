\ BINSAVE.SEQ           Save Target Binary Image        by Andrew McKewan

ONLY FORTH ALSO COMPILER ALSO HOST ALSO FORTH DEFINITIONS

headerless

: save-image.bin ( -- )
                [compiler]
                ?nosave ?exit
                atsave 2@ at
                image.name targethndl $>handle
                " BIN" ">$ targethndl $>ext
                targethndl hcreate                      \ make image.com
                if      >console
                        cr ." Error while creating object file."
                        255 #bye
                then
                cr cr ." Created object file - " targethndl count type
                0 $2000 dup>r  ( always write 8K )
                targethndl seg-code exhwrite r> -       \ write CODE
                if      >console
                        cr ." Error while saving CODE to object file."
                        255 #bye
                then
                cr ." Wrote " here-t code-start - ( dup>r ) 5 u.r
                ."  Bytes of CODE." \  rounded up to Paragraph."
                cr ;

' SAVE-IMAGE.BIN IS SAVE-IMAGE.COM

headers

