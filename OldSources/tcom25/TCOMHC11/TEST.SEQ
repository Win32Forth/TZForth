\\ test.seq             A test file for 6805            by Tom Zimmer

                .options /opt /debug
{

variable bingo
variable bozo
variable bongo

CODE bolo       ( -- n1 )
                push,
                ldaa # $97
                tsy
                neg 34 y
                adda 22 y
                ldy # 234
                cpd # 1234h
                cpd bolo
                ldx 23 y
                rts     end-code

MACRO bulgogy   ( -- )
                dec bozo
                END-MACRO


: looper        ( -- )
                for
                next
                ;

: loopity       ( n1 n2 -- n3 )
                for 1+ next ;

: MAIN          ( -- )
                33 >R R>
                bingo decr
                bulgogy
                bolo
                500MS
                7 looper
                9 5 loopity drop
                34 dup
                swap
                drop
                bingo @
                5 +
                bongo 5 + !
                dup
                swap drop
                bingo bongo 7 cmove ;


