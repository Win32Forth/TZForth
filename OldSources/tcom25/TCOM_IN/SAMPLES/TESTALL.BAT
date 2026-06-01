@echo off
cls
echo.
echo You are about to compile all of the TCOM sample programs.
echo All of the compiler messages will be directed to file TESTALL.LST
echo.
echo You should have a couple of megabytes of harddisk space available before
echo running this batch file, since 70+ programs will be added to your hard
echo disk. With total memory requirements exceeding 1 megabyte including all
echo generated data files.
echo.
echo These compiles all use the "/CLEAN" compile option to automatically discard
echo any data files created by the compile, so if an error is encountered you
echo will need to recompile a program manually before attempting to debug the
echo problem.
echo.
echo It takes a while to compile these 70+ programs, so take a break.
echo When this completes, read TESTALL.LST for any error messages.
echo.
pause or press Control-Break to abort
@echo ----------------------------------------------------------------------
@echo BANNER,   A banner generator program.
tcom  BANNER    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >TESTALL.LST
@echo ----------------------------------------------------------------------
@echo BEGTIME & ENDTIME, A pair of utilities for keeping track of time used on a
@echo           project.
tcom  BEGTIME   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
tcom  ENDTIME   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo BINEDIT,  An editor for binary files.
tcom  BINEDIT   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo CAPSOFF,  A utility to turn off the CAPS LOCK key.
tcom  CAPSOFF   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo CARD,     A simple card file database program.
tcom  CARD      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo CLOCK,    A roman numeral visual clock program.
tcom  CLOCK     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo COLOURS,  A program to display all color combinations.
tcom  COLOURS   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo CSUM,     A program to calculate the checksum of a file.
tcom  CSUM      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo CURSOR,   A program to turn the cursor back on.
tcom  CURSOR    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo D,        A simple sorted directory program.
tcom  D         /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo DDUP,     A simple single drive fast disk duplicator, uses the hard disk
@echo           to hold the floppy image being copied. will also format if needed.
tcom  DDUP      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo DESCR,    User donated utility to create a specialized description file.
tcom  DESCR     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo DOODLE & DRAW, A pair of programs that allow simple graphic drawing with the
@echo           mouse.
tcom  DOODLE    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
tcom  DRAW      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo EMMTEST,  A program to illustrate TCOM's Expanded Memory support.
tcom  EMMTEST   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo FILTER,   A program illustrating how to make a file filter program.
tcom  FILTER    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo FLOATER,  A program demonstrating TCOM's floating point support.
tcom  FLOATER   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo FORM,     A program to send a formfeed to the printer.
tcom  FORM      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo G,        A program to make movement between directories easier.
tcom  G         /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo GCLOCK,   A graphics clock program.
tcom  GCLOCK    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo GLOBAL,   Performs a simple global edit on a set of files.
tcom  GLOBAL    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo GSS,      A Graphic Screen Saver, shows squares on VGA VERY QUICKLY.
tcom  GSS       /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo GT,       A program to test your video cards graphic memory speed.
tcom  GT        /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo HELLO,    A program that build an extremely small version of Hello World!
tcom  HELLO     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo HYPER,    A program to compile index files for the Z editors browse capability.
tcom  HYPER     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo ICON,     A simple ICON editor/designer program.
tcom  ICON      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo KOKO,     A floating point graphics demo program for TCOm and F-PC.
tcom  KOKO      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo LINES,    Simple line drawing program in graphics mode.
tcom  LINES     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo LINESCAN, Another graphics screen saver demo program.
tcom  LINESCAN  /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo LOOK,     A utility to search for text strings in file, files or a whole drive.
tcom  LOOK      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo LZX,      A primitive used by LZ.  LZX is NOT for use directly from DOS!
tcom  LZX       /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo LZ,       A file compression utility, reduces the size of COM files.
tcom  LZ        /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo MANGEN,   Dr.Ting's Mandelbrot 486 graphics program, as enhanced by Tom Zimmer.
tcom  MANGEN    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo MANSHOW,  A Mandelbrot display program for computers without 80x87 coprocessor.
tcom  MANSHOW   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo MIDNIGHT, The towers of hanoi program by Peter Midnight.
tcom  MIDNIGHT  /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo NOW,      Show the current date and time.
tcom  NOW       /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo PASCAL,   A TCOM version of my original PASCAL compiler.
tcom  PASCAL    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo PROMPTER, A program illustrating how to prompt for information from the user.
tcom  PROMPTER  /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo PUSHCR,   Push string following into keyboard buffer.
tcom  PUSHCR    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo RANDOM,   A random number generator for batch file processing.
tcom  RANDOM    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo RESTART,  Reboot the computer with either a cold or warm parameter.
tcom  RESTART   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo RINGS,    Draws random circle shapes in graphics mode.
tcom  RINGS     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo RS232IB,  A utility to provide interrupt driven RS232 support for
@echo           TCOM programs.
tcom  RS232IB   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo SAMPLE,   A small sample program that displays "hello world".
tcom  SAMPLE    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo SET50,    A program to put a VGA into 50 line mode, or EGA into 43 line mode.
tcom  SET50     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo SETMODE,  A program to allow easy selection of a numerical video mode.
tcom  SETMODE   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo SHELL,    A program to illustrate TCOM's window and file selection facilities.
tcom  SHELL     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo SPLAT,    Another graphic screen saver, and also a security program.
tcom  SPLAT     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo SSBLIT,   Display SAMSUNG logo using "BITBLIT" (fast bit image move).
tcom  SSBLIT    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo STRIP,    Process the lines of a file, writing results to another file.
tcom  STRIP     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo SZ,       The Small Zimmers editor, allows editing files upto about 55k bytes.
tcom  SZ        /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TETRA,    An example of a simple implementation of the TETRIS game.
tcom  TETRA     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TEXTFORM, A text processor, interprets documents, and generates print files.
tcom  TEXTFORM  /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TIMEFILE, A utility that inserts a time/date related valid file name into a
@echo           commandline following, useful for generating automatic backups.
tcom  TIMEFILE  /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TIMEIT,   A utility to measure the execution time of a following commandline.
tcom  TIMEIT    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TSR,      A TSR (Terminate Stay Resident) program for number conversion.
tcom  TSR       /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TSRCLOCK, A TSR (Terminate Stay Resident) program to display the time.
tcom  TSRCLOCK  /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TSRKOKO,  A TSR version of Konrad Kollers fractal program.
tcom  TSRKOKO   /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TSRLINES, A TSR (Terminate Stay Resident) program draws graphic lines.
tcom  TSRLINES  /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo TSRPAL,   A TSR random color pallete selection program. Gaudy but fun!
tcom  TSRPAL    /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo VED,      A virtual editor for very large files. (upto 40 megabytes or so)
tcom  VED       /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo YESNO,    A little utility to prompt for Y, N or F1=help.
tcom  YESNO     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo ZIM,      An experimental file compression and library program.
tcom  ZIM       /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo ZLIST,    A fast browser for small files or very large files.
tcom  ZLIST     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo ZMOVE,   A utility to allow sending files over an RS232 link between computers.
tcom  ZMOVE     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo ZRAY,     A simple TSR memory monitor program.
tcom  ZRAY      /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo ZTREE,    A utility to display the amount of disk space used by the files in
@echo           the various directories on your disk.  Useful for finding out where
@echo           all of your disk space has gone. Can also cleanup a disk.
tcom  ZTREE     /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo ZZ,       A program integrator for TCOM.  See ZZ.TXT for more information.
tcom  ZZ        /Q >TEST.LST
@TYPE TEST.LST
@TYPE TEST.LST >>TESTALL.LST
@echo ----------------------------------------------------------------------
@echo off
echo all DONE, look at TESTALL.LST for error messages.
