\\ TPOINT.SEQ           Pointer support for TCOM        by Tom Zimmer

  This file implements external memory support (pointer memory) for TCOM.
While this implementation of POINTER is simpler that F-PC's, it should be
reasonably compatible with F-PC in user applications.

{

: pointer       ( d1 -<name>- ) \ define name as a pointer to d1 bytes
                ( -- seg )      \ returns physical seg at runtime or
                                \ returns a zero if no space available
                create 0 , dparagraph ,
                does>   dup>r @ 0=
                if      r@ 2+ @
                        alloc 8 =
                        if      2drop 0 r@ !
                        else    nip r@ !
                        then
                then    r> @ ;

}

\ Simple example of POINTER usage:

45000. pointer ptr1             \ define several pointers to blocks of mem
45000. pointer ptr2
45000. pointer ptr3
45000. pointer ptr4
45000. pointer ptr5

: main          ( -- )          \ allocate space and display sizes of first
                                \ several segments
                dosio_init              \ initialize I/O
                0 set_memory            \ reduce TCOM programs memory usage
                ptr1 0=
                ptr2 0= or
                ptr3 0= or
                ptr4 0= or
                ptr5 0= or abort" Not enough memory available"
                ptr1 dup h.                             \ allocate some mem
                ptr2 dup rot - 16 *d d. cr dup h.
                ptr3 dup rot - 16 *d d. cr dup h.
                ptr4 dup rot - 16 *d d. cr dup h.
                ptr5 dup rot - 16 *d d. cr     h.
                ;


