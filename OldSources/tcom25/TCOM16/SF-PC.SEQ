\ SF-PC.SEQ     Extend file for KERNEL.COM to build SF.EXE

CFGHNDL !HCB .CFG               \ Clear the configuration filename

FLOAD TIMER.SEQ                 \ Timing and measurment words.
FLOAD TIMESTUF.SEQ              \ More timing words

WARNING OFF                     \ Don't warn me about any re-definitions.

.( Loading the extensions to KERNEL.COM, with all HEADERS PRESENT. ) CR

FLOAD COMMENT.SEQ  .( .)   \ Allows multi-line comments in source.
FLOAD UTILS.SEQ    .( .)   \ Some low level utilities.
FLOAD BRACES.SEQ   .( .)   \ Glen Haydons's comment tool uses { }    OPTIONAL
FLOAD VOCABS.SEQ   .( .)   \ Forths ONLY ALSO vocabulary structure.

FLOAD UNHEAD.SEQ   .( .)   \ a utility to remove some heads from F-PC

HWORDS+                    \ DON'T Throw away heads

FLOAD DEFERS.SEQ   .( .)   \ Adds DEFERS and UNDEFERS
FLOAD BUFSET.SEQ   .( .)   \ Automatically adjust read buffer size.
FLOAD DECOM.SEQ    .( .)   \ decompiler,                        OPTIONAL
FLOAD DUMP.SEQ     .( .)   \ dump utility,                      OPTIONAL
FLOAD CASE.SEQ     .( .)   \ A CASE utility needed by PASM.SEQ
FLOAD PASM.SEQ     .( .)   \ Prefix/Postfix assembler for 8086/8088
FLOAD NEWLAB.SEQ   .( .)   \ new local label definition file
FLOAD LOADEXE.SEQ  .( .)   \ The load part of the SAVE-EXE mechanism
FLOAD SAVEEXE.SEQ  .( .)   \ The save part of the SAVE-EXE mechanism

\ Now we can save the system back to disk at any time.

FLOAD DBGFIX.SEQ   .( .)   \ Convert inline NEXT to JMP NEXT. for DEBUG
FLOAD DEBUG.SEQ    .( .)   \ high level debugger,               OPTIONAL

FLOAD PATHSET.SEQ  .( .)   \ Includes paths on files,           OPTIONAL
FLOAD SEARCH.SEQ   .( .)   \ String comparison & search stuff
FLOAD LARGEST.SEQ  .( .)   \ find the largest word in a list
FLOAD WORDS.SEQ    .( .)   \ WORDS,                             OPTIONAL
FLOAD IBMCURSR.SEQ .( .)   \ IBM cursor shape control words
FLOAD MONOCROM.SEQ .( .)   \ Monochrome support, always needed.
FLOAD COLOR.SEQ    .( .)   \ Support for Color                  OPTIONAL
FLOAD BLINKER.SEQ  .( .)   \ background blink on/off            OPTIONAL?
FLOAD BOXTEXT.SEQ  .( .)   \ ability to draw boxes
FLOAD SAVESCR.SEQ  .( .)   \ Screen save and restore.

CAPS ON

FLOAD qvideo.seq   .( .)   \ SPEED UP SCREEN DISPLAY            OPTIONAL
FLOAD pertype.seq  .( .)   \ Imbedded display attributes in TYPE
FLOAD ledit.seq    .( .)   \ Line editor utility
FLOAD fl.seq       .( .)   \ File selection.
FLOAD needs.seq    .( .)   \ Allow optional loading of needed files.
FLOAD environ.seq  .( .)   \ Environment words.
FLOAD exec.seq     .( .)   \ DOS interface for things like DIR,COPY ect.
FLOAD makedef.seq  .( .)   \ allow conversion from : to defered OPTIONAL
FLOAD print.seq    .( .)   \ Print to a file words.             OPTIONAL
FLOAD sound.seq    .( .) \ Add TONE and change BEEP to use TONE    OPTIONAL

: help  ( -- )
        savescr
        " ZLIST TCOMHELP.DOC " ">$ [ hidden ] $SYS drop
        restscr  ;

hidden >keys1 ' help 187 lkey!         \ help shells to Z editor
       >keys2 ' help 187 lkey!

hidden ' <equit> alias defmenu forth

FLOAD xexpect.seq  .( .) \ A line editor for EXPECT.               OPTIONAL

warning on

\u decimalbase          decimalbase     \ default to DECIMAL on any error

6000 =: #listsegs               \ give me a BIGGER dictionary
   0 =: #ovbytes                \ no overlays for now
   0 =: #ovsegs                 \ no overlays for now "again"

BEHEAD

save-exe SF

bye                             \ All done, leave now.

