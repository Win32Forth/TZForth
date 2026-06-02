\ TARGGEN.SEQ           A New GENERIC Target Compiler

FPATH+ C:\TCOM\SRC

autoeditoff

warning off             \ don't tell me about re-definitions, I KNOW!

fload head2.seq         \ allow adding duplicate headers
fload compile1.seq      \ load the Compiler part 1
fload compile2.seq      \ load the Compiler part 2
fload host.seq          \ words target gets to use from host
fload asmgen.seq        \ the assembler for GENERIC target
fload optgen.seq        \ optimizers for the library
fload libgen.seq        \ library of target functions

forth

CFGHNDL !HCB TCOMGEN.CFG   \ Change the configuration file name

FPATH

on> ?noloaded,          \ disable LOADED, in FLOAD

' noop is loadstat
statoff                 \ no status display
vocoff                  \ we don't want the vocabulary display
cr .free

/QUIET

xdpseg @ xseg @ - $800 + =: #listsegs   \ need at least 16k free
                       0 =: #ovbytes    \ no overlays for now
                       0 =: #ovsegs     \ no overlays for now "again"

warning on

FSAVE TCOMGEN

