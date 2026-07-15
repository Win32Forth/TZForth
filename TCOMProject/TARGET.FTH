\ TARGET.fth              A New Target Compiler


\ fload head2.fth         \ allow adding duplicate headers

\ fload dis8086.fth       \ disassembler for 8086 family
fload compile1.fth      \ load the Compiler part one
fload compile2.fth      \ load the Compiler part two
fload tcomndx.fth       \ TCOM's Index file builder
fload host.fth          \ words target gets to use from host
fload optimiz.fth       \ optimizers for the target library
fload library.fth       \ library of target functions

\ fload tsearch.fth       \ library search utility
fload tvideo.fth        \ library direct video output
fload tsavescr.fth      \ save and restore screen               OPTIONAL
fload tcolor.fth        \ color support                         OPTIONAL
fload thand1.fth        \ some handle primitives
fload tpath.fth         \ automatic file path prepend
fload thandles.fth      \ handle file support
fload tstdio.fth        \ standard I/O support
\ fload texec.fth         \ DOS shell support
\ fload tenviron.fth      \ environment support
\ fload definit.fth       \ default target initialization
\ fload tbox.fth          \ box drawing                           OPTIONAL
\ fload tmenu.fth         \ Pull down menu support                OPTIONAL
\ fload tblock.fth        \ simple virtual BLOCK storage          OPTIONAL
\ fload tledit.fth        \ line editor support                   OPTIONAL
\ fload twfl.fth          \ popup window file selection tool
\ fload ttimer.fth        \ basic time and date support           OPTIONAL
\ fload ttimstuf.fth      \ calibrated time delay words           OPTIONAL
\ fload tsread.fth        \ lineread support                      OPTIONAL
\ fload tsound.fth        \ TONE support                          OPTIONAL
\ \ fload therc.fth         \ HERCULES graphics support             OPTIONAL
\ \ fload tgraph.fth        \ CGA/EGA/VGA graphics support          OPTIONAL
\ \ fload tmouse.fth        \ Mouse support                         OPTIONAL

forth

CFGHNDL !HCB TCOM.CFG   \ Change the configuration file name

FPATH

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

FSAVE ..\TCOM

nosave

