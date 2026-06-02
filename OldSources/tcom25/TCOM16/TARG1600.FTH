\\ TARGET.SEQ              A New Target Compiler
{

HEADERS
HWORDS-

fpath+ \tcom\src

\+ autoeditoff autoeditoff
warning off

fload head2.seq
fload compile1.seq
fload compile2.seq
fload tcomndx.seq
fload ndx1600.seq                       \ index file code for 1600
fload host.seq
fload hexsave.seq                       \ save images in hex format
fload asm1600.seq                       \ assembler for sam8
fload opt1600.seq                       \ optimizers for the library
fload lib1600.seq                       \ library of target functions
forth

CFGHNDL !HCB TCOM16.CFG         \ Change the configuration file name

FPATH

long_branch            \ default to long branches
long_library           \ also use long branches in library

/opt                    \ default to use optimization
' noop is loadstat
\+ statoff statoff                      \ no status display
\+ vocoff vocoff                        \ we don't want the vocabulary display
cr .free

8192 =: iblimit                         \ limit read size to 4k

2 =: svmax                              \ save at most two screens

xdpseg @ xseg @ - $100 + =: #listsegs   \ need at least 4k free
                       0 =: #ovbytes    \ no overlays for now
                       0 =: #ovsegs     \ no overlays for now "again"

EMMON           \ enable the use of expanded memory and disk memory on shells
SWAPFILE TCOM16.SWP

warning on

cr at? atsave 2!

FSAVE TCOM16

nosave

