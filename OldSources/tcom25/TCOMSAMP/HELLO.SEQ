\\ HELLO.SEQ         Smallest TCOM Hello World           by Tom Zimmer

 This file illustrates the limits to which it is possible to go in trying
to minimize the size of a program. This simple program just displays
"Hello World!" on the display with a blank line above and below the
message.   While it is not very useful, it does contain a few interesting
tricks to notice.

 The first example program, shows the absolute extremes possible.
/ASM disables all automatic program initialization, and essentially tells
the compiler that this is an assembly language program, not a Forth
program. In this example, the first three instructions form the absolute
minimum amount of initialization that needs be done for an assembly
language program that uses information from the data segment.  It just sets
the data segment, and thats it.  The string "Hello World!" is placed in the
data segment.  No stacks are available, or needed in this version of the
program. The resulting program is 49 bytes.

{
        .options /asm

create helloadr ,"  Hello World" $0D0A ,
        $0A0D helloadr !                \ fill in first two bytes with crlf

main:           MOV AX, CS              \ get a copy of the CODE segment
                ADD AX, # $E4F6         \ patched later
                MOV DS, AX              \ Set the data segment
                mov bx, # helloadr
                mov cx, # 14
        0 $:    mov dl, 0 [bx]
                mov ah, # 6
                int $21
                inc bx
                loop 0 $
                int $20   end-code

\\
 The remainder of this file illustrates less extreme examples of the same
program.

----------------------------------------------------------------------------

 The simplest Forth version of the program appears as follows:

                .options /opt

: main          ( -- )
                cr ." Hello World!" cr ;

 In this version, no .OPTIONS directive telling the compiler not to
initialize I/O is included in the source file, so automtic I/O
initialization is performd.  Actually the .OPTIONS statment isn't needed
at all since the /OPT directive is a default compiler directive anyway.
This simple version of the program will result in abount a 2.5k byte
program.

----------------------------------------------------------------------------

 A large amount of space can be saved by selecting only the I/O initialization
needed by the program.  This example will compile to about 1100 bytes.

        .options /opt /noinit

: main          ( -- )
                dosio_init
                cr ." Hello World!" cr ;

 Here space is saved because much unneeded initialization is not done.
However, even this version performs initialization of some I/O that is not
needed.

---------------------------------------------------------------------------

 Even more space can be saved by avoiding initialization, and writing the
program so initialization is not needed.  this example will compile to less
than 160 bytes.

 Here the /0INIT options doesn't initialize any I/O, and includes
only a minimum amount of stack initialization.  The result is that the
program begins execution at the FIRST function, unlike a normal
TCOM program which starts execution at the last colon definition in the
program.

        .options /opt /0init

create hello$ ,"   Hello World  "
        $0A0D hello$ !                \ fill in first two bytes with crlf
        $0A0D hello$ count + 2- !     \ set last two bytes to crlf

: main          ( -- )
                hello$ count 1-
                for     dup c@ dosemit 1+
                next    drop ;

---------------------------------------------------------------------------

  Whatever level of optimization or customization you choose, I hope you
will find TCOM easy to use.






