\ TARGET.SEQ              A New Target Compiler

\ fload unref.seq

\ HWORDS+

warning off             \ don't tell me about re-definitions, I KNOW!

\ fload profile.seq     \ include, to automatically profile TCOM
fload head2.seq         \ allow adding duplicate headers
fload compile1.seq      \ load the Compiler part one
\ fload tcommap.seq       \ generate the map file
fload compile2.seq      \ load the Compiler part two
fload tcomndx.seq       \ TCOM's Index file builder
fload host.seq          \ words target gets to use from host
fload optimiz.seq       \ optimizers for the target library
fload library.seq       \ library of target functions

fload tsearch.seq       \ library search utility
fload tvideo.seq        \ library direct video output
fload tsavescr.seq      \ save and restore screen               OPTIONAL
fload tcolor.seq        \ color support                         OPTIONAL
fload thand1.seq        \ some handle primitives
fload tpath.seq         \ automatic file path prepend
fload thandles.seq      \ handle file support
fload tstdio.seq        \ standard I/O support
fload texec.seq         \ DOS shell support
fload tenviron.seq      \ environment support
fload definit.seq       \ default target initialization
fload tbox.seq          \ box drawing                           OPTIONAL
fload tmenu.seq         \ Pull down menu support                OPTIONAL
fload tblock.seq        \ simple virtual BLOCK storage          OPTIONAL
fload tledit.seq        \ line editor support                   OPTIONAL
fload twfl.seq          \ popup window file selection tool
fload ttimer.seq        \ basic time and date support           OPTIONAL
fload ttimstuf.seq      \ calibrated time delay words           OPTIONAL
fload tsread.seq        \ lineread support                      OPTIONAL
fload tsound.seq        \ TONE support                          OPTIONAL
fload tmouse.seq        \ Mouse support                         OPTIONAL

forth

CFGHNDL !HCB TCOM.CFG   \ Change the configuration file name

FPATH

/opt                                    \ default to use optimization

2048 !> iblimit                         \ limit read size to 4k
   1 !> svmax                           \ only allow saving one screen

\- headseg xdpseg @ xseg @ - $700 + =: #listsegs \ need at least 20k free
                                  0 =: #ovbytes  \ no overlays for now
                                  0 =: #ovsegs   \ no overlays for now "again"

EMMON DISKON            \ enable use of expanded memory and or disk memory
                        \ for any DOS SHELL "$SYS" commands.

off> \fpc               \ set compiler flags properly
on> \tcom

cr at? atsave 2!

FSAVE ..\TCOM

nosave

