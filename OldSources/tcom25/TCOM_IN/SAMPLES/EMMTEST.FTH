\\ EMMTEST.SEQ        Expanded memory support test file     by Tom Zimmer
.options /opt /definit

  This file illustrates the basic steps required to use the expanded memory
interface on a PC. An EMM driver is required for this to work.

{

include \tcom\temm.seq                \ expanded memory support

0 value emmhndl

: main          ( -- )          \ the main entry point for the program
                cr ." A simple Expanded Memory Manager test program for TCOM."
                emm-present? 0=         abort" No EMM present"
                emm-get-version dup $30 <
                                        abort" Requires at least version 3.0"
                cr ." Expanded Memory Manager version: "
                HEX
                0 <# # '.' hold # #> type
                DECIMAL
                emm-page-frame                  \ init the page frame pointer
                emm-total-pages                 \ get total EMM pages
                cr ." There are " u. ." EMM (16k) pages in this system."
                emm-avail-pages                 \ get the available EMM pages
                cr u. ." EMM pages are available."
                cr ." Allocating 4 pages."
                4 emm-alloc-pages !> emmhndl    \ allocate 4 pages = 64k
                emm-avail-pages                 \ get the available EMM pages
                cr ." There are now " u. ." EMM pages available."
                cr ." Mapping and filling pages 0, 1, 2 & 3."
                0 0 emmhndl emm-map-pages       \ log-page phy-page handle --
                1 1 emmhndl emm-map-pages
                2 2 emmhndl emm-map-pages
                3 3 emmhndl emm-map-pages
                ?emm: $0000 $4000 $00 lfill     \ fill first page
                ?emm: $4000 $4000 $11 lfill
                ?emm: $8000 $4000 $22 lfill
                ?emm: $C000 $4000 $33 lfill
                ?emm: $C000 $10 ldump           \ dump some of first page
                ?emm: $8000 $10 ldump
                ?emm: $4000 $10 ldump
                ?emm: $0000 $10 ldump
                cr ." Re-Mapping as pages 3, 2, 1 & 0."
                0 3 emmhndl emm-map-pages       \ log-page phy-page handle --
                1 2 emmhndl emm-map-pages
                2 1 emmhndl emm-map-pages
                3 0 emmhndl emm-map-pages
                ?emm: $C000 $10 ldump           \ dump some of first page
                ?emm: $8000 $10 ldump
                ?emm: $4000 $10 ldump
                ?emm: $0000 $10 ldump
                ?emm: save!> sseg               \ set search segment to ?EMM:
                $C000 $4000 $00 skip nip        \ Verify the contents of the
                $8000 $4000 $11 skip nip or     \ remapped EMM pages.
                $4000 $4000 $22 skip nip or
                $0000 $4000 $33 skip nip or     \ -- f1=true if failed
                restore> sseg
                cr ." De-Allocating pages."
                emmhndl emm-dealloc-pages       \ release our pages
                emm-avail-pages                 \ get the available EMM pages
                cr ." There are now " u. ." EMM pages available."
                if      cr ." *** FAILED the remap & compare test! ***"
                then    ;


\S **********************************************************************
   *************   Documentation on Expanded memory   *******************
   **********************************************************************

\ test the expanded memory system to see if it is present.  This MUST be
\ successful BEFORE any other expanded memory operations may be done.

EMM-PRESENT?    ( --- f1 )      \ true  = emm is present
                                \ false = no emm present

\ Get the status of the expanded memory system. Should return 0

EMM-STATUS?     ( --- )         \ request status code into EMM-STATUS

\ EMM status code evaluator, prints the error code for any error received.

?EMMERR         ( --- f1 )      \ get status of most recent emm operation
                                \ TRUE if there is a problem.

\ Set the PAGE-FRAME variable with the physical segment of the EMM page frame.

EMM-PAGE-FRAME  ( --- )          \ initialize PAGE-FRAME variable

\ return the number of 16k pages that are available for allocation by
\ your application.

EMM-AVAIL-PAGES ( --- pages )           \ request UNALLOCATED pages

\ return the total pages of expanded memory in the system. The number you
\ can allocate will likely be less, and is determined by the previous func.

EMM-TOTAL-PAGES ( --- pages )      \ request TOTAL pages

\ Allocates the number of pages you specify, and returns a handle to the
\ pages if successful.

EMM-ALLOC-PAGES ( pages --- handle ) \ allocate pages, return handle

\ This un-suspecting function actually makes the expanded memory available
\ for your use, by mapping the logical expanded memory into the physical
\ page specified in the PAGE-FRAME variable. Each page is a 16k chunk.

EMM-MAP-PAGES   ( log-page phy-page handle --- )

\ Deallocate the pages associated with handle. This gives them back to the
\ system for somebody else to use. This MUST be done before exiting back
\ to DOS, or the pages specified by handle will not be available to
\ other programs.

EMM-DEALLOC-PAGES ( handle --- )

\ return the version number of the installed EMM in BCD
\ (two nibbles packed into the low byte)

EMM-GET-VERSION ( --- version )    \ request version funcion

\ Put the segment of the PAGE-FRAME on the stack under the address specified.

?EMM:           ( --- page-frame )      \ get the page frames base segment

