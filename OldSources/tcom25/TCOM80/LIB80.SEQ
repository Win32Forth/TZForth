\\ KERNEL80.SEQ          Z80 Kernel for TCOM

{

>LIBRARY

TARGET DEFINITIONS

CODE STOP                       \ a marker to use while debugging
        >NEXT JMP    END-CODE

CODE UNNEST
        RP LHLD   M C MOV   H INX   M B MOV   H INX   RP SHLD
        >NEXT JMP    END-CODE

CODE EXIT     ( -- )
        RP LHLD   M C MOV   H INX   M B MOV   H INX   RP SHLD
        >NEXT JMP    END-CODE

CODE (LIT)   ( -- n )
        IP LDAX  IP INX  A L MOV  IP LDAX  IP INX  A H MOV
        HPUSH JMP  END-CODE

CODE (LIT+2)    ( -- n )
        IP LDAX  IP INX  A L MOV  IP LDAX  IP INX  A H MOV
        H INX H INX
        HPUSH JMP  END-CODE             NO-INTERPRET

FORTH   >FORTH

: %UNNEST       ( -- )
                F['] UNNEST RES_COMP_CALL ;

' %UNNEST IS DO_RET                     \ link into optimizer file

: %(LIT)        ( n1 -- )
                F['] (LIT) RES_COMP_CALL ,-T ;

' %(LIT) IS COMP_SINGLE                 \ link into number compiler

\ ***************************************************************************
\ Forward store and fetch words
\ define words that pickup the following word and use it like a variable

: for_does>80   ( a1 -- )
                [forth]
                ' ?lib
                if      compile res_comp_cll f['] (lit+2) x,
                        compile res_comp_cll x,
                        @ x,
                else    f['] (lit+2) res_comp_call
                                      compile_call
                                           perform
                then    ;

' for_does>80 is for_does>

\ ***************************************************************************


: NEXT          [ASM80] >NEXT JMP ;
: IP>HL         [ASM80] B H MOV C L MOV ;

TARGET  >LIBRARY


\ Run Time Code for Control Structures                04MAR83HHL

CODE BRANCH   ( -- )
     IP>HL   M C MOV H INX M B MOV   NEXT   END-CODE

CODE ?BRANCH  ( f -- )
        H POP   L A MOV   H ORA   0 $ JNZ
        IP>HL   M C MOV H INX M B MOV   NEXT
0 $:    IP INX   IP INX     NEXT   END-CODE

FORTH   >FORTH

: %IF           ( -- )
                F['] ?BRANCH RES_COMP_CALL +BR# $ OFFSET_16, ;

: %ELSE         ( -- )
                F['] BRANCH RES_COMP_CALL +BR# $ OFFSET_16,
                BR#SWAP -BR# DUP $: 01LAB ;

: %THEN         ( -- )
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

: IF            ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %IF
                ELSE    %IF
                THEN    ; IMMEDIATE

: ELSE          ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %ELSE
                ELSE    %ELSE
                THEN    ; IMMEDIATE

: THEN          ( -- )
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

CODE (LOOP)   ( -- )
        RP LHLD   M INR 0 $ JNZ
        H INX M INR 0 $ JNZ
        RP LHLD  6 D LXI   D DAD   RP SHLD
        IP INX IP INX   NEXT
0 $:    IP>HL   M C MOV H INX M B MOV   NEXT   END-CODE

CODE (+LOOP)   ( n -- )
        RP LHLD   M E MOV H INX M D MOV
        H POP  H A MOV A ORA 2 $ JM
        D DAD 1 $ JC
0 $:    XCHG RP LHLD E M MOV H INX D M MOV
        IP>HL   M C MOV H INX M B MOV   NEXT
2 $:    D DAD  0 $ JC
1 $:    RP LHLD  6 D LXI   D DAD   RP SHLD
        IP INX IP INX
        NEXT    END-CODE

FORTH   >FORTH

: %LOOP         ( -- )
                F['] (LOOP) RES_COMP_CALL
                -BR# DUP $ OFFSET_16, 01LAB
                -BR# DUP $:           01LAB ;

: %+LOOP        ( -- )
                F['] (+LOOP) RES_COMP_CALL
                -BR# DUP $ OFFSET_16, 01LAB
                -BR# DUP $:           01LAB ;

: LOOP          ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %LOOP
                ELSE    %LOOP
                THEN    ; IMMEDIATE

: +LOOP         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %+LOOP
                ELSE    %+LOOP
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

\ Execution Control                                   07SEP83HHL

CODE EXECUTE    ( cfa -- )
                H POP      >NEXT1 JMP
                END-CODE                NO-INTERPRET

CODE PERFORM    ( addr-of-cfa -- )
                H POP  M E MOV  H INX  M D MOV  XCHG  >NEXT1 JMP
                END-CODE                NO-INTERPRET

FORTH   >FORTH

: %PERFORM      ( n1 -- )
                F['] PERFORM RES_COMP_CALL ;

' %PERFORM IS COMP_PERFORM              \ link into number compiler

TARGET  >LIBRARY

CODE NOOP   NEXT   END-CODE             NO-INTERPRET

\ Execution Control                                   01Oct83map

CODE I   ( -- n )
   RP LHLD   M E MOV H INX M D MOV
   H INX M A MOV H INX M H MOV   A L MOV   D DAD
   HPUSH JMP   END-CODE                 NO-INTERPRET

CODE J   ( -- n )
   RP LHLD   6 D LXI   D DAD  M E MOV H INX M D MOV
   H INX M A MOV H INX M H MOV   A L MOV   D DAD
   HPUSH JMP   END-CODE                 NO-INTERPRET

CODE (LEAVE)   ( -- )
   RP LHLD   H INX H INX H INX H INX
   M C MOV H INX M B MOV H INX   RP SHLD   NEXT   END-CODE
                                        NO-INTERPRET
CODE (?LEAVE)   ( f -- )
        H POP   H A MOV L ORA 0 $ JZ   NEXT
0 $:    RP LHLD   H INX H INX H INX H INX
        M C MOV H INX M B MOV H INX   RP SHLD   NEXT   END-CODE
                                        NO-INTERPRET

FORTH   >FORTH

: %LEAVE        ( -- )
                F['] (LEAVE) RES_COMP_CALL ;

: %?LEAVE       ( -- )
                F['] (?LEAVE) RES_COMP_CALL ;

: LEAVE         ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %LEAVE
                ELSE    %LEAVE
                THEN    ; IMMEDIATE

: ?LEAVE        ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %?LEAVE
                ELSE    %?LEAVE
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

\ 16 and 8 bit Memory Operations                      19Jan87TJZ

CODE @     ( addr -- n )
   H POP   M E MOV   H INX   M D MOV   D PUSH   NEXT  END-CODE
                                        EXECUTES> @-T

CODE !     ( n addr -- )
   H POP   D POP   E M MOV   H INX   D M MOV   NEXT  END-CODE
                                        EXECUTES> !-T

FORTH   >FORTH

: %@            ( n1 -- )
                F['] @ RES_COMP_CALL ;

' %@ IS COMP_FETCH              \ link into number compiler

: %!            ( n1 -- )
                F['] ! RES_COMP_CALL ;

' %! IS COMP_STORE              \ link into number compiler

TARGET  >LIBRARY

CODE C@     ( addr -- char )
   H POP   M L MOV   0 H MVI   HPUSH JMP  END-CODE
                                        EXECUTES> C@-T
CODE C!     ( char addr -- )
   H POP   D POP   E M MOV   NEXT  END-CODE
                                        EXECUTES> C!-T
\ Block Move Memory Operations                        24FEB83HHL

CODE CMOVE      (  from to count -- )
                IP>HL   B POP  D POP  XTHL ( STACK=IP BC=len DE=to HL=from )
1 $:            B A MOV  C ORA
        0 $ JZ
                M A MOV  H INX  D STAX  D INX  B DCX
        1 $ JMP
0 $:            B POP  NEXT
                END-CODE                NO-INTERPRET

CODE CMOVE>     ( from to count -- )
                IP>HL   B POP  D POP  XTHL ( STACK=IP BC=len DE=to HL=from )
                B DAD H DCX   XCHG   B DAD H DCX    XCHG
1 $:            B A MOV   C ORA
        0 $ JZ
                M A MOV H DCX D STAX   D DCX B DCX
        1 $ JMP
0 $:            B POP   NEXT
                END-CODE                NO-INTERPRET

\ 16 bit Stack Operations                             24FEB83HHL

CODE SP@     ( -- n )
     0 H LXI   SP DAD   HPUSH JMP   END-CODE
                                        NO-INTERPRET
CODE SP!     ( n -- )
     H POP    SPHL   NEXT   END-CODE    NO-INTERPRET

CODE RP@     ( -- addr )
     RP LHLD   HPUSH JMP   END-CODE     NO-INTERPRET

CODE RP!     ( n -- )
     H POP   RP SHLD   NEXT   END-CODE  NO-INTERPRET

\ 16 bit Stack Operations                             24FEB83HHL

CODE DROP    ( n1 -- )
     H POP   NEXT   END-CODE            EXECUTES> DROP

CODE DUP      ( n1 -- n1 n1 )
   H POP   H PUSH   HPUSH JMP END-CODE  EXECUTES> DUP

CODE SWAP     ( n1 n2 -- n2 n1 )
   H POP   XTHL   HPUSH JMP    END-CODE EXECUTES> SWAP

CODE OVER     ( n1 n2 -- n1 n2 n1 )
   D POP H POP H PUSH DPUSH JMP END-CODE
                                        EXECUTES> OVER

CODE TUCK     ( n1 n2 -- n2 n1 n2 )
   H POP   D POP   H PUSH   DPUSH JMP   END-CODE
                                        NO-INTERPRET
CODE NIP      ( n1 n2 -- n2 )
   H POP  D POP  HPUSH JMP   END-CODE   EXECUTES> NIP

CODE ROT   ( n1 n2 n3 --- n2 n3 n1 )
   D POP H POP XTHL DPUSH JMP END-CODE  EXECUTES> ROT

CODE -ROT   ( n1 n2 n3 --- n3 n1 n2 )
   H POP D POP XTHL XCHG DPUSH JMP END-CODE
                                        NO-INTERPRET
CODE FLIP   ( n -- n )
   D POP   E H MOV  D L MOV  HPUSH JMP   END-CODE
                                        EXECUTES> FLIP
: ?DUP      ( n -- [n] n )
   DUP IF   DUP   THEN   ;              EXECUTES> ?DUP

\ 16 bit Stack Operations                             24FEB83HHL

CODE R>     ( -- n )
   RP LHLD   M E MOV   H INX   M D MOV   H INX
   RP SHLD   D PUSH   NEXT   END-CODE   NO-INTERPRET

CODE >R     ( n -- )
   D POP   RP LHLD   H DCX   H DCX   RP SHLD
   E M MOV   H INX   D M MOV   NEXT   END-CODE
                                        NO-INTERPRET
CODE R@
   RP LHLD   M E MOV   H INX   M D MOV   D PUSH   NEXT END-CODE
                                        NO-INTERPRET

CODE PICK    ( nm ... n2 n1 k -- nm ... n2 n1 nk )
   H POP H DAD SP DAD   M E MOV H INX M D MOV
   D PUSH NEXT END-CODE                 NO-INTERPRET

\ 16 bit Logical Operations                           13Apr84map

CODE AND     ( n1 n2 -- n3 )
   D POP   H POP   E A MOV   L ANA   A L MOV
   D A MOV   H ANA   A H MOV   HPUSH JMP  END-CODE
                                        EXECUTES> AND
CODE OR      ( n1 n2 -- n3 )
   D POP   H POP   E A MOV   L ORA   A L MOV
   D A MOV   H ORA   A H MOV   HPUSH JMP  END-CODE
                                        EXECUTES> OR
CODE XOR      ( n1 n2 -- n3 )
   D POP   H POP   E A MOV   L XRA   A L MOV
   D A MOV   H XRA   A H MOV   HPUSH JMP  END-CODE
                                        EXECUTES> XOR
CODE NOT     ( n -- n' )
   H POP  L A MOV  CMA  A L MOV  H A MOV  CMA  A H MOV
   HPUSH JMP  END-CODE                  EXECUTES> NOT

-1 CONSTANT TRUE
 0 CONSTANT FALSE



\ Logical Operations                                  16Oct83map

CODE CSET   ( b addr -- )
   H POP D POP   M A MOV  E ORA  A M MOV   NEXT   END-CODE
                                        NO-INTERPRET
CODE CRESET   ( b addr -- )
   H POP D POP   E A MOV CMA A E MOV
                 M A MOV  E ANA  A M MOV   NEXT   END-CODE
                                        NO-INTERPRET
CODE CTOGGLE  ( b addr -- )
   H POP   D POP   M A MOV   E XRA   A M MOV   NEXT   END-CODE
                                        NO-INTERPRET
CODE ON   ( addr -- )
   $FFFF  H LXI XTHL H PUSH
   H POP   D POP   E M MOV   H INX   D M MOV   NEXT  END-CODE
                                        NO-INTERPRET

CODE OFF   ( addr -- )
   $0000 H LXI XTHL H PUSH
   H POP   D POP   E M MOV   H INX   D M MOV   NEXT  END-CODE
                                        NO-INTERPRET

FORTH   >FORTH

: %ON           ( n1 -- )
                F['] ON RES_COMP_CALL ;

' %ON IS COMP_ON                \ link into number compiler

: %OFF          ( n1 -- )
                F['] OFF RES_COMP_CALL ;

' %OFF IS COMP_OFF                \ link into number compiler

TARGET  >LIBRARY

\ 16 bit Arithmetic Operations                        13Apr84map

CODE +   ( n1 n2 -- sum )
   D POP   H POP   D DAD   HPUSH JMP   END-CODE
                                        EXECUTES> +
CODE NEGATE   ( n -- n' )
   H POP  H DCX  H PUSH
   H POP  L A MOV  CMA  A L MOV  H A MOV  CMA  A H MOV
   HPUSH JMP  END-CODE                  EXECUTES> NEGATE

CODE -  ( n1 n2 -- n1-n2 )
        D POP H POP   D A MOV CMA A D MOV   E A MOV CMA A E MOV
        D INX    D DAD   HPUSH JMP   END-CODE
                                        EXECUTES> -
CODE ABS   ( n -- n )
        H POP H PUSH   H A MOV A ORA 0 $ JM
        >NEXT JMP
0 $:    H POP  H DCX  H PUSH
        H POP  L A MOV  CMA  A L MOV  H A MOV  CMA  A H MOV
        HPUSH JMP       END-CODE        EXECUTES> ABS

CODE +! ( n addr -- )
        H POP   D POP   M A MOV   E ADD   A M MOV
                H INX   M A MOV   D ADC   A M MOV   NEXT   END-CODE
                                        NO-INTERPRET

FORTH   >FORTH

: %+!           ( n1 -- )
                F['] +! RES_COMP_CALL ;

' %+! IS COMP_PSTORE            \ link into number compiler

TARGET  >LIBRARY


\ 16 bit Arithmetic Operations                        26Sep83map

CODE 2*   ( n -- 2*n )
   H POP   H DAD   HPUSH JMP   END-CODE EXECUTES> 2*

CODE 2/   ( n -- n/2 )
   H POP   H A MOV   RLC RRC RAR   A H MOV
   L A MOV   RAR   A L MOV   HPUSH JMP   END-CODE
                                        EXECUTES> 2/
CODE U2/   ( u -- u/2 )
   H POP   A ORA   H A MOV   RAR   A H MOV
   L A MOV   RAR   A L MOV   HPUSH JMP   END-CODE
                                        EXECUTES> U2/

CODE 8*   ( n -- 8*n )
   H POP   H DAD   H DAD   H DAD   HPUSH JMP   END-CODE
                                        NO-INTERPRET

CODE 1+      H POP H INX HPUSH JMP END-CODE
                                        EXECUTES> 1+

CODE 2+      H POP H INX H INX HPUSH JMP END-CODE
                                        EXECUTES> 2+

CODE 1-      H POP H DCX HPUSH JMP END-CODE
                                        EXECUTES> 1-

CODE 2-      H POP H DCX H DCX HPUSH JMP END-CODE
                                        EXECUTES> 2-
: ROLL   ( n1 n2 .. nk n -- wierd )
   >R R@ PICK   SP@ DUP 2+   R> 1+ 2* CMOVE>  DROP  ;
                                        NO-INTERPRET
\ 16 bit Arithmetic Operations   Unsigned Multiply    26Sep83map

CODE UM*      ( n1 n2 -- d )
     D POP      H POP     B PUSH   H B MOV   L A MOV
     0 H LXI   ( 0=Partial Product )
             4 C MVI   ( Loop Counter )
        BEGIN  H DAD ( Shift AHL left by 24 bits )
             RAL CS IF D DAD   0 ACI THEN
             H DAD   RAL CS IF D DAD   0 ACI THEN
             C DCR
        0= UNTIL
     H PUSH   A H MOV   B A MOV    H B MOV
     0 H LXI   ( 0=Partial Product )
             4 C MVI   ( Loop Counter )
        BEGIN  H DAD ( Shift AHL left by 24 bits )
             RAL CS IF D DAD   0 ACI THEN
             H DAD   RAL CS IF D DAD   0 ACI THEN
             C DCR
        0= UNTIL
     D POP    D C MOV     B DAD      0 ACI   L D MOV    H L MOV
   A H MOV      B POP     DPUSH JMP END-CODE NO-INTERPRET

: U*D   ( n1 n2 -- d )   UM*  ;         NO-INTERPRET

\ 16 bit Arithmetic Operations   Unsigned Divide      25FEB83HHL

CODE UM/MOD   ( d1 n1 -- Remainder Quotient )
                IP>HL    B POP D POP XTHL XCHG
                ( HLDE = Numerator  BC = Denominator )
                L A MOV C SUB   H A MOV B SBB
        0 $ JNC
                H A MOV L H MOV D L MOV 8 D MVI D PUSH
        2 $ CALL
                D POP H PUSH E L MOV
        2 $ CALL
                A D MOV H E MOV B POP C H MOV B POP
                D PUSH
                HPUSH JMP
0 $:    -1 H LXI
                B POP   H PUSH
                HPUSH JMP
1 $:            A E MOV H A MOV C SUB   A H MOV E A MOV B SBB
        3 $ JNC
                H A MOV C ADD   A H MOV E A MOV D DCR RZ
2 $:            H DAD RAL
        1 $ JNC
                A E MOV H A MOV C SUB   A H MOV E A MOV B SBB
3 $:            L INR D DCR
        2 $ JNZ
        RET     END-CODE                NO-INTERPRET

\ 16 bit Comparison Operations                        13Apr84map

CODE 0=      ( n -- f )
   H POP   L A MOV   H ORA
        0 $ JZ $0000 H LXI   HPUSH JMP
0 $:    $FFFF H LXI HPUSH JMP END-CODE   EXECUTES> 0=

CODE 0<      ( n -- f )
   H POP   H DAD
        0 $ JC $0000 H LXI   HPUSH JMP
0 $:    $FFFF H LXI HPUSH JMP  END-CODE  NO-INTERPRET

CODE 0>   ( n -- f )
   H POP H A MOV A ORA  1 $ JM   L ORA
        0 $ JNZ $0000 H LXI   HPUSH JMP
0 $:    $FFFF H LXI HPUSH JMP
1 $:    $0000 H LXI HPUSH JMP END-CODE  NO-INTERPRET

CODE 0<>  ( n -- f )
   H POP   L A MOV   H ORA
        0 $ JNZ $0000 H LXI   HPUSH JMP
0 $:    $FFFF H LXI HPUSH JMP END-CODE   NO-INTERPRET

CODE =       ( n1 n2 -- f )
   H POP D POP   L A MOV E CMP   0 $ JNZ
                 H A MOV D CMP   0 $ JNZ
               $FFFF H LXI   HPUSH JMP
0 $:           $0000 H LXI   HPUSH JMP  END-CODE
                                        NO-INTERPRET
: <>     ( n1 n2 -- f )   = NOT   ;     NO-INTERPRET

: ?NEGATE    ( n1 n2 -- n3 )   0< IF    NEGATE   THEN   ;
                                        NO-INTERPRET
\ 16 bit Comparison Operations                        13Apr84map

CODE U<   ( n1 n2 -- f )   H POP  D POP
        H A MOV D CMP   0 $ JC   1 $ JNZ
        L A MOV  E CMP   0 $ JC   1 $ JNZ
0 $:    $0000 H LXI HPUSH JMP
1 $:    $FFFF H LXI HPUSH JMP END-CODE  NO-INTERPRET

CODE U>   ( n1 n2 -- f )
        D POP  H POP  H A MOV D CMP   0 $ JC   1 $ JNZ
        L A MOV  E CMP   0 $ JC   1 $ JNZ
0 $:    $0000 H LXI HPUSH JMP
1 $:    $FFFF H LXI HPUSH JMP END-CODE  NO-INTERPRET

CODE <   ( n1 n2 -- f )
        H POP  D POP D A MOV 128 XRI A D MOV  H A MOV 128 XRI
        D CMP   0 $ JC   1 $ JNZ
        L A MOV  E CMP   0 $ JC   1 $ JNZ
0 $:    $0000 H LXI HPUSH JMP
1 $:    $FFFF H LXI HPUSH JMP END-CODE  NO-INTERPRET

CODE >   ( n1 n2 -- f )
        D POP  H POP  D A MOV 128 XRI A D MOV  H A MOV 128 XRI
        D CMP   0 $ JC   1 $ JNZ
        L A MOV  E CMP   0 $ JC   1 $ JNZ
0 $:    $0000 H LXI HPUSH JMP
1 $:    $FFFF H LXI HPUSH JMP END-CODE  NO-INTERPRET

: BETWEEN   ( n1 min max -- f )
   >R  OVER >  SWAP R> >  OR NOT  ;     NO-INTERPRET

: WITHIN   ( n1 min max -- f )   1- BETWEEN  ;
                                        NO-INTERPRET
\ 32 bit Memory Operations                            09MAR83HHL

CODE 2@     ( addr -- d )
   H POP   2 D LXI   D DAD   M E MOV   H INX   M D MOV   D PUSH
          -3 D LXI   D DAD   M E MOV   H INX   M D MOV   D PUSH
          NEXT   END-CODE               NO-INTERPRET

CODE 2!     ( d addr -- )
   H POP   D POP   E M MOV   H INX   D M MOV   H INX
           D POP   E M MOV   H INX   D M MOV   NEXT  END-CODE
                                        NO-INTERPRET
\ 32 bit Memory and Stack Operations                  13Apr84map

CODE 2DROP     ( d -- )
   H POP H POP   NEXT   END-CODE        EXECUTES> 2DROP

CODE 2DUP     ( d -- d d )
   H POP D POP   D PUSH H PUSH   DPUSH JMP   END-CODE
                                        NO-INTERPRET
CODE 2SWAP     ( d1 d2 -- d2 d1 )
   H POP D POP XTHL H PUSH
   5 H LXI SP DAD M A MOV D M MOV A D MOV
   H DCX M A MOV E M MOV A E MOV  H POP DPUSH JMP END-CODE
                                        EXECUTES> 2SWAP
CODE 2OVER      ( d2 d2 -- d1 d2 d1 )
   7 H LXI SP DAD M D MOV H DCX M E MOV D PUSH
            H DCX M D MOV H DCX M E MOV D PUSH   NEXT  END-CODE
                                        NO-INTERPRET
: MIN   ( n1 n2 -- n3 )   2DUP > IF   SWAP   THEN   DROP   ;
                                        NO-INTERPRET
: MAX   ( n1 n2 -- n3 )   2DUP < IF   SWAP   THEN   DROP   ;
                                        NO-INTERPRET
\ Run Time Code for Control Structures                02MAR83HHL

: (DO)   ( n1 n2 -- )
   R> DUP @ >R 2+ -ROT    SWAP DUP >R   - >R   >R   ;
                                        NO-INTERPRET
: (?DO)   ( n1 n2 -- )
   2DUP = IF   DROP DROP R> @ >R
   ELSE    R> DUP @ >R 2+ -ROT
           SWAP DUP >R   - >R   >R   THEN ;
                                        NO-INTERPRET
FORTH   >FORTH

: %(DO)         ( -- )
                F['] (DO) RES_COMP_CALL +BR# $ OFFSET_16,
                +BR# $: ;

: %(?DO)        ( -- )
                F['] (?DO) RES_COMP_CALL +BR# $ OFFSET_16,
                +BR# $: ;

: DO            ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %(DO)
                ELSE    %(DO)
                THEN    ; IMMEDIATE

: ?DO           ( -- )
                ?LIB    [FORTH]
                IF      COMPILE %(?DO)
                ELSE    %(?DO)
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

: 3DUP          ( a b c -- a b c a b c )
                DUP 2OVER ROT   ;       NO-INTERPRET

: 4DUP          ( a b c d -- a b c d a b c d )
                2OVER 2OVER   ;         NO-INTERPRET

: 2ROT          ( a b c d e f --- c d e f a b )
                5 ROLL 5 ROLL ;         NO-INTERPRET

\ 32 bit Arithmetic Operations                        13Apr84map

CODE D+  ( d1 d2 -- dsum )
   6 H LXI  SP DAD  M E MOV C M MOV  H INX
   M D MOV  B M MOV  B POP  H POP  D DAD  XCHG
   H POP  L A MOV  C ADC  A L MOV  H A MOV  B ADC
   A H MOV  B POP  DPUSH JMP   END-CODE NO-INTERPRET

CODE DNEGATE  ( d# -- d#' )
   H POP  D POP  A SUB  E SUB  A E MOV  0 A MVI  D SBB
   A D MOV  0 A MVI     L SBB  A L MOV  0 A MVI  H SBB
   A H MOV  DPUSH JMP  END-CODE         NO-INTERPRET

CODE   S>D      ( n -- d )
   D POP 0 H LXI D A MOV 128 ANI 0= NOT IF   H DCX   THEN
   DPUSH JMP   END-CODE                 NO-INTERPRET

CODE DABS   ( d# -- d# )
        H POP H PUSH   H A MOV A ORA 0 $ JM
        >NEXT JMP
0 $:    H POP  D POP  A SUB  E SUB  A E MOV  0 A MVI  D SBB
        A D MOV  0 A MVI     L SBB  A L MOV  0 A MVI  H SBB
        A H MOV
        DPUSH JMP       END-CODE        NO-INTERPRET

\ 32 bit Arithmetic Operations                        2Oct86 TJZ

CODE D2*   ( d -- d*2 )
   H POP   D POP
   E A MOV   STC CMC
             RAL   A E MOV   D A MOV   RAL   A D MOV
   L A MOV   RAL   A L MOV   H A MOV   RAL   A H MOV
   DPUSH JMP   END-CODE                 NO-INTERPRET

CODE D2/   ( d -- d/2 )
   H POP   D POP
   H A MOV   RLC RRC RAR   A H MOV   L A MOV   RAR   A L MOV
   D A MOV   RAR           A D MOV   E A MOV   RAR   A E MOV
   DPUSH JMP   END-CODE                 NO-INTERPRET

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

: MU/MOD  ( d# n1 -- rem d#quot )
   >R  0  R@  UM/MOD  R>  SWAP  >R  UM/MOD  R>   ;
                                        NO-INTERPRET
\ 16 bit multiply and divide                          27Sep83map

: *   ( n1 n2 -- n3 )   UM* DROP   ;    EXECUTES> *

: /MOD  ( n1 n2 -- rem quot )   >R  S>D  R>  M/MOD  ;
                                        NO-INTERPRET
: /     ( n1 n2 -- quot )   /MOD  NIP ; EXECUTES> /

: MOD   ( n1 n2 -- rem )    /MOD DROP ; EXECUTES> MOD

: */MOD  ( n1 n2 n3 -- rem quot )
   >R  *D  R>  M/MOD  ;                 NO-INTERPRET

: */    ( n1 n2 n3 -- n1*n2/n3 )     */MOD  NIP  ;
                                        NO-INTERPRET

\ Machine dependent IO words                          04Apr84map

CODE PC@        ( port# -- n )
                D POP  HERE 5 + H LXI ( Sorry self modifying code )
                E M MOV  0 IN  A L MOV  0 H MVI
                HPUSH JMP   END-CODE    NO-INTERPRET

CODE PC!        ( n port# -- )
                D POP  HERE 7 + H LXI  ( Sorry self modifying code again )
                E M MOV  H POP  L A MOV  0 OUT
                NEXT END-CODE           NO-INTERPRET

\ System VARIABLEs                                    22Jan87TJZ

: SP0           ( -- a1 )
                SPZERO ;

: RP0           ( a1 -- )
                RPZERO ;

\ VARIABLE SP0          \ INITIAL PARAMETER STACK
\ VARIABLE RP0          \ INITIAL RETURN STACK
VARIABLE DP             \ DICTIONARY POINTER
VARIABLE #OUT           \ NUMBER OF CHARACTERS EMITTED
VARIABLE #LINE          \ THE NUMBER OF LINES SENT SO FAR
VARIABLE BASE           \ FOR NUMERIC INPUT AND OUTPUT
VARIABLE HLD            \ POINTS TO LAST CHARACTER HELD IN PAD
VARIABLE DPL            \ NUMERIC INPUT PUNCTUATION
VARIABLE R#             \ EDITING CURSOR POSITION
VARIABLE LAST           \ POINTS TO NFA OF LATEST DEFINITION
VARIABLE CONTEXT        \ VOCABULARY SEARCHED FIRST
VARIABLE 'TIB           \ ADDRESS OF TERMINAL INPUT BUFFER
VARIABLE >IN            \ OFFSET INTO INPUT STREAM
VARIABLE SPAN           \ NUMBER OF CHARACTERS EXPECTED
VARIABLE #TIB           \ NUMBER OF CHARACTERS TO INTERPRET
VARIABLE END?           \ TRUE IF INPUT STREAM EXHAUSTED
VARIABLE CAPS

\ Devices                     Strings                 13Apr84map

   32 CONSTANT BL
    8 CONSTANT BS
    7 CONSTANT BELL

CODE FILL         (  start-addr count char -- )
                IP>HL  D POP  B POP  XTHL  XCHG
1 $:            B A MOV   C ORA
        0 $ JZ
                L A MOV   D STAX  D INX   B DCX
        1 $ JMP
0 $:            B POP
                NEXT    END-CODE        NO-INTERPRET

: ERASE      ( addr len -- )   0 FILL   ;
                                        NO-INTERPRET
: BLANK      ( addr len -- )   BL FILL   ;
                                        NO-INTERPRET
CODE COUNT   ( addr -- addr+1 len )
   H POP   M E MOV 0 D MVI   H INX   XCHG   DPUSH JMP END-CODE
                                        NO-INTERPRET
CODE LENGTH  ( addr -- addr+2 len )
   H POP  M E MOV  H INX  M D MOV
   H INX   XCHG   DPUSH JMP END-CODE    NO-INTERPRET

\ Devices                     Strings                 13Apr84map

CODE UPC   ( char -- char' )
           H POP
         L A MOV
        0 $ CALL                \ call uppercase subroutine
         A L MOV
          H PUSH
            NEXT                \ return
0 $:     'a' CPI
              RC                \ return on CARRY set
      'z' 1+ CPI
             RNC                \ return on CARRY NOT set
          BL SUI                \ mask the caracter
             RET        END-CODE        NO-INTERPRET

CODE UPPER      ( addr len -- )
                D POP H POP
                BEGIN   D A MOV
                        E ORA
         0= NOT WHILE   M A MOV 0 $ CALL A M MOV
                        H INX D DCX
                REPEAT
                NEXT
0 $:    'a' CPI
             RC
     'z' 1+ CPI
            RNC
         BL SUI
            RET         END-CODE        NO-INTERPRET

: HERE   ( -- addr )   DP @   ;         EXECUTES> HERE-T

: PAD    ( -- addr )   HERE 80 +   ;    NO-INTERPRET

: -TRAILING   ( addr len -- addr len' )
   DUP 0 ?DO   2DUP + 1- C@   BL <> ?LEAVE   1-   LOOP   ;
                                        NO-INTERPRET

\ Devices                     Strings                 26Sep83map

CODE COMP   ( addr1 addr2 len -- -1 | 0 | 1 )
   C L MOV  B H MOV  B POP  D POP  XTHL
   ( Stack=IP  BC=len  DE=addr2  HL=addr1 )
   BEGIN   B A MOV  C ORA  0= NOT WHILE
     M A MOV  XCHG  M CMP  XCHG
     0= IF   D INX  H INX  B DCX
        ELSE    0< IF   1 H LXI   ELSE   -1 H LXI   THEN
                 B POP   HPUSH JMP   THEN
   REPEAT   0 H LXI   B POP   HPUSH JMP   END-CODE
                                        NO-INTERPRET
\ Devices                     Strings                 26Sep83map

CODE CAPS-COMP   ( addr1 addr2 len -- -1 | 0 | 1 )
   C L MOV  B H MOV  B POP  D POP  XTHL
   ( Stack=IP  BC=len  DE=addr2  HL=addr1 )
   BEGIN   B A MOV  C ORA  0= NOT WHILE
        M A MOV  'a' CPI  RC  'z' 1+ CPI  RNC  BL SUI
        B PUSH  A C MOV  XCHG
        M A MOV  'a' CPI  RC  'z' 1+ CPI  RNC  BL SUI
        C CMP   B POP    XCHG
     0= IF   D INX  H INX  B DCX
        ELSE    0< IF   1 H LXI   ELSE   -1 H LXI   THEN
                 B POP   HPUSH JMP   THEN
   REPEAT   0 H LXI   B POP   HPUSH JMP   END-CODE
                                        NO-INTERPRET
: COMPARE   ( addr1 addr2 len -- -1 | 0 | 1 )
        CAPS @ IF  CAPS-COMP  ELSE  COMP  THEN  ;
                                        NO-INTERPRET

\ Devices      Terminal IO via CP/M                 21Jan87TJZ

CODE BDOS       ( n fun -- m )
                H POP   D POP   B PUSH   L C MOV
                5 CALL
                0 H MVI   A L MOV   B POP
                HPUSH JMP   END-CODE    NO-INTERPRET

: KEY?          ( -- f )
                255 6 BDOS ;            NO-INTERPRET

: KEY           ( -- char )
                BEGIN KEY? ?DUP UNTIL ; NO-INTERPRET

: EMIT          ( char -- )
                $7F AND 6 BDOS DROP 1 #OUT +! ; EXECUTES> EMIT

: CR            ( -- )
                13 EMIT   10 EMIT   #OUT OFF
                1 #LINE +! ;            EXECUTES> CR

: TYPE          ( addr len -- )
                0 ?DO  COUNT EMIT  LOOP   DROP   ;
                                        NO-INTERPRET
: SPACE         ( -- )
                BL EMIT   ;             EXECUTES> SPACE

: SPACES        ( n -- )
                0 MAX   0 ?DO   SPACE   LOOP   ;
                                        EXECUTES> SPACES
: BACKSPACES    ( n -- )
                0 ?DO BS EMIT -2 #OUT +! LOOP ;
                                        NO-INTERPRET
: BEEP          ( -- )
                BELL EMIT -1 #OUT +! ;  EXECUTES> BEEP

\ Devices   System Dependent Control Characters       19Jan87TJZ

: BS-IN         ( n c -- 0 | n-1 )
                DROP DUP IF   1-   BS   ELSE BELL THEN EMIT -2 #OUT +! ;
                                        NO-INTERPRET
: DEL-IN        ( n c -- 0 | n-1 )
                DROP DUP IF  1-  BS EMIT SPACE BS
                ELSE  BELL  THEN  EMIT -2 #OUT +! ;
                                        NO-INTERPRET
: BACK-UP       ( n c -- 0 )
                DROP   DUP BACKSPACES   DUP SPACES   BACKSPACES   0   ;
                                        NO-INTERPRET
: ESC-IN        ( c -- )
                DROP   2DUP  + @ EMIT  1+  ;
                                        NO-INTERPRET
\ Devices                     Terminal Input          24AUG84MJM

: CR-IN         ( m a n c -- m a m )
                DROP   SPAN !   OVER   BL EMIT   ;
                                        NO-INTERPRET
: CHAR          ( a n char -- a n+1 )
                3DUP EMIT + C!   1+   ;
                                        NO-INTERPRET
: EXEC:         ( n1 -- )
                2* R> + PERFORM ;       NO-INTERPRET

: DO_ACHAR      ( n1 -- )
        EXEC:
        CHAR    CHAR   CHAR   CHAR   CHAR   CHAR    CHAR   CHAR
        BS-IN   CHAR   CHAR   CHAR   CHAR   CR-IN   CHAR   CHAR
        CHAR    CHAR   CHAR   CHAR   CHAR   BACK-UP CHAR   CHAR
        BACK-UP CHAR   CHAR   ESC-IN CHAR   CHAR    CHAR   CHAR ;
                                        NO-INTERPRET

: EXPECT   ( adr len -- )
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

CODE DIGIT      ( char base -- n true | char false )
                H POP   D POP  D PUSH   E A MOV   '0' SUI
        0 $ JM
                10 CPI
        1 $ JM
                7 SUI   10 CPI
        0 $ JM
1 $:            L CMP
        0 $ JP
                A E MOV    H POP D PUSH
                $FFFF H LXI   HPUSH JMP
0 $:            $0000 H LXI   HPUSH JMP
                END-CODE                NO-INTERPRET

: DOUBLE?   ( -- f )      DPL @ 1+   0<> ;
                                        NO-INTERPRET
: CONVERT   ( +d1 adr1 -- +d2 adr2 )
   BEGIN  1+  DUP >R  C@  BASE @  DIGIT
   WHILE  SWAP  BASE @ UM*  DROP  ROT  BASE @ UM*  D+
      DOUBLE?  IF  1 DPL +!  THEN  R>
   REPEAT  DROP  R>  ;                  NO-INTERPRET

\ Interactive Layer           Number Output           03Apr84map

: HOLD   ( char -- )   -1 HLD +!   HLD @ C!   ;
                                        NO-INTERPRET
: <#     ( -- )     PAD  HLD  !  ;      NO-INTERPRET

: #>     ( d# -- addr len )    2DROP  HLD  @  PAD  OVER  -  ;
                                        NO-INTERPRET
: SIGN   ( n1 -- )  0< IF  '-'  HOLD  THEN  ;
                                        NO-INTERPRET
: #      ( -- )
  BASE @ MU/MOD ROT 9 OVER < IF  7 + THEN '0'  +  HOLD  ;
                                        NO-INTERPRET
: #S     ( -- )     BEGIN  #  2DUP  OR  0=  UNTIL  ;
                                        NO-INTERPRET

: HEX        ( -- )   16 BASE !  ;      EXECUTES> HEX

: DECIMAL    ( -- )   10 BASE !  ;      EXECUTES> DECIMAL

\ Interactive Layer           Number Output           24FEB83HHL

: (U.)  ( u -- a l )   0    <# #S #>   ;
                                        NO-INTERPRET
: U.    ( u -- )       (U.)   TYPE SPACE   ;
                                        NO-INTERPRET
: U.R   ( u l -- )     >R   (U.)   R> OVER - SPACES   TYPE   ;
                                        NO-INTERPRET

: (.)   ( n -- a l )   DUP ABS 0   <# #S   ROT SIGN   #>   ;
                                        NO-INTERPRET
: .     ( n -- )       (.)   TYPE SPACE   ;
                                        EXECUTES> .
: .R    ( n l -- )     >R   (.)   R> OVER - SPACES   TYPE   ;
                                        EXECUTES> .R

: H.    ( n -- )        BASE @ HEX SWAP U. BASE ! ;

: H.R   ( n l -- )      BASE @ HEX -ROT U.R BASE ! ;

: (UD.) ( ud -- a l )  <# #S #>   ;     NO-INTERPRET

: UD.   ( ud -- )      (UD.)   TYPE SPACE   ;
                                        NO-INTERPRET
: UD.R  ( ud l -- )    >R   (UD.)   R> OVER - SPACES   TYPE  ;
                                        NO-INTERPRET
: (D.)  ( d -- a l )   TUCK DABS   <# #S   ROT SIGN  #>   ;
                                        NO-INTERPRET
: D.    ( d -- )       (D.)   TYPE SPACE   ;
                                        NO-INTERPRET
: D.R   ( d l -- )     >R   (D.)   R> OVER - SPACES   TYPE   ;
                                        NO-INTERPRET
\ Interactive Layer           Parsing                 30Sep83map

CODE  SKIP      ( addr len char -- addr' len' )
                IP>HL   B POP D POP XTHL ( C=char DE=length  HL=addr )
1 $:            D A MOV  E ORA
        0 $ JZ
                M A MOV  C CMP
        0 $ JNZ
                H INX  D DCX
        1 $ JMP
0 $:            B POP   H PUSH   D PUSH
                NEXT    END-CODE        NO-INTERPRET

CODE  SCAN      ( addr len char -- addr' len' )
                IP>HL   B POP  D POP  XTHL ( C=char DE=length HL=addr )
1 $:            D A MOV  E ORA
        0 $ JZ
                M A MOV   C CMP
        0 $ JZ
                H INX  D DCX
        1 $ JMP
0 $:            B POP   H PUSH   D PUSH
                NEXT    END-CODE        NO-INTERPRET

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

CODE (FIND)     ( here nfa -- here false | cfa flag )
                H POP H A MOV L ORA
        1 $ JZ
4 $:            D POP  D PUSH  H PUSH  H INX  H INX
                D LDAX  M XRA  63 ANI
        2 $ JNZ
3 $:            D INX H INX D LDAX M XRA A ADD
        2 $ JNZ
        3 $ JNC
                H INX D POP XTHL XCHG
                H INX H INX  M A MOV  64 ANI
        0 $ JZ
                $0001 H LXI   HPUSH JMP
2 $:            H POP  M E MOV  H INX  M D MOV
                XCHG   H A MOV   L ORA
        4 $ JNZ
1 $:            $0000 H LXI   HPUSH JMP
0 $:            $FFFF H LXI   HPUSH JMP
                END-CODE                NO-INTERPRET

: (")    ( -- addr len )   R> COUNT 2DUP + >R  ;

: BYE   ( -- )
        0 0 BDOS  ;                     NO-INTERPRET

VARIABLE ABORT_FUNC

: ABORT         ( -- )          \ Just leave when we abort
                ABORT_FUNC @ ?DUP
                IF      EXECUTE
                ELSE    CR BYE
                THEN    ;                               EXECUTES> ABORT

: ?ABORT"       ( f1 a1 n1 -- ) \ display string a1,n1 & abort if f1 true
                ROT
                IF      TYPE ABORT
                ELSE    2DROP
                THEN    ;

FORTH   >FORTH

: %T"80         ( a1 -- )               \ compile string into target
                F['] (") RES_COMP_CALL
                [FORTH]
                DUP C@ 1+ S,-T          \ compile string to data area
                ;
' %T"80 IS %T"                          \ link into compiler

: %T."          ( | string" -- )
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

: %TABORT"      ( | string" -- )
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
                IF      CONTEXT @ (FIND)
                ELSE    DROP END? ON  ['] NOOP 1
                THEN    ;

: ?UPPERCASE    ( adr -- adr )
                CAPS @ IF  DUP COUNT UPPER   THEN  ;

: DEFINED       ( -- here 0 | cfa [ -1 | 1 ] )
                BL WORD  ?UPPERCASE  FIND   ;

: ?STACK        ( -- )   ( System dependant )
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

: DEPTH         ( -- n1 )       \ return the depth of the data stack
                SP@ SP0 @ SWAP - U2/  ;

: .S            ( -- )
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

: ?KEYPAUSE     ( --- )         \ Pause if key pressed
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

: WORDS         ( -- )
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


