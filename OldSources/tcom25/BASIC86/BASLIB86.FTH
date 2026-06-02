\ BASLIB86.SEQ           Target Library Source           by Tom Zimmer

\ ***************************************************************************
\ Target specific words used by the compiler to complete compilation of
\ the the various types of library and target definitions.  These words
\ will need to be re-written when a new traget is being written.

\ ***************************************************************************
\                       Target Library words
\ ***************************************************************************

TARGET DEFINITIONS

\ ***************************************************************************
\ This macro puts a literal number on the data stack. The instructon
\ sequence used is not optimal, but is likely to be optimized later by the
\ automatic SAVE_BX optimizer.

MACRO (LIT)     ( n1 -- )       \ Special macro to compile an inline number
                SAVE_BX A;      \ to the stack.
                [FORTH]
                HERE-T IMM-HERE !
                [ASSEMBLER]
                MOV BX, #       END-MACRO

' (LIT) >EXECUTE IS COMP_SINGLE \ link into number compiler

MACRO ?BRANCH   ( -- )          \ compile a branch on true
                load_bx         a;
                JZ +BR# $       END-MACRO

' ?BRANCH >EXECUTE IS COMP_?BRANCH

MACRO BRANCHRES ( -- )
                JMP +BR# $      a;      \ compile branch, resolve later
                BR#SWAP
                -BR# DUP $: 01LAB       \ resolve branch from previous IF
                END-MACRO

' BRANCHRES >EXECUTE IS COMP_BRANCHRES

MACRO RESOLVE   ( -- )
                -BR# DUP $: 01LAB
                OPT_OFF1                \ disable optimization
                END-MACRO

' RESOLVE >EXECUTE IS COMP_RESOLVE

MACRO UNDO      ( --- )
                ADD SP, # 4     END-MACRO

MACRO %DO       ( l i -- )
                LODSW
                ADD AX, # $8000
                PUSH AX
                SUB BX, AX
                PUSH BX
                LOAD_BX
                +BR# $:
                OPT_OFF1        END-MACRO

MACRO I        ( -- n )
                SAVE_BX
                MOV DI, SP
                MOV BX, 0 [DI]
                ADD BX, 2 [DI]  END-MACRO

: DO            ( I-addr -- )
                F['] %do >execute execute
                F['] I   >execute execute
                comp_single comp_store ;

' DO IS COMP_DO

MACRO (LOOP)    ( -- )
                MOV DI, SP
                INC 0 [DI] WORD                 A;
                ?LONG
                [FORTH]
                IF      [ASSEMBLER]
                        JO here 5 +             A;      \ branch around JMP
                        JMP -BR# DUP $ WORD 01LAB   A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JNO -BR# DUP $  01LAB   A;
                        [FORTH]
                THEN    ?long_set
                [ASSEMBLER]     ?REOPT   END-MACRO

MACRO (+LOOP)   ( n -- )
                LODSW
                XCHG BX, AX
                MOV DI, SP
                ADD 0 [DI], AX                  A;
                ?LONG
                [FORTH]
                IF      [ASSEMBLER]
                        JO here 5 +             A;      \ branch around JMP
                        JMP -BR# DUP $ WORD 01LAB   A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JNO -BR# DUP $  01LAB   A;
                        [FORTH]
                THEN    ?long_set
                [ASSEMBLER]     ?REOPT   END-MACRO

\ : %LOOP         ( -- )
\                 F['] (LOOP) >EXECUTE EXECUTE
\                 F['] UNDO   >EXECUTE EXECUTE ;

: %+LOOP       ( -- )
                F['] (+LOOP) >EXECUTE EXECUTE
                F['] UNDO    >EXECUTE EXECUTE ;

' %+LOOP IS COMP_LOOP

\ **********************************************************************
\ Stack operators
\ **********************************************************************

MACRO SWAP      ( n1 n2 -- n2 n1 )
                XCHG 0 [SI], BX END-MACRO

' SWAP >EXECUTE IS COMP_SWAP            \ link into compiler

LCODE _ROT      ( n1 n2 n3 --- n2 n3 n1 )
                XCHG SI, SP
                POP DX
                POP AX
                PUSH DX
                XCHG BX, AX
                PUSH AX
                XCHG SI, SP
                RET             END-LCODE

I: ROT          ( -- )
                F['] _ROT RES_COMP_CALL ;

' ROT IS COMP_ROT                       \ link to compiler

LCODE _-ROT     ( n1 n2 n3 --- n3 n1 n2 )
                XCHG SI, SP
                POP AX
                POP DX
                XCHG BX, AX
                PUSH AX
                PUSH DX
                XCHG SI, SP
                RET             END-LCODE

I: -ROT         ( -- )
                F['] _-ROT RES_COMP_CALL ;

' -ROT IS COMP_-ROT                     \ link to compiler

\ **********************************************************************
\ Memory operators
\ **********************************************************************

MACRO @         ( addr -- n )
                AT_OPT          END-MACRO

' @ >EXECUTE IS COMP_FETCH              \ link into compiler

MACRO !         ( n addr -- )
                STORE_OPT
                LOAD_BX
                STORE_OPT2
                STORE_OPT2A
                STORE_OPT2B
                STORE_OPT3      END-MACRO

' ! >EXECUTE IS COMP_STORE      \ link to compiler

MACRO C@        ( addr -- char )
                CAT_OPT
                SUB BH, BH      END-MACRO

' C@ >EXECUTE IS COMP_CFETCH              \ link into compiler

MACRO C!        ( char addr -- )
                CSTORE_OPT
                LOAD_BX         END-MACRO

' C! >EXECUTE IS COMP_CSTORE      \ link to compiler

LCODE _C@L      ( seg addr -- byte )
                MOV DX, ES
                LODSW
                MOV ES, AX
                MOV BL, ES: 0 [BX]
                MOV ES, DX
                SUB BH, BH
                RET             END-LCODE

I: C@L          ( -- )
                F['] _C@L RES_COMP_CALL ;

' C@L IS COMP_CFETCHL                   \ link to compiler

LCODE _C!L      ( byte seg addr -- )
                MOV DX, ES
                LODSW           MOV ES, AX
                LODSW
                MOV ES: 0 [BX], AL
                MOV ES, DX
                LOAD_BX
                RET             END-LCODE

I: C!L          ( -- )
                F['] _C!L RES_COMP_CALL ;

' C!L IS COMP_CSTOREL                   \ link to compiler

\ **********************************************************************
\ Logical operators
\ **********************************************************************

MACRO NOT       ( n -- n' )
                NOT BX          END-MACRO

TARGET ' NOT >EXECUTE IS COMP_NOT         \ link to compiler

MACRO AND       ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                AND BX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                AND BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        AND BX, AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO

' AND >EXECUTE IS COMP_AND         \ link to compiler

MACRO OR        ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                OR BX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                OR BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        OR BX, AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO

' OR >EXECUTE IS COMP_OR        \ link to compiler

MACRO XOR       ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                XOR BX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                XOR BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        XOR BX, AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO

' XOR >EXECUTE IS COMP_XOR         \ link to compiler

\ **********************************************************************
\ Math opoerators
\ **********************************************************************

MACRO +         ( n1 n2 -- sum )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                ADD BX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                ADD BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        ADD BX, AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO

' + >EXECUTE IS COMP_+           \ link to compiler

MACRO -         ( n1 n2 -- n1-n2 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                SUB BX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                SUB BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        SUB AX, BX
                        MOV BX, AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO

' - >EXECUTE IS COMP_-           \ link to compiler

MACRO *         ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                MOV AX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV AX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        [FORTH]
                THEN
                [ASSEMBLER]
                MUL BX
                MOV BX, AX
                [TARGET]        END-MACRO

' * >EXECUTE IS COMP_*           \ link to compiler

LCODE _/        ( num den --- quot )
                LODSW
                CWD
                MOV CX, BX      XOR CX, DX
                [ASSEMBLER]
            0>= IF                              \ POSITIVE QUOTIENT CASE
                        IDIV BX
                ELSE
                        IDIV BX         OR DX, DX
                    0<> IF
                                DEC AX
                        THEN
                THEN
                MOV BX, AX      END-LCODE

I: /            ( -- )
                F['] _/ RES_COMP_CALL ;

' / IS COMP_/                           \ link to compiler

LCODE _MOD       ( num den --- rem )
                LODSW           CWD
                MOV CX, BX      XOR CX, DX
                [ASSEMBLER]
            0>= IF
                        IDIV BX
                ELSE
                        IDIV BX
                        OR DX, DX
                    0<> IF
                                ADD DX, BX
                        THEN
                THEN
                MOV BX, DX
                RET             END-LCODE

I: MOD          ( -- )
                F['] _MOD RES_COMP_CALL ;

' MOD IS COMP_MOD                       \ link to compiler

MACRO NEGATE    ( n -- n' )
                NEG BX          END-MACRO

' NEGATE >EXECUTE IS COMP_NEGATE        \ link to compiler

\ **********************************************************************
\ Port access
\ **********************************************************************

MACRO PC@       ( port# -- n )
                IMM_BEFORE
                [FORTH]
                IF      DUP 255 >
                        IF
                                [ASSEMBLER]
                                MOV DX, # ( xxxx )
                                IN AL, DX
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                IN AL, # ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        MOV DX, BX
                        IN AL, DX
                        [FORTH]
                THEN
                [ASSEMBLER]
                SUB AH, AH
                MOV BX, AX
                [TARGET]        END-MACRO

' PC@ >EXECUTE IS COMP_PC@         \ link to compiler

MACRO PC!       ( n port# -- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF      DUP 255 >
                                IF
                                        [ASSEMBLER]
                                        MOV AX, BX
                                        MOV DX, # ( xxxx )
                                        OUT DX, AL
                                        [FORTH]
                                ELSE
                                        [ASSEMBLER]
                                        MOV AX, BX
                                        OUT # ( xxxx ) AL
                                        [FORTH]
                                THEN
                        ELSE
                                [ASSEMBLER]
                                MOV AX, BX
                                MOV DX, ( xxxx )
                                OUT DX, AL
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        MOV DX, BX
                        LODSW
                        OUT DX, AL
                        [FORTH]
                THEN
                [ASSEMBLER]
                LOAD_BX
                [TARGET]        END-MACRO

' PC! >EXECUTE IS COMP_PC!              \ link to compiler

\ **********************************************************************
\ Comparison words
\ **********************************************************************

MACRO =         ( n1 n2 -- f )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                SUB BX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                SUB BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        SUB BX, AX
                        [FORTH]
                THEN
                [ASSEMBLER]
                SUB BX, # 1
                SBB BX, BX
                [TARGET]        END-MACRO

' = >EXECUTE IS COMP_=           \ link to compiler

MACRO <>        ( n1 n2 -- f )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<
                        IF
                                [ASSEMBLER]
                                SUB BX, # ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                SUB BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        SUB BX, AX
                        [FORTH]
                THEN
                [ASSEMBLER]
                NEG BX
                SBB BX, BX
                [TARGET]        END-MACRO

' <> >EXECUTE IS COMP_<>          \ link to compiler

MACRO <         ( n1 n2 -- f )
                LODSW
                MOV DI, # TRUE
                CMP AX, BX
                [ASSEMBLER]
             >= IF      SUB DI, DI
                THEN
                MOV BX, DI      END-MACRO

' < >EXECUTE IS COMP_<                  \ link to compiler

MACRO >         ( n1 n2 -- f )
                LODSW
                MOV DI, # TRUE
                CMP AX, BX
                [ASSEMBLER]
             <= IF      SUB DI, DI
                THEN
                MOV BX, DI      END-MACRO

' > >EXECUTE IS COMP_>                  \ link to compiler

: <=            ( n1 n2 -- f )
                f['] >   >execute execute
                f['] NOT >execute execute ;

' <= IS COMP_<=                         \ link to compiler

: >=            ( n1 n2 -- f )
                f['] <   >execute execute
                f['] NOT >execute execute ;

' >= IS COMP_>=                         \ link to compiler

LCODE BDOS2     ( CX DX AL -- CX DX AX )
                MOV AX, BX
                MOV DX, 0 [SI]
                MOV CX, 2 [SI]
                MOV AH, AL      INT $21
                MOV BX, AX
                MOV 0 [SI], DX
                MOV 2 [SI], CX
                RET             END-LCODE

L: OS2          BDOS2 255 AND L;

LCODE BDOS      ( DX AH -- AL )
                CMP BX, BP                      \ is function 0=terminate
             0= IF      JMP FINAL_EXIT          \ force use of normal exit
                THEN                            \ to restore vectors etc.
                LODSW
                MOV DX, AX
                MOV AH, BL
                INT $21
                SUB AH, AH
                MOV BX, AX
                RET             END-LCODE

\ L: DOSEMIT      ( c1 -- )
\                 6 BDOS DROP ( #OUT INCR ) L;

MACRO BYE       ( -- )
                JMP FINAL_EXIT  END-LCODE

LCODE KEY?      ( -- f1 )               \ BIOS KEY?, NO redirection!
\ Return a true flag if a key, other than control break, has been pressed.
                SAVE_BX
        BEGIN
                MOV AH, # 1
                PUSH SI         PUSH BP
                INT $16
                POP BP          POP SI
          0= IF
                SUB BX, BX
                RET
             THEN
                CMP AX, # 0     \ Ignore Control Break keys
     0= WHILE
                MOV AH, # 0     \ That is, throw them away
                PUSH SI         PUSH BP
                INT $16
                POP BP          POP SI
        REPEAT
                MOV BX, # -1
                RET             END-LCODE

LCODE BIOSKEY    ( -- c1 )
\ Return the value of the next key, other than control break.
                SAVE_BX
        BEGIN
                MOV AH, # 0
                PUSH SI         PUSH BP
                INT $16
                POP BP          POP SI
                CMP AX, # 0             \ Ignore Control BREAK, 00 Hex.
    0<> UNTIL
                MOV BX, AX
                RET             END-LCODE

L: BDOSKEY?     ( -- c1 )               \ DOS KEY?, redirectable
                255 6 BDOS $FF AND L;

: @INKEY        ( -- )
                [forth]
                token $? 0=
                if      -token
                then    F['] BDOSKEY? RES_COMP_CALL ;

MACRO BYE       ( -- )
                JMP FINAL_EXIT  END-MACRO

: @END          \ END           \ terminate the program
                F['] BYE >EXECUTE EXECUTE ;

