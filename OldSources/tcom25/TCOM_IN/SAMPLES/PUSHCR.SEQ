\\ PUSHCR.SEQ     Push a string into keyboard buffer      Tom Zimmer

  Reset the keyboard buffer to empty and push a string of upto 14
characters from the command line into the keyboard buffer, followed
by a carraige return character.

  While this is a limited utility, there are times when it is very handy
to be able to type into a program on the following commandline as if we
were typing on the keyboard.

                .options /noinit /tailopton

{

: KB+CHAR       ( c1 -- )
                $40 DUP $1C C@L !L
                $40 $1C [macro:] 2DUP C@L 2+ [macro:] -ROT C!L ;

: main          ( -- )
                $1E   $40 $1A !L                \ reset beg to start of buf
                $1E   $40 $1C !L                \ reset end to start of buf
                ?CS: $80 C@L ?DUP
                IF      14 MIN 1
                        DO      ?CS: $81 I + C@L KB+CHAR
                        LOOP
                THEN    $0D KB+CHAR ;

}

