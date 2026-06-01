\ TERMSTAY.SEQ  An example of how to make a program terminate & stay resident

CODE TERM&STAY  ( n1 -- )               \ terminate and stay resident
                                        \ reserve n1 paragraphs for program
                mov dx, bx              \ move BX (top of stack) to DX
                mov ax, # $3100         \ func 31, return code 0
                int $21
                ret     end-code        \ never gets here I hope

\ Use "0 SET_MEMORY" to reduce the programs allocated memory to the minimum
\ size actually needed.

: main          ( -- )
                dosio_init
                0 set_memory

\ Insert any functions here to capture interrupts for your program to process

\               ............

\ Then use the following lines at the end of your TCOM program.
\ They determine how much memory to retain and then terminate with
\ only that amount of memory reserved.

                ?ds: ?cs: -             \ CODE space paragraphs needed
                memend @ paragraph +    \ DATA space paragraphs needed
                term&stay               \ terminate with needed paragraphs
                ;

