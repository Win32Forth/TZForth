\\

        .OPTIONS /OPT /NOINIT

{

: t1 ( -- ) \ test colour combinations
                VMODE.SET
                blinkoff
        attrib c@ >R
        cls
        8 0 do  cr
                8 0 do  j 16 * i     + DUP attrib ! ." AbCd"
                        >NORM SPACE
                                     128 + attrib ! ." AbCd"
                        >NORM ." ³"
                    loop
                cr
                8 0 do  j 16 * i + 8 + DUP attrib ! ." AbCd"
                        >NORM SPACE
                                     128 + attrib ! ." AbCd"
                        >NORM ." ³"
                    loop
                cr
                8 0 do  j 1 .r i 8 .r i 15 < if space then loop
            loop
        key drop
        r> attrib c!
        ;


