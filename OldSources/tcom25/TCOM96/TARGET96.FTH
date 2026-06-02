\ TARGET96.SEQ              A New Target Compiler

HWORDS-

fpath+ c:\tcom\src              \ path for source of kernel of TCOM compiler
\ fpath+ \tcomtarg\compiler      \ path for source of shared remote-target stuff
\ on> withpath
autoeditoff
warning off             \ don't tell me about re-definitions, I KNOW!

fload head2.seq
\ fload dis8096.seq       \ disassembler for 80196
\ fload label96.seq       \ add long branchs to the compiler
fload compile1.seq      \ load the Compiler
fload compile2.seq      \ load the Compiler
fload host.seq
fload tcomndx.seq       \ source index stuff
fload ndxcomma.seq      \ ,(comma) index file support
fload hexsv96.seq       \ save images in HEX format
fload asm96.seq         \ assembler for 80196
fload opt96.seq         \ optimizers for the library
fload lib96.seq         \ library of target functions

forth

CFGHNDL !HCB TCOM96.CFG   \ Change the configuration file name

FPATH

' noop is loadstat
statoff                 \ no status display
vocoff                  \ we don't want the vocabulary display
cr .free

xdpseg @ xseg @ - $800 + =: #listsegs  \ need at least 16k free

warning on

FSAVE TCOM96

nosave


