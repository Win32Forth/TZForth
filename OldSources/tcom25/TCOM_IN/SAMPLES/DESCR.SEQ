\\ descr.seq extract first line of file to 4dos description file

   $Logfile:   D:/SRC/FPC/VCS/DESCR.SEV  $
   $Revision:   1.1  $
   $Date:   25 Jan 1993 22:04:58  $
   $Author: U.Hoffmann$

 ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄuh 23Aug92
 ³ This application works only in conjunction with the          ³
 ³ excellent command processor 4DOS by JP Software Inc.         ³
 ³ If you don't know 4DOS you don't need this file. But! Where  ³
 ³ have you been the last few years?                            ³
 ³                                                              ³
 ³ Loading this file under either FPC or TCOM provides a        ³
 ³ single user word, DESCR <filename>, which extracts a file    ³
 ³ comment from the first line of a given file and sets its     ³
 ³ 4DOS description according to the extracted text.            ³
 ³                                                              ³
 ³ This Code is public domain software                          ³
 ³                                                              ³
 ³ Remarks and comments are welcome.                            ³
 ³                                                              ³
 ³               Ulrich Hoffmann                                ³
 ³               Graf-Spee-Strasse 38                           ³
 ³               W2300 Kiel 1                                   ³
 ³               Germany                                        ³
 ³               +49 431 80 12 14                               ³
 ³               +49 431 80 12 33 (FAX)                         ³
 ³               uh@informatik.uni-kiel.dbp.de                  ³
 ³                                                              ³
 ³                                                              ³
 ³ Currently first lines are assumed to have the form:          ³
 ³ \ FILENAME.EXT COMMENT ...                                   ³
 ³                                                              ³
 ³ COMMENT is treated as the relevant comment and converted     ³
 ³ to the 4DOS description. Check TRANSFORM-DESCRIPTION for     ³
 ³ details.                                                     ³
 ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 DESCR does not accept wildcards.
 If compiled as TCOM application, a 4DOS FOR-loop, or SELECT
 is recomended if you want to describe multiple files:

 for %f in (*.seq) do descr %f

 or

 select descr (*.seq)


{

\fpc Only Forth also hidden definitions also  decimal

handle thisfile

Create description $100 allot  \ Buffer to hold the description cmd line

: set-description ( filename len description len' -- )
   \ construct a 4dos command line in the form:
   \  DESCRIBE <filename> "<description>"
   description $100 blank
   " describe " tuck description 1+       swap cmove  >r
   2swap        tuck description 1+ r@ +  swap cmove  r> + >r
   Ascii "           description 2+ r@ +  c!          r> 2+ >r
                tuck description 1+ r@ +  swap cmove  r> + >r
   Ascii "           description 1+ r@ +  c!
   r> 1+ description c! ;

: set-4dos-description ( filename len description len' -- )
   \ construct 4dos description command line and let it process
   set-description
   description $sys ?syserror ;

$100 Constant linelen  \ holds the first line of file

: read-line ( hdl -- addr len )
   \ read line from file, give start & length 
   pad linelen blank
   pad linelen rot hread
   pad over $0D scan nip  - pad swap ;

: filename? ( addr len -- flag )
   \ try to figure out, if ADDR LEN is a filename
   dup 4 <                 IF 2drop  false EXIT THEN
   2dup 4 - + c@ ascii . = IF 2drop  true  EXIT THEN
   2drop false ;

: ?skip-filename ( addr len -- addr' len' )
   \ if filename detected skip it, so it's not included in the description
   2dup
   2dup bl scan nip - filename? IF bl scan bl skip THEN ;

: transform-description ( addr len -- addr' len' )
   \ convert first-line-comment to 4dos-description
   Ascii \ skip
   bl      skip
   ?skip-filename
;

: describe-file ( filename -- )
   \ describe file with given filename, by extracting it's first line
   dup count rot thisfile $>handle  thisfile hopen  abort" cannot open file"
   thisfile read-line
   thisfile hclose drop
   transform-description
   set-4dos-description
\fpc cr
   description count type cr ;

\fpc Only Forth also definitions hidden also

: descr ( <name> -- )
\ User word with prefix syntax. Scan filename from input stream, then describe
\fpc   gfl bl word
\tcom  bl word dup c@ 0= abort" Usage: desc <filename>"
   describe-file ;

\fpc Only Forth also definitions
\fpc cr .( DESCRIBE loaded )

}

ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ

Revision history:
$Log:   D:/SRC/FPC/VCS/DESCR.SEV  $
   
      Rev 1.1   25 Jan 1993 22:04:58
   leading cr made F-PC specific
   
   
      Rev 1.0   25 Jan 1993 22:03:52
   Initial revision.
   

