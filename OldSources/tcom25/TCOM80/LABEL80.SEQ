\\ LONGLABL.SEQ         Modified local labels for long branches

{

: %"ERRMSG3     ( cfa A1 N1 -- )        \ a dummy filler till real one
                cr type drop ;

DEFER "ERRMSG3  ' %"errmsg3 is "errmsg3

ASSEMBLER DEFINITIONS ALSO

DEFER T@        FORTH ' @       ASSEMBLER IS T@

' HERE ALIAS ASMHERE

}
 =========================================================
               BEGIN LOCAL LABELS SECTION:
 =========================================================

{

FORTH DEFINITIONS

  0 value ?long
  0 value ?long_lib

: long_branch   ( -- )
                on> ?long ;

\ : short_branch  ( -- )
\                 off> ?long ;

: long_library  ( -- )
                on> ?long_lib ;

\ : short_library ( -- )
\                 off> ?long_lib ;

long_branch            \ default to LONG branches
long_library           \ also use LONG branches in library

ASSEMBLER DEFINITIONS

}
 Translates a label reference to the appropriate dictionary
 location and sets the "ever referenced?" flag.

 If the reference is a forward reference, then a linked list
 of the forward references themselves is built using the
 dictionary byte locations where the jump offsets are
 "compiled".  The reason for using this technique at all is
 that it allows an arbitrary number of forward references per
 label to be made (within the jump offset limitations of
 course) and that it requires table space only for the linked
 list head pointer.  The technique is eloquent if convoluted
 and, as a minimum, needs explanation.
{

' $ ALIAS $|    ( n1 -- n2 )

}
 Resolves all local label forward references for a given
 label.
{

: >resW ( ^line -- )
        [ FORTH ]
        2+ @ dup 0=     \ if nothing to resolve
        IF      drop exit               \   then exit
        THEN                            \ stack contains addr to be resolved
        BEGIN   1+ DUP T@ >R ASMHERE OVER T!
                R> TUCK - 1- 0=         \ loop till branch to self
        UNTIL   DROP ;

: $$:w  ( n -- )                \ defines a local label
        [ FORTH ]
        true !> ll-used?        \ set "labels used?" flag
        llab>line
        dup @ 0<>
        if      0 " Label can't be multiply defined" "errmsg3 abort
        then
        dup >resW               \ resolve forward references if needed
        ASMHERE swap ! ;        \ and set label for subsequent refs

: >resF ( ^line -- )
        [ FORTH ]
        2+ @ dup 0=     \ if nothing to resolve
        IF      drop exit               \   then exit
        THEN                            \ stack contains addr to be resolved
        BEGIN   DUP T@ >R ASMHERE OVER T!
                R> TUCK - 0=            \ loop till branch to self
        UNTIL   DROP ;

: $$:f  ( n -- )                \ defines a local label
        [ FORTH ]
        true !> ll-used?        \ set "labels used?" flag
        llab>line
        dup @ 0<>
        if      0 " Label can't be multiply defined" "errmsg3 abort
        then
        dup >resF               \ resolve forward references if needed
        ASMHERE swap ! ;        \ and set label for subsequent refs

                        \ word resolution resolve, for JMP type instructions
: $:|   ( n -- )        \ allow use as prefix/postfix
        [ FORTH ]
        ['] $$:w a;! a; a; ;

' $:| alias $:

                        \ word resolution resolve, for FORTH type branches
: $:F   ( n -- )        \ allow use as prefix/postfix
        [ FORTH ]
        ['] $$:f a;! a; a; ;

FORTH DEFINITIONS

ONLY FORTH ALSO DEFINITIONS

}
 =========================================================
                END LOCAL LABELS SECTION:
 =========================================================

