\\ LIST2.SEQ Main word in the listing file application by Jerry Boutelle
========================================================================
{

: init-handles  ( -- )
                fil-file-handle clr-hcb
                inx-file-handle clr-hcb
                sym-file-handle clr-hcb
                lst-file-handle >bhandle clr-hcb ;

: LIST ( -- )
\fpc    unedit
        decimal
\tcom   init-cursor                             \ get initial cursor shape
\tcom   margin_init                             \ initialize margins & tabs
\tcom   caps on                                 \ ignore case
\tcom   ?ds: sseg !                             \ initialize the search seg
\tcom   dosio_init                              \ init dos stuff
\tcom   $0000 SET_MEMORY                        \ DEFAULT TO 64K CODE SPACE
\tcom   lineread_init                           \ init for reading lines
\tcom   init-handles
        savecursor
        cursor-off
        ['] %file-output is file-output
        ['] %inx-file#> is inx-file#>
        ['] %get-fil-name is get-fil-name
        ['] %disasm is disasm
        ['] %.inst-bytes is .inst-bytes
        ['] %load-obj-file is load-obj-file
        ['] %close-files is close-files
        ['] d-tc@ is d-datac@
        processor-init                          \ target processor specific
        produce-listing
        close-files                             \ close files
        screen-output
        at? restcursor at
        decimal
        ;



