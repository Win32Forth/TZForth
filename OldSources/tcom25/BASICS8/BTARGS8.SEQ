\ BTARGET.SEQ             A New Target Compiler for BASIC

HWORDS-

fpath+ \tcom\src

autoeditoff

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
fload basopts8.seq      \ optimizers for the target library
fload baslibs8.seq      \ library of target functions

forth

CFGHNDL !HCB TCOM.CFG   \ Change the configuration file name

FPATH

long_branch
/libafter
/opt                    \ default to use optimization
' noop is loadstat
statoff                 \ no status display
vocoff                  \ we don't want the vocabulary display
cr .free

\- headseg xdpseg @ xseg @ - $800 + =: #listsegs \ need at least 16k free
                                  0 =: #ovbytes  \ no overlays for now
                                  0 =: #ovsegs   \ no overlays for now "again"

EMMON DISKON            \ enable use of expanded memory and or disk memory
                        \ for any DOS SHELL "$SYS" commands.
warning on

off> \fpc
on> \tcom

cr at? atsave 2!

FSAVE TCOMBS8

nosave

