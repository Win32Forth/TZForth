\ TCOM6811.SEQ         6811 Target Compiler            by Tom Zimmer
\ as derived from:
\ TCOM6805.SEQ         6805 Target Compiler            by Andrew McKewen

\ Based on TCOM by Tom Zimmer
\ Modified for the M68HC05 by Andrew McKewan
\ modified again for the 6811 by Tom Zimmer

FPATH+ C:\TCOM\SRC

\+ autoeditoff  autoeditoff
warning off             \ don't tell me about re-definitions, I KNOW!

\ 100 constant version    \ tcom version number

fload head2.seq         \ allow adding duplicate headers
fload compile1.seq      \ load the Compiler part one
fload compile2.seq      \ load the Compiler part two
fload tcomndx.seq       \ TCOM's Index file builder
fload host.seq          \ words target gets to use from host
fload hexsave.seq       \ HEX file save
\ fload binsave.seq
fload asm6811.seq       \ 6811 Assembler
fload opt6811.seq       \ optimizers for the library
fload lib6811.seq       \ library of target functions

>library

\ *********************** ????????????????????????????????
fload regs6811.seq      \ Define 6811 registers

forth >forth

CFGHNDL !HCB TCOM11.CFG \ Change the configuration file name

FPATH

' noop is loadstat
\+ statoff statoff                      \ no status display
\+ vocoff vocoff                        \ we don't want the vocabulary display
cr .free

xdpseg @ xseg @ - $800 + =: #listsegs   \ need at least 16k free
                       0 =: #ovbytes    \ no overlays for now
                       0 =: #ovsegs     \ no overlays for now "again"

warning on

off> \fpc
on> \tcom

FSAVE TCOM11

nosave                  \ don't try to save the target image on build

