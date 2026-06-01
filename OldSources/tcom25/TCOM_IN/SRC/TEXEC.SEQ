\ TEXEC.SEQ     Shell command library function          by Tom Zimmer

comment:

  This file along with "EXECF" in LIBRARY.SEQ provides an interface to
DOS allowing commands to be shelled out.

  An example definition of MAIN is provided at the end of this file.
Place it in SAMPLE.SEQ and compile with this library file to make a
simple example of "shelling out" to DOS.

comment;

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

$80 ARRAY EXEC.BUF
$10 ARRAY EXEC.PARAM
$30 ARRAY CMDPATH

: EXEC.BUF+/c+$ ( a1 -- )
                " /C "   exec.buf  place
                count    exec.buf +place
                exec.buf count + off ;

: $sys          ( command_line --- f1 )         \ spawn a shell
                cmdpath c@ 0= abort" COMSPEC not initialized"
                exec.param 16 erase
                dup c@
        if      exec.buf+/c+$
        else    drop exec.buf off
        then    ?CS: 44 @L  exec.param      !   \ environment segmnt
                ?ds:        exec.param  4 + !   \ command line seg
                exec.buf    exec.param  2 + !   \ and offset
                $0D exec.buf count + c!         \ append a carraige return
                cmdpath count + off
                cmdpath 1+ exec.param execf ;

: ?syserror     ( n1 --- )      \ handle ONLY error codes 2 and 8 from $sys
                dup  2 = abort" Can't find COMMAND.COM"
                dup  8 = abort" Not enough memory"
                drop ;

>FORTH FORTH TARGET >TARGET

\S      Stop loading HERE!
\ ***************************************************************************
\  Put the following into SAMPLE.SEQ, and you can spawn a simple DOS shell.

: MAIN          ( -- )
                ." Enter a command line->"
                PAD 1+ 80 EXPECT SPAN @ PAD C!
                CR
                PAD $SYS DROP BYE ;

