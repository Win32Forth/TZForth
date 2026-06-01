\ TARG86A.SEQ        A New ANSI Compatible Target Compiler

fpath+ \tcom\src

hwords+

warning off             \ don't tell me about re-definitions, I KNOW!

fload head2.seq         \ allow adding duplicate headers
fload compile1.seq      \ load the Compiler part one
fload compile2.seq      \ load the Compiler part two
fload tcomndx.seq       \ TCOM's Index file builder
fload host.seq          \ words target gets to use from host
fload opt86a.seq        \ optimizers for the target library
fload lib86a.seq        \ library of target functions

fload definit.seq       \ default target initialization

forth

CFGHNDL !HCB TCOM86A.CFG   \ Change the configuration file name

FPATH

/opt                                    \ default to use optimization

4000 !> iblimit                         \ limit read size to 4k
   1 !> svmax                           \ only allow saving one screen

\- headseg xdpseg @ xseg @ - $700 + =: #listsegs \ need at least 20k free
                                  0 =: #ovbytes  \ no overlays for now
                                  0 =: #ovsegs   \ no overlays for now "again"

EMMON DISKON            \ enable use of expanded memory and or disk memory
                        \ for any DOS SHELL "$SYS" commands.

off> \fpc               \ set compiler flags properly
on> \tcom

cr at? atsave 2!

FSAVE TCOM86A

nosave

