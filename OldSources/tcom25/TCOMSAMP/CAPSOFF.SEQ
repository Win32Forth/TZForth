\\ CAPSOFF.SEQ   Simple program to turn off the CAPS LOCK key

.OPTIONS /OPT /CUSTOM_INIT      \ compile options for this program

  /CUSTOM_INIT is used above to tell the compiler that absolutely no
initialization code is to be provided.  No registers are initialized.

   !!!!!!!!!!!!!!!  YOU ARE ON YOUR OWN COMPLETELY !!!!!!!!!!!!!!!!

{

code capsoff    ( -- )
                mov   dx, # $40         \ adjust DS to physical seg $40
                mov   ds, dx
                mov   al, $17           \ get physical mem contents $17
                and   al, # $BF         \ clear the $40 bit
                mov   $17  al           \ store result back to $17
                int $20  end-code       \ terminate back to DOS

}

  This file illustrates how to make a VERY SMALL program (~15 bytes).

NOTE: Even though the .OPTIONS statement in line three above is inside a
comment area, it will still be recognized. The .OPTIONS statement can
occur anywhere in the first 32 lines of a file, and will be interpreted
as a Forth command line option list. Note the "\" after the options,
marking the remainder of the line as a comment. This is needed, since
that line is interpreted even though it sits in the middle of a group of
comment lines.


