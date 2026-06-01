\ TARGET.SEQ              A New Target Compiler

FPATH+ C:\TCOM\SRC

autoeditoff

warning off             \ don't tell me about re-definitions, I KNOW!

fload head2.seq         \ allow adding duplicate headers
fload compile1.seq      \ load the Compiler part 1
fload compile2.seq      \ load the Compiler part 2
fload tcomndx.seq       \ TCOM's Index file builder
fload host.seq          \ words target gets to use from host
fload asm80.seq         \ the assembler for 8080 target
fload opt80.seq         \ optimizers for the library
fload lib80.seq         \ library of target functions

forth

CFGHNDL !HCB TCOM80.CFG   \ Change the configuration file name

FPATH

on> ?noloaded,          \ disable LOADED, in FLOAD

' noop is loadstat
statoff                 \ no status display
vocoff                  \ we don't want the vocabulary display
cr .free

xdpseg @ xseg @ - $800 + =: #listsegs   \ need at least 16k free
                       0 =: #ovbytes    \ no overlays for now
                       0 =: #ovsegs     \ no overlays for now "again"

warning on

FSAVE TCOM80

nosave

