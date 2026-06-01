\\ EXPANDED.SEQ  An interface to expanded memory for F-PC        by Tom Zimmer

  Here is an interface to the EMM (Expanded Memory Manager). I used the
LOTUS/INTEL/MICROSOFT Expanded Memory Sp[ecification Version 4.0 to impliment
these operators, using the assembly examples right out of their manual. Not
all functions are supported, although you can certainly add any additional
ones you might need.  What is supported is I believe sufficient for most
applications.
                                        Tom Zimmer
{

CREATE EMMNAME ," EMMXXXX0"
VARIABLE PAGE-FRAME
VARIABLE EMM-STATUS

\ test the expanded memory system to see if it is present.  This MUST be
\ successful BEFORE any other expanded memory operations may be done.

code EMM-PRESENT? ( --- f1 )            \ true  = emm is present
                                        \ false = no emm present
                save_bx
                push si
                push es
                mov ah, # $35
                mov al, # $67
                int $21
                mov di, # $0A
                lea si, emmname 1+
                mov cx, # 8
                cld
                repe    cmpsb
                pop es  pop si
             0= if      mov bx, # true          /nostack1
                else    mov bx, # false
                then
                ret     end-code

\ Get the status of the expanded memory system. Should return 0

code EMM-STATUS? ( --- )
                mov ah, # $40           \ request status code
                int $67
                mov al, ah              \ ah = status of emm
                sub ah, ah
                mov emm-status ax
                ret     end-code

\ EMM status code evaluator, prints the error code for any error received.

: ?EMMERR       ( --- f1 )              \ test the most recent emm operation
                emm-status @ ;          \ TRUE if there is a problem.

\ Set the PAGE-FRAME variable with the physical segment of the EMM page frame.

code EMM-PAGE-FRAME ( --- )
                push bx                 \ save BX for later
                mov ah, # $41           \ request page frame segment
                int $67
                mov page-frame bx       \ page frame to PAGE-FRAME
                pop bx                  \ recover BX
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                ret     end-code

\ return the number of 16k pages that are available for allocation by
\ your application.

code EMM-AVAIL-PAGES ( --- pages )
                save_bx
                mov ah, # $42           \ request unallocated pages
                int $67                 \ unallocated pages are in BX
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                ret     end-code

\ return the total pages of expanded memory in the system. The number you
\ can allocate will likely be less, and is determined by the previous func.

code EMM-TOTAL-PAGES ( --- pages )
                save_bx
                mov ah, # $42           \ request unallocated pages
                int $67
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                mov bx, dx              \ dx = total pages
                ret     end-code

\ Allocates the number of pages you specify, and returns a handle to the
\ pages if successful.

code EMM-ALLOC-PAGES ( pages --- handle )
                                        \ number of pages to allocate in BX
                mov ah, # $43           \ allocate pages function
                int $67
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                mov bx, dx              \ dx = handle of pages allocated
                ret     end-code        \ in the range 1 to 255

CODE EMM-REALLOC-PAGES ( pages handle -- )
                mov dx, bx              \ emm handle in DX
                lodsw
                mov bx, ax              \ the new page count
                mov ah, # $51           \ reallocate pages function
                int $67
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                load_bx
                ret     END-CODE       \ in the range 1 to 255

\ This un-suspecting function actually makes the expanded memory available
\ for your use, by mapping the logical expanded memory into the physical
\ page specified in the PAGE-FRAME variable. Each page is a 16k chunk.

code EMM-MAP-PAGES ( log-page phy-page handle --- )
                mov dx, bx              \ emm handle in DX
                lodsw
                mov bx, ax
                lodsw
                xchg bx, ax             \ logical in BX, physical in AX
                mov ah, # $44           \ map pages function
                int $67
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                load_bx
                ret     end-code

\ Deallocate the pages associated with handle. This gives them back to the
\ system for somebody else to use. This MUST be done before exiting back
\ to DOS, or the pages specified by handle will not be available to
\ other programs.

code EMM-DEALLOC-PAGES ( handle --- )
                mov dx, bx              \ emm handle in DX
                mov ah, # $45           \ deallocate pages function
                int $67
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                load_bx
                ret     end-code

\ return the version number of the installed EMM in BCD
\ (two nibbles packed into the low byte)

code EMM-GET-VERSION ( --- version )
                save_bx
                mov ah, # $46           \ request version funcion
                int $67
                sub dx, dx              \ clear dx to receive version
                mov dl, al              \ version to DL
                mov al, ah              \ ah = status
                sub ah, ah
                mov emm-status ax
                mov bx, dx              \ return version
                ret     end-code

\ Put the segment of the PAGE-FRAME on the stack under the address specified.

code ?EMM:      ( --- page-frame )
                save_bx
                mov bx, page-frame
                ret     end-code

: EMM-INIT      ( -- )          \ initialize expanded memory driver
                true emm-status !               \ init flag to failed, will
                                                \ reset if all goes ok
                emm-present? 0= ?exit           \ is there any EMM in system?
                emm-page-frame
                emm-status @ ?exit              \ set the page frame
                emm-get-version
                emm-status @ ?exit              \ get the EMM version
                255 and $30 <                   \ stop if OLD
                if      emm-status on
                then    ;                       \ return init status

