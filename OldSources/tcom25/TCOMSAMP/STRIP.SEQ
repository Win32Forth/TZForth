\\ STRIP.SEQ            A Simple Text Line Processor    by Tom Zimmer

  This file reads all of the lines of an input file, and after performing
some user specifiable processing on the line, writes the line back to the
output file.

{

.options /opt /noinit

fload \tcom\tfileio.seq         \ buffered file I/O support

256 array readbuf               \ a buffer to hold read lines in
256 array writebuf              \ a buffer to fill for output of lines

bhandle readhndl                \ we are reading from this file
bhandle wrthndl                 \ we are writing the results to this file

: get-aline     ( -- f1 )       \ read a line from main file
                readhndl blineread dup  \ got a length non-zero?
                if      readbuf placel  \ then place the line in buf
                        true            \ return true, got a line
                else    nip nip         \ else return false nogood
                        readbuf off     \ clear read buffer
                then    ;

: process-aline ( -- )
                                        \ remove the CRLF from each line
                readbuf count + 2- @ $0A0D = if -2 readbuf c+! then
\ ********************************************************************** \
\ ***************** Line processing goes here ************************** \
\ ********************************************************************** \
                readbuf count writebuf place ;

create crlf$ $0D c, $0A c,

: put-aline     ( -- )
                writebuf count wrthndl bwrite   \ write it to output
                crlf$ 2 wrthndl bwrite ;        \ append a CRLF

: out_init      ( -- )         \ init and make the output file
                readhndl >bhandle wrthndl $>bhandle
                " OUT" ">$ wrthndl >bhandle $>ext
                wrthndl  bcreate abort" Failed to create output file" ;

: strip_init    ( -- )          \ initalization for a TCOM program
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                " TXT" defext place             \ set the default file ext
                $0A !> term_char                \ set lineread term character
                ;

: main          ( -<filename>- )
                strip_init
                bl word readhndl $>bhandle      \ get input filename
                                                \ check its not a .PRN file
                readhndl >bhandle handle>ext " .OUT" compare 0=
                abort" Output file uses .OUT, can't use .OUT for input file!"
                readhndl >bhandle ?def.ext      \ supply .TXT if not given
                readhndl bopen
                if      ." Bad filename, or no input file specified"
                        bye                     \ and leave
                then
                out_init
                ." Processing file: " readhndl  >bhandle count type cr
                ." Into Outputfile: "  wrthndl  >bhandle count type cr
                begin   get-aline
                        broken @ 0= and         \ allow Ctrl-Break to abort
                while   process-aline
                        put-aline
                repeat
                broken @
                if      ." Aborting..."
                then
                readhndl bclose drop
                wrthndl  bflush
                wrthndl  bclose drop
                cr ."  DONE " ;


