FILE-ECHO ON
\\ High Level FLoating Point .  IEEE Format.     11:30 07Nov88RS)

          Copyright 1988 by Robert L. Smith
      2300 St. Francis Drive, Palo Alto, CA 94303
                 (415) 856-9321

 These routines may be freely used, provided only that the
 copyright notice be displayed and preserved.

\                                               09:02 23Oct88RS)

Please: If you wish to distribute any of your changes to this
 package, please give your name, address and telephone number
 so that any other users can contact you if they find problems.

      ( Approximate times on 4.77 MHz 8088 are: )
      ( F+    10 milliseconds )
      ( F/    20 milliseconds )
      ( FLN   30 milliseconds )

\ Load Block                                    14:33 08Nov88RS)

: COPYRIGHT
     CR ." Floating Forth  Version 1.2   Jan. 25, 1990 " CR
     CR ." written by Robert L. Smith "
     CR ." 2300 St. Francis Drive, Palo Alto, CA 94303 " CR ;

{

DECIMAL

\ The following forces use of ONLY in Forth vocabulary

ONLY FORTH ALSO DEFINITIONS

FLOAD FLOAT4TH.FTH

: %FLOAT_POP   ( r: f1 -- d1 ) \ pop a floating point number to data stack
                FPOP 2 ?ENOUGH ;

FORTH
' %FLOAT_POP IS FLOAT_POP       \ link to compilers FCONSTANT
TARGET

CODE DSHFT8     ( lo hi -- lowest middle high )
                LODSW           \ ax=low, bx=hi
                SUB CL, CL
                MOV CH, AL      MOV AL, AH
                MOV AH, BL      MOV BL, BH
                SUB BH, BH
                DEC SI          DEC SI          MOV 0 [SI], CX
                DEC SI          DEC SI          MOV 0 [SI], AX
                RET             END-CODE

}
\ 8-bit shift functions

DSHFT8   Perform an 8 bit shift on a double precision number,
   returning a triple word result (no loss of bits).  The
   results can be considered as either right or left shifted.
{

IMACRO D1+      ( d1 -- d1+ )
                ADD 0 [SI], # 1 WORD
                ADC BX, # 0
                END-IMACRO

\  MA  MB  MC  XMD  Y*  FRACT*                 07:07 15Oct88RS)

8 ARRAY MA

: Y*   ( d1 d2 -- t )  ( High order 8 bits of d1 and d2 = 0 )
        MA 2!  MA 4 + 2!  MA 2+ @ MA 6 + @ UM* 0
        MA @ MA 6 + @ UM* D+  MA 2+ @ MA 4 + @ UM* D+
        MA @ MA 4 + @ * + ;

: FRACT*   ( n1 n2 -- n3 )
        UM* NIP ;

}
\  Partial and fractional multiplication.       20:51 23Oct88RS)

MA  MB  MC  XMD  Variables used for multiplication.

Y*   Take the product of two 24-bit numbers, returning a triple
   precision result.  The 24-bit multiplicands are double
   numbers with the most significant 8 bits cleared to 0.

FRACT*  Take the product of two single numbers, treated as
   fractions with the binary point at the left.

{
\  F#BYTES  FPSTAT  FPSTAT  FPS0  FDEPTH        16:17 15Nov88RS)

4 CONSTANT F#BYTES           ( Size of floating point number )

TABLE FPSTAT    0 , 0 ,          ( Holds error information )
                END-TABLE

\ ******** FCLEAR MUST BE USED TO INITIALIZE THE FLOATING POINT STACK *******
20 F#BYTES * CONSTANT FPSSIZE           \ Size of floating pt. stack

FPSSIZE 3 F#BYTES * + ARRAY FPSTACK     \ Floating Point Stack
                                        \ with room for underflow

: FSP0          ( -- a1 )               \ Point to base of stack.
                FPSTACK FPSSIZE + ;

\ ******** FCLEAR MUST BE USED TO INITIALIZE THE FLOATING POINT STACK *******
VARIABLE FSP                            \ Points to top of stack

: FDEPTH   ( -- n )
        FSP0 FSP @ - F#BYTES / ;

}
\ Definition of the Floating Point stack.       21:36 23Oct88RS)

F#BYTES   Size of a floating point number in bytes.
FPSTAT    A variable to hold the Floating Point Status.

FPSSIZE   The size of the floating point stack, in bytes.

FPSTACK   The floating point stack.

FSP0      The base of the floating point stack.
FSP       Contains the pointer to the F.P. Stack top.

FDEPTH    The depth of the floating point stack, in FPSSIZE
          units.

{
\  XBIAS  FCLEAR  FDROP  FPUSH                  14:40 08Nov88RS)

$3F80 CONSTANT XBIAS             ( Exponent bias )

: FPUSH   ( F: -- r ; d -- )
        -4 FSP +!  FSP @ 2! ;           EXECUTES> FPUSH

' FPUSH ALIAS FPUSHER

FORTH   >FORTH

: %FPUSH        ( | string" -- )
                [FORTH]
                ['] FPUSHER COMP_CALL ; IMMEDIATE

' %FPUSH FORTH IS COMP_FPUSH    \ link into defered word

: [F#]          ( | floating_number -- )
                [FORTH]
                F# FPOP SWAP COMP_SINGLE COMP_SINGLE
                COMP_FPUSH ; IMMEDIATE

FORTH DECIMAL TARGET >LIBRARY       \ Library continues

: FCLEAR   ( -- )
        FSP0 FSP ! ;

: FDROP   ( F: r -- )
        F#BYTES FSP +! ;

: F2DROP  ( -- )
        FDROP FDROP ;

}
\  XBIAS  FCLEAR  FDROP                         14:17 08Nov88RS)

XBIAS   The exponent bias.

FCLEAR  Empties the floating point stack.

FDROP   Drop one floating point element from the F.P. stack.

FNSWAP  Exchange the n-th item on the F.P. stack with the
        zeroth item.

{
\ FPICK  FDUP  FOVER  FSWAP                     14:32 08Nov88RS)

: FPICK   ( F: rn rn-1 ... r0 -- fn rn-1 ... r0 rn ; n -- )
        F#BYTES * FSP @ + 2@ FPUSH ;

: FDUP   ( F: r -- r r )
        FSP @ 2@  F#BYTES NEGATE FSP +!
        FSP @ 2! ;

: FOVER   ( F: r1 r2 -- r1 r2 r1 )
        F#BYTES NEGATE FSP +!
        FSP @ 8 + 2@ FSP @ 2! ;

: F2DUP   ( ? -- ? )
        FOVER FOVER ;

: FSWAP   ( F: r1 r2 -- r2 r1 )
        FSP @ 2@  FSP @ 4 + 2@
        FSP @ 2!  FSP @ 4 + 2! ;
}
\ FDUP  FOVER  FSWAP                            14:35 08Nov88RS)

FPICK   Push a copy of the nth element of the F.P. stack
        onto the F.P. stack.

FDUP    Duplicate the top element on the F.P. stack.

FOVER   Push a copy of the second element on the F.P. stack
        onto the F.P. stack.

FSWAP   Interchange the top two elements on the F.P. stack.

{
\  FNEGATE  FNIP  FROT  F-ROT                   21:40 23Oct88RS)

: FNEGATE   ( F: r1 -- r2 )
        FSP @ DUP @ $8000 XOR SWAP ! ;

: FNIP   ( F: r1 r2 -- r2 )
        FSP @ 2@  4 FSP +!  FSP @ 2! ;

: FROT   ( F: r1 r2 r3 -- r2 r3 r1 )
        FSP @ 2@  FSP @ 4 + 2@  FSP @ 8 + 2@
        FSP @ 2!  FSP @ 8 + 2!  FSP @ 4 + 2! ;

: F-ROT   ( F: r1 r2 r3 -- r3 r1 r2 )
        FSP @ 2@  FSP @ 4 + 2@  FSP @ 8 + 2@
        FSP @ 4 + 2!  FSP @ 2!  FSP @ 8 + 2! ;

}
\  FNEGATE  FNIP  FROT  F-ROT                   21:44 23Oct88RS)

FNEGATE   Reverse the sign of the element at the top of the
          F.P. stack.

FNIP      Drop the second item from the F.P. stack.

FROT      Rotate the top three items on the F.P. stack,
          bring the third element to the top.

F-ROT     Rotate the top three items on the F.P. stack,
          bringing the second item to the top, and moving the
          former top item to the third position.

{
\ FPOP  FPCOPY  F0=  FNSWAP              14:39 014:45 08Nov88RS)

: FPOP   ( F: r -- ; -- d )
        FSP @ 2@ FDROP ;                EXECUTES> FPOP

: FPCOPY   ( F: r -- r ; -- d )
        FSP @ 2@ ;

: F0=   ( F: r -- ; -- flag )
        FPOP $7FFF AND OR 0= ;

: FPOP0=   ( F: r -- ; -- d flag )
        FPOP 2DUP $7FFF AND OR 0= ;

}
\ FPOP  FPUSH  FPCOPY  F0=                      23:02 23Oct88RS)

FPOP    Pop the top number from the F.P. stack, and push it
        onto the parameter stack as a double number.

FPUSH   Pop the top double number and

FPCOPY  Get a copy of the top number on th F.P. stack and push
        it on the parameter stack.

F0=     Pop the top member of the F.P. stack and test its value.
        If the value is zero, push true, else push false onto
        the parameter stack.

{
\  F0<  F=                                      14:45 08Nov88RS)

: F0<   ( F: r -- ; -- flag )
        FPOP DUP 0<
        IF      $7FFF AND OR 0= 0=
        ELSE    2DROP 0   THEN ;

: F=   ( F: r1 r2 -- ; -- flag )
        FPOP0=
        IF      2DROP FPOP0= NIP NIP
        ELSE    FPOP D=   THEN ;

: FNSWAP   ( F: rn rn-1 ... r0 -- r0 rn-1 ... rn ; n -- )
        F#BYTES * FSP @ + DUP >R 2@  FSP @ 2@
        R> 2!  FSP @ 2! ;

}
\  F0<  FPOP0=  F=                              23:13 23Oct88RS)

F0<     Pop and test the number at the top of the F.P. stack.
        If the sign is negative and the value is non-zero, push
        a true flag.  Otherwise push a false flag.

FPOP0=  Pop the top member of the F.P. stack, test, and push it
        onto the parameter stack.  If the number has a value of
        zero, also push a true flag; otherwise push a false
        flag.
F=      Pop the top two elements from the F.P. stack.  If the
        two numbers are equal, push a true flag.  Otherwise,
        push a false flag.

{
\  F<                                           16:07 14Oct88RLS

: F<    ( F: r1 r2 -- ; -- flag )
        FPOP FPOP DUP 0<
        IF      DU<
        ELSE    2SWAP D<
        THEN ;

}
\  F<                                           23:16 23Oct88RS)

F<      Pop the top two F.P. numbers from the F.P. stack and
        compare them.  If the second number is arithmetically
        less than the first number, push a true flag.
        Otherwise push a false flag.

{
\ F>                                            06:44 18Jul89RS)

: F>    ( F: r1 r2 -- ; -- flag )
        FPOP FPOP DUP 0<
        IF      2SWAP DU<
        ELSE    D<
        THEN ;

}
\ F>                                            23:18 23Oct88RS)

F>      Pop the top two numbers from the F.P. stack and
        compare them.  If the second number is arithmetically
        greater than the top, push a true flag onto the
        parameter stack.  Otherwise push a false flag.

{
\  FABS  FMIN  FMAX                             06:31 18Jul89RS)


: FABS  ( F: r1 -- r2 )
        FSP @ DUP @ $7FFF AND SWAP ! ;

: FMIN   ( F: r1 r2 -- r3 )
        FPOP FPOP 2OVER 2OVER DUP 0<
        IF   DU<
        ELSE 2SWAP D<
        THEN
        IF   2SWAP  THEN
        2DROP FPUSH ;

: FMAX   ( F: r1 r2 -- r3 )
        FPOP FPOP 2OVER 2OVER DUP 0<
        IF      2SWAP DU<
        ELSE    D<
        THEN
        IF  2SWAP  THEN
        2DROP FPUSH ;

}
\  FABS  FMIN  FMAX                             23:26 23Oct88RS)

FABS    Set the sign of the top of the F.P. stack to 0.

FMIN    Pop the top two members from the F.P. stack.  Push the
        arithmetically smaller back onto the F.P. stack.

FMAX    Pop the top two members from the F.P. stack.  Push the
        arithmetically larger back onto the F.P. stack.

{
\ F@  F!  FCONSTANT  FVARIABLE                  08:03 20Oct88RS)

: F@   ( F: -- r ; addr -- )
        2@ FPUSH ;

: F!   ( F: r -- ; addr -- )
        >R FPOP R> 2! ;

}
\ F@  F!  FCONSTANT  FVARIABLE                  00:03 23Oct88RS)

F@      Fetch the F.P. variable at the address specified by the
        top of the parameter stack.  Push the contents of the
        variable onto the F.P. stack.  Pop and discard the
        address at the top of the parameter stack.
F!      Store the number at the top of the F.P. stack into
        memory at the address at the top of the parameter stack.
        Pop the number from the F.P. stack, and pop the address
        from the parameter stack.
FCONSTANT  Create a F.P. constant with a value equal to the
        number poped off the F.P. stack.
FVARIABLE  Create a F.P. variable.

{
\ Various FCONSTANTs: F1.0 PI F0.0 FLOG10E      07:20 15Oct88RS)

F# 2.0E0 FCONSTANT F2.0

$0000 $3F80 FPUSH FCONSTANT F1.0
$0FDB $4049 FPUSH FCONSTANT PI
$0000 $0000 FPUSH FCONSTANT F0.0
$5BD9 $3EDE FPUSH FCONSTANT FLOG10E
$5D8E $4013 FPUSH FCONSTANT FLN10.0
$0000 $4120 FPUSH FCONSTANT F10.0
$0000 $3F00 FPUSH FCONSTANT F0.5

}
\ Various FCONSTANTs: F1.0 PI F0.0 FLOG10E      00:07 23Oct88RS)

F1.0      Floating point 1.
PI        Floating point pi
F0.0      Floating point 0.
FLOG10E   Floating point log base 10 of e
FLN10.0   Floating point natural log of 10
F10.0     Floating point 10.
F0.5      Floating point 0.5

{
\ T2/  T2*  T>SHIFT                             07:21 15Oct88RS)

FALSE #IF       \ FALSE = load the CODE equivelant words
                \ TRUE  = load the hi-level versions

: T2/   ( t1 -- t2 )
        >R D2/ R@ 1 AND
        IF    $8000 OR   ELSE   $7FFF AND   THEN    R> 2/ ;

: T2*   ( t1 -- t2 )
        >R DUP 0<
        IF   D2* R> 2* 1 OR   ELSE   D2* R> 2*  THEN ;

: T>SHIFT   ( t1 n -- t2 )   ( n is multiple of 80 hex )
        ?DUP
        IF   0  DO  T2/  $80 +LOOP  THEN ;

#ELSE

MACRO  T2/
        SAR   BX, # 1
        RCR   0 [SI], # 1 WORD
        RCR   2 [SI], # 1 WORD
        END-MACRO

MACRO  T2*
        SHL   2 [SI], # 1 WORD
        RCL   0 [SI], # 1 WORD
        RCL   BX, # 1
        END-MACRO

CODE T>SHIFT
        MOV CX, BX
        JCXZ 0 $
        MOV AX, CX
        SUB DX, DX
        MOV BX, # $80
        IDIV BX                 \ divide divisor by $80
        MOV CX, AX
        LODSW
        MOV BX, AX
   1 $: SAR BX, # 1
        RCR 0 [SI], # 1 WORD
        RCR 2 [SI], # 1 WORD
        LOOP 1 $
        RET
   0 $: LODSW
        MOV BX, AX
        RET             END-CODE

#ENDIF

}
\ T2/  T2*  T>SHIFT                             00:10 23Oct88RS)

T2/     Shift right a triple precision number.

T2*     Shift left a triple precision number.

T>SHIFT  Shift right a triple precision number by a count equal
         to the argument divided by 128 (80 hex).

{
\ D>SHIFT  D<SHIFT  D-CY                        07:21 15Oct88RS)

\ : D>SHIFT   ( d1 n -- d2 )   ( n a multiple of 80 hex )
\         ?DUP  IF  0  DO D2/  $80 +LOOP  THEN ;
\
\ : D<SHIFT   ( d1 n -- d2 )  ( n is multiple of 80 hex )
\         ?DUP
\         IF      0 DO  D2*  $80 +LOOP
\         THEN ;

CODE D>SHIFT
        SHL   BX, # 1
        MOV   BL, BH
        SUB   BH, BH
        MOV   CX, BX
        LODSW
        MOV   BX, AX
        JCXZ  0 $
   1 $: SAR   BX, # 1
        RCR   0 [SI], # 1 WORD
        LOOP 1 $
   0 $: RET             END-CODE

CODE D<SHIFT
        SHL   BX, # 1
        MOV   BL, BH
        SUB   BH, BH
        MOV   CX, BX
        LODSW
        MOV   BX, AX
        JCXZ  3 $
   4 $: SHL   0 [SI], # 1 WORD
        RCL   BX, # 1
        LOOP 4 $
   3 $: RET             END-CODE

: D-CY   ( d1 d2 -- d3 n )   ( n is borrow or carry )
        2OVER 2OVER DU<
        IF      D- -1
        ELSE    D- 0
        THEN ;

}
\ D>SHIFT  D<SHIFT  D-CY                        00:14 23Oct88RS)

D>SHIFT  Shift a double precision number right by a count equal
         to the top parameter divided by 128 (80 hex).

D<SHIFT  Shift a double precision number left by a count equal
         to the top parameter divided by 128 (80 hex).

D-CY     Subtract the top double number from the second.
         Return the difference and a borrow flag.

{
\  D+CY  ZSIGN  ZEXP  FIXGRS                    07:21 15Oct88RS)

: D+CY   ( d1 d2 -- d3 n )
        DNEGATE D-CY ;

TABLE ZSIGN     0 ,     END-TABLE
TABLE ZEXP      0 ,     END-TABLE

: FIXGRS   ( n1 -- n2 )
        DUP $3FFF AND
        IF      $C000 AND $0F OR
        THEN ;

}
\  D+CY  ZSIGN  ZEXP  FIXGRS                    00:18 23Oct88RS)

D+CY    Add the top two double numbers and return a carry flag.

ZSIGN   A variable to carry the sign of a result.
ZEXP    A vaiable to carry the resultant exponent.

FIXGRS  Set "sticky" bit flags.

{
\  UNNORMALIZE                                  07:21 15Oct88RS)

: UNNORMALIZE   ( d1 n -- d2 grs )  ( n is multiple of 80X )
        NO_INLINE
        >R R@ $480 <
        IF      0 -ROT R> T>SHIFT ROT FIXGRS EXIT   THEN
        R@ $880 <
        IF      $800 R> - D<SHIFT SWAP 0 SWAP FIXGRS EXIT  THEN
        R@ $D80 <
        IF      SWAP DUP $3FF AND
                IF      $4000 OR   THEN  SWAP
                R> $800 - D>SHIFT 0 ROT FIXGRS EXIT
        THEN
        R> DROP OR
        IF      0 0 $0F  ELSE   0 0 0  THEN ;

}
\  UNNORMALIZE                                  00:21 23Oct88RS)

UNNORMALIZE   Unnormalize the double number by a count specified
              at the top of the stack.  The number at the top of
              the stack is a signed count multiplied by 128
              (128 hex).

{
\  >NORMALIZE                                   07:22 15Oct88RS)

: >NORMALIZE   ( d1 -- grs d2 n )
        0 -ROT 0 $480 0
        DO      DROP DUP $100 U<
                IF      I LEAVE
                ELSE    T2/ I
                THEN
       $80 +LOOP ;

}
\  >NORMALIZE                                   00:26 23Oct88RS)

>NORMALIZE   Normalize the double number at the top of the
             parameter stack.  Return GRS (Guard, Round, and
             Sticky) bits and a normalizing count multiplied
             by 128.

{
\ MROUND  EVROUND  DENORMALIZE1                 07:57 31Oct88RS)

: MROUND   ( d1 evenflg -- d2 )
        IF      D1+ SWAP $FFFE AND SWAP
        ELSE    D1+
        THEN ;

: EVROUND   ( d1 grs -- d2 )
        DUP 0<
        IF      $8000 =   MROUND
        ELSE    DROP
        THEN ;

: DENORMALIZE1   ( d1 n -- d2 )
                NEGATE $80 + UNNORMALIZE EVROUND ;

}
\ MROUND  EVROUND  DENORMALIZE1                 07:57 31Oct88RS)

MROUND  Round the double number on the stack.  If the flag at
        the top of the stack is true, then round to even.

EVROUND  If the guard bit is set, round the double number on the
         stack.

DENORMALIZE1  Denormalize the double number according to the
        shifted count at the top of the stack.  Round toward
        even.
{
\ DENORMALIZE2  1NORMALIZE                      07:56 31Oct88RS)

: DENORMALIZE2   ( grs d1 n -- d2 )
        NEGATE $80 + UNNORMALIZE >R ROT R> OR EVROUND ;

: 1NORMALIZE    ( d1 -- d2 n )
        $8000 $C00 0
        DO      DROP DUP $7F >
                IF      $7F AND I NEGATE LEAVE
                ELSE    D2* $8000
                THEN
       $80 +LOOP ;

}
                                                08:04 31Oct88RS)

DENORMALIZE2  Denormalize the combination of d1 and GRS
              according to the shifted count n .

1NORMALIZE    Shift the double number left until it is in a
              normalized form.  A shifted form of the count is
              left on the stack.  The shifted form is used to
              speed up the conversion process.

{
\ NORMALIZE  4NORMALIZE                         08:16 31Oct88RS)

: NORMALIZE   ( d1 -- d2 n )
        NO_INLINE
        2DUP D0=
        IF      0 EXIT  THEN
        1NORMALIZE ;

: 4NORMALIZE   ( d1 -- d2 )
        NO_INLINE
        2DUP OR 0=  IF   EXIT   THEN
        $1000 0
        DO      D2* DUP $7F >
                IF      $7F AND $3F00 I - OR LEAVE
                THEN
       $80 +LOOP ;

}
                                                08:26 31Oct88RS)

NORMALIZE  Perform a normalization process on the double number.
           Push the shifted count on the stack.

4NORMALIZE  Normalize a double number by shifting left.  This is
            used only by 2NORMALIZE (and ultimately by FLN).
            The result is really a floating point number on the
            parameter stack.

{
\ 3NORMALIZE                                    08:18 31Oct88RS)

: 3NORMALIZE   ( d1 -- d2 )
        $4480 $4000
        DO      DUP $200 <
                IF      D1+ D2/ DUP $0FF >
                        IF      D2/
                        ELSE    $7F AND
                        THEN
                        I + LEAVE
                ELSE    D2/
                THEN
       $80 +LOOP ;

}
                                                08:25 31Oct88RS)

3NORMALIZE  Normalize a double number by shifting right.  This
            routine is used only by 2NORMALIZE (and ultimately
            by FLN).  The result is really a floating point
            number on the parameter stack.

{
\ 2NORMALIZE                                    08:20 31Oct88RS)

: 2NORMALIZE   ( d1 -- d2 )
        $7FFF AND DUP $0FF >
        IF      3NORMALIZE
        ELSE    DUP $80 <
                IF      4NORMALIZE
                ELSE
                        $3F80 OR
                THEN
        THEN ;

}
                                                08:27 31Oct88RS)

2NORMALIZE  Normalize the double number, performing either a
            left or right shift, as required.

{
\ FLOAT                                         07:15 19Oct88RS)

: FLOAT         ( F: -- r ; d -- )
                NO_INLINE
                2DUP OR 0= IF  FPUSH EXIT THEN
                DUP 0< $8000 AND >R DABS DUP $80 U<
                IF      NORMALIZE >R $7F AND $4B00 R> + OR
                        R> OR FPUSH EXIT
                THEN    >NORMALIZE $4B00 + >R ROT DUP 0<
                IF      $8000 =  MROUND
                        DUP $100 U< 0=
                        IF      D2/ $7F AND R> $80 + OR
                                R> OR FPUSH EXIT
                        THEN
                ELSE    DROP
                THEN    $7F AND R> OR
                R> OR FPUSH ;

}
                                                08:28 31Oct88RS)

FLOAT   Convert the double number on the parameter stack to a
        floating point number on the floating point stack.

{
\ DINTABS                                       05:49 01Nov88RS)

: DINTABS   ( F: r -- ; -- d flag )
        NO_INLINE
        FPOP DUP $7F80 AND DUP $3F80 <
        IF      DROP 2DROP 0 0 0 EXIT  THEN
        SWAP $7F AND $80 OR SWAP $4B00 - DUP 0<
        IF      0 SWAP DO   D2/  $80 +LOOP  0
        ELSE    $0400 MIN DUP
                IF      0 DO   D2*   $80 +LOOP
                ELSE    DROP
                THEN    DUP 0<
        THEN  ;

}
                                                05:45 01Nov88RS)

DINTABS  Pop the top number from the floating point stack.
         Take the absolute value and convert it to a double
         number on the parameter stack.  If the resulting
         number is positive, push a 0 onto the stack.
         Otherwise, push a true flag (-1) onto the stack.

{
\ INT   BMASK                                   07:23 15Oct88RS)

: INT   ( F: r -- ; -- d )
        FDUP F0<
        IF      DINTABS >R DNEGATE R>
        ELSE    DINTABS
        THEN    ABORT"  Out of range in INT " ;

TABLE BMASK     $0000 , $8000 , $C000 , $E000 , $F000 , $F800 ,
                $FC00 , $FE00 , $FF00 , $FF80 , $FFC0 , $FFE0 ,
                $FFF0 , $FFF8 , $FFFC , $FFFE , $FFFF ,
END-TABLE

}
                                                05:54 01Nov88RS)

INT     Pop a floating point number from the f.p. stack and
        convert it to a double number.

BMASK   An array of bit masks used to obtain the integer part
        of a floating point number.

{
\ FINT                                          07:24 15Oct88RS)

: FINT   ( F: r1 -- r2 )
        NO_INLINE
        FPOP
                        \ is r1 less than 1.0000000?
        DUP $7F80 AND DUP $3F80 <          \ 3F80=exponent bias
        IF      DROP $8000 AND NIP 0 SWAP FPUSH EXIT  THEN
        DUP $4B00 <
        IF      $3B00 - 2* $100 / 2* DUP $20 <
                IF      BMASK + @ AND
                        NIP 0 SWAP              \ 05/14/93 16:18 rls FIX
                ELSE    $1F AND BMASK + @ ROT AND SWAP
                THEN
        ELSE    DROP
        THEN
        FPUSH ;

}
                                                05:54 01Nov88RS)

FINT    Convert the number at the top of the f.p. stack to its
        integer part represented as a floating point number.

{
\ ROUND1                                        07:24 15Oct88RS)

: ROUND1   ( grs d1 n1 -- d2 n2 )
        >R ROT DUP 0<
        IF      $8000 = MROUND
                DUP $0FF >
                IF      D2/ R> $80 +
                ELSE    R>
                THEN
        ELSE    DROP R>
        THEN ;

}
                                                05:58 01Nov88RS)

ROUND1  The input parameters represent a floating point number
        broken into an exponent at the top, a double number,
        and the GRS (guard, round, sticky) bits.  Round the
        number according to GRS.

{
\ ROUND2                                        07:24 15Oct88RS)

: ROUND2   ( d1 grs -- d2 n )
        $8000 =
        IF      SWAP $FFFE AND SWAP
        THEN
        DUP $0FF >
        IF      D2/ $80
        ELSE    0
        THEN ;

}
                                                05:58 01Nov88RS)

ROUND2  Round the double number according to the GRS bits at
        the top of the stack.

{
\ Aux for F+                                    07:24 15Oct88RS)

: (F-X1=X2)   ( F: -- r ; d1 d2 -- )  ( F- : Equal exponents )
        NO_INLINE
        D- DUP 0<
        IF      ( mantissa1 < mantissa2 )
                DNEGATE ZSIGN @ $8000 XOR ZSIGN !
        ELSE    2DUP D0=  IF   EXIT   THEN
        THEN   ZEXP @ $80 >
        IF      ( Equal exponents, normal r1' )
                NORMALIZE ZEXP @ + DUP $80 <
                IF      ( denormalize )
                        DENORMALIZE1
                ELSE    SWAP $7F  AND OR
                THEN
         THEN ( ZSIGN @ OR ) ;

}
                                                06:02 01Nov88RS)

(F-X1=X2)  Auxilliary floating point subtraction of magnitudes
           function for the case of equal exponents for the two
           operands.

{
\ Auxilliary for F+                             08:33 20Oct88RS)

: (F+X1=X2)   ( F: -- r ; d1 d2 -- )
        D+ DUP $0FF >
        IF      ( normal case )  OVER 1 AND
                IF      ( Round to even case )
                        D1+ D2/ SWAP $FFFE AND SWAP
                ELSE    D2/
                THEN   ZEXP @ + DUP 0< ABORT"  Overflow in F+ "
        ELSE    DUP $7F >
                IF      $7F AND ZEXP @ DUP 0=
                        IF      DROP $80   THEN  OR
                THEN
        THEN  ( ZSIGN @ OR ) ;

}
                                                06:01 01Nov88RS)

(F+X1=X2)  Auxillary floating point addition of magnitudes
           function for the case of equal exponents of the
           operands.

{
\ Auxilliary for F+                             07:25 15Oct88RS)

: (1F-)   ( d1 d2 x1-x2 -- grs d3 n )
        NO_INLINE
        UNNORMALIZE NEGATE DUP >R
        IF    D1+  THEN   D- R> -ROT        ( grs d3 )
        DUP $7F >  IF   0 EXIT  THEN
        T2* DUP $7F >
        IF      $FF80 EXIT  THEN
        T2* 0 $C800 $0100
        DO      DROP DUP $7F >
                IF      I NEGATE LEAVE THEN
                D2* I NEGATE $80
        +LOOP ;

}
                                                06:03 01Nov88RS)

(1F-)   An auxillary function for floating point subtraction of
        magnitudes.

{
\ Aux for F+                                    07:25 15Oct88RS)

: (F+-AUX)   ( d2 sx2 -- d3 sx2 x1-x2 flag )
        DUP $7F80 AND DUP 0=
        IF      DROP >R $7F AND R> $80 OR $80   THEN
        ZEXP @ SWAP - DUP 0< ;

}
                                                06:05 01Nov88RS)

(F+-AUX)  An auxillary function for floating point addition.

{
\ Aux for F+                                    07:26 15Oct88RS)

: (F-)   ( d1 d2 sx2 -- d3 )        ( Subtract magnitudes )
        NO_INLINE
        (F+-AUX)
        IF      ( x2 > x1 )
                NEGATE SWAP DUP $7F80 AND ZEXP !
                $8000 AND ZSIGN !  >R 2SWAP R>
        ELSE    ( x2 <= x1 )  NIP DUP 0=
                IF      ( Exponents are equal )
                        DROP (F-X1=X2) EXIT
                THEN
        THEN    ( d1 d2 x1-x2 )
        (1F-) ZEXP @ + DUP $80 <
        IF   DENORMALIZE2  ELSE   ROUND1 SWAP $7F AND OR  THEN ;

}
                                                06:06 01Nov88RS)

(F-)    Auxilliary function for the subtraction of magnitudes
        of floating point numbers.

{
\ Auxilliary for F+                             08:46 20Oct88RS)

: (F+)   ( d1 d2 sx2 -- d3 )
        NO_INLINE
        (F+-AUX)
        IF      ( x2 > x1 )  NEGATE SWAP DUP $7F80 AND ZEXP !
                $8000 AND ZSIGN !  >R 2SWAP R>
        ELSE    ( x2 <= x1 )   NIP DUP 0=
                IF      ( x1 = x2 ) DROP (F+X1=X2) EXIT  THEN
        THEN    ( d1 d2 x1-x2 ) UNNORMALIZE
        >R D+ DUP $0FF >   IF  D1+ R> 0=
                IF      SWAP $FFFC AND SWAP  THEN  D2/ $80
        ELSE    R@ 0<
                IF   D1+ R> ROUND2  ELSE   R> DROP 0  THEN
        THEN  ZEXP @ + DUP 0< ABORT"  Overflow in F+ " DUP
        IF      SWAP $7F AND SWAP  THEN  OR ;
}
(F+)                                            06:11 01Nov88RS)

(F+)    Auxillary function for addition of floating point
        numbers having the same sign.

{
\  F+                                           07:26 15Oct88RS)

: F+   ( F: r1 r2 -- r3 )
        NO_INLINE
        FSP @ 4 + 2@ DUP $8000 AND ZSIGN !
        DUP $7F80 AND DUP ZEXP !
        IF      $7F AND $80 OR
        ELSE    $7F AND 2DUP OR 0=
                IF   2DROP FNIP EXIT   THEN
        THEN
        FPOP0=  IF    2DROP 2DROP EXIT   THEN
        FDROP DUP $7F AND $80 OR SWAP $FF80 AND DUP
        ZSIGN @ XOR 0<
        IF      (F-)  ELSE    (F+)   THEN
        ZSIGN @ XOR FPUSH ;

}
F+                                              06:11 01Nov88RS)

F+      Floating point addition.

{
\ F-  FIX  ZDEN  ZQUOT                          08:46 20Oct88RS)

: F-   ( F: r1 r2 -- r3 )
        FNEGATE F+ ;

: FIX   ( F: r -- ; -- d )
        FDUP F0<
        IF      FABS F0.5 F+ DINTABS >R DNEGATE R>
        ELSE    F0.5 F+ DINTABS
        THEN    ABORT"  Out of range in FIX " ;

2VARIABLE ZDEN   2VARIABLE ZQUOT

}
F-  FIX  ZDEN  ZQUOT                            06:10 01Nov88RS)

F-      Floating point subtraction.

FIX     Pop a number from the floating point stack, convert it
        to a double number and push the result on the parameter
        stack.  Issue an error message if the number cannot be
        properly converted.

ZDEN    A variable for temporary results in f.p. division.
ZQUOT   A variable for temporary results in f.p. division.

{
\ Aux for F/                                    07:27 15Oct88RS)

: (1F/)   ( 0 d1 d2 -- t )
        ( Set quotient exponent, possible num adjust )
        FDROP DUP $7F AND $80 OR SWAP $7F80 AND DUP
        IF      XBIAS - NEGATE
        ELSE    DROP NORMALIZE
        THEN
        2/ ZEXP +!
        2OVER 2OVER DU< 0=
        IF      ZDEN 2!  T2/
        ELSE    ZDEN 2!  $-40 ZEXP +!
        THEN
        ZDEN 2@ DSHFT8 DROP ZDEN 2! ;  ( Shift den left by 8 )

}
\ Aux for F/                                    06:13 01Nov88RS)

(1F/)   An auxillary function for floating point division.
        Set the quotient exponent, possibly adjust the
        numerator.

{
\ Aux for F/                                    06:15 01Nov88RS)

: (2F/)   ( t -- d )
        ZDEN @ UM/MOD DUP ZQUOT !
        ZDEN 2+ @ UM* D-CY
        IF      ZDEN 2@ D+CY
                IF      ZDEN 2@ D+ -2
                ELSE    -1
                THEN
                ZQUOT +!
        THEN ;

}
\ Aux for F/                                    06:14 01Nov88RS)

(2F/)   An auxilliary function for floating point division.
        In this routine we obtain the most significant part
        of the quotient.

{
\ Aux for F/                                    15:24 14Oct88RLS

: (3F/)   ( 0 d1 n -- d2 )  ( Usual generate low quotient )
        UM/MOD DUP ZQUOT 2+ !
        ZDEN 2+ @ UM* D-CY
        IF      ZDEN 2@ D+CY
                IF      ZDEN 2@ D+ -2
                ELSE    -1
                THEN
                ZQUOT 2+ +!
        THEN ;

}
                                                06:16 01Nov88RS)

(3F/)   Auxillary function for floating point division.  This
        routine is normally called to obtain the low order part
        of the quotient.

{
\ Aux for F/                                    15:23 14Oct88RLS

: (4F/)   ( 0 d1 n -- d2 )
        ( Gen low quotient for hi num = hi den )
        DROP NIP ZDEN 2+ @ SWAP 0 ZDEN @ 0 D+
        ZDEN 2+ @ 0 D- NIP 0<           \ TJZ 01/25/90 17:37:40.03 ADDED NIP
        IF      ZDEN 2@ D+CY
                IF      ZDEN 2@ D+ -3
                ELSE    -2
                THEN
        ELSE    -1
        THEN
        ZQUOT 2+ ! ;

}
\ Aux for F/                                    06:18 01Nov88RS)

(4F/)   Auxilliary function for floating point division.
        Generate the low part of the quotient for the case of
        the high part of the numerator equal to the high part
        of the denominator.

{
\ SROUND                                        07:27 15Oct88RS)

: SROUND        ( d1 -- d2 )
                NO_INLINE
                DUP 0<
                IF      ( Round up )  2DROP ZQUOT 2@ D1+ EXIT
                THEN    D2* 2DUP ZDEN 2@ DU< 0=
                IF      ( Do we round to even? )
                        ZDEN 2@ D=
                        IF      ( Yes )
                                ZQUOT 2@ D1+
                                SWAP $FFFE AND SWAP
                        ELSE    ZQUOT 2@ D1+
                        THEN
                ELSE    2DROP ZQUOT 2@
                THEN    ;

}
                                                06:20 01Nov88RS)

SROUND  A rounding function used in floating point division.

{
\ Auxilliary for F/                             07:27 15Oct88RS)

: (UF/)   ( d1 -- d2 )   ( Generate unnormalized quotient )
        ZEXP @ 2* NEGATE $80 + UNNORMALIZE DUP 0<
        IF      $8000 = MROUND
        ELSE    DROP
        THEN ;

VARIABLE ZTEMP

}
                                                06:22 01Nov88RS)

(UF/)   An auxilliary function used in floating point division
        to generate an unnormalized quotient.

ZTEMP   Another variable for temporary storage.

{
\  F/                                           08:47 20Oct88RS)

: F/   ( F: r1 r2 -- r3 )
        NO_INLINE
      0 0 FSP @ 4 + 2@ DUP FSP @ @ XOR $8000 AND ZSIGN !
      DUP $7F80 AND DUP 2/ ZEXP !
      IF      $7F AND $80 OR
      ELSE    $7F AND 2DUP OR 0=
              IF  2DROP FDROP FDROP 0 ZSIGN @ FPUSH EXIT
              THEN  NORMALIZE $80 + 2/ ZEXP !
      THEN  FPOP0= ABORT"  Floating Division by 0" (1F/) (2F/)
      ZDEN @ 2DUP U<  IF   (3F/)  ELSE  (4F/)  THEN
      ZEXP @ $40 <    IF  (UF/)  ELSE  SROUND
        ZEXP @ $3FC0 > ABORT"  Overflow in F/ "
              $7F AND ZEXP @ 2* OR
      THEN  ZSIGN @ OR FPUSH ;
}
                                                06:31 01Nov88RS)

F/      The floating point division routine.  The rather sneaky
        technique used here is attributable to Roedy Green, the
        author of BBL/Abundance.  To do a division by a double
        number, shift the denominator until the m.s. bit is
        set.  Use the high order part to obtain the first
        approximation, along with its remainder.  If neccessary,
        make one or two stages of correction to obtain the
        exact high order part and temporary remainder.  Repeat
        the process to obtain the low order part.

{
\ (F*CLEANUP)    Aux for F*                     08:47 20Oct88RS)

: (F*CLEANUP)   ( t1 flag -- d2 )
                NO_INLINE
                IF    ZEXP @ 2* NEGATE $80 + UNNORMALIZE DUP 0<
                        IF    $8000 = ZTEMP @ 0= AND MROUND
                        ELSE  DROP
                        THEN  EXIT            \ leave here
                THEN    ROT DUP 0<
                IF      $8000 = ZTEMP @ 0= AND MROUND DUP $0FF >
                        IF      D2/ $40 ZEXP +!  ZEXP @ $3FC0 >
                                ABORT"  Overflow in F* "
                        THEN
                ELSE  DROP
                THEN  $7F AND ZEXP @ 2* OR ;

}
\ (F*CLEANUP)    Aux for F*                     06:32 01Nov88RS)

(F*CLEANUP)  Auxillary function for F*

{
\ 1F*  Aux for F*                               07:30 15Oct88RS)

: 1F*   ( n1 -- n1 )
     DUP $7F80 AND DUP 2/ $40 + ZEXP !
     IF      $7F AND $80 OR
     ELSE    $7F AND NORMALIZE $80 + 2/ ZEXP !
     THEN ;

}
                                                06:32 01Nov88RS)

1F*     Auxillary function for F*

{
\  F*  Floating point multiply                  08:47 20Oct88RS)

: F*   ( F: r1 r2 -- r3 )
        NO_INLINE
     FPOP FSP @ @ OVER XOR $8000 AND ZSIGN !  $7FFF AND 2DUP D0=
     IF      2DROP FDROP 0 ZSIGN @ FPUSH EXIT  THEN
     1F* FPOP $7FFF AND 2DUP D0=
     IF      2DROP 2DROP 0 ZSIGN @ FPUSH EXIT  THEN
     DUP $7F80 AND DUP
     IF      XBIAS - 2/ ZEXP +! $7F AND $80 OR
     ELSE    $7F AND NORMALIZE $80 + XBIAS - 2/ ZEXP +!
     THEN   Y* DUP 0< 0=
     IF      T2* $-40 ZEXP +!  THEN
     ROT ZTEMP !  DSHFT8 ZEXP @ DUP $3FC0 > ABORT"   Overflow in F* "
     $40 < (F*CLEANUP)
     ZSIGN @ OR FPUSH ;

}
F*                                              06:32 01Nov88RS)

F*      Floating point multiplication function.

{
\ F**+N   Raise fp to positive integer power.   07:30 15Oct88RS)

: F**+N     ( F: r1 -- r2 ; n -- )
        $7FFF AND >R F1.0
        BEGIN R@ 1 AND
              IF   FOVER F*  THEN
              R> 2/ DUP
        WHILE >R FSWAP FDUP F* FSWAP
        REPEAT
        DROP FNIP ;

}
                                                06:34 01Nov88RS)

F**+N   Raise the floating point number at the top of the f.p.
        stack to the positive integer power at the top of the
        parameter stack.

{
\ F**N  F**N*  MF**2                            07:31 15Oct88RS)

: F**N     ( F: r1 -- r2 ; n -- )  ( r1^n )
        DUP 0<
        IF    ABS F**+N F1.0 FSWAP F/
        ELSE  F**+N
        THEN ;

: F**N*    ( F: r1 r2 -- r3 ; n -- ) ( r1 * [r2^n] )
        DUP 0< IF   ABS F**+N F/ ELSE    F**+N F*  THEN ;

: MF**2   ( xlo lhi -- x^2lo x^2hi )
        DUP >R UM* NIP 0 D2*
        R> DUP UM* D+ ;

}
\ F**N  F**N*  MF**2                            06:39 01Nov88RS)

F**N    Raise the number at the top of the f.p. stack to the
        power specified at the top of the parameter stack.

F**N    Raise the number at the top of the f.p. stack to the
        power specified at the top of the parameter stack,
        then multiply by the number second on the f.p. stack.
MF**2   Square the double number mantissa on the parameter
        stack.

{
\  D2**N                                        07:31 15Oct88RS)

TABLE 2**NTAB   $0001 , $0002 , $0004 , $0008 , $0010 , $0020 ,
                $0040 , $0080 , $0100 , $0200 , $0400 , $0800 ,
                $1000 , $2000 , $4000 , $8000 ,
END-TABLE

: D2**N    ( n -- d )
        $1F AND DUP $10 <
        IF      2* 2**NTAB + @ 0
        ELSE    $0F AND 2* 2**NTAB + @ 0 SWAP
        THEN ;

2VARIABLE DROOT

}
                                                06:47 01Nov88RS)

2**NTAB  A table of 2 raised to various powers.

D2**N    Return a double number representing 2 raised to the
         power specified.

DROOT    A double number variable for temporary use with
         square roots.

{
\ Auxilliaries for Square Root.                 14:18 14Oct88RLS

: SQRTSTEP   ( d1 n1 -- d2 n2 )
        2* >R D2* D2* DUP R@ >
        IF      R@ 1 OR -  R> 2 OR
        ELSE    R> THEN ;

: DSQRTSTEP   ( d1 d2 -- d3 d4 )
        D2* DROOT 2!  D2* D2* 2DUP DROOT 2@ 2SWAP D<
        IF      DROOT 2@ D1+ D-
                DROOT 2@ D1+ D1+
        ELSE
                DROOT 2@
        THEN ;

}
                                                06:48 01Nov88RS)

SQRTSTEP  Auxillary function for FSQRT .

DSQRTSTEP  Another auxillary function for FSQRT .

{
\ Auxilliary Square Root function.              08:45 20Oct88RS)

: FSQRT1   ( F: r1 -- ; -- n1 n2 n3 )
        NO_INLINE
        FPOP0=  IF  FPUSH EXIT  THEN  DUP 0<
        ABORT"  Negative argument for FSQRT "
        DUP $7F80 AND DUP ZEXP !
        IF      $7F AND $80 OR
        ELSE    $7F AND NORMALIZE $80 + ZEXP +!
        THEN   DSHFT8 DROP  ZEXP @ XBIAS - DUP $80 AND
        IF      $80 - 2/ XBIAS + ZEXP !  0 D2* D2*
        ELSE    2/ XBIAS + ZEXP !  0 D2*
        THEN
        1- 2  7 0
        DO      SQRTSTEP  LOOP ;

}
                                                06:48 01Nov88RS)

FSQRT1  Yet another auxillary function for FSQRT .

{
\ FSQRT                                         07:32 15Oct88RS)

: FSQRT   ( F: r1 -- r2 )
        FSQRT1 ROT DROP  5 0  DO  SQRTSTEP  LOOP
        ROT DROP 0 SWAP 0  $0C 0
        DO      DSQRTSTEP  LOOP
        D2/ OVER 1 AND
        IF      D2/ 2SWAP D0=
                IF      D1+ SWAP $FFFE AND SWAP
                ELSE    D1+
                THEN
        ELSE    D2/ 2SWAP 2DROP
        THEN
        DUP $0FF >
        IF      D2/ -1 ZEXP +!   THEN
        $7F AND ZEXP @ OR FPUSH ;
}
                                                06:49 01Nov88RS)

FSQRT   Replace the number at the top of the f.p. stack with
        its square root.

{
\ Tables for logarithms.                        07:32 15Oct88RS)

TABLE LOGTAB1
        $0000 , $0000 ,   $00FC , $14D8 ,   $01F0 , $A30C ,
        $02DE , $1A51 ,   $03C4 , $E0EE ,   $04A5 , $54BE ,
        $057F , $CC1C ,   $0654 , $96A7 ,   $0723 , $FDF2 ,
        $07EE , $461B ,   $08B3 , $AE56 ,   $0974 , $715D ,
        $0A30 , $C5E1 ,   $0AE8 , $DEE0 ,   $0B9C , $EBFB ,
        $0C4D , $19C3 ,   $0CF9 , $91F6 ,   $0D22 , $7BBE ,
        $0E47 , $FBE4 ,
END-TABLE

TABLE LOGTAB2
        $0000 , $0000 ,   $0208 , $2BB1 ,   $0421 , $662D ,
        $064C , $D797 ,   $088B , $C741 ,   $0ADF , $A036 ,
        $0D49 , $F69E ,   $0FCC , $8E36 ,
END-TABLE

}
                                                06:50 01Nov88RS)

LOGTAB1  Auxillary table used for logarithm functions.

LOGTAB2  Auxillary table used for logarithm functions.

{
\ Auxilliary functions                          08:09 31Oct88RS)

: YLN2*   ( n -- d )
        2* DUP >R $B172 UM* R> $17F8 UM*
        $8000 0 D+ NIP 0 D+ 2NORMALIZE
        DUP IF  $80 -  THEN ;

: XLN2*   ( n -- d )  ( Multiply a shifted exponent by ln 2 )
        DUP 0<
        IF      ABS YLN2* $8000 OR
        ELSE    YLN2*
        THEN ;

}
                                                08:12 31Oct88RS)

YLN2*   Multiply the positive shifted exponent by the natural
        logarithm of 2.

XLN2*   Multiply the shifted exponent by the natural log of 2.

{
\ Auxilliary function for FLN                   07:32 15Oct88RS)

: FLN+   ( F: -- r ; d1 n -- )
        $3F80 - XLN2* FPUSH
        DUP $FC AND DUP $7C AND >R  $100 * >R      ( R: div 4J )
        3 AND >R 0 SWAP D2/ D2/ D2/ $1FFF AND
        0 R> D2/ D2/ D2/ DROP OR
        R@ UM/MOD SWAP 0 SWAP R> UM/MOD NIP SWAP
        DUP >R $20 R@ 0<  IF  1-  THEN
        R@ FRACT* $0555 SWAP - DUP 0=
        IF      DROP R@
        ELSE    NEGATE R@ FRACT*
        THEN    R> FRACT* 0 SWAP DSHFT8 ROT DROP D2* D2*
        D- DSHFT8 ROT DROP R> LOGTAB1 + 2@ D+
        2NORMALIZE DUP IF  $300 -  THEN
        FPUSH F+ ;
}
                                                06:56 01Nov88RS)

FLN+    Auxillary function for the natural logarithm function
        used when the mantissa is less than or equal to 1.5625 .

{
\ Auxilliary function for Logarithm             07:33 15Oct88RS)

: FLN-   ( F: -- r ; d n -- )
        $3F00 - XLN2* FPUSH DUP $F8 AND 8 + $100 * >R
        0 $100 2SWAP D- DUP $F8 AND 2/ R> SWAP >R >R
        7 AND >R 0 SWAP D2/ D2/ D2/ D2/ $FFF AND
        0 R> D2/ D2/ D2/ D2/ DROP OR R@ DUP
        IF  UM/MOD SWAP 0 SWAP R> UM/MOD NIP SWAP
        ELSE    R> 2DROP
        THEN   DUP >R 2DUP MF**2 DUP R@ $033 FRACT* $400 +
        R@ FRACT* $5555 + R> FRACT* FRACT* 0 SWAP D2/ D2/ D2/
        D+ D2/ D2/ D2/ D2/ D2/ D+  D2/ $7FFF AND
        D2/ D2/ D2/ D2/ D2/ R> LOGTAB2 + 2@ D+ 2DUP D0= 0=
        IF      2NORMALIZE $380 - $8000 OR  THEN
        FPUSH F+ ;

}
                                                06:56 01Nov88RS)

FLN-    Auxillary function for natural logarithm, used when
        the mantissa is greater than 1.5625 and less than 2.0 .

{
\ FLN   Natural Logarithm                       08:47 20Oct88RS)

: FLN   ( F: r1 -- r2 )
        NO_INLINE
        FPOP0= ABORT"  Zero argument for FLN "
\                2DROP -1 -1 FPUSH EXIT
        DUP 0< ABORT"  Negative argument for FLN "
        DUP $7F80 AND DUP 0=
        IF      1NORMALIZE
        ELSE    SWAP $7F AND $80 OR SWAP
        THEN
        OVER $C8 >
        IF      FLN-   ELSE    FLN+   THEN ;

}
                                                06:57 01Nov88RS)

FLN     Replace the number at the top of the f.p. stack with
        its natural logarithm.

{
\ FLOG ( Common Logarithm ) E.PARTS and F.PARTS  04/30/93 15:33 rls&tjz)

: FLOG   ( F: r1 -- r2 )
        FLN FLOG10E F* ;

: E.PARTS   ( F: r1 -- ; n -- d exp sign )   ( Aux for E. )
        NO_INLINE
        8 MIN 1 MAX FDUP F0=
        IF      FDROP DROP 0 0 0 0 EXIT  THEN
        FSP @ @ 0< >R
        FABS FDUP FLOG INT DROP
        2DUP - F10.0 F**N* F0.5 F+ FINT
        SWAP FDUP F10.0 F**N F< 0=
        IF      F10.0 F/ 1+  THEN
        >R INT R> R> ;

: F.PARTS  ( F: r1 -- ; n -- d )   ( Aux for F. )
        NO_INLINE
        8 MIN 1 MAX FDUP F0=
        IF      FDROP DROP 0 0 EXIT  THEN
        FABS    F10.0 F**N* F0.5 F+ FINT INT ;

}
                                                06:59 01Nov88RS)

FLOG    Replace the number at the top of the f.p. stack with
        its common (base 10) logarithm.

E.PARTS  An auxillary function for  (E.) .

F.PARTS  An auxillary function for  (F.) .

{
\ Numeric output E.                             14:28 08Nov88RS)

VARIABLE F#PLACES

: (E.)          ( F: r -- ; n -- addr cnt )
                F#PLACES @
                E.PARTS BASE @ >R >R DECIMAL <# DUP ABS 0 # # 2DROP 0<
                IF     $2D   ELSE $2B  THEN     ( Send "-" or "+" )
                HOLD $45 HOLD                   ( Send the "E" )
                F#PLACES @ 0 DO  #  LOOP        ( Send the fraction )
                $2E HOLD R> 0<                  ( Send "." Check sign )
                IF      $2D HOLD THEN           ( Send "-" )
                R> BASE ! #> ;                  ( Restore BASE )

: E.            ( F: r -- )
                8 F#PLACES ! (E.) TYPE SPACE ;

: E.R           ( F: r -- ; places width -- )
                >R 8 min 1 max F#PLACES ! (E.)   R> OVER - SPACES TYPE   ;

: .FS           ( -- )
                FDEPTH  IF   CR FSP @ FDEPTH F#BYTES * 0 DO  DUP I + 2@
                FPUSH E. F#BYTES  +LOOP  DROP  ELSE ."  Empty"  THEN ;

: (F.)          ( F: r -- ; n -- addr cnt )
                FDUP FABS FDUP FINT F-
                F#PLACES @ F.PARTS BASE @ >R DECIMAL <#
                F#PLACES @ 0max 0 ?DO # LOOP
                2DROP                           \ discard fractional part
                $2E HOLD                        ( Send "." Check sign )
                FSP @ @ 0< >R                   \ save sign of r
                FINT INT                        \ init integer part
                #S R>
                IF  $2D HOLD THEN               ( Send "-" )
                R> BASE ! #> ;                  ( Restore BASE )

: F.            ( F: r -- )
                8 F#PLACES ! (F.) TYPE SPACE ;

: F.R           ( F: r -- ; places width -- )
                >R 8 min 1 max F#PLACES ! (F.)   R> OVER - SPACES TYPE   ;

}

(E.)  E.                                        14:29 08Nov88RS)

(E.)    Auxillary function for E.

E.      The floating point output routine.

.FS     A utility for checking the contents of the F.P. stack.

{
\ Auxilliary finctions for numeric input.       14:05 14Oct88RLS

: Ee(?   ( n -- flag )
        DUP 40 =                     ( Check for left paren )
        IF    DROP -1
        ELSE  DUP 69 = SWAP 101 = OR  ( Check for "e" or "E" )
        THEN ;

: -?    ( addr1 -- addr2 flag )
        DUP 1+ C@ 45 =
        IF      1+ -1
        ELSE    0
        THEN ;

}
                                                07:03 01Nov88RS)

E.(?    Auxillary function to test for exponential indicator
        in floating point input.  The indicator should be one
        of the following:   E  e  (

-?      Check the character at the specified address for
        ASCII - sign.  If found, increment the address pointer
        and return a true flag.  Otherwise, return a false flag.

{
\ Numeric Input Conversion                      11:27 07Nov88RS)

: FCONVERT      ( +d1 adr1 -- +d2 adr2 )
\ Convert the string at adr1 to a double number until an unconvertable
\ character is encountered (pointed to by adr2).  Accumulate in +d1.
                BEGIN   >R DUP $F000 AND        \ check for overflow
                        IF      R> EXIT
                        THEN
                        R> 1+  DUP>R  C@  BASE @  DIGIT
                WHILE   SWAP  BASE @ UM*  DROP  ROT  BASE @ UM*  D+
                        DOUBLE?  IF  DPL INCR THEN  R>
                REPEAT  DROP  R>  ;

: (FNUMBER?)    ( a1 -- f1 ; F: -- r )  \ convert string a1 to floating point #
        0 0     ROT -? >R DUP 1+ C@ Ee(?
        IF      1+ ROT DROP 1 -ROT 0 >R   ( 1 to mantissa )
        ELSE    FCONVERT DUP C@ 46 =          ( Check for "." )
                IF      DUP >R FCONVERT DUP R> - 1-
                ELSE    0  THEN    >R
        THEN
        DUP C@ Ee(?
        IF      -? >R >R 0 0 R> FCONVERT NIP
        ELSE    0 SWAP 0 >R THEN
        C@ DUP 0= SWAP DUP 32 = SWAP 41 = OR OR 0=
        IF      DROP 2DROP R>DROP R>DROP R>DROP F0.0 FALSE
        ELSE    R> IF   NEGATE  THEN  R> - BASE @ 0 FLOAT F**N
                FLOAT F* R>  IF  FNEGATE  THEN
                ( TRUE ) 1      \ return 1 to be compatible with SFLOAT
        THEN    ;

: $F#   ( a1 -- F: -- r )       \ convert string a1 to floating point #
        (FNUMBER?) 0= ABORT"  Bad Floating Point Input" ;

: F#    ( F: -- r )             \ convert string from input stream to
                                \ a floating point nubmer
        $20 WORD $F# ;          EXECUTES> F#

FORTH ALSO HOST COMPILER !> ?STACK_CHECK PREVIOUS
                                \ restore ?STACK_CHECK from stack
FORTH TARGET >TARGET

}
                                                07:07 01Nov88RS)

$F#     This function converts a counted string into a floating point
        number.

F#      This is the function used to get a floating point number
        from the input stream.  Usage examples follow:

                F# -2.34
                F# 34.5e6
                F# -.1E-2
                F# 2.34(5)

