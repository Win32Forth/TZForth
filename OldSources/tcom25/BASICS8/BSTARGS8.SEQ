\ TARGET.SEQ              A New Target Compiler

hwords-

fpath+ \tcom\src

warning off             \ don't tell me about re-definitions, I KNOW!

fload head2.seq         \ allow adding duplicate headers
fload compile1.seq      \ load the Compiler part one
fload basic.seq         \ basic compiling
fload bascomp2.seq      \ load the BASic COMPiler part 2
fload tcomndx.seq       \ TCOM's Index file builder
fload ndxs8.seq         \ index file code for Sam8
fload bashost.seq       \ words target gets to use from host
fload hexsave.seq       \ save images in hex format
fload asms8.seq         \ assembler for sam8
fload basoptS8.seq      \ optimizers for the target library
fload baslibS8.seq      \ library of target functions

forth

CFGHNDL !HCB TCOM.CFG   \ Change the configuration file name

FPATH

/libafter
/opt                                    \ default to use optimization

4000 !> iblimit                         \ limit read size to 4k
   1 !> svmax                           \ only allow saving one screen

\- headseg xdpseg @ xseg @ - $500 + =: #listsegs \ need at least 20k free
                                  0 =: #ovbytes  \ no overlays for now
                                  0 =: #ovsegs   \ no overlays for now "again"

EMMON DISKON            \ enable use of expanded memory and or disk memory
                        \ for any DOS SHELL "$SYS" commands.

off> \fpc               \ set compiler flags properly
on> \tcom

cr at? atsave 2!

FSAVE TCOMBS8

nosave

