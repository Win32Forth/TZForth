\\ CURSOR.SEQ            Turn on the computers cursor    by Tom Zimmer
.options /opt /0init /tailopton

  This file is an example of a very small program that just turns the
cursor on. It also illustrates a use of "0INIT", that initializes in a
VERY MINIMAL WAY only DS and the stacks. The 0INIT overhead is only about
23 bytes, much smaller than the 200+ byte /NOINIT, which performs only
machine initialization, and no special I/O initialization. Of course
/NOINIT is itself much less initialization than /DEFINIT, which
intializes most of the I/O functions, with an overhead of about 2.5k.

  While these different forms of initialization may seem confusing, they
provide substantial flexibility to you the programmer in deciding how
much initialization is needed by your program. Of course you may not know
how much initialization is needed, in which case you should always use
the most available (/DEFINIT).  Reducing initialization overhead requires
knowledge of the application, and the compiler. Study the file
DEFINIT.SEQ in the \TCOM\SRC directory, and read the notes contained in
HISTORY.DOC for further information.

{

: main          ( -- )
                cursor-on ;

