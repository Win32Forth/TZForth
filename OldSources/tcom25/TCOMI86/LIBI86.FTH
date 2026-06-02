\\ KERNEL80.SEQ          Z80 Kernel for TCOM

{

>LIBRARY

TARGET DEFINITIONS

( &*& ) \ SP0
( &*& ) \ RP0
( &*& ) \ 'TIB
( &*& ) \ CONTEXT



CODE STOP                       \ a marker to use while debugging
        JMP >NEXT       END-CODE

( &*& ) CODE UNNEST
        XCHG RP, SP     \  4 cycles
        POP IP          \ 11 cycles
        XCHG RP, SP     \  4 cycles
        JMP >NEXT       END-CODE

CODE EXIT     ( -- )
        XCHG RP, SP     \  4 cycles
        POP IP          \ 11 cycles
        XCHG RP, SP     \  4 cycles
        JMP >NEXT       END-CODE

( &*& ) CODE (LIT)   ( -- n )
        MOV AX, 0 [IP]
        INC IP
        INC IP
        JMP 1PUSH       END-CODE

CODE (LIT+2)   ( -- n )
        MOV AX, 0 [IP]
        ADD AX, # 2
        INC IP
        INC IP
        JMP 1PUSH       END-CODE

FORTH   >FORTH

( &*& ) : %UNNEST       ( -- )
                F['] UNNEST RES_COMP_CALL ;

' %UNNEST IS DO_RET                     \ link into optimizer file

( &*& ) : %(LIT)        ( n1 -- )
                F['] (LIT) RES_COMP_CALL
                codewordtype here-t index!
                ,-T ;

' %(LIT) IS COMP_SINGLE                 \ link into number compiler

\ ***************************************************************************
\ Forward store and fetch words
\ define words that pickup the following word and use it like a variable

: for_does>86   ( a1 -- )
                [forth]
                ' ?lib
                if      compile res_comp_cll f['] (lit+2) x,
                        compile res_comp_cll x,
                        @ x,
                else    f['] (lit+2) res_comp_call
                                      compile_call
                                           perform
                then    ;

' for_does>86 is for_does>

\ ***************************************************************************

TARGET  >LIBRARY


\ Run Time Code for Control Structures                04MAR83HHL

( &*& ) CODE BRANCH   ( -- )
        MOV IP, 0 [IP]
        JMP >NEXT   END-CODE

( &*& ) CODE ?BRANCH  ( f -- )
        POP CX
        JCXZ 0 $
        INC IP
        INC IP
        JMP >NEXT
   0 $: MOV IP, 0 [IP]
        JMP >NEXT   END-CODE

FORTH   >FORTH

( &*& ) : %IF           ( -- )
                F['] ?BRANCH RES_COMP_CALL +BR# $ OFFSET_16, ;

( &*& ) : %ELSE         ( -- )
                F['] BRANCH RES_COMP_CALL +BR# $ OFFSET_16,
                BR#SWAP -BR# DUP $: 01LAB ;

( &*& ) : %THEN         ( -- )
                -BR# DUP $: 01LAB ;

: %BEGIN        ( -- )
                +BR# $: ;

: %WHILE        ( -- )
                F['] ?BRANCH RES_COMP_CALL +BR# $ OFFSET_16, ;

: %REPEAT       ( -- )
                F['] BRANCH RES_COMP_CALL
                BR#SWAP -BR# DUP $ OFFSET_16, 01LAB
                        -BR# DUP $:           01LAB ;

: %AGAIN        ( -- )
                F['] BRANCH RES_COMP_CALL
                -BR# DUP $ OFFSET_16, 01LAB ;

: %UNTIL        ( -- )
                F['] ?BRANCH RES_COMP_CALL
                -BR# DUP $ OFFSET_16, 01LAB ;

( &*& ) : IF            ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %IF
                ELSE    %IF
                THEN    ; IMMEDIATE

( &*& ) : ELSE          ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %ELSE
                ELSE    %ELSE
                THEN    ; IMMEDIATE

( &*& ) : THEN          ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %THEN
                ELSE    %THEN
                THEN    ; IMMEDIATE

: BEGIN         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %BEGIN
                ELSE    %BEGIN
                THEN    ; IMMEDIATE

: WHILE         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %WHILE
                ELSE    %WHILE
                THEN    ; IMMEDIATE

: REPEAT        ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %REPEAT
                ELSE    %REPEAT
                THEN    ; IMMEDIATE

: AGAIN         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %AGAIN
                ELSE    %AGAIN
                THEN    ; IMMEDIATE

: UNTIL         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %UNTIL
                ELSE    %UNTIL
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

\ Run Time Code for Control Structures                07JUL83HHL

( &*& ) CODE (LOOP)     ( -- )  \ Primitive form of LOOP
                INC 0 [RP] WORD
           OV<> IF
                        MOV ES: IP, 0 [IP]
                        JMP >NEXT
                THEN
                ADD RP, # 6     ADD IP, # 2
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE (+LOOP)    ( n -- )  \ Primitive form of +LOOP
                AX POP          ADD 0 [RP], AX
           OV<> IF
                        MOV ES: IP, 0 [IP]
                        JMP >NEXT
                THEN
                ADD RP, # 6     ADD IP, # 2
                JMP >NEXT
                END-CODE                NO-INTERPRET

FORTH   >FORTH

( &*& ) : %LOOP         ( -- )
                F['] (LOOP) RES_COMP_CALL
                -BR# DUP $ OFFSET_16, 01LAB
                -BR# DUP $:           01LAB ;

( &*& ) : %+LOOP        ( -- )
                F['] (+LOOP) RES_COMP_CALL
                -BR# DUP $ OFFSET_16, 01LAB
                -BR# DUP $:           01LAB ;

( &*& ) : LOOP          ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %LOOP
                ELSE    %LOOP
                THEN    ; IMMEDIATE

( &*& ) : +LOOP         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %+LOOP
                ELSE    %+LOOP
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

\ Execution Control                                   07SEP83HHL

( &*& ) CODE EXECUTE    ( cfa -- )
                POP BX
                JMP >NEXT1
                END-CODE                NO-INTERPRET

( &*& ) CODE PERFORM    ( addr-of-cfa -- )
                POP BX
                MOV BX, 0 [BX]
                JMP >NEXT1
                END-CODE                NO-INTERPRET

FORTH   >FORTH

( &*& ) : %PERFORM      ( n1 -- )
                F['] PERFORM RES_COMP_CALL ;

' %PERFORM IS COMP_PERFORM              \ link into number compiler

TARGET  >LIBRARY

CODE NOOP   JMP >NEXT  END-CODE             NO-INTERPRET

\ Execution Control                                   01Oct83map

( &*& ) CODE I          ( -- n )
\  get the current index of the innermost loop
                MOV AX, 0 [RP]
                ADD AX, 2 [RP]
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE J          ( -- n )
\  Get the index of the second most inner loop.
                MOV AX, 6 [RP]
                ADD AX, 8 [RP]
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE K          ( -- n )
\  Get the index of the third most inner loop.
                MOV AX, 12 [RP]
                ADD AX, 14 [RP]
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE (LEAVE)    ( -- )
\ run time version of LEAVE to jump past the end of a DO-LOOP
                MOV IP, 4 [RP]
                ADD RP, # 6
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE (?LEAVE)   ( f -- )
\ If the flag is non-zero, jump out of the DO-LOOP.
                POP AX
                OR AX, AX
             0= IF      JMP >NEXT
                THEN
                MOV IP, 4 [RP]
                ADD RP, # 6
                JMP >NEXT
                END-CODE                NO-INTERPRET

FORTH   >FORTH

( &*& ) : %LEAVE        ( -- )
                F['] (LEAVE) RES_COMP_CALL ;

( &*& ) : %?LEAVE       ( -- )
                F['] (?LEAVE) RES_COMP_CALL ;

( &*& ) : LEAVE         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %LEAVE
                ELSE    %LEAVE
                THEN    ; IMMEDIATE

( &*& ) : ?LEAVE        ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %?LEAVE
                ELSE    %?LEAVE
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

\ 16 and 8 bit Memory Operations

( &*& ) CODE @          ( addr -- n )
                POP BX
                PUSH 0 [BX]
                JMP >NEXT
                END-CODE                EXECUTES> @-T

( &*& ) CODE !          ( n addr -- )
                POP BX
                POP 0 [BX]
                JMP >NEXT
                END-CODE                EXECUTES> !-T

FORTH   >FORTH

( &*& ) : %@            ( n1 -- )
                F['] @ RES_COMP_CALL ;

' %@ IS COMP_FETCH              \ link into number compiler

( &*& ) : %!            ( n1 -- )
                F['] ! RES_COMP_CALL ;

' %! IS COMP_STORE              \ link into number compiler

TARGET  >LIBRARY

CODE C@         ( addr -- char )
                POP BX
                SUB AX, AX
                MOV AL, 0 [BX]
                JMP 1PUSH
                END-CODE                EXECUTES> C@-T

( &*& ) CODE C!     ( char addr -- )
                POP BX
                POP AX
                MOV 0 [BX], AL
                JMP >NEXT
                END-CODE                EXECUTES> C!-T

\ Block Move Memory Operations

CODE CMOVE      (  from to count -- )
                MOV BX, IP      MOV AX, DS
                POP CX          POP DI          POP IP
                MOV DX, ES      MOV ES, AX
                REPNZ MOVSB
                MOV IP, BX      MOV ES, DX
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE CMOVE>     ( from to count -- )
                MOV BX, IP      MOV AX, DS
                POP CX          DEC CX
                POP DI          POP IP
                ADD DI, CX      ADD IP, CX      INC CX
                MOV DX, ES      MOV ES, AX
                STD
                REPNZ           MOVSB
                CLD
                MOV IP, BX
                MOV ES, DX
                JMP >NEXT
                END-CODE                NO-INTERPRET

\ 16 bit Stack Operations

( &*& ) CODE SP@        ( -- n )
                MOV AX, SP
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE SP!        ( n -- )
                POP SP
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE RP@        ( -- addr )
                PUSH RP
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE RP!        ( n -- )
                POP RP
                JMP >NEXT
                END-CODE                NO-INTERPRET

\ 16 bit Stack Operations

( &*& ) CODE DROP       ( n1 -- )
                ADD SP, # 2
                JMP >NEXT
                END-CODE                EXECUTES> DROP

( &*& ) CODE DUP        ( n1 -- n1 n1 )
                MOV DI, SP      \ 2
                PUSH 0 [DI]     \ 21 = 23
                JMP >NEXT
                END-CODE                EXECUTES> DUP

( &*& ) CODE SWAP       ( n1 n2 -- n2 n1 )
                POP DX
                POP AX
                JMP 2PUSH
                END-CODE                EXECUTES> SWAP

( &*& ) CODE OVER       ( n1 n2 -- n1 n2 n1 )
                MOV DI, SP
                PUSH 2 [DI]
                JMP >NEXT
                END-CODE                EXECUTES> OVER

( &*& ) CODE TUCK       ( n1 n2 -- n2 n1 n2 )
                POP AX
                POP DX
                PUSH AX
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE NIP        ( n1 n2 -- n2 )
                POP AX
                ADD SP, # 2
                JMP 1PUSH
                END-CODE                EXECUTES> NIP

( &*& ) CODE ROT        ( n1 n2 n3 --- n2 n3 n1 )
                POP DX
                POP BX
                POP AX
                PUSH BX
                JMP 2PUSH
                END-CODE                EXECUTES> ROT

( &*& ) CODE -ROT       ( n1 n2 n3 --- n3 n1 n2 )
                POP BX
                POP AX
                POP DX
                PUSH BX
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE FLIP       ( n -- n )
                POP AX
                XCHG AL, AH
                JMP 1PUSH
                END-CODE                EXECUTES> FLIP

( &*& ) : ?DUP          ( n -- [n] n )
                DUP IF DUP THEN ;       EXECUTES> ?DUP

( &*& ) CODE R>         ( -- n )
                PUSH 0 [RP]
                ADD RP, # 2
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE >R         ( n -- )
                SUB RP, # 2     \  4
                POP 0 [RP]      \ 22 = 26 cycles
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE R@         ( -- n )
                PUSH 0 [RP]
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE PICK       ( nm ... n2 n1 k -- nm ... n2 n1 nk )
                POP DI
                SHL DI, # 1
                ADD DI, SP
                PUSH 0 [DI]
                JMP >NEXT
                END-CODE                NO-INTERPRET

\ 16 bit Logical Operations

( &*& ) CODE AND        ( n1 n2 -- n3 )
                POP BX
                POP AX
                AND AX, BX
                JMP 1PUSH
                END-CODE                EXECUTES> AND

( &*& ) CODE OR         ( n1 n2 -- n3 )
                POP BX
                POP AX
                OR AX, BX
                JMP 1PUSH
                END-CODE                EXECUTES> OR

CODE XOR        ( n1 n2 -- n3 )
                POP BX
                POP AX
                XOR AX, BX
                JMP 1PUSH
                END-CODE                EXECUTES> XOR

CODE NOT        ( n -- n' )
                POP AX
                NOT AX
                JMP 1PUSH
                END-CODE                EXECUTES> NOT

-1 CONSTANT TRUE
 0 CONSTANT FALSE

CODE CSET       ( b addr -- )
                POP BX
                POP AX
                OR 0 [BX], AL
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE CRESET     ( b addr -- )
                POP BX
                POP AX
                NOT AX
                AND 0 [BX], AL
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE CTOGGLE    ( b addr -- )
                POP BX
                POP AX
                XOR 0 [BX], AL
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE ON         ( addr -- )
                POP BX
                MOV 0 [BX], # $FFFF WORD
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE OFF        ( addr -- )
                POP BX
                MOV 0 [BX], # $0000 WORD
                JMP >NEXT
                END-CODE                NO-INTERPRET

FORTH   >FORTH

: %ON           ( n1 -- )
                F['] ON RES_COMP_CALL ;

' %ON IS COMP_ON                \ link into number compiler

( &*& ) : %OFF          ( n1 -- )
                F['] OFF RES_COMP_CALL ;

' %OFF IS COMP_OFF                \ link into number compiler

TARGET  >LIBRARY

\ 16 bit Arithmetic Operations                        13Apr84map

( &*& ) CODE +          ( n1 n2 -- sum )  \ Add top two elements
                POP BX
                POP AX
                ADD AX, BX
                JMP 1PUSH
                END-CODE                EXECUTES> +

( &*& ) CODE NEGATE     ( n -- n' )  \ Arithmetically negate top stack element.
                POP AX
                NEG AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE -          ( n1 n2 -- n1-n2 )  \ Subtract top stack element from second
                POP BX
                POP AX
                SUB AX, BX
                JMP 1PUSH
                END-CODE                EXECUTES> -

( &*& ) CODE ABS        ( n1 -- n2 )   \  Return absolute value of top stack item
                POP AX
                CWD
                XOR AX, DX
                SUB AX, DX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE +!         ( n addr -- )
                POP BX
                POP AX
                ADD 0 [BX], AX
                JMP >NEXT
                END-CODE                NO-INTERPRET

FORTH   >FORTH

: %+!           ( n1 -- )
                F['] +! RES_COMP_CALL ;

' %+! IS COMP_PSTORE            \ link into number compiler

TARGET  >LIBRARY

\ 16 bit Arithmetic Operations

( &*& ) CODE 2*         ( n -- 2*n )  \ Logical left shift n by 1 position.
                POP AX
                SHL AX, # 1
                JMP 1PUSH
                END-CODE                EXECUTES> 2*

CODE 2/         ( n -- n/2 )  \ Arithmetic right shift of n by 1 position
                POP AX
                SAR AX, # 1
                JMP 1PUSH
                END-CODE                EXECUTES> 2/

( &*& ) CODE U2/        ( u -- u/2 )  \ Logical right shift of n by 1 position
                POP AX
                SHR AX, # 1
                JMP 1PUSH
                END-CODE                EXECUTES> U2/

CODE 8*         ( n -- 8*n )  \ Logical shift left by 3 positions.
                POP AX
                SHL AX, # 1
                SHL AX, # 1
                SHL AX, # 1
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE 1+         ( n1 --- n2 )  \  Add 1 to top stack element
                POP AX
                INC AX
                JMP 1PUSH
                END-CODE                EXECUTES> 1+

( &*& ) CODE 2+         ( n1 --- n2 )  \  Add 2 to top stack element
                POP AX
                ADD AX, # 2
                JMP 1PUSH
                END-CODE                EXECUTES> 2+

( &*& ) CODE 1-         ( n1 --- n2 )  \  Subtract 1 from top stack element
                POP AX
                DEC AX
                JMP 1PUSH
                END-CODE                EXECUTES> 1-

CODE 2-         ( n1 --- n2 )  \  Subtract 2 from top stack element
                POP AX
                SUB AX, # 2
                JMP 1PUSH
                END-CODE                EXECUTES> 2-

: ROLL          ( n1 n2 .. nk n -- wierd )
                >R R@ PICK   SP@ DUP 2+   R> 1+ 2* CMOVE>  DROP  ;
                                        NO-INTERPRET

\ 16 bit Arithmetic Operations   Unsigned Multiply    26Sep83map

CODE UM*        ( n1 n2 -- d )
\  Form a 32 bit product from two 16 bit unsigned numbers
                POP AX          POP BX
                MUL BX
                XCHG DX, AX
                JMP 2PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE *          ( n1 n2 -- n3 )
\  Form a 16 bit product from two 16 bit numbers
                POP AX          POP BX
                MUL BX
                JMP 1PUSH
                END-CODE                EXECUTES> *

: U*D           ( n1 n2 -- d )
\  Form a 32 bit product from two 16 bit unsigned numbers
                UM*   ;                 NO-INTERPRET

( &*& ) CODE UM/MOD     ( ud un -- URemainder UQuotient )
\ Unsigned double number divided by unsigned single results in unsigned
\ remainder and quotient, with quotient on top.
                POP BX          POP DX          POP AX
                CMP DX, BX
            U>=  ( divide by zero? )
            IF
                MOV AX, # -1    MOV DX, AX
                JMP 2PUSH
            THEN
                DIV BX
                JMP 2PUSH
                END-CODE                NO-INTERPRET

\ 16 bit Comparison Operations

( &*& ) CODE 0=         ( n -- f )  \  Return TRUE if n is zero.  Otherwise FALSE.
                POP AX
                SUB AX, # 1
                SBB AX, AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE 0<         ( n -- f )
\  If n is negative, return TRUE.  Otherwise FALSE.
                POP AX
                CWD
                PUSH DX
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE 0>         ( n -- f )
\  If n is greater than 0, return TRUE.  Otherwise FALSE.
                POP AX          NEG AX
           OV<> IF      CWD
                        PUSH DX
                        JMP >NEXT
                THEN
                SHL AX, # 1
                JMP 1PUSH
                END-CODE                NO-INTERPRET

CODE 0<>        ( n -- f )
\  If n is not equal to 0, return TRUE.  Otherwise FALSE.
                POP AX
                NEG AX
                SBB AX, AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE =          ( n1 n2 -- f )
\  If n1 is equal to n2, return TRUE.  Otherwise FALSE.
                POP AX
                POP CX
                SUB AX, CX
                SUB AX, # 1
                SBB AX, AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

CODE <>         ( n1 n2 -- f )
\  If n1 is not equal to n2, return TRUE.  Otherwise FALSE.
                POP AX
                POP CX
                SUB AX, CX
                NEG AX
                SBB AX, AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

: ?NEGATE       ( n1 n2 -- n3 )
                0<
                IF      NEGATE
                THEN    ;               NO-INTERPRET

\ 16 bit Comparison Operations                        13Apr84map

( &*& ) CODE   U<       ( n1 n2 -- f )
\  If unsigned n1 is less than unsigned n2, return TRUE, otherwise FALSE.
                POP CX          POP AX
                SUB AX, CX
                SBB AX, AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

CODE   U>       ( n1 n2 -- f )
\  If unsigned n1 is greater than unsigned n2, return TRUE, otherwise FALSE.
                POP AX          POP CX
                SUB AX, CX
                SBB AX, AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE <          ( n1 n2 -- f )
\  If signed n1 is less than signed n2, return TRUE, otherwise return FALSE.
                POP AX          POP BX
                CMP BX, AX
             >= IF
                        SUB AX, AX
                        JMP 1PUSH
                THEN
                MOV AX, # $FFFF
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE >          ( n1 n2 -- f )
\  If signed n1 is greater than signed n2, return TRUE, otherwise FALSE.
                POP AX          POP BX
                CMP BX, AX
             <= IF
                        SUB AX, AX
                        JMP 1PUSH
                THEN
                MOV AX, # $FFFF
                JMP 1PUSH
                END-CODE                NO-INTERPRET

CODE UMIN       ( n1 n2 -- n3 )
\ Return smaller of n1 or n2, treated as unsigned numbers.
                POP AX          POP BX
                CMP BX, AX
            U<= IF
                        PUSH BX
                        JMP >NEXT
                THEN
                JMP 1PUSH
                END-CODE                NO-INTERPRET

CODE MIN        ( n1 n2 -- n3 )
\ Return smaller of n1 or n2, treated as signed numbers.
                POP AX          POP BX
                CMP BX, AX
             <= IF
                        PUSH BX
                        JMP >NEXT
                THEN
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE MAX        ( n1 n2 -- n3 )
\ Return larger of n1 or n2, treated as signed numbers.
                POP AX          POP BX
                CMP BX, AX
             <= IF
                        JMP 1PUSH
                THEN
                PUSH BX
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE 0MAX       ( n1 -- n3 )
\ Return larger of n1 or ZERO, treated as signed numbers.
                POP AX
                SUB BX, BX
                CMP BX, AX
             <= IF
                        JMP 1PUSH
                THEN
                PUSH BX
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE UMAX       ( n1 n2 -- n3 )
\ Return larger of n1 or n2, treated as unsigned numbers.
                POP AX          POP BX
                CMP BX, AX
            U<= IF
                        JMP 1PUSH
                THEN
                PUSH BX
                JMP >NEXT
                END-CODE                NO-INTERPRET

: BETWEEN       ( n1 min max -- f )
                >R  OVER >  SWAP R> >  OR NOT  ;     NO-INTERPRET

: WITHIN        ( n1 min max -- f )
                1- BETWEEN  ;           NO-INTERPRET

\ 32 bit Memory Operations

CODE 2@         ( addr -- d )  \  Fetch a 32 bit value from addr
                POP BX
                PUSH 2 [BX]
                PUSH 0 [BX]
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE 2!         ( d addr -- )  \ Store a 32 bit value into addr
                POP BX
                POP 0 [BX]
                POP 2 [BX]
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE 2DROP      ( d -- )  \ Drop two 16 bit values from stack
                ADD SP, # 4
                JMP >NEXT
                END-CODE                EXECUTES> 2DROP

CODE 3DROP      ( n1 n2 n3 -- )  \ Drop 3 items from the stack.
                ADD SP, # 6
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE 2DUP       ( d -- d d )  \  Duplicate two top items on stack.
                MOV DI, SP
                PUSH 2 [DI]
                PUSH 0 [DI]
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE 3DUP       ( n1 n2 n3 -- n1 n2 n3 n1 n2 n3 )
\ Duplicate top 3 items on stack.
                MOV DI, SP
                PUSH 4 [DI]
                PUSH 2 [DI]
                PUSH 0 [DI]
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE 2SWAP      ( d1 d2 -- d2 d1 )
\ Exchange top two pairs of numbers on stack.
                POP CX          POP BX
                POP AX          POP DX
                PUSH BX         PUSH CX
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE 2OVER      ( d2 d2 -- d1 d2 d1 )
\ Copy second pair of numbers over top pair of numbers on stack.
                MOV DI, SP      \  2
                PUSH 6 [DI]     \ 24
                PUSH 4 [DI]     \ 24 = 50
                JMP >NEXT
                END-CODE                NO-INTERPRET


\ Run Time Code for Control Structures                02MAR83HHL

( &*& ) CODE (DO)       ( l i -- )  \ Primitive form of DO
                POP DX          POP BX
                XCHG RP, SP             \ 4
                LODSW                   \ 12
                PUSH AX                 \ 11
                ADD BX, # $8000          \ 4
                PUSH BX                 \ 11
                SUB DX, BX              \ 3
                PUSH DX                 \ 11
                XCHG RP, SP             \ 4     = 62
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) CODE (?DO)      ( l i -- )  \ Primitive form of ?DO
                POP DX          POP BX
                CMP BX, DX
             0= IF
                        MOV ES: IP, 0 [IP]
                        JMP >NEXT
                THEN
                XCHG RP, SP             \ 4
                LODSW                   \ 12
                PUSH AX                 \ 11
                ADD BX, # $8000          \ 4
                PUSH BX                 \ 11
                SUB DX, BX              \ 3
                PUSH DX                 \ 11
                XCHG RP, SP             \ 4     = 62
                JMP >NEXT
                END-CODE

FORTH   >FORTH

( &*& ) : %(DO)         ( -- )
                F['] (DO) RES_COMP_CALL +BR# $ OFFSET_16,
                +BR# $: ;

( &*& ) : %(?DO)        ( -- )
                F['] (?DO) RES_COMP_CALL +BR# $ OFFSET_16,
                +BR# $: ;

( &*& ) : DO            ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %(DO)
                ELSE    %(DO)
                THEN    ; IMMEDIATE

( &*& ) : ?DO           ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %(?DO)
                ELSE    %(?DO)
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

: 4DUP          ( a b c d -- a b c d a b c d )
                2OVER 2OVER   ;         NO-INTERPRET

: 2ROT          ( a b c d e f --- c d e f a b )
                5 ROLL 5 ROLL ;         NO-INTERPRET

\ 32 bit Arithmetic Operations

CODE D+         ( d1 d2 -- dsum )  \  Add top two double numbers on stack
                POP AX          POP DX
                POP BX          POP CX
                ADD DX, CX      ADC AX, BX
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE DNEGATE    ( d# -- d#' )  \  Negate double number on top of stack.
                POP AX
                POP DX
                NEG AX
                NEG DX
                SBB AX, # 0
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE   S>D      ( n -- d )
\  Convert single signed number to signed double
                POP AX
                CWD
                XCHG DX, AX
                JMP 2PUSH
                END-CODE                NO-INTERPRET

( &*& ) CODE DABS       ( d1 -- d2 )
\  Replace the top double number with its absolute value.
                POP AX
                OR AX, AX
            0>= IF
                        JMP 1PUSH
                THEN
                POP DX
                NEG AX
                NEG DX
                SBB AX, # 0
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE D2*        ( d -- d*2 )  \  32 bit left shift
                POP AX          POP DX
                SHL DX, # 1     RCL AX, # 1
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE D2/        ( d -- d/2 )  \ 32 bit arithmetic right shift
                POP AX          POP DX
                SAR AX, # 1     RCR DX, # 1
                JMP 2PUSH
                END-CODE                NO-INTERPRET

CODE UD16/      ( d -- d/16 )   \ 32 bit UNSIGNED right shift 4 bits
                POP AX          POP DX
                SHR AX, # 1     RCR DX, # 1
                SHR AX, # 1     RCR DX, # 1
                SHR AX, # 1     RCR DX, # 1
                SHR AX, # 1     RCR DX, # 1
                JMP 2PUSH
                END-CODE                NO-INTERPRET

: D-    ( d1 d2 -- d3 )  DNEGATE D+ ;   NO-INTERPRET

: ?DNEGATE  ( d1 n -- d2 )     0< IF   DNEGATE   THEN   ;
                                        NO-INTERPRET
\ 32 bit Comparison Operations                        05Oct83map

: D0=   ( d -- f )        OR 0= ;       NO-INTERPRET

: D=    ( d1 d2 -- f )    D-  D0=  ;    NO-INTERPRET

: DU<   ( ud1 ud2 -- f )   ROT SWAP 2DUP U<
   IF   2DROP 2DROP $FFFF
   ELSE  <> IF   2DROP $0000  ELSE  U<  THEN
   THEN  ;                              NO-INTERPRET

: D<    ( d1 d2 -- f )   2 PICK OVER =
   IF   DU<   ELSE  NIP ROT DROP <  THEN  ;
                                        NO-INTERPRET
: D>    ( d1 d2 -- f )    2SWAP D<   ;  NO-INTERPRET

: DMIN  ( d1 d2 -- d3 )   4DUP D> IF   2SWAP   THEN   2DROP ;
                                        NO-INTERPRET
: DMAX  ( d1 d2 -- d3 )   4DUP D< IF   2SWAP   THEN   2DROP ;
                                        NO-INTERPRET
\ Mixed Mode Arithmetic                               01Oct83map

: *D   ( n1 n2 -- d# )
   2DUP  XOR  >R  ABS  SWAP  ABS  UM*  R>  ?DNEGATE  ;
                                        NO-INTERPRET
: M/MOD   ( d# n1 -- rem quot )
   ?DUP
   IF  DUP >R  2DUP XOR >R  >R DABS R@ ABS  UM/MOD
     SWAP R> ?NEGATE
     SWAP R> 0< IF  NEGATE OVER IF  1- R@ ROT - SWAP  THEN THEN
     R> DROP
   THEN  ;                              NO-INTERPRET

( &*& ) : MU/MOD  ( d# n1 -- rem d#quot )
   >R  0  R@  UM/MOD  R>  SWAP  >R  UM/MOD  R>   ;
                                        NO-INTERPRET
\ 16 bit multiply and divide                          27Sep83map

: /MOD  ( n1 n2 -- rem quot )   >R  S>D  R>  M/MOD  ;
                                        NO-INTERPRET
: /     ( n1 n2 -- quot )   /MOD  NIP ; EXECUTES> /

: MOD   ( n1 n2 -- rem )    /MOD DROP ; EXECUTES> MOD

: */MOD  ( n1 n2 n3 -- rem quot )
   >R  *D  R>  M/MOD  ;                 NO-INTERPRET

: */    ( n1 n2 n3 -- n1*n2/n3 )     */MOD  NIP  ;
                                        NO-INTERPRET

\ Since the 8086 has a seperate IO path, we define a Forth
\ interface to it.  Use P@ and P! to read or write directly to
\ the 8086 IO ports.

CODE PC@        ( port# -- n )
\ Read 8-bit port at "port#" and push value on stack.
                POP DX          IN AL, DX
                SUB AH, AH
                PUSH AX
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE P@         ( port# -- n )
\ Read 16-bit value at "port#" and push value on stack.
                POP DX
                IN AX, DX
                PUSH AX
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE PC!        ( n port# -- )
\ Write 8 bit value "n" to "port#".
                POP DX          POP AX
                OUT DX, AL
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE P!         ( n port# -- )
\ Write 16 bit value "n" to "port#".
                POP DX          POP AX
                OUT DX, AX
                JMP >NEXT
                END-CODE                NO-INTERPRET

\ System VARIABLEs                                    22Jan87TJZ

VARIABLE RP0            ' RP0 IS RPZERO
VARIABLE SP0            ' SP0 IS SPZERO
VARIABLE 'TIB           ' 'TIB IS TICKTIB
VARIABLE DP             ' DP IS DPADDR
VARIABLE CONTEXT        ' CONTEXT IS CONADDR
VARIABLE CURRENT        ' CURRENT IS CURADDR
VARIABLE SSEG           ' SSEG IS SSEGADDR

( &*& ) VARIABLE #OUT           \ NUMBER OF CHARACTERS EMITTED
( &*& ) VARIABLE #LINE          \ THE NUMBER OF LINES SENT SO FAR
( &*& ) VARIABLE BASE           \ FOR NUMERIC INPUT AND OUTPUT
( &*& ) VARIABLE HLD            \ POINTS TO LAST CHARACTER HELD IN PAD
VARIABLE DPL            \ NUMERIC INPUT PUNCTUATION
VARIABLE >IN            \ OFFSET INTO INPUT STREAM
( &*& ) VARIABLE SPAN           \ NUMBER OF CHARACTERS EXPECTED
VARIABLE #TIB           \ NUMBER OF CHARACTERS TO INTERPRET
VARIABLE END?           \ TRUE IF INPUT STREAM EXHAUSTED
VARIABLE CAPS

\ Devices                     Strings                 13Apr84map

( &*& )    32 CONSTANT BL
( &*& )     8 CONSTANT BS
( &*& )     7 CONSTANT BELL

CODE FILL         (  start-addr count char -- )
\ Fill each byte of memory in the specified address range with "char".
                CLD             MOV BX, DS
                POP AX          POP CX          POP DI
                PUSH ES         MOV ES, BX
                REPNZ           STOSB           POP ES
                JMP >NEXT
                END-CODE                NO-INTERPRET

: ERASE      ( addr len -- )   0 FILL   ;
                                        NO-INTERPRET

: BLANK      ( addr len -- )   BL FILL   ;
                                        NO-INTERPRET

( &*& ) CODE COUNT   ( addr -- addr+1 len )
\ Convert from the address of a counted string to an address and count.
                POP BX          SUB AX, AX      MOV AL, 0 [BX]
                INC BX          PUSH BX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

CODE LENGTH  ( addr -- addr+2 len )
\ Similiar to COUNT , except that the count is in a word, not a byte.
                POP BX          MOV AX, 0 [BX]
                ADD BX, # 2
                PUSH BX
                JMP 1PUSH
                END-CODE                NO-INTERPRET

\ Devices                     Strings                 13Apr84map

CODE UPC        ( char -- char' )
\ Convert a character to upper case.
                POP AX
                AND AX, # 127
                CMP AX, # 'a'
                JL 0 $
                CMP AX, # 'z'
                JG 0 $
                AND AX, # $5F
        0 $:    JMP 1PUSH       END-CODE        NO-INTERPRET

CODE UPPER      ( addr len -- )
\ Convert a string to upper case.
                POP CX                  \ get length
                POP DI                  \ and starting address
                PUSH SI                 \ save IP
                MOV DX, ES              \ and LIST POINTER
                MOV BX, DS
                MOV ES, BX              \ set ES to DS
                MOV SI, DI              \ set SI to DI
                MOV BX, # ATBL          \ loadup BX with table
                CLD                     \ clear direction flag
          CX<>0 IF
                        1 $:    LODSB           \ get a char and traslate it
                                AND AX, # 127
                                CMP AX, # 'a'
                                JL 0 $
                                CMP AX, # 'z'
                                JG 0 $
                                AND AX, # $5F
                                STOSB
                        0 $:    LOOP  1 $       \ until all chars are done
                THEN
                MOV ES, DX              \ restore ES=LIST
                POP SI                  \     and SI=IP
                JMP >NEXT
                END-CODE                NO-INTERPRET

( &*& ) : HERE          ( -- addr )
                DP @   ;                EXECUTES> HERE-T

( &*& ) : PAD           ( -- addr )
                HERE 80 +   ;           NO-INTERPRET

: -TRAILING     ( addr len -- addr len' )
                DUP 0
               ?DO      2DUP + 1- C@   BL <> ?LEAVE   1-
                LOOP    ;               NO-INTERPRET

\ Devices                     Strings                 26Sep83map
CODE COMP       ( addr1 addr2 len -- -1 | 0 | 1 )
\ Compare two strings.  If equal, return 0.  If str1 < str2, return -1.
\ If str1 > str2, return 1 .
                MOV DX, SI      POP CX
                POP DI          POP SI
          CX<>0 IF      PUSH ES
                        MOV ES, SSEG
                        REPZ CMPSB
                    0<> IF
                             0< IF      MOV CX, # -1
                                ELSE    MOV CX, # 1
                                THEN
                        THEN
                        POP ES
                THEN
                MOV SI, DX
                PUSH CX
                JMP >NEXT
                END-CODE

CODE CAPS-COMP  ( addr1 addr2 len -- -1 | 0 | 1 )
\ Perform a comparison of two strings, but ignore Case differences.
                MOV DX, SI      POP CX
                POP DI          POP SI
                PUSH ES         MOV ES, SSEG
                BEGIN
                    JCXZ  0 $
                    MOV     AH, 0 [SI]      INC SI
                    MOV ES: AL, 0 [DI]      INC DI
                    OR AX, # $02020         CMP AH, AL
                    JNE 1 $                 DEC CX
                AGAIN
        1 $: 0< IF
                   MOV CX, # -1
                ELSE
                   MOV CX, # 1
                THEN
        0 $:    MOV SI, DX
                POP ES
                PUSH CX
                JMP >NEXT
                END-CODE

: COMPARE       ( addr1 addr2 len -- -1 | 0 | 1 )
\ Compare two strings.  If CAPS is true, ignore case.
                CAPS @ IF   CAPS-COMP   ELSE   COMP   THEN   ;


\ Devices      Terminal IO via CP/M                 21Jan87TJZ

( &*& ) CODE BDOS       ( n fun -- m )
                POP AX          MOV AH, AL      POP DX
                INT $21         SUB AH, AH
                JMP 1PUSH
                END-CODE                NO-INTERPRET

( &*& ) : KEY?          ( -- f )
                255 6 BDOS ;            NO-INTERPRET

( &*& ) : KEY           ( -- char )
                BEGIN KEY? ?DUP UNTIL ; NO-INTERPRET

( &*& ) : EMIT          ( char -- )
                $7F AND 6 BDOS DROP 1 #OUT +! ; EXECUTES> EMIT

( &*& ) : CR            ( -- )
                13 EMIT   10 EMIT   #OUT OFF
                1 #LINE +! ;            EXECUTES> CR

( &*& ) : TYPE          ( addr len -- )
                0 ?DO  COUNT EMIT  LOOP   DROP   ;
                                        NO-INTERPRET
( &*& ) : SPACE         ( -- )
                BL EMIT   ;             EXECUTES> SPACE

( &*& ) : SPACES        ( n -- )
                0 MAX   0 ?DO   SPACE   LOOP   ;
                                        EXECUTES> SPACES
( &*& ) : BACKSPACES    ( n -- )
                0 ?DO BS EMIT -2 #OUT +! LOOP ;
                                        NO-INTERPRET
: BEEP          ( -- )
                BELL EMIT -1 #OUT +! ;  EXECUTES> BEEP

\ Devices   System Dependent Control Characters       19Jan87TJZ

( &*& ) : BS-IN         ( n c -- 0 | n-1 )
                DROP DUP IF   1-   BS   ELSE BELL THEN EMIT -2 #OUT +! ;
                                        NO-INTERPRET
( &*& ) : DEL-IN        ( n c -- 0 | n-1 )
                DROP DUP IF  1-  BS EMIT SPACE BS
                ELSE  BELL  THEN  EMIT -2 #OUT +! ;
                                        NO-INTERPRET
( &*& ) : BACK-UP       ( n c -- 0 )
                DROP   DUP BACKSPACES   DUP SPACES   BACKSPACES   0   ;
                                        NO-INTERPRET
( &*& ) : ESC-IN        ( c -- )
                DROP   2DUP  + @ EMIT  1+  ;
                                        NO-INTERPRET
\ Devices                     Terminal Input          24AUG84MJM

( &*& ) : CR-IN         ( m a n c -- m a m )
                DROP   SPAN !   OVER   BL EMIT   ;
                                        NO-INTERPRET
( &*& ) : CHAR          ( a n char -- a n+1 )
                3DUP EMIT + C!   1+   ;
                                        NO-INTERPRET
( &*& ) : EXEC:         ( n1 -- )
                2* R> + PERFORM ;       NO-INTERPRET

( &*& ) : DO_ACHAR      ( n1 -- )
        EXEC:
        CHAR    CHAR   CHAR   CHAR   CHAR   CHAR    CHAR   CHAR
        BS-IN   CHAR   CHAR   CHAR   CHAR   CR-IN   CHAR   CHAR
        CHAR    CHAR   CHAR   CHAR   CHAR   BACK-UP CHAR   CHAR
        BACK-UP CHAR   CHAR   ESC-IN CHAR   CHAR    CHAR   CHAR ;
                                        NO-INTERPRET

( &*& ) : EXPECT   ( adr len -- )
        DUP SPAN !   SWAP 0   ( len adr 0 )
        BEGIN   2 PICK OVER - ( len adr #so-far #left )
        WHILE   KEY DUP 127 AND BL <
                IF      DUP DO_ACHAR
                ELSE    DUP 127 = IF   DEL-IN   ELSE   CHAR   THEN
                THEN
        REPEAT    2DROP DROP   ;        NO-INTERPRET


: TIB           ( -- adr )
                'TIB @  ;               NO-INTERPRET

: QUERY         ( -- )
                TIB 80 EXPECT
                SPAN @ #TIB !
                >IN OFF  ;              NO-INTERPRET

: BOUNDS        ( adr len -- lim first )
                OVER + SWAP   ;         NO-INTERPRET

\ Interactive Layer           Number Input            04Apr84map

CODE DIGIT      ( char base -- n f )
\ If the character is equivalent to a digit in the specified base,
\ convert the character and return a  TRUE  flag, else leave char and  FALSE.
                POP DX
                POP AX
                PUSH AX
                SUB AL, # $30           \ ascii '0'
                JB 0 $
                        CMP AL, # 9
              > IF
                        CMP AL, # 17
                        JB 0 $
                        SUB AL, # 7
                THEN
                CMP AL, DL
                JAE 0 $
                        MOV DL, AL
                        POP AX
                        MOV AX, # $FFFF
                        JMP 2PUSH
        0 $:    SUB AX, AX
                JMP 1PUSH
                END-CODE                NO-INTERPRET


: DOUBLE?   ( -- f )      DPL @ 1+   0<> ;
                                        NO-INTERPRET
: CONVERT   ( +d1 adr1 -- +d2 adr2 )
   BEGIN  1+  DUP >R  C@  BASE @  DIGIT
   WHILE  SWAP  BASE @ UM*  DROP  ROT  BASE @ UM*  D+
      DOUBLE?  IF  1 DPL +!  THEN  R>
   REPEAT  DROP  R>  ;                  NO-INTERPRET

\ Interactive Layer           Number Output           03Apr84map

( &*& ) : HOLD   ( char -- )   -1 HLD +!   HLD @ C!   ;
                                        NO-INTERPRET
( &*& ) : <#     ( -- )     PAD  HLD  !  ;      NO-INTERPRET

( &*& ) : #>     ( d# -- addr len )    2DROP  HLD  @  PAD  OVER  -  ;
                                        NO-INTERPRET
( &*& ) : SIGN   ( n1 -- )  0< IF  '-'  HOLD  THEN  ;
                                        NO-INTERPRET
( &*& ) : #      ( -- )
  BASE @ MU/MOD ROT 9 OVER < IF  7 + THEN '0'  +  HOLD  ;
                                        NO-INTERPRET
( &*& ) : #S     ( -- )     BEGIN  #  2DUP  OR  0=  UNTIL  ;
                                        NO-INTERPRET

( &*& ) : HEX        ( -- )   16 BASE !  ;      EXECUTES> HEX

( &*& ) : DECIMAL    ( -- )   10 BASE !  ;      EXECUTES> DECIMAL

\ Interactive Layer           Number Output           24FEB83HHL

( &*& ) : (U.)  ( u -- a l )   0    <# #S #>   ;
                                        NO-INTERPRET
( &*& ) : U.    ( u -- )       (U.)   TYPE SPACE   ;
                                        NO-INTERPRET
( &*& ) : U.R   ( u l -- )     >R   (U.)   R> OVER - SPACES   TYPE   ;
                                        NO-INTERPRET

( &*& ) : (.)   ( n -- a l )   DUP ABS 0   <# #S   ROT SIGN   #>   ;
                                        NO-INTERPRET
( &*& ) : .     ( n -- )       (.)   TYPE SPACE   ;
                                        EXECUTES> .
( &*& ) : .R    ( n l -- )     >R   (.)   R> OVER - SPACES   TYPE   ;
                                        EXECUTES> .R

( &*& ) : H.    ( n -- )        BASE @ HEX SWAP U. BASE ! ;

( &*& ) : H.R   ( n l -- )      BASE @ HEX -ROT U.R BASE ! ;

( &*& ) : (UD.) ( ud -- a l )  <# #S #>   ;     NO-INTERPRET

: UD.   ( ud -- )      (UD.)   TYPE SPACE   ;
                                        NO-INTERPRET
( &*& ) : UD.R  ( ud l -- )    >R   (UD.)   R> OVER - SPACES   TYPE  ;
                                        NO-INTERPRET
( &*& ) : (D.)  ( d -- a l )   TUCK DABS   <# #S   ROT SIGN  #>   ;
                                        NO-INTERPRET
( &*& ) : D.    ( d -- )       (D.)   TYPE SPACE   ;
                                        NO-INTERPRET
: D.R   ( d l -- )     >R   (D.)   R> OVER - SPACES   TYPE   ;
                                        NO-INTERPRET
\ Interactive Layer           Parsing                 30Sep83map

CODE  SKIP      ( addr len char -- addr' len' )
\ Skip char through addr for len, returning addr' and len' of char+1.
                POP AX          POP CX
                JCXZ 0 $
                POP DI
                MOV DX, ES      MOV ES, SSEG
                REPZ            SCASB
                MOV ES, DX
            0<> IF      INC CX
                        DEC DI
                THEN
                PUSH DI
        0 $:    PUSH CX
                JMP >NEXT
                END-CODE                NO-INTERPRET

CODE  SCAN      ( addr len char -- addr' len' )
\ Scan for char through addr for len, returning addr' and len' of char.
                POP AX          POP CX
                JCXZ 0 $
                POP DI
                MOV DX, ES      MOV ES, SSEG
                REPNZ           SCASB
                MOV ES, DX
             0= IF      INC CX
                        DEC DI
                THEN
                PUSH DI
        0 $:    PUSH CX
                JMP >NEXT
                END-CODE                NO-INTERPRET

\ Interactive Layer           Parsing                 02Apr84map

: /STRING       ( addr len n -- addr' len' )
                OVER MIN   ROT OVER +   -ROT -   ;   NO-INTERPRET

: PLACE         ( str-addr len to -- )
                3DUP  1+ SWAP CMOVE  C! DROP  ;       NO-INTERPRET

: SOURCE        ( -- addr len )
                TIB #TIB @   ;          NO-INTERPRET

: PARSE-WORD   ( char -- addr len )
   >R  SOURCE TUCK  >IN @ /STRING  R@ SKIP  OVER SWAP R> SCAN
   >R OVER -  ROT R>  DUP 0<> + - >IN !  ;
                                        NO-INTERPRET
: PARSE   ( char -- addr len )
   >R   SOURCE >IN @ /STRING   OVER SWAP R> SCAN
   >R OVER -  DUP R>  0<> -  >IN +!  ;  NO-INTERPRET

\ Interactive Layer           Parsing                 07Mar84map

: WORD          ( char -- addr )
                PARSE-WORD  HERE PLACE
                HERE DUP COUNT + BL SWAP C!   ( Stick Blank at end )   ;
                                        NO-INTERPRET

\ Interactive Layer           Dictionary              04Apr84map

: BODY>      2-   ;                     NO-INTERPRET

: >BODY      2+   ;                     NO-INTERPRET

\ Interactive Layer           Dictionary              27Oct86TJZ

: (FIND)        ( here vocabulary -- cfa flag | here false )
                STOP
                BEGIN   DUP
                WHILE   2DUP 2+ DUP C@ 1+ CAPS-COMP
                        IF      @
                        ELSE    NIP 2+ COUNT + TRUE EXIT        \ **** EXITS
                        THEN
                REPEAT  ;               NO-INTERPRET

( &*& ) : (")    ( -- addr len )   R> COUNT 2DUP + >R  ;

( &*& ) : BYE   ( -- )
        0 0 BDOS  ;                     NO-INTERPRET

( &*& ) VARIABLE ABORT_FUNC

( &*& ) : ABORT         ( -- )          \ Just leave when we abort
                ABORT_FUNC @ ?DUP
                IF      EXECUTE
                ELSE    CR BYE
                THEN    ;                               EXECUTES> ABORT

( &*& ) : ?ABORT"       ( f1 a1 n1 -- ) \ display string a1,n1 & abort if f1 true
                ROT
                IF      TYPE ABORT
                ELSE    2DROP
                THEN    ;

FORTH   >FORTH

: %T"86         ( a1 -- )               \ compile string into target
                F['] (") RES_COMP_CALL
                [FORTH]
                :stringtype here-t index!
                DUP C@ 1+ S,-T          \ compile string to data area
                endtype here-t index! ;

' %T"86 IS %T"                          \ link into compiler

( &*& ) : %T."          ( | string" -- )
                [COMPILE] T"
                F['] TYPE RES_COMP_CALL ; IMMEDIATE

' %T." IS T."

: %L."          ( | string" -- )
                [COMPILE] L"
                COMPILE RES_COMP_CLL F['] TYPE X, ; IMMEDIATE

' %L." IS L."

: %T[']         ( | <name> -- a1 )
                F['] (LIT)    RES_COMP_CALL
                [FORTH] '     RES_COMP_CALL ; IMMEDIATE
' %T['] IS T[']

: %L[']         ( | <name> -- a1 )
                COMPILE RES_COMP_CLL F['] (LIT) X,
                COMPILE RES_COMP_CLL [FORTH] '  X, ; IMMEDIATE
' %L['] IS L[']

( &*& ) : %TABORT"      ( | string" -- )
                [COMPILE] T" F['] ?ABORT" COMP_CALL ; IMMEDIATE
' %TABORT" IS TABORT"

: %LABORT"      ( | string" -- )
                [COMPILE] L"
                COMPILE <'> COMPILE ?ABORT" COMPILE COMP_CALL ; IMMEDIATE
' %LABORT" IS LABORT"

TARGET  >LIBRARY

\ Interactive Layer           Dictionary              27Oct86TJZ

: FIND          ( addr -- cfa flag | addr false )
                DUP C@
                IF      STOP CONTEXT @ (FIND)
                ELSE    DROP END? ON  ['] NOOP 1
                THEN    ;

: ?UPPERCASE    ( adr -- adr )
                CAPS @ IF  DUP COUNT UPPER   THEN  ;

: DEFINED       ( -- here 0 | cfa [ -1 | 1 ] )
                BL WORD  ?UPPERCASE  FIND   ;

( &*& ) : ?STACK        ( -- )   ( System dependant )
                SP@ SP0 @ SWAP U<       ABORT" Stack Underflow"
                SP@ PAD U<              ABORT" Stack Overflow"   ;

: CRASH         ( -- )
                TRUE ABORT"  Uninitialized execution vector."  ;

: ?MISSING      ( f -- )        IF HERE COUNT TYPE TRUE ABORT"  ?" THEN ;

\ Interactive Layer           Number Input            06Oct83map

: (NUMBER?)   ( adr -- d flag )
   0 0  ROT  DUP 1+  C@  '-'  =  DUP  >R  -  -1 DPL !
   BEGIN   CONVERT  DUP C@  ',' '/' BETWEEN
   WHILE   0 DPL !
   REPEAT  -ROT  R> IF  DNEGATE  THEN   ROT C@ BL =  ;
                                        NO-INTERPRET
: NUMBER?   ( adr -- d flag )
   $0000  OVER COUNT BOUNDS
   ?DO  I C@ BASE @ DIGIT NIP IF  DROP $FFFF LEAVE THEN  LOOP
   IF  (NUMBER?)  ELSE  DROP  0 0 $0000  THEN  ;
                                        NO-INTERPRET
: NUMBER        ( adr -- d# )
                NUMBER? NOT ?MISSING  ; NO-INTERPRET

( &*& ) : DEPTH         ( -- n1 )       \ return the depth of the data stack
                SP@ SP0 @ SWAP - U2/  ;

( &*& ) : .S            ( -- )
                DEPTH ?DUP
                IF      DUP ."  [" 1 .R ." ]"
                        0 SWAP 1- 3 MIN
                        DO I PICK 7 U.R SPACE -1 +LOOP
                ELSE    ."  Stack Empty. "  THEN ;

: INTERPRET     ( -- )
                BEGIN   ?STACK DEFINED
                        IF     EXECUTE
                        ELSE   NUMBER  DOUBLE? NOT IF  DROP  THEN
                        THEN   END? @ END? OFF
                UNTIL   ;

: QUIT          ( -- )
                SP0 @ 'TIB !
                BEGIN   RP0 @ RP!
                        CR QUERY INTERPRET
                        ."  ok" DEPTH ?DUP
                        IF      1 MAX 10 MIN 0 DO ." ." LOOP
                        THEN
                AGAIN   ;

: RESTART       ( -- )
                SP0 @ SP!       \ reset the data stack
                QUIT ;          \ and QUIT

: COLD          ( -- )
                CR ." Cold Starting 8080 Forth" CR
                ['] RESTART !> ABORT_FUNC
                DECIMAL CAPS ON
                QUIT   ;

( &*& ) : ?KEYPAUSE     ( --- )         \ Pause if key pressed
                KEY?    DUP
                IF      DUP 27 = IF ABORT THEN
                        KEY 27 = IF ABORT THEN
                THEN    DROP ;                  NO-INTERPRET

VARIABLE DUMP_OFF

: DUMP          ( addr len -- )
                DUMP_OFF OFF 0
               ?DO      CR DUP DUMP_OFF @ + 4 H.R ."  | "
                        DUP 16 0 DO DUP C@ 3 H.R 1+ LOOP DROP ."  | "
                        DUP 16 0 DO DUP C@ $7F AND BL MAX EMIT 1+ LOOP DROP
                        16 +
                        ?KEYPAUSE
            16 +LOOP    DROP    ;

( &*& ) : WORDS         ( -- )
                CR
                CONTEXT @
                BEGIN   ?DUP
                WHILE   DUP 2+ COUNT TYPE 2 SPACES
                        #OUT @ 64 > IF CR THEN
                        @ ?KEYPAUSE
                REPEAT  ;

' !> ALIAS =: IMMEDIATE
' !> ALIAS IS IMMEDIATE

FORTH >FORTH

