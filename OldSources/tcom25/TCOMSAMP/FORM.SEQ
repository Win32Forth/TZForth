\\ FORM.SEQ       Send a FORMFEED to printer            by Tom Zimmer

.options /opt /0init /tailopton         \ the compiler options

  Since 0INIT is used above, program execution just falls into whatever
code follows. 0INIT starts the program with only IP, CS, DS, SP, BP and
SI (the stack) initialized.

  This file illustrates how to make a VERY SMALL program (~70 bytes).

NOTE: Even though the .OPTIONS statement in line three above is inside a
comment area, it will still be recognized. The .OPTIONS statement can
occur anywhere in the first 32 lines of a file, and will be interpreted
as a Forth command line option list. Note the "\" after the options,
marking the remainder of the line as a comment. This is needed, since
that line is interpreted even though it sits in the middle of a group of
comment lines.

  This is just about the smallest Forth program you can write with TCOM
that will actually do something useful.

{

: main          ( -- )          \ send a FORMFEED to the printer
                12 pemit ;

}

  The following example, (which is commented out) illustrates how to
write a VERY VERY SMALL assembly language program (~9 bytes) that uses
no automatic compiler initialization at all.  The /CUSTOM_INIT option
leaves you completely on your own, and doesn't initialize ANY registers.

.options /opt /CUSTOM_INIT      \ the compilers options

CODE FORM       ( -- )
                SUB DX, DX      \ printer number 0
                MOV AX, # $0C
                INT $17
                INT $20  END-CODE


