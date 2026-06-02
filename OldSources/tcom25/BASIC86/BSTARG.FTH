\ TARGET.SEQ              A New Target Compiler

fpath+ \tcom\src

hwords-

warning off             \ don't tell me about re-definitions, I KNOW!

fload head2.seq         \ allow adding duplicate headers
fload compile1.seq      \ load the Compiler part one
fload basic.seq         \ basic compiling
fload bascomp2.seq      \ load the BASic COMPiler part 2
fload tcomndx.seq       \ TCOM's Index file builder
fload bashost.seq       \ words target gets to use from host
fload basopt86.seq      \ optimizers for the target library
fload baslib86.seq      \ library of target functions

forth

CFGHNDL !HCB TCOM.CFG   \ Change the configuration file name

FPATH

long_branch
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

FSAVE TCOMB86

nosave

