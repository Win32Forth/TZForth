\ LIBRARY.SEQ           Target Library Source           by Tom Zimmer

\ ***************************************************************************
\ Target specific words used by the compiler to complete compilation of
\ the the various types of library and target definitions.  These words
\ will need to be re-written when a new traget is being written.

\ ***************************************************************************
\                       Target Library words
\ ***************************************************************************

>LIBRARY

TARGET DEFINITIONS

\ ***************************************************************************
\ This macro puts a literal number on the data stack. The instructon
\ sequence used is not optimal, but is likely to be optimized later by the
\ automatic SAVE_BX optimizer.

MACRO (LIT)     ( n1 -- )       \ Special macro to compile an inline number
                SAVE_BX A;      \ to the stack.
                [FORTH]
                HERE-T IMM-HERE !
                HERE-T  6 -  @-T OVER  =
                HERE-T  7 - C@-T $BB   = AND    \ MOV BX, # xxxx
                HERE-T  4 -  @-T $4E4E = AND    \ 4E           DEC SI
                7 #?OPT                  AND    \ 4E           DEC SI
                0=                              \ 89 1C        MOV 0 [SI], BX
                IF      [ASSEMBLER]
                        MOV BX, #
                        [FORTH]
                ELSE    DROP
                THEN    [TARGET]        END-MACRO       NO-INTERPRET

' (LIT) >EXECUTE IS COMP_SINGLE \ link into number compiler

MACRO (LIT)AX   ( n1 -- )       \ Special macro to compile an inline number
                [FORTH]         \ to AX, used for CREATE|DOES> to save space
                HERE-T IMM-HERE !
                [ASSEMBLER]
                MOV AX, #       END-MACRO       NO-INTERPRET

' (LIT)AX >EXECUTE IS COMP_SINGLE_ALT   \ link into number compiler

CODE %EXEC:     ( n1 -- )       \ execute the n-th CALL following EXEC:
                                \ MUST be followed by CALL's, not MACROS
                MOV AX, BX              \ AX = BX
                SHL BX, # 1             \ BX * 2
                ADD AX, BX              \ BX + 1 equals n1*3
                POP DI                  \ get return address
                ADD DI, AX              \ offset to desired CALL
                INC DI                  \ step over the CALL opcode
                ADD DI, CS: 0 [DI]      \ add relative destination to pointer
                ADD DI, # 2             \ plus 2 to correct for relative CALL
                LOAD_BX                 \ reload BX
                JMP DI  END-CODE        \ and finally jump to function

FORTH   >FORTH

: EXEC:         ( | <name> -- a1 )
                [FORTH] ?LIB 0=
                IF      ON> EXEC:ING?   \ we used EXEC: in this definition
                        F['] %EXEC: RES_COMP_CALL
                ELSE    COMPILE %ON> F['] EXEC:ING? X,
                        COMPILE RES_COMP_CLL F['] %EXEC: X,
                THEN    ; IMMEDIATE

TARGET  >LIBRARY

ICODE BOUNDS    ( n1 n2 --- n3 n4 )  \ Calculate limits used in DO-loop
                XCHG SI, SP
                POP AX
                ADD BX, AX
                XCHG BX, AX
                PUSH AX
                XCHG SI, SP
                RET             END-ICODE

MACRO ?CS:      ( -- cs )       \ where the code is located.
                SAVE_BX
                MOV BX, CS      END-MACRO       EXECUTES> ?CS:

MACRO ?DS:      ( -- ds )       \ where all of our @(fetch) & !(store) data
                                \ is located.
                SAVE_BX
                MOV BX, DS      END-MACRO       NO-INTERPRET

MACRO DS:!      ( ds -- )       \ set DS to the value on the stack
                MOV DS, BX
                LOAD_BX         END-MACRO       NO-INTERPRET

MACRO DS:->SS:  ( -- )          \ set SS to DS
                MOV AX, DS
                MOV SS, AX      END-MACRO

MACRO EXIT      ( -- )          \ Terminate a high-level definition
                a; [FORTH]
                here-t !> opt_limit
                [ASSEMBLER]
                RET             END-MACRO       NO-INTERPRET

MACRO RECURSIVE ( -- )          \ Do nothing in TCOM, all words accessable
                END-MACRO       NO-INTERPRET

LMACRO ?EXIT     ( f1 -- )       \ If boolean f1 is true, exit from definition.
                ?0=IF_OPT
                MEMORY_IF_OPT   \ optimize IF preceeded by a MEMORY reference
                #=IF_OPT        \ optimize IF preceeded by a immediate compare
                [FORTH]
                IF      [ASSEMBLER]             \ if optimizing, use 0=?EXIT
                     0= IF      RET
                        THEN
                        [FORTH]
                ELSE    [ASSEMBLER]             \ else use ?EXIT
                    0<> IF      RET
                        THEN
                        [FORTH]
                THEN    [ASSEMBLER]
                ?REOPT   END-LMACRO       NO-INTERPRET

LMACRO BEGIN     ( -- )
                +BR# $:
                OPT_OFF1
                END-LMACRO       NO-INTERPRET

LMACRO AGAIN     ( -- )          \ an unconditional branch
                JMP -BR# DUP $ 01LAB WORD
                ?REOPT
                END-LMACRO       NO-INTERPRET

LMACRO IF        ( f -- )        \ branch if flag is zero
                ?0=IF_OPT       ( -- f1 )       \ if optimizing and preceeded
                MEMORY_IF_OPT   \ optimize IF preceeded by a MEMORY reference
                DUP_IF_OPT      \ optimize IF preceeded by a DUP
                #=IF_OPT        \ optimize IF preceeded by a immediate compare
                [FORTH]                         \ by 0=
        IF      ?LONG                           \ then use 0=IF instead of IF
                IF      [ASSEMBLER]
                        JZ here 5 +     A;      \ branch around JMP
                        JMP +BR# $ WORD A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JNZ +BR# $      A;
                        [FORTH]
                THEN
        ELSE    ?LONG                           \ else use IF
                IF      [ASSEMBLER]
                        JNZ here 5 +    A;      \ branch around JMP
                        JMP +BR# $ WORD A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JZ +BR# $       A;
                        [FORTH]
                THEN
        THEN    ?long_set
                [ASSEMBLER]     ?REOPT
                3                       \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

TARGET ' IF ALIAS WHILE     ( f1 -- )

LMACRO ELSE      ( -- )
                3 ?PAIRS                \ make sure conditionals match
                [FORTH]
                PREV_RET? 0=
        IF      ?LONG
                IF      [ASSEMBLER]
                        JMP +BR# $ WORD a;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JMP +BR# $      a;
                        [FORTH]
                THEN
        ELSE    [ASSEMBLER]
                +BR# DROP
                [FORTH]
        THEN    ?long_set
                [ASSEMBLER]
                BR#SWAP
                -BR# DUP $: 01LAB
                ( OPT_OFF1 )    ?REOPT
                4                       \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

LMACRO THEN      ( -- )          \ resolve branch
                drop                    \ discard conditional match value
                -BR# DUP $: 01LAB
                OPT_OFF1        END-LMACRO       NO-INTERPRET



TARGET ' THEN ALIAS ENDIF

FORTH   >FORTH

0 VALUE #CASES          \ a CASE counter

FORTH

I: %CASE        ( -- )
                [FORTH]
                OFF> #CASES ;

FORTH

: CASE          ( -- )
                [FORTH]
                ?LIB
                IF      COMPILE %CASE
                ELSE    %CASE
                THEN
                [TARGET]
                7                       \ for conditional branch matching
                ; IMMEDIATE

TARGET  >LIBRARY

LMACRO OF        ( n1 n2  -- n1 )  ( n1 n2 -- )
                [FORTH]
                7 ?pairs                \ conditional branch match check
                IMM/ABS_OPT ?DUP
                IF      0<              \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                CMP BX, # ( xxxx )      a;
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                CMP BX, ( xxxx )        a;
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW           a;
                        XCHG AX, BX     a;
                        CMP BX, AX      a;
                        [FORTH]
                THEN
\                INCR> #CASES                    \ bump number of cases
                ?LONG
                IF      [ASSEMBLER]
                        JZ here 5 +     A;      \ branch around JMP
                        JMP +BR# $ WORD A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JNZ +BR# $       A;
                        [FORTH]
                THEN    ?long_set
                [ASSEMBLER]
                LOAD_BX         ?REOPT
                8                       \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

LMACRO ENDOF     ( -- )
                8 ?pairs                \ conditional match check
                [FORTH]
                PREV_RET? 0=
        IF      [ASSEMBLER]
                JMP +BR# $ WORD A;
                [FORTH]
        ELSE    [ASSEMBLER]
                +BR# DROP
                [FORTH]
        THEN    [ASSEMBLER]
                BR#SWAP
                -BR# DUP $: 01LAB
                [FORTH]
                INCR> #CASES                    \ bump number of cases
                [assembler]
                ?REOPT
                7                       \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

LMACRO ENDCASE   ( -- )          \ resolve branch
                [FORTH]
                7 ?pairs                \ conditional match check
                #CASES  0               \ resolve #CASES case statments
                ?DO     [ASSEMBLER]
                        -BR# DUP $: 01LAB a;
                        [FORTH]
                LOOP
                OFF> #CASES
                [ASSEMBLER]
                OPT_OFF1        END-LMACRO       NO-INTERPRET

LMACRO EXITOF   ( -- )
                8 ?pairs                \ conditional match check
                tail_opt
                -BR# DUP $: 01LAB
                ?REOPT
                7                       \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

LMACRO REPEAT    ( -- )
                drop                    \ discard conditional match value
                BR#SWAP
                JMP -BR# DUP $  01LAB WORD A;   \ jump back
                    -BR# DUP $: 01LAB           \ resolve branch to here
                ?REOPT   END-LMACRO                       NO-INTERPRET

LMACRO UNTIL     ( f1 -- )
                ?0=IF_OPT
                MEMORY_IF_OPT   \ optimize IF preceeded by a MEMORY reference
                #=IF_OPT        \ optimize IF preceeded by a immediate compare
                [FORTH]
        IF      ?LONG
                here-t br# $ - 126 > or                 \ test for long needed
                IF      [ASSEMBLER]
                        JZ here 5 +    A;               \ branch around JMP
                        JMP -BR# DUP $ WORD 01LAB A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JNZ  -BR# DUP $  01LAB A;
                        [FORTH]
                THEN
        ELSE    ?LONG
                here-t br# $ - 126 > or                 \ test for long needed
                IF      [ASSEMBLER]
                        JNZ here 5 +    A;              \ branch around JMP
                        JMP -BR# DUP $ WORD 01LAB A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JZ  -BR# DUP $  01LAB A;
                        [FORTH]
                THEN
        THEN    ?long_set
                [ASSEMBLER]     ?REOPT   END-LMACRO       NO-INTERPRET

LMACRO FOR       ( n1 -- )
                PUSH BX
                LOAD_BX
                +BR# $:
                OPT_OFF1
                a; 5                    \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

LMACRO NEXT      ( -- )
                5 ?pairs                \ conditional match check
                POP CX
                [ASSEMBLER]
          CX<>0 IF
                        DEC CX
                        PUSH CX
                        JMP -BR# DUP $ 01LAB
                THEN            ?REOPT   END-LMACRO       NO-INTERPRET

LMACRO UNDO      ( --- )
                ADD SP, # 4     END-LMACRO       NO-INTERPRET

LMACRO DO        ( l i -- )
                [FORTH]
                ?DOING @
                IF      0 " DO's Nested in ?DO's are NOT ALLOWED!" "errmsg
                THEN
\                ?DOING   OFF
                [ASSEMBLER]
                LODSW
                ADD AX, # $8000
                PUSH AX
                SUB BX, AX
                PUSH BX
                LOAD_BX
                +BR# $:
                OPT_OFF1
                a; 6                    \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

LMACRO ?DO       ( l i -- )
                [FORTH]
                ?DOING @
                IF      0 " Nested ?DO's are NOT ALLOWED!" "errmsg
                THEN
                ?DOING ON
                [ASSEMBLER]
                MOV DI, BX
                LODSW           MOV DX, AX
                LOAD_BX
                CMP DX, DI              A;
                ?LONG   [FORTH]
                IF      [ASSEMBLER]
                        JNE here 5 +    A;      \ branch around JMP
                        JMP +BR# $ WORD A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JE +BR# $       A;
                        [FORTH]
                THEN    ?long_set
                [ASSEMBLER]
                ADD DX, # $8000
                PUSH DX
                SUB DI, DX
                PUSH DI
                +BR# $:
                OPT_OFF1
                a; 6                       \ for conditional branch matching
                END-LMACRO       NO-INTERPRET

LMACRO (LOOP)    ( -- )
                MOV DI, SP
                INC 0 [DI] WORD                 A;
                [FORTH]
                ?LONG
                here-t br# $ - 126 > or                 \ test for long needed
                IF      [ASSEMBLER]
                        JO here 5 +             A;      \ branch around JMP
                        JMP -BR# DUP $ WORD 01LAB   A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JNO -BR# DUP $  01LAB   A;
                        [FORTH]
                THEN    ?long_set
                [ASSEMBLER]     ?REOPT   END-LMACRO       NO-INTERPRET

LMACRO (+LOOP)   ( n -- )
                LODSW
                XCHG BX, AX
                MOV DI, SP
                ADD 0 [DI], AX                  A;
                [FORTH]
                ?LONG
                here-t br# $ - 126 > or                 \ test for long needed
                IF      [ASSEMBLER]
                        JO here 5 +             A;      \ branch around JMP
                        JMP -BR# DUP $ WORD 01LAB   A;
                        [FORTH]
                ELSE    [ASSEMBLER]
                        JNO -BR# DUP $  01LAB   A;
                        [FORTH]
                THEN    ?long_set
                [ASSEMBLER]     ?REOPT   END-LMACRO       NO-INTERPRET

LMACRO DO?       ( -- )
                -BR# DUP $: 01LAB
                [FORTH]
                ?DOING OFF      END-LMACRO       NO-INTERPRET

LMACRO LEAVE?    ( -- )
                127 DUP $: 01LAB
                [FORTH]
                ?LEAVING DECR   END-LMACRO       NO-INTERPRET

FORTH   >FORTH

I: %LOOP        ( -- )
                6 ?pairs                \ conditional match check
                F['] (LOOP) >EXECUTE EXECUTE
                [FORTH]
                ?LEAVING @
                IF      F['] LEAVE? >EXECUTE EXECUTE
                THEN
                [TARGET]
                F['] UNDO >EXECUTE EXECUTE
                [FORTH]
                ?DOING @
                IF      F['] DO? >EXECUTE EXECUTE
                THEN
                [TARGET] ;

FORTH

: LOOP          ( -- )
                [FORTH]
                ?LIB
                IF      COMPILE %LOOP
                ELSE    %LOOP
                THEN
                [TARGET] ; IMMEDIATE

FORTH

I: %+LOOP       ( -- )
                6 ?pairs                \ conditional match check
                F['] (+LOOP) >EXECUTE EXECUTE
                [FORTH]
                ?LEAVING @
                IF      F['] LEAVE? >EXECUTE EXECUTE
                THEN
                [TARGET]
                F['] UNDO >EXECUTE EXECUTE
                [FORTH]
                ?DOING @
                IF      F['] DO? >EXECUTE EXECUTE
                THEN
                [TARGET] ;

FORTH

: +LOOP         ( -- )
                [FORTH]
                ?LIB
                IF      COMPILE %+LOOP
                ELSE    %+LOOP
                THEN
                [TARGET] ; IMMEDIATE

TARGET  >LIBRARY

LMACRO LEAVE     ( -- )
                [FORTH]
                ?LEAVING INCR [ASSEMBLER]
                JMP 127 $ WORD    ?REOPT
                END-LMACRO       NO-INTERPRET

LMACRO ?LEAVE    ( f -- )
                [FORTH]
                ?LEAVING INCR [ASSEMBLER]
                LODSW
                XCHG BX, AX
                OR AX, AX               A;
                JE here 5 +             A;      \ branch around JMP
                JMP 127 $  WORD         A;
                [ASSEMBLER]     ?REOPT
                END-LMACRO       NO-INTERPRET

MACRO I        ( -- n )
                SAVE_BX
                MOV DI, SP
                MOV BX, 0 [DI]
                ADD BX, 2 [DI]  END-MACRO       NO-INTERPRET

MACRO J         ( -- n )
                SAVE_BX
                MOV DI, SP
                MOV BX, 4 [DI]
                ADD BX, 6 [DI]  END-MACRO       NO-INTERPRET

MACRO K         ( -- n )
                SAVE_BX
                MOV DI, SP
                MOV BX,  8 [DI]
                ADD BX, 10 [DI] END-MACRO       NO-INTERPRET

MACRO EXECUTE   ( cfa -- )
                [FORTH]
                IMM/ABS_OPT ?DUP                \ -1 or -2 treated the same
                IF      0<
                        IF                      \ Immediate
                                [ASSEMBLER]
                                CALL ( xxxx )
                                [FORTH]
                        ELSE                    \ absolute
                                [ASSEMBLER]
                                CALL [] ( xxxx )
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        XCHG BX, AX
                        CALL AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

MACRO PERFORM   ( addr-of-cfa -- )
                [FORTH]
                IMM/ABS_OPT ?DUP                \ -1 or -2 treated the same
                IF      0<
                        IF
                                [ASSEMBLER]
                                CALL [] ( xxxx )
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV DI, ( xxxx )
                                MOV AX, 0 [DI]
                                CALL AX
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        XCHG BX, AX
                        MOV DI, AX
                        MOV AX, 0 [DI]
                        CALL AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

' PERFORM >EXECUTE IS COMP_PERFORM      \ link into compiler

MACRO @         ( addr -- n )
                AT_OPT          END-MACRO       EXECUTES> @-D

' @ >EXECUTE IS COMP_FETCH              \ link into compiler

MACRO !         ( n addr -- )
                STORE_OPT
                LOAD_BX
                STORE_OPT2
                STORE_OPT2A'
                STORE_OPT2A
                STORE_OPT2B
                STORE_OPT3      END-MACRO       EXECUTES> !-D

' ! >EXECUTE IS COMP_STORE      \ link to compiler

COMPILER DEFINITIONS

MACRO %SAVE>R   ( a1 -- )
                MOV BX, 0 [BX]
                PUSH BX
                LOAD_BX         END-MACRO       NO-INTERPRET

' %SAVE>R >EXECUTE IS COMP_SAVE

MACRO %SAVE!>R  ( n1 a1 -- )
                MOV DI, BX
                MOV DI, 0 [DI]
                PUSH DI
                LODSW
                MOV 0 [BX], AX
                LOAD_BX         END-MACRO       NO-INTERPRET

' %SAVE!>R >EXECUTE IS COMP_SAVEST

MACRO %R>REST   ( a1 -- )
                POP AX
                MOV 0 [BX], AX
                LOAD_BX         END-MACRO       NO-INTERPRET

' %R>REST >EXECUTE IS COMP_REST

TARGET DEFINITIONS

ICODE 2!L       ( d seg off -- )
                XCHG SI, SP
                MOV DX, DS
                POP DS
                POP 0 [BX]
                POP 2 [BX]
                POP BX
                MOV DS, DX
                XCHG SI, SP
                RET             END-ICODE

ICODE 2@L       ( seg off -- d )
                XCHG SI, SP
                MOV DX, DS
                POP DS
                PUSH 2 [BX]
                MOV BX, 0 [BX]
                MOV DS, DX
                XCHG SI, SP
                RET             END-ICODE

ICODE @L        ( seg addr -- word )
                MOV DX, ES
                LODSW
                MOV ES, AX
                MOV BX, ES: 0 [BX]
                MOV ES, DX
                RET             END-ICODE

ICODE C@L       ( seg addr -- byte )
                MOV DX, ES
                LODSW
                MOV ES, AX
                MOV BL, ES: 0 [BX]
                MOV ES, DX
                SUB BH, BH
                RET             END-ICODE

ICODE C!L       ( byte seg addr -- )
                MOV DX, ES
                LODSW           MOV ES, AX
                LODSW
                MOV ES: 0 [BX], AL
                MOV ES, DX
                LOAD_BX
                RET             END-ICODE

ICODE !L        ( n1 seg addr -- )
                MOV DX, ES
                LODSW           MOV ES, AX
                LODSW
                MOV ES: 0 [BX], AX
                MOV ES, DX
                LOAD_BX
                RET             END-ICODE

MACRO C@        ( addr -- char )
                CAT_OPT
                SUB BH, BH      END-MACRO       EXECUTES> C@-D

MACRO C!        ( char addr -- )
                CSTORE_OPT
                LOAD_BX
                CSTORE_OPT2
                CSTORE_OPT2A
                END-MACRO       EXECUTES> C!-D

ICODE CMOVE     (  from to count -- )
                MOV CX, BX
                LODSW           MOV DI, AX
                LODSW           MOV BX, SI      MOV SI, AX
                MOV DX, ES      MOV AX, DS      MOV ES, AX
                TEST DI, # 1
                JZ 0 $
                JCXZ 0 $
                MOVSB
                DEC CX
        0 $:    SHR CX, # 1
                REPNZ           MOVSW
                RCL CX, # 1
                REPNZ           MOVSB
                MOV SI, BX      MOV ES, DX
                LOAD_BX
                RET             END-ICODE

ICODE CMOVE>    ( from to count -- )
                MOV CX, BX      DEC CX
                LODSW           MOV DI, AX
                LODSW           MOV BX, SI      MOV SI, AX
                ADD DI, CX      ADD IP, CX      INC CX
                MOV DX, ES      MOV AX, DS      MOV ES, AX
                STD
                REPNZ           MOVSB
                CLD
                MOV SI, BX      MOV ES, DX
                LOAD_BX
                RET             END-ICODE

ICODE PLACE     ( from cnt to -- )
                MOV DI, BX
                LODSW           MOV CX, AX
                LODSW           XCHG AX, SI
                MOV 0 [DI], CL
                INC DI
                CLD
                MOV DX, ES
                MOV BX, DS      MOV ES, BX
                TEST DI, # 1
                JZ 0 $
                JCXZ 0 $
                MOVSB
                DEC CX
        0 $:    SHR CX, # 1
                REPNZ           MOVSW
                RCL CX, # 1
                REPNZ           MOVSB
                MOV SI, AX
                MOV ES, DX
                LOAD_BX
                RET             END-ICODE

ICODE +PLACE    ( from cnt to -- )      \ append text to counted string
                MOV DI, BX
                LODSW           MOV CX, AX
                LODSW
                PUSH ES
                XCHG AX, SI
                SUB DX, DX
                MOV DL, 0 [DI]          \ pick up current length
                ADD 0 [DI], CL          \ adj current length plus cnt
                INC DI                  \ step to text start
                ADD DI, DX              \ adjust to current text end
                CLD
                MOV BX, DS      MOV ES, BX
                TEST DI, # 1
                JZ 0 $
                JCXZ 0 $
                MOVSB
                DEC CX
        0 $:    SHR CX, # 1
                REPNZ           MOVSW
                RCL CX, # 1
                REPNZ           MOVSB   \ append the text
                MOV SI, AX
                POP ES
                LOAD_BX
                RET             END-ICODE

CODE DEPTH      ( -- n1 )
                SAVE_BX
                MOV BX, SP0
                SUB BX, SI
                SAR BX, # 1
                DEC BX
                RET             END-CODE        EXECUTES> DEPTH

MACRO TIB       ( -- a1 )       \ Terminal Input Buffer address above stack
                SAVE_BX
                MOV BX, 'TIB    END-MACRO       EXECUTES> TIB

MACRO SP@       ( -- n )
                SAVE_BX
                MOV BX, SI      END-MACRO       NO-INTERPRET

MACRO SP!       ( n -- )
                MOV SI, BX
                SUB BX, BX      END-MACRO       NO-INTERPRET

MACRO RP@       ( -- addr )
                SAVE_BX
                MOV BX, SP      END-MACRO       NO-INTERPRET

MACRO RP!       ( n -- )
                MOV SP, BX
                LOAD_BX         END-MACRO       NO-INTERPRET

MACRO DROP      ( n1 -- )
                LOAD_BX         END-MACRO       EXECUTES> DROP

MACRO DUP       ( n1 -- n1 n1 )
                DEC SI
                DEC SI
                MOV 0 [SI], BX  END-MACRO       EXECUTES> DUP

MACRO SWAP      ( n1 n2 -- n2 n1 )
                XCHG 0 [SI], BX END-MACRO       EXECUTES> SWAP

MACRO OVER      ( n1 n2 -- n1 n2 n1 )
                SAVE_BX
                MOV BX, 2 [SI]  END-MACRO       EXECUTES> OVER


MACRO PLUCK     ( n1 n2 n3 --- n1 n2 n3 n1 )
                SAVE_BX
                MOV BX, 4 [SI]  END-MACRO       NO-INTERPRET

CODE TUCK       ( n1 n2 -- n2 n1 n2 )
                LODSW
                SUB SI, # 4
                MOV 2 [SI], BX
                MOV 0 [SI], AX
                RET             END-CODE        EXECUTES> TUCK

MACRO NIP       ( n1 n2 -- n2 )
                INC SI
                INC SI          END-MACRO       EXECUTES> NIP

CODE ROT        ( n1 n2 n3 --- n2 n3 n1 )
                XCHG SI, SP
                POP DX
                POP AX
                PUSH DX
                XCHG BX, AX
                PUSH AX
                XCHG SI, SP
                RET             END-CODE        EXECUTES> ROT

CODE -ROT       ( n1 n2 n3 --- n3 n1 n2 )
                XCHG SI, SP
                POP AX
                POP DX
                XCHG BX, AX
                PUSH AX
                PUSH DX
                XCHG SI, SP
                RET             END-CODE        EXECUTES> -ROT

MACRO FLIP      ( n1 -- n2 )
                XCHG BL, BH     END-MACRO       EXECUTES> FLIP

CODE SPLIT      ( n1 --- low high )     \ Splits n1 into two bytes
                MOV AX, BX
                SUB AH, AH
                DEC SI
                DEC SI
                MOV 0 [SI], AX
                MOV BL, BH
                MOV BH, AH
                RET             END-CODE        EXECUTES> SPLIT

CODE JOIN       ( low high -- n1 )      \ Join bytes into one word
                LODSW
                MOV AH, BL
                MOV BX, AX
                RET             END-CODE        EXECUTES> JOIN

MACRO ?DUP      ( n1 -- [n1] n1 )
                MOV CX, BX
                [ASSEMBLER]
          CX<>0 IF      DEC SI
                        DEC SI
                        MOV 0 [SI], BX
                THEN
                OPT_OFF1
                END-MACRO       EXECUTES> ?DUP

MACRO R>        ( -- n )
                SAVE_BX
                POP BX          END-MACRO       EXECUTES> R>

IMACRO R>DROP   ( --- )
\                ADD SP, # 2
                INC SP
                INC SP          END-IMACRO

IMACRO DUP>R    ( n1 --- n1 )
                PUSH BX         END-IMACRO

MACRO >R        ( n -- )
                PUSH BX
                LOAD_BX         END-MACRO       EXECUTES> >R

IMACRO 2R>      ( -- n1 n2 )
                SUB SI, # 4
                MOV 2 [SI], BX
                POP BX
                POP AX
                MOV 0 [SI], AX  END-IMACRO

IMACRO 2>R      ( n1 n2 -- )
                XCHG SI, SP
                SUB SI, # 4
                MOV 0 [SI], BX
                POP 2 [SI]
                POP BX
                XCHG SI, SP     END-IMACRO

MACRO R@        ( -- n )
                XCHG SI, SP
                PUSH BX
                MOV BX, 0 [SI]
                XCHG SI, SP     END-MACRO       EXECUTES> R@

IMACRO 2R@      ( -- n1 n2 )
                XCHG SI, SP
                PUSH BX
                PUSH 2 [SI]
                MOV BX, 0 [SI]
                XCHG SI, SP     END-IMACRO

MACRO PICK      ( nm ... n2 n1 k -- nm ... n2 n1 nk )
                SHL BX, # 1
                ADD BX, SI
                MOV BX, 0 [BX]  END-MACRO       NO-INTERPRET

IMACRO RPICK    ( nm ... n2 n1 k -- nm ... n2 n1 nk )
                SHL BX, # 1
                ADD BX, SP
                MOV BX, 0 [BX]  END-IMACRO

MACRO AND       ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      dup 0<
                        IF      -1 =
                                IF      [ASSEMBLER]
                                        AND BX, # ( xxxx )
                                        [FORTH]
                                ELSE    HERE-T 2- @-T AND  \ do it at compile
                                        HERE-T 2- %!-T     \ time
                                THEN
                        ELSE    drop
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
                [TARGET]        END-MACRO       EXECUTES> AND

MACRO OR        ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      dup 0<
                        IF      -1 =
                                IF      [ASSEMBLER]
                                        OR BX, # ( xxxx )
                                        [FORTH]
                                ELSE    HERE-T 2- @-T OR   \ do it at compile
                                        HERE-T 2- %!-T     \ time
                                THEN
                        ELSE    drop
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
                [TARGET]        END-MACRO       EXECUTES> OR

MACRO NOT       ( n -- n' )
                NOT BX          END-MACRO       EXECUTES> NOT

IMACRO CSET     ( b addr -- )
                LODSW
                OR 0 [BX], AL
                LOAD_BX         END-IMACRO

IMACRO CRESET   ( b addr -- )
                LODSW
                NOT AX
                AND 0 [BX], AL
                LOAD_BX         END-IMACRO

IMACRO CTOGGLE  ( b addr -- )
                LODSW
                XOR 0 [BX], AL
                LOAD_BX         END-IMACRO

MACRO ON        ( addr -- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                MOV ( xxxx ) # TRUE WORD
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV DI, ( xxxx )
                                MOV 0 [DI], # TRUE WORD
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        MOV 0 [BX], # TRUE WORD
                        LOAD_BX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

' ON  >EXECUTE IS COMP_ON         \ link to compiler

MACRO OFF       ( addr -- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                MOV ( xxxx ) BP
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV DI, ( xxxx )
                                MOV 0 [DI], BP
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        MOV 0 [BX], BP          \ BP is always FALSE
                        LOAD_BX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

' OFF >EXECUTE IS COMP_OFF        \ link to compiler

MACRO INCR      ( addr --- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                INC ( xxxx ) WORD
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV DI, ( xxxx )
                                INC 0 [DI] WORD
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        INC 0 [BX] WORD
                        LOAD_BX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

' INCR >EXECUTE IS COMP_INCR       \ link to compiler

MACRO DECR      ( addr --- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                DEC ( xxxx ) WORD
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV DI, ( xxxx )
                                DEC 0 [DI] WORD
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        DEC 0 [BX] WORD
                        LOAD_BX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

' DECR >EXECUTE IS COMP_DECR       \ link to compiler

MACRO +         ( n1 n2 -- sum )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      dup 0<
                        IF      -1 =
                                IF      dup 1 =
                                        IF      drop
                                                [ASSEMBLER]
                                                INC BX
                                                [FORTH]
                                                here-t 1- =: opt_limit
                                        ELSE    [ASSEMBLER]
                                                ADD BX, # ( xxxx )
                                                [FORTH]
                                        THEN
                                ELSE    HERE-T 2- @-T +   \ do it at compile
                                        HERE-T 2- %!-T    \ time
                                THEN
                        ELSE    drop
                                [ASSEMBLER]
                                ADD BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE    OVER_OPT
                        IF      [ASSEMBLER]
                                ADD BX, 0 [SI]
                                [FORTH]
                        ELSE    [ASSEMBLER]
                                LODSW
                                ADD BX, AX
                                [FORTH]
                        THEN
                THEN
                [TARGET]        END-MACRO       EXECUTES> +


MACRO NEGATE    ( n -- n' )
                NEG BX          END-MACRO       EXECUTES> NEGATE

MACRO -         ( n1 n2 -- n1-n2 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      dup 0<
                        IF      -1 =
                                IF      dup 1 =
                                        IF      drop
                                                [ASSEMBLER]
                                                DEC BX
                                                [FORTH]
                                        ELSE    [ASSEMBLER]
                                                SUB BX, # ( xxxx )
                                                [FORTH]
                                        THEN
                                ELSE    HERE-T 2- @-T SWAP -
                                                        \ do it at compile
                                        HERE-T 2- %!-T  \ time
                                THEN
                        ELSE    drop
                                [ASSEMBLER]
                                SUB BX, ( xxxx )
                                [FORTH]
                        THEN
                ELSE    OVER_OPT
                        IF      [ASSEMBLER]
                                SUB BX, 0 [SI]
                                [FORTH]
                        ELSE    [ASSEMBLER]
                                LODSW
                                SUB AX, BX
                                MOV BX, AX
                                [FORTH]
                        THEN
                THEN
                [TARGET]        END-MACRO       EXECUTES> -

MACRO ABS       ( n1 -- n2 )
                MOV AX, BX
                CWD
                XOR AX, DX
                SUB AX, DX
                MOV BX, AX      END-MACRO       EXECUTES> ABS

ICODE D+!       ( d addr -- )
                XCHG SI, SP
                POP AX          POP DX
                ADD 2 [BX], DX
                ADC 0 [BX], AX
                POP BX
                XCHG SI, SP
                RET             END-ICODE

MACRO +!        ( n addr -- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                ADD ( xxxx ) BX
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV DI, ( xxxx )
                                ADD 0 [DI], BX
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        ADD 0 [BX], AX
                        [FORTH]
                THEN
                LOAD_BX
                [TARGET]        END-MACRO       NO-INTERPRET

' +!   >EXECUTE IS COMP_PSTORE     \ link to compiler

MACRO C+!       ( n addr -- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                ADD ( xxxx ) BL
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV DI, ( xxxx )
                                ADD 0 [DI], BL
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        ADD 0 [BX], AL
                        [FORTH]
                THEN
                LOAD_BX         END-MACRO       NO-INTERPRET

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
                [TARGET]        END-MACRO       NO-INTERPRET

MACRO P@        ( port# -- n )
                IMM_BEFORE
                [FORTH]
                IF      DUP 255 >
                        IF
                                [ASSEMBLER]
                                MOV DX, # ( xxxx )
                                IN AX, DX
                                MOV BX, AX
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                IN AX, # ( xxxx )
                                MOV BX, AX
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        MOV DX, BX
                        IN AX, DX
                        MOV BX, AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

MACRO PC!       ( n port# -- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
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
                [TARGET]        END-MACRO       NO-INTERPRET

MACRO P!        ( n port# -- )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF      DUP 255 >
                                IF
                                        [ASSEMBLER]
                                        MOV AX, BX
                                        MOV DX, # ( xxxx )
                                        OUT DX, AX
                                        [FORTH]
                                ELSE
                                        [ASSEMBLER]
                                        MOV AX, BX
                                        OUT # ( xxxx ) AX
                                        [FORTH]
                                THEN
                        ELSE
                                [ASSEMBLER]
                                MOV AX, BX
                                MOV DX, ( xxxx )
                                OUT DX, AX
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        MOV DX, BX
                        LODSW
                        OUT DX, AX
                        [FORTH]
                THEN
                [ASSEMBLER]
                LOAD_BX
                [TARGET]        END-MACRO       NO-INTERPRET

ICODE PDOS      ( addr drive# --- f1 )  \ get current directory to addr
                                        \ return f1 true if failed
                MOV DX, BX
                LODSW
                PUSH SI         MOV SI, AX
                MOV AH, # $47   INT $21
                [ASSEMBLER]
             U< IF
                        MOV AL, # 1
                ELSE
                        SUB AL, AL
                THEN
                SUB AH, AH      POP SI
                MOV BX, AX
                RET             END-ICODE

MACRO 2*        ( n -- 2*n )
                SHL BX, # 1     END-MACRO       EXECUTES> 2*

MACRO 4*        ( n -- 2*n )
                SHL BX, # 1
                SHL BX, # 1     END-MACRO       NO-INTERPRET

MACRO 2/        ( n -- n/2 )
                SAR BX, # 1     END-MACRO       EXECUTES> 2/

MACRO U2/       ( u -- u/2 )
                SHR BX, # 1     END-MACRO       EXECUTES> U2/

CODE U16/       ( u -- u/16 )
                SHR BX, # 1     SHR BX, # 1
                SHR BX, # 1     SHR BX, # 1
                RET             END-CODE        EXECUTES> U16/

CODE UD16/      ( d -- d/16 )   \ 32 bit UNSIGNED right shift 4 bits
                MOV DX, 0 [SI]
                SHR BX, # 1     RCR DX, # 1
                SHR BX, # 1     RCR DX, # 1
                SHR BX, # 1     RCR DX, # 1
                SHR BX, # 1     RCR DX, # 1
                MOV 0 [SI], DX
                RET             END-CODE

CODE U8/        ( u -- u/8 )
                SHR BX, # 1
                SHR BX, # 1
                SHR BX, # 1
                RET             END-CODE        EXECUTES> U8/

CODE 8*         ( n -- 8*n )
                SHL BX, # 1
                SHL BX, # 1
                SHL BX, # 1
                RET             END-CODE        EXECUTES> 8*

\ MACRO 1+        ( n1 --- n2 )
\                 INC BX          END-MACRO       EXECUTES> 1+

M: 1+           ( n1 -- n2 )
                1 + ;           EXECUTES> 1+

\ MACRO 2+        ( n1 --- n2 )
\                 ADD BX, # 2     END-MACRO       EXECUTES> 2+

M: 2+           ( n1 -- n2 )
                2 + ;           EXECUTES> 2+

\ MACRO 1-        ( n1 --- n2 )
\                 DEC BX          END-MACRO       EXECUTES> 1-

M: 1-           ( n1 -- n2 )
                1 - ;           EXECUTES> 1-

\ MACRO 2-        ( n1 --- n2 )
\                 SUB BX, # 2     END-MACRO       EXECUTES> 2-

M: 2-           ( n1 -- n2 )
                2 - ;           EXECUTES> 2-

CODE UM*        ( n1 n2 -- d )
                MOV AX, 0 [SI]
                MUL BX
                MOV 0 [SI], AX
                XCHG BX, DX
                RET             END-CODE        EXECUTES> UM*

MACRO *         ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      dup 0<
                        IF      -1 =
                                IF      [ASSEMBLER]
                                        MOV AX, # ( xxxx )
                                        MUL BX
                                        MOV BX, AX
                                        [FORTH]
                                ELSE    HERE-T 2- @-T *   \ do it at compile
                                        HERE-T 2- %!-T    \ time
                                THEN
                        ELSE    drop
                                [ASSEMBLER]
                                MOV AX, ( xxxx )
                                MUL BX
                                MOV BX, AX
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        MUL BX
                        MOV BX, AX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       EXECUTES> *

M: U*D          ( n1 n2 -- d )
                UM*   ;                         NO-INTERPRET

CODE UM/MOD    ( ud un -- URemainder UQuotient )
                NO_INLINE
                XCHG SI, SP
                POP DX
                POP AX
                CMP DX, BX
                [ASSEMBLER]
            U>= IF                      \ divide by zero?
                        MOV AX, # -1
                        MOV DX, AX
                        PUSH DX
                        MOV BX, AX
                        XCHG SI, SP
                        RET
                THEN
                DIV BX
                PUSH DX
                MOV BX, AX
                XCHG SI, SP
                RET             END-CODE        EXECUTES> UM/MOD

MACRO 0=        ( n -- f )
                SUB BX, # 1
                SBB BX, BX      END-MACRO       EXECUTES> 0=

MACRO 0<        ( n -- f )
                MOV AX, BX
                CWD
                MOV BX, DX      END-MACRO       EXECUTES> 0<

CODE 0>        ( n -- f )
                NO_INLINE
                MOV AX, BX
                NEG AX
                [ASSEMBLER]
           OV<> IF      CWD
                        MOV BX, DX
                        RET
                THEN
                SUB BX, BX
                RET             END-CODE

IMACRO 0<>      ( n -- f )
                NEG BX
                SBB BX, BX      END-IMACRO

MACRO =         ( n1 n2 -- f )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
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
                [TARGET]        END-MACRO       NO-INTERPRET

MACRO <>        ( n1 n2 -- f )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
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
                [TARGET]        END-MACRO       NO-INTERPRET

: ?NEGATE       ( n1 n2 -- n3 )
                0< IF    NEGATE   THEN   ;      NO-INTERPRET

MACRO U<        ( n1 n2 -- f )
                LODSW
                SUB AX, BX
                SBB AX, AX
                MOV BX, AX      END-MACRO       NO-INTERPRET

MACRO U>        ( n1 n2 -- f )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<                      \ -1 or -2 treated the same
                        IF
                                [ASSEMBLER]
                                MOV AX, # ( xxxx )
                                SUB AX, BX
                                SBB AX, AX
                                MOV BX, AX
                                [FORTH]
                        ELSE
                                [ASSEMBLER]
                                MOV AX, ( xxxx )
                                SUB AX, BX
                                SBB AX, AX
                                MOV BX, AX
                                [FORTH]
                        THEN
                ELSE
                        [ASSEMBLER]
                        LODSW
                        SUB BX, AX
                        SBB BX, BX
                        [FORTH]
                THEN
                [TARGET]        END-MACRO       NO-INTERPRET

ICODE <         ( n1 n2 -- f )
                LODSW
                MOV DI, # TRUE
                CMP AX, BX
                [ASSEMBLER]
             >= IF      SUB DI, DI
                THEN
                MOV BX, DI
                RET             END-ICODE

ICODE >         ( n1 n2 -- f )
                LODSW
                MOV DI, # TRUE
                CMP AX, BX
                [ASSEMBLER]
             <= IF      SUB DI, DI
                THEN
                MOV BX, DI
                RET             END-ICODE

CODE _UMIN      ( n1 n2 -- n3 )
                LODSW
                CMP BX, AX
                [ASSEMBLER]
             U> IF      MOV BX, AX
                THEN
                RET             END-CODE

MACRO UMIN      ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<              \ -1 or -2 treated the same
                        IF      >R
                                [ASSEMBLER]
                                CMP BX, # R@ ( xxxx )           A;
                             U> IF      MOV BX, # R> ( xxxx )   A;
                                THEN
                                [FORTH]
                        ELSE    >R
                                [ASSEMBLER]
                                CMP BX, R@ ( xxxx )             A;
                             U> IF      MOV BX, R> ( xxxx )     A;
                                THEN
                                [FORTH]
                        THEN    OPT_OFF1
                ELSE    F['] _UMIN RES_COMP_CALL
                THEN    [TARGET] END-MACRO

CODE _MIN       ( n1 n2 -- n3 )
                LODSW
                CMP BX, AX
                [ASSEMBLER]
              > IF      MOV BX, AX
                THEN
                RET             END-CODE

MACRO MIN       ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<              \ -1 or -2 treated the same
                        IF      >R
                                [ASSEMBLER]
                                CMP BX, # R@ ( xxxx )           A;
                              > IF      MOV BX, # R> ( xxxx )   A;
                                THEN
                                [FORTH]
                        ELSE    >R
                                [ASSEMBLER]
                                CMP BX, R@ ( xxxx )             A;
                              > IF      MOV BX, R> ( xxxx )     A;
                                THEN
                                [FORTH]
                        THEN    OPT_OFF1
                ELSE    F['] _MIN RES_COMP_CALL
                THEN    [TARGET] END-MACRO

CODE _MAX       ( n1 n2 -- n3 )
                LODSW
                CMP BX, AX
                [ASSEMBLER]
             <= IF      MOV BX, AX
                THEN
                RET             END-CODE

MACRO MAX       ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<              \ -1 or -2 treated the same
                        IF      >R
                                [ASSEMBLER]
                                CMP BX, # R@ ( xxxx )           A;
                             <= IF      MOV BX, # R> ( xxxx )   A;
                                THEN
                                [FORTH]
                        ELSE    >R
                                [ASSEMBLER]
                                CMP BX, R@ ( xxxx )             A;
                             <= IF      MOV BX, R> ( xxxx )     A;
                                THEN
                                [FORTH]
                        THEN    OPT_OFF1
                ELSE    F['] _MAX RES_COMP_CALL
                THEN    [TARGET] END-MACRO

IMACRO 0MAX     ( n1 -- n3 )
                [ASSEMBLER]
                CMP BX, BP
             <= IF      SUB BX, BX
                THEN            END-IMACRO

CODE _UMAX      ( n1 n2 -- n3 )
                [ASSEMBLER]
                LODSW
                CMP BX, AX
            U<= IF      MOV BX, AX
                THEN
                RET             END-CODE

MACRO UMAX      ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      0<              \ -1 or -2 treated the same
                        IF      >R
                                [ASSEMBLER]
                                CMP BX, # R@ ( xxxx )           A;
                            U<= IF      MOV BX, # R> ( xxxx )   A;
                                THEN
                                [FORTH]
                        ELSE    >R
                                [ASSEMBLER]
                                CMP BX, R@ ( xxxx )             A;
                            U<= IF      MOV BX, R> ( xxxx )     A;
                                THEN
                                [FORTH]
                        THEN    OPT_OFF1
                ELSE    F['] _UMAX RES_COMP_CALL
                THEN    [TARGET] END-MACRO

ICODE WITHIN    ( n lo hi -- flag )
                [ASSEMBLER]
                MOV DI, BX
                LODSW
                MOV CX, AX
                LODSW
                SUB BX, BX
                CMP AX, DI
              < IF      CMP AX, CX
                     >= IF      DEC BX
                        THEN
                THEN
                RET             END-ICODE

ICODE BETWEEN   ( n lo hi -- flag )
                [ASSEMBLER]
                MOV DX, BX
                LODSW
                MOV CX, AX
                LODSW
                SUB BX, BX
                CMP AX, DX
             <= IF      CMP AX, CX
                     >= IF      DEC BX
                        THEN
                THEN
                RET             END-ICODE

ICODE UBETWEEN  ( n ulo uhi -- flag )
                [ASSEMBLER]
                MOV DX, BX
                LODSW
                MOV CX, AX
                LODSW
                SUB BX, BX
                CMP AX, DX
            U<= IF      CMP AX, CX
                    U>= IF      DEC BX
                        THEN
                THEN
                RET             END-ICODE

$FFFF CONSTANT TRUE
$0000 CONSTANT FALSE

ICODE 2@        ( addr -- d )
                XCHG SI, SP
                PUSH 2 [BX]
                MOV BX, 0 [BX]
                XCHG SI, SP
                RET             END-ICODE

ICODE 2!        ( d addr -- )
                XCHG SI, SP
                POP 0 [BX]
                POP 2 [BX]
                POP BX
                XCHG SI, SP
                RET             END-ICODE

MACRO 2DROP     ( d -- )
                INC SI
                INC SI
                LOAD_BX         END-MACRO       EXECUTES> 2DROP

IMACRO 3DROP    ( n1 n2 n3 -- )
                ADD SI, # 4
                LOAD_BX         END-IMACRO

CODE 2DUP       ( d -- d d )
                XCHG SI, SP
                MOV DI, SP
                PUSH BX
                PUSH 0 [DI]
                XCHG SI, SP
                RET             END-CODE        EXECUTES> 2DUP

ICODE 3DUP      ( n1 n2 n3 -- n1 n2 n3 n1 n2 n3 )
                XCHG SI, SP
                MOV DI, SP
                PUSH BX
                PUSH 2 [DI]
                PUSH 0 [DI]
                XCHG SI, SP
                RET             END-ICODE

ICODE 2SWAP     ( d1 d2 -- d2 d1 )
                XCHG SI, SP
                POP CX          XCHG BX, CX
                POP AX          POP DX
                PUSH BX         PUSH CX
                PUSH DX
                MOV BX, AX
                XCHG SI, SP
                RET             END-ICODE

ICODE 2OVER     ( d1 d2 -- d1 d2 d1 )
                XCHG SI, SP
                MOV DI, SP
                PUSH BX
                PUSH 4 [DI]
                MOV BX, 2 [DI]
                XCHG SI, SP
                RET             END-ICODE

ICODE D+        ( d1 d2 -- dsum )
                MOV DX, BX
                LODSW
                ADD 2 [SI], AX
                LOAD_BX
                ADC BX, DX
                RET             END-ICODE

IMACRO DNEGATE  ( d# -- d#' )
                NEG BX
                NEG 0 [SI] WORD
                SBB BX, BP      END-IMACRO

CODE S>D        ( n -- d )
                MOV AX, BX
                CWD
                DEC SI
                DEC SI
                MOV 0 [SI], AX
                MOV BX, DX
                RET             END-CODE        EXECUTES> S>D

ICODE DABS      ( d1 -- d2 )
                [ASSEMBLER]
                OR BX, BP
             0< IF      NEG BX
                        NEG 0 [SI] WORD
                        SBB BX, BP
                THEN
                RET             END-ICODE

IMACRO D2*      ( d -- d*2 )
                SHL 0 [SI], # 1 WORD
                RCL BX, # 1     END-IMACRO

IMACRO D2/      ( d -- d/2 )
                SAR BX, # 1
                RCR 0 [SI], # 1 WORD
                END-IMACRO

M: D-           ( d1 d2 -- d3 )
                DNEGATE D+   ;                  NO-INTERPRET

: ?DNEGATE      ( d1 n -- d2 )
                0< IF   DNEGATE   THEN   ;      NO-INTERPRET

M: D0=          ( d -- f )
                OR 0= ;                         NO-INTERPRET

M: D=           ( d1 d2 -- f )
                D-  D0=  ;                      NO-INTERPRET

: DU<           ( ud1 ud2 -- f )
                ROT SWAP 2DUP U<
                IF      2DROP 2DROP TRUE
                ELSE    <> IF   2DROP FALSE  ELSE  U<  THEN
                THEN  ;                         NO-INTERPRET

: D<            ( d1 d2 -- f )
                2 PICK OVER =
                IF      DU<
                ELSE  NIP ROT DROP <  THEN  ;   NO-INTERPRET

M: D>           ( d1 d2 -- f )
                2SWAP D<   ;                    NO-INTERPRET

M: 4DUP         ( a b c d -- a b c d a b c d )
                2OVER 2OVER   ;                 NO-INTERPRET

: DMIN          ( d1 d2 -- d3 )
                4DUP D> IF  2SWAP  THEN 2DROP ; NO-INTERPRET

: DMAX          ( d1 d2 -- d3 )
                4DUP D< IF 2SWAP THEN 2DROP ;   NO-INTERPRET

ICODE *D        ( n1 n2 -- d# )
                MOV AX, 0 [SI]
                IMUL BX
                MOV 0 [SI], AX
                MOV BX, DX
                RET             END-ICODE

: MU/MOD        ( ud# un1 -- rem d#quot )
                >R  0  R@  UM/MOD  R>  SWAP  >R  UM/MOD  R>   ;
                                                EXECUTES> MU/MOD

CODE  /         ( num den --- quot )
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
                MOV BX, AX
                RET             END-CODE        EXECUTES> /

ICODE /MOD      ( num den --- rem quot )
                MOV AX, 0 [SI]  CWD
                MOV CX, BX      XOR CX, DX
                [ASSEMBLER]
            0>= IF
                        IDIV BX
                ELSE
                        IDIV BX
                        OR DX, DX
                    0<> IF
                                ADD DX, BX
                                DEC AX
                        THEN
                THEN
                MOV 0 [SI], DX
                MOV BX, AX
                RET             END-ICODE

M: MOD          ( n1 n2 -- rem )
                /MOD  DROP  ;                   EXECUTES> MOD

ICODE */MOD     ( n1 n2 n3 --- rem quot )
                XCHG SI, SP
                POP AX          POP CX
                IMUL CX         MOV CX, BX
                XOR CX, DX
                [ASSEMBLER]
            0>= IF
                        IDIV BX
                ELSE
                        IDIV BX
                        OR DX, DX
                    0<> IF
                                ADD DX, BX
                                DEC AX
                        THEN
                THEN
                PUSH DX
                MOV BX, AX
                XCHG SI, SP
                RET             END-ICODE

MACRO XOR       ( n1 n2 -- n3 )
                [FORTH]
                IMM/ABS_OPT ?DUP
                IF      dup 0<
                        IF      -1 =
                                IF      [ASSEMBLER]
                                        XOR BX, # ( xxxx )
                                        [FORTH]
                                ELSE    HERE-T 2- @-T XOR \ do it at compile
                                        HERE-T 2- %!-T    \ time
                                THEN
                        ELSE    drop
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
                [TARGET]        END-MACRO       EXECUTES> XOR

: M/MOD         ( d# n1 -- rem quot )
                ?DUP 0= ?EXIT
                DUP>R  2DUP XOR >R  >R DABS R@ ABS  UM/MOD
                SWAP R> ?NEGATE
                SWAP R> 0<
                IF      NEGATE OVER
                        IF  1- R@ ROT - SWAP  THEN
                THEN    R>DROP ;                NO-INTERPRET

M: */           ( n1 n2 n3 -- n1*n2/n3 )
                */MOD  NIP  ;                   NO-INTERPRET

: ROLL          ( n1 n2 .. nk k -- n2 n3 .. nk n1 )
                >R R@ PICK   SP@ DUP 2+   R> 1+ 2* CMOVE>  DROP  ;
                                                NO-INTERPRET
: 2ROT          ( a b c d e f - c d e f a b )
                5 ROLL  5 ROLL  ;               NO-INTERPRET

ICODE FILL      (  start-addr count char -- )
                XCHG SI, SP
                MOV AX, BX
                CLD             MOV BX, DS
                POP CX          POP DI
                XCHG SI, SP
                PUSH ES         MOV ES, BX
                REPNZ           STOSB           POP ES
                LOAD_BX
                RET             END-ICODE

ICODE LFILL     (  seg start-addr count char -- )
                XCHG SI, SP
                CLD
                MOV AX, BX      POP CX
                POP DI          POP BX
                XCHG SI, SP
                PUSH ES         MOV ES, BX
                REPNZ           STOSB           POP ES
                LOAD_BX
                RET             END-ICODE

ICODE LFILLW    (  seg start-addr BYTE-count WORD -- )
                SAVE_BX
                XCHG SI, SP
                CLD             POP AX
                POP CX
                SHR CX, # 1
                POP DI          POP BX
                MOV DX, ES      MOV ES, BX
                REPNZ           STOSW
                MOV ES, DX
                XCHG SI, SP
                LOAD_BX
                RET             END-ICODE

: ERASE         ( addr len -- )
                0 FILL   ;                      NO-INTERPRET

$20 CONSTANT BL                 \ a blank
$80 CONSTANT DOS_CMD_TAIL       \ DOS command line pointer in ?CS: space

: BLANK         ( addr len -- )
                BL FILL   ;                     NO-INTERPRET

CODE COUNT      ( a1 --- a2 n1 )
                SUB AX, AX
                MOV AL, 0 [BX]
                INC BX
                DEC SI
                DEC SI
                MOV 0 [SI], BX
                MOV BX, AX
                RET             END-CODE        EXECUTES> COUNT-D

ICODE COUNTL    ( seg addr -- seg addr+1 len )
                MOV AX, 0 [SI]
                MOV DX, DS      MOV DS, AX
                XOR AX, AX      MOV AL, 0 [BX]
                INC BX
                MOV DS, DX
                DEC SI
                DEC SI
                MOV 0 [SI], BX
                MOV BX, AX
                RET             END-ICODE

ICODE LENGTH    ( a1 --- a2 n1 )
                MOV AX, 0 [BX]
                INC BX
                INC BX
                DEC SI
                DEC SI
                MOV 0 [SI], BX
                MOV BX, AX
                RET             END-ICODE

ICODE CMOVEL    ( sseg sptr dseg dptr cnt -- )
                PUSH DS
                PUSH ES
                XCHG SI, SP
                MOV CX, BX              \ count to CX
                MOV BX, SI              \ preserve SI
                CLD
                POP DI
                POP ES          POP SI
                POP DS
\                TEST DI, # 1
\                JZ 0 $
\                JCXZ 0 $
\                MOVSB
\                DEC CX
\        0 $:    SHR CX, # 1
\                REPNZ           MOVSW
\                RCL CX, # 1
                REPNZ           MOVSB
                MOV SI, BX              \ restore SI
                POP BX
                XCHG SI, SP
                POP ES
                POP DS
                RET             END-ICODE

ICODE CMOVEL>   ( sseg sptr dseg dptr cnt -- )
                PUSH DS
                PUSH ES
                XCHG SI, SP
                MOV CX, BX      DEC CX  \ count to BX
                MOV BX, SI              \ preserve SI
                POP DI
                POP ES
                POP SI          POP DS
                ADD DI, CX      ADD SI, CX      INC CX
                STD
                REPNZ           MOVSB
                CLD
                MOV SI, BX              \ restore SI
                POP BX
                XCHG SI, SP
                POP ES
                POP DS
                RET             END-ICODE

: MOVE          ( from to len -- )
                -ROT    2DUP U<
                IF      ROT GOTO CMOVE>
                THEN    ROT      CMOVE ;        NO-INTERPRET

CODE CRLF>BL'S  ( a1 --- a1 )   \ change CRLF at end of string to blanks
                                \ leaving the string address on the stack
                mov cx, bx      \ Same as -> DUP COUNT + 2- DUP @ $0D0A =
                mov al, 0 [bx]  \            IF 8224 SWAP ! ELSE DROP DROP ;
                sub ah, ah
                add bx, ax
                dec bx
                cmp 0 [bx], # $0A0D word        \ if line ends in CRLF
             0= if      mov 0 [bx], # 8224 word \ change then to blanks
                then
                mov bx, cx
                RET             END-CODE

VARIABLE DPL
VARIABLE BASE
VARIABLE HLD
VARIABLE CAPS
VARIABLE SSEG
VARIABLE SPAN
VARIABLE #OUT
VARIABLE #LINE
VARIABLE SAVECUR
VARIABLE ESC_FLG
VARIABLE #TIB
VARIABLE >IN
\ VARIABLE TIB0
VARIABLE #EXSTRT
VARIABLE FUDGE
VARIABLE ATTRIB
VARIABLE LMARGIN
VARIABLE RMARGIN
VARIABLE TABSIZE
VARIABLE PRINTING

DEFER AT?
DEFER AT
DEFER KEY
DEFER EMIT
DEFER TYPE
DEFER SPACES
DEFER CR        EXECUTES> CR
DEFER DARK      EXECUTES> DARK

  0 VALUE G-ENABLED?     \ is graphic plotting enabled, or are we texting
 -1 VALUE G-COLOR        \ current graphics color
 80 VALUE COLS
 25 VALUE ROWS
512 VALUE PADSIZE       \ default size of PAD in bytes
                        \ these bytes are reserved from allocation

TARGET ' DARK ALIAS CLS

CODE COMP       ( addr1 addr2 len -- -1 | 0 | 1 )
                [ASSEMBLER]
                XCHG SI, SP
                MOV DX, SI      MOV CX, BX
                POP DI          POP SI
          CX<>0 IF      PUSH ES         MOV ES, SSEG
                        REPZ CMPSB
                    0<> IF
                             0< IF      MOV CX, # -1
                                ELSE    MOV CX, # 1
                                THEN
                        THEN
                        POP ES
                THEN
                MOV SI, DX
                MOV BX, CX
                XCHG SI, SP
                RET             END-CODE

CODE CAPS-COMP ( addr1 addr2 len -- -1 | 0 | 1 )
                [ASSEMBLER]
                PUSH ES
                XCHG SI, SP
                MOV DX, SI      MOV CX, BX
                POP DI          POP SI
                MOV ES, SSEG
                BEGIN
                    JCXZ  0 $
                    MOV AH,     0 [SI]  INC SI
                    MOV AL, ES: 0 [DI]  INC DI
                    OR AX, # $02020     CMP AH, AL
                    JNE 1 $             DEC CX
                AGAIN
        1 $: 0< IF
                   MOV CX, # -1
                ELSE
                   MOV CX, # 1
                THEN
        0 $:    MOV SI, DX
                MOV BX, CX
                XCHG SI, SP
                POP ES
                RET             END-CODE

CODE SKIP      ( addr len char -- addr' len' ) \ skip char forwards
                [ASSEMBLER]
                LODSW   MOV CX, AX
                MOV AX, BX
          CX<>0 IF      MOV DI, 0 [SI]
                        MOV DX, ES      MOV ES, SSEG
                        REPZ            SCASB
                        MOV ES, DX
                    0<> IF
                                INC CX
                                DEC DI
                        THEN
                        MOV 0 [SI], DI
                THEN    MOV BX, CX
                RET             END-CODE

CODE -SKIP     ( addr len char -- addr' len' ) \ skip char backwards
                [ASSEMBLER]
                LODSW   MOV CX, AX
                MOV AX, BX
          CX<>0 IF      MOV DI, 0 [SI]
                        MOV DX, ES      MOV ES, SSEG
                        STD     REPZ    SCASB   CLD
                        MOV ES, DX
                    0<> IF
                                INC CX
                                INC DI  \ 11/11/91 18:02:25.77 tjz
                        THEN
                        MOV 0 [SI], DI
                THEN    MOV BX, CX
                RET             END-CODE

CODE SCAN      ( addr len char -- addr' len' ) \ scan char forwards
                [ASSEMBLER]
                LODSW   MOV CX, AX
                MOV AX, BX
          CX<>0 IF      MOV DI, 0 [SI]
                        MOV DX, ES      MOV ES, SSEG
                        REPNZ           SCASB
                        MOV ES, DX
                     0= IF              INC CX
                                        DEC DI
                        THEN
                        MOV 0 [SI], DI
                THEN    MOV BX, CX
                RET     END-CODE

CODE  -SCAN    ( addr len char -- addr' len' ) \ scan char backwards
                [ASSEMBLER]
                LODSW   MOV CX, AX
                MOV AX, BX
          CX<>0 IF      MOV DI, 0 [SI]
                        MOV DX, ES      MOV ES, SSEG
                        STD     REPNZ   SCASB   CLD
                        MOV ES, DX
                     0= IF              INC CX  \ 11/11/91 18:02:37.41 tjz
                                        INC DI
                        THEN
                        MOV 0 [SI], DI
                THEN    MOV BX, CX
                RET     END-CODE

                                        \ a1 = scan start address
                                        \ w1 = length to scan (words)
                                        \ w2 = word we are looking for
                                        \ a2 = address where w2 was found
                                        \ w3 = remaining search length (WORDS)
CODE  SCANW     ( a1 w1 w2 --- a2 w3 )  \ Scan array a1 for word w2.
                LODSW
                MOV CX, AX
          CX<>0 IF      LODSW
                        MOV DI, AX
                        MOV AX, BX
                        PUSH ES
                        MOV ES, SSEG
                        REPNZ   SCASW
                        POP ES
                     0= IF      INC CX
                                DEC DI
                                DEC DI
                        THEN
                        DEC SI
                        DEC SI
                        MOV 0 [SI], DI
                THEN                        \ zero search length exit
                MOV BX, CX
                RET     END-CODE

CODE -TRAILING  ( addr len -- addr len1 ) \ remove trailing blanks
                MOV CX, BX
                MOV DI, 0 [SI]
          CX<>0 IF      MOV AX, DS
                        PUSH ES
                        STD
                        MOV ES, AX
                        ADD DI, CX
                        DEC DI
                        MOV AL, # $20
                        REPE SCASB
                    0<> IF      INC CX
                        THEN
                        CLD
                        POP ES
                THEN
                MOV BX, CX
                RET             END-CODE

ICODE /STRING   ( addr len n -- addr' len' )
                LODSW
                XCHG BX, AX
                CMP BX, AX
                [ASSEMBLER]
            U<= IF      MOV AX, BX      \ AX = SMALLER OF AX BX
                THEN
                ADD 0 [SI], AX
                SUB BX, AX
                RET             END-ICODE

CODE DIGIT     ( char base -- n f )
                NO_INLINE
                [ASSEMBLER]
                MOV AX, 0 [SI]
                SUB AL, # $30           \ ASCII 0    can't user ASCII in CODE
                JB 0 $
                        CMP AL, # 9
              > IF
                        CMP AL, # 17
                        JB 0 $
                        SUB AL, # 7
                THEN
                CMP AL, BL
                JAE 0 $
                        MOV 0 [SI], AX
                        MOV BX, # -1
                        RET
           0 $: SUB BX, BX
                RET             END-CODE

M: HERE         ( -- A1 )       \ return a1 the address of the next available
                                \ free memory space in data ram
                DP @ ;                          EXECUTES> HERE-D

M: PAD          ( -- a1 )       \ a place to put things for a bit
                DP @ 82 + ;                     EXECUTES> PAD

M: ALLOT        ( n1 -- )       \ allot some DS: ram
                DP +! ;                         EXECUTES> ALLOT-D

: WORD          ( c1 -- a1 )    \ return a1 a word from TIB
                >R
                TIB #TIB @ >IN @ /STRING        \ starting point for word
                R@ SKIP 2DUP R> SCAN NIP        \ parse out a word
                #TIB @ OVER - >IN !             \ adj >in to new point in $
                - HERE PLACE HERE               \ return string in HERE
                $2020 HERE COUNT + ! ;          \ append blanks
                                                EXECUTES> WORD

: DOS_TO_TIB    ( -- )          \ Move the DOS commandline to Forths TIB
                ?CS: DOS_CMD_TAIL COUNTL DUP #TIB ! ?DS: TIB ROT CMOVEL
                >IN OFF ;                       NO-INTERPRET

M: HEX          ( -- )
                $10 BASE ! ;                    EXECUTES> HEX

M: DECIMAL      ( -- )
                $0A BASE ! ;                    EXECUTES> DECIMAL

M: OCTAL        ( -- )
                $08 BASE ! ;                    EXECUTES> OCTAL

M: BINARY       ( -- )
                $02 BASE ! ;                    EXECUTES> BINARY

: COMPARE       ( addr1 addr2 len -- -1 | 0 | 1 )
                CAPS @
                IF      GOTO CAPS-COMP
                THEN    COMP ;                  NO-INTERPRET

: DOUBLE?       ( -- f )
                DPL @ 1+   0<> ;                NO-INTERPRET

: CONVERT       ( +d1 adr1 -- +d2 adr2 )
                BEGIN   1+  DUP>R  C@  BASE @  DIGIT
                WHILE   SWAP  BASE @ UM*  DROP  ROT  BASE @ UM*  D+
                        DOUBLE?  IF  DPL INCR THEN  R>
                REPEAT  DROP  R>  ;             NO-INTERPRET

: (NUMBER?)     ( adr -- d flag )
                0 0  ROT  DUP 1+  C@  ASCII -  =  DUP  >R  -  -1 DPL !
                BEGIN   CONVERT  DUP C@  ASCII , ASCII / BETWEEN
                WHILE   0 DPL !
                REPEAT  -ROT  R> IF  DNEGATE  THEN   ROT C@ BL =  ;
                                                NO-INTERPRET

: NUMBER?       ( adr -- d flag )
                FALSE  OVER COUNT BOUNDS
                ?DO     I C@ BASE @ DIGIT NIP
                        IF      DROP TRUE LEAVE THEN
                LOOP
                IF      (NUMBER?)
                ELSE    DROP  0 0 FALSE
                THEN  ;                         NO-INTERPRET

TARGET ' NUMBER? ALIAS %NUMBER

ICODE %DOSEXPECT ( addr +n --- n2 )
                PUSH BP
                XCHG SI, SP
                MOV AX, BX                      \ count to ax
                MOV BX, SP
                SUB BX, # $100                  \ buffer 256 bytes below stck
                MOV 0 [BX], AL                  \ 1st byte buffer = chars
                MOV DX, BX                      \ DX = ^buffer
                MOV AH, # $0A                   \ buffered keyboard input
                INT $21                         \ DOS function call
                SUB CX, CX                      \ zero CX
                INC BX                          \ BX = ^#chars read
                MOV CL, 0 [BX]                  \ CX = #chars READ
                POP DI                          \ DI = forth address
                PUSH CX                         \ return CX
                INC BX                          \ BX = ^buffer
                MOV DX, SI                      \ DX saves SI
                MOV AX, ES                      \ AX saves ES
                MOV SI, BX                      \ SI = DOS address
                MOV BX, DS
                MOV ES, BX                      \ set ES = DS
                TEST DI, # 1
                JZ 0 $
                JCXZ 0 $
                MOVSB
                DEC CX
        0 $:    SHR CX, # 1
                REPNZ MOVSW
                RCL CX, # 1
                REPNZ MOVSB                     \ move it
                MOV SI, DX                      \ restore SI
                MOV ES, AX                      \ restore ES
                POP BX
                XCHG SI, SP
                POP BP
                RET             END-ICODE

ICODE DEALLOC   ( n1 -- f1 )            \ n1 = segment returned by ALLOC
                PUSH ES         MOV ES, BX
                MOV AH, # $49
                INT $21
                [ASSEMBLER]
             U< IF      SUB AH, AH
                ELSE    SUB AX, AX
                THEN
                POP ES
                MOV BX, AX
                RET             END-ICODE

ICODE ALLOC     ( n1 -- n2 n3 f1 )      \ n1 = "PARAGRAPHS" not bytes
                                        \ n2 = largest available if failed
                                        \ n3 = segment start if succeeded
                                        \ f1 = 8 if failed else don't care
                XCHG SI, SP
                MOV AH, # $48
                INT $21
                PUSH BX
                PUSH AX
                [ASSEMBLER]
             U< IF      SUB AH, AH
                ELSE    SUB AX, AX
                THEN
                MOV BX, AX
                XCHG SI, SP
                RET             END-ICODE

ICODE SETBLOCK  ( seg siz -- f1 )
                LODSW
                MOV DX, AX
                MOV AH, # $4A           \ setblock call
                PUSH ES
                MOV ES, DX
                INT $21
                [ASSEMBLER]
             U< IF      SUB AH, AH
                ELSE    SUB AX, AX
                THEN
                POP ES
                MOV BX, AX
                RET             END-ICODE

: PARAGRAPH     ( offset -- paragraph-inc )
                15 + U16/ ;             EXECUTES> PARAGRAPH

: DPARAGRAPH    ( dbl_bytes -- paragraphs )
                15. D+ UD16/ DROP ;     EXECUTES> DPARAGRAPH

ICODE EXECF     ( string PARMS --- return-code )
                [ASSEMBLER]             \ BX contains PARMS
                LODSW
                MOV DX, AX              \ DX contains string
                PUSH ES                 PUSH SI
                PUSH BP                 PUSH DS
                MOV AX, DS              MOV ES, AX
                MOV AX, # $4B00
                INT $21
                POP DS                  POP BP
                POP SI                  POP ES
             U< IF                      \ ONLY when carry is NON ZERO
                        AND AX, # $FF
                ELSE    SUB AX, AX
                THEN
                MOV BX, AX
                RET             END-ICODE

ICODE VIDEO     ( DX CX BX AX -- DX AX )        \ perform a VIDEO interrupt
                                                \ call.
                MOV DX, BX
                LOAD_BX
                LODSW   MOV CX, AX
                LODSW   XCHG DX, AX
                PUSH SI         PUSH BP
                INT $10
                POP BP          POP SI
                DEC SI
                DEC SI
                MOV 0 [SI], DX
                MOV BX, AX
                RET             END-ICODE

: IBM-AT?       ( -- x y )              \ return the current cursor position
                0 0 0 $0300 VIDEO DROP SPLIT ;  NO-INTERPRET

: IBM-AT        ( X Y -- )              \ set the current cursor position
                ROWS 1- UMIN #LINE !
                COLS 1- UMIN #OUT  !
                #OUT @ #LINE @ FLIP OR 0 0 $0200 VIDEO 2DROP ; NO-INTERPRET

: VMODE@        ( -- n1 )               \ get the current video mode.
                0 0 0 $0F00 VIDEO NIP $FF AND ; NO-INTERPRET

: VMODE!        ( n1 -- )               \ use to set video modes. n1 is the
                                        \ desired mode number. For example
                                        \ 6 VMODE! will select 640x200
                                        \ black & white graphics.
                >R 0 0 0 R> VIDEO 2DROP ;       NO-INTERPRET

: IBM-DARK      ( -- )                  \ fetch and store video mode thus
                                        \ clearing the screen.
                VMODE@ VMODE! #OUT OFF #LINE OFF ; NO-INTERPRET

ICODE ?VMODE    ( --- N1 )              \ Get the video mode from DOS
                DEC SI
                DEC SI
                MOV 0 [SI], BX
                MOV AH, # $0F
                INT $10
                SUB AH, AH
                MOV BX, AX
                RET             END-ICODE

ICODE SET-CURSOR ( n1 --- )              \ set the cursor shape
                MOV CX, BX
                MOV AH, # 1
                PUSH SI         PUSH BP
                INT $10
                POP BP          POP SI
                LOAD_BX
                RET             END-ICODE

: GET-CURSOR    ( --- shape )           \ get the cursor shape
                0 $460 @L ;                     NO-INTERPRET

: INIT-CURSOR   ( -- )
                GET-CURSOR SAVECUR ! ;                  NO-INTERPRET

: CURSOR-OFF    ( --- )
                GET-CURSOR $2000  OR SET-CURSOR ;       NO-INTERPRET

: CURSOR-ON     ( --- )
                GET-CURSOR $0F0F AND SET-CURSOR ;       NO-INTERPRET

: NORM-CURSOR   ( --- )
                SAVECUR C@ DUP 1- FLIP + SET-CURSOR ;   NO-INTERPRET

: BIG-CURSOR    ( --- )
                SAVECUR C@ SET-CURSOR ;                 NO-INTERPRET

: NOOP          ( -- )
                ;                                       EXECUTES> NOOP

: SAVECURSOR    ( -- )          \ save all of the current cursor stuff
                R>
                ATTRIB @ >R             \ save attribute
                GET-CURSOR >R           \ cursor shape
                #OUT @ #LINE @ 2>R      \ and position
                >R ;                                    NO-INTERPRET

: %RESTCURSOR   ( -- )          \ restore all of the cursor stuff
                R>
                2R> AT                  \ restore position
                R> SET-CURSOR           \ shape
                R> ATTRIB !             \ and attribute
                >R ;                                    NO-INTERPRET

M: RESTCURSOR   ( -- )
                %RESTCURSOR
                [compile] OPT_OFF1      \ turn off optimization one step
                ;                                       NO-INTERPRET

ICODE BDOS2     ( CX DX AL -- CX DX AX )
                MOV AX, BX
                MOV DX, 0 [SI]
                MOV CX, 2 [SI]
                MOV AH, AL      INT $21
                MOV BX, AX
                MOV 0 [SI], DX
                MOV 2 [SI], CX
                RET             END-ICODE

: OS2           BDOS2 255 AND ;                         NO-INTERPRET

CODE BDOS       ( DX AH -- AL )
                CMP BX, BP                      \ is function 0=terminate
             0= IF      JMP FINAL_EXIT          \ force use of normal exit
                THEN                            \ to restore vectors etc.
                LODSW
                MOV DX, AX
                MOV AH, BL
                INT $21
                SUB AH, AH
                MOV BX, AX
                RET             END-CODE

: DOSVER        ( -- n1 )
                0 $030 BDOS $0FF AND ;                  NO-INTERPRET

: DOSEMIT       ( c1 -- )
                6 BDOS DROP #OUT INCR ;                 NO-INTERPRET

CODE COLOREMIT  ( c1 -- )       \ Emit that handles color characters
                                \ BUT, no I/O redirection available
                CMP BX, # 20h           \ test for a control character
                JGE 0 $                 \ pass using int 21h
                        MOV DX, BX
                        MOV AH, # 6
                        INT 21h
                        CMP BX, # 0Dh
                        JNE 1 $
                        MOV #OUT # 0 WORD
                        JMP 2 $
\                3 $:    CMP BX, # 0Ah
\                        JNE 1 $
\                        ADD #LINE # 1 WORD
\                        JMP 1 $
        0 $:    MOV AX, BX              \ if printable, use INT 10h
                SUB BH, BH
                MOV BL, ATTRIB
                MOV CX, # 1
                MOV AH, # 9
                INT 10H
        1 $:    ADD #OUT # 1 WORD
        2 $:    MOV DX, #LINE
                CMP DX, &> ROWS
            U>= IF      MOV DX, &> ROWS         \ limit line to screen
                        DEC DX                  \ lines minus one
                THEN
                MOV DH, #OUT
                XCHG DH, DL
                MOV AH, # 2
                INT 10h                         \ set the cursor position
                LOAD_BX
                RET             END-CODE                NO-INTERPRET

CODE ROW/COL_SET ( -- )
                SAVE_BX
                push ds
                mov ax, # $40           \ absolute segment $40:00
                mov ds, ax              \ goes into ds
                mov bl, $4A             \ get the # of cols from    $40:$4A
                mov cl, $84             \ get the # of rows from    $40:$84
                pop ds
                mov &> cols bl
                cmp cl, # 24
              < if      mov cl, # 25    \ at least 25 rows
                else    inc cl
                then
                mov &> rows cl
                LOAD_BX
                ret     END-CODE

MACRO BYE       ( -- )
                JMP FINAL_EXIT  END-MACRO               EXECUTES> BYE

ICODE PR-STATUS ( n1 -- b1 )
                MOV DX, BX      \ PRINTER NUMBER
                MOV AH, # 2
                PUSH SI         PUSH BP
                INT $17
                POP BP          POP SI
                MOV BL, AH
                SUB BH, BH
                RET             END-ICODE

: ?PRINTER.READY ( -- f1 )
                0 PR-STATUS ( $090 AND ) $090 = ;       NO-INTERPRET

CODE PEMIT      ( c1 -- )
                MOV DX, # 0     \ PRINTER NUMBER
                MOV AL, BL
                MOV AH, # 0
                PUSH SI         PUSH BP
                INT $17
                POP BP          POP SI
                INC #OUT WORD
                LOAD_BX
                RET             END-CODE

: (EMIT)        ( C1 -- )
                PRINTING @
                IF      GOTO PEMIT
                THEN    DOSEMIT ;               NO-INTERPRET

ICODE KEY?      ( -- f1 )               \ BIOS KEY?, NO redirection!
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
                RET             END-CODE

ICODE BIOSKEY   ( -- c1 )
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
                RET             END-CODE        NO-INTERPRET

: BDOSKEY?      ( -- c1 )               \ DOS KEY?, redirectable
                255 6 BDOS $FF AND ;            NO-INTERPRET

: BDOSKEY       ( -- c1 )               \ DOS KEY, redirectable, RAW
                0 7 BDOS $FF AND ;              NO-INTERPRET

: %KEY          ( -- c1 )               \ DOS KEY, redirectable, translates
                BDOSKEY ?DUP 0=         \ function keys to above 128.
                IF      BDOSKEY 128 OR
                THEN    ;                       NO-INTERPRET

TARGET ' %KEY ALIAS (KEY)

: SPACE         ( -- )
                BL EMIT ;                       EXECUTES> SPACE

: %SPACES       ( n1 -- )
                0 MAX   ?DUP
                IF      1-
                        FOR BL EMIT NEXT
                THEN    ;                       NO-INTERPRET

: %TYPE         ( a1 n1 -- )
                0 MAX   ?DUP
                IF      1-
                        FOR     DUP C@ EMIT 1+
                        NEXT    DROP
                ELSE    DROP
                THEN    ;                               NO-INTERPRET

TARGET ' %TYPE ALIAS (TYPE)

: $TYPE         ( a1 -- )       \ type a counted string a1
                COUNT TYPE ;

: SP>COL        ( n1 -- )       \ space over to column n1
                #OUT @ - SPACES ;                       EXECUTES> SP>COL

: EEOL          ( -- )          \ Erase to end of line
                COLS SP>COL ;                           EXECUTES> EEOL

: CRLF          ( -- )
                $0D (EMIT) $0A (EMIT)
                #OUT OFF #LINE INCR ;

: $>TIB         ( A1 --- )
                COUNT DUP #TIB ! TIB SWAP CMOVE >IN OFF ; NO-INTERPRET

: MARGIN_INIT   ( -- )
                LMARGIN OFF 64 RMARGIN !        \ default margins
                8 TABSIZE ! ;                           NO-INTERPRET

: MS            ( n1 -- )       \ Delay n1 units of about a millisecond.
                FOR     FUDGE @ 1+ FOR NEXT
                NEXT    ;                               EXECUTES> MS

: ?IN_REDIRECT  ( -- f1 )               \ f1=true if console input redirected
                ?CS: $18 C@L 1 <> ;

: ?OUT_REDIRECT ( -- f1 )               \ f1=true if console output redirected
                ?CS: $19 C@L 1 <> ;

ICODE TT[']     ( -- a1 )       \ get address of routine following this one
                DEC SI
                DEC SI
                MOV 0 [SI], BX
                POP BX          \ get address where we came from
                INC BX
                MOV AX, BX
                INC AX
                INC AX
                PUSH AX         \ push adjusted return address on return stk
                ADD AX, CS: 0 [BX]
                MOV BX, AX      \ BX holds address of routine following
                RET             END-ICODE

: DOSIO_INIT    ( -- )          \ initialize the DOS I/O words
                DECIMAL                         \ really need a default base
                TT['] CRLF      !> CR
                TT['] IBM-AT?   !> AT?
                TT['] IBM-AT    !> AT           \ init  AT
                TT['] %KEY      !> KEY          \       KEY,
                ?IN_REDIRECT                    \ if I/O redirection active
                ?OUT_REDIRECT OR                \ select proper EMIT version
                IF      TT['] (EMIT)    !> EMIT \ B/W   EMIT, or
                ELSE    TT['] COLOREMIT !> EMIT \ COLOR EMIT,
                THEN    TT['] (TYPE)    !> TYPE \       TYPE,
                TT['] %SPACES   !> SPACES       \       SPACES
                TT['] IBM-DARK  !> DARK         \ and   DARK
                7 ATTRIB !                      \ default to normal B/W
                PRINTING OFF                    \ not printing
                ROW/COL_SET                     \ init COLS and ROWS
                AT? AT ;                        \ init the cursor position

M: SLOW         ( -- )
                DOSIO_INIT ;    \ for compatiblity with F-PC

: ?LINE         ( N -- )
                #OUT @ +  RMARGIN @ > IF CR LMARGIN @ SPACES THEN ;
                                                        NO-INTERPRET
: ?CR           ( -- )
                0 ?LINE  ;                              NO-INTERPRET

0 VALUE ABORT_FUNC

: ABORT         ( -- )          \ Just leave when we abort
                ABORT_FUNC ?DUP
                IF      EXECUTE
                ELSE    CR BYE
                THEN    ;                               EXECUTES> ABORT

: ?ABORT$       ( f1 a1 -- ) \ display string a1 & abort if f1 true
                SWAP 0=
                IF      DROP EXIT
                THEN    $TYPE ABORT ;

FORTH   >FORTH

\ I: %T[']        ( | <name> -- a1 )
\                 F['] TT[']    RES_COMP_CALL
\                 [FORTH] ' DUP RES_COMP_CALL >DTYPE C@ {S} <>
\                 ABORT" is NOT a subroutine, Can ONLY ['] subroutines!" ;
\                 IMMEDIATE
I: %T[']        ( | <name> -- a1 )
                [FORTH] ' DUP >DTYPE C@ {S} <>
                ABORT" is NOT a subroutine, Can ONLY ['] subroutines!"
                DUP >RESADDR @ -1 =     \ if unresolved
        IF      F['] TT[']    RES_COMP_CALL RES_COMP_CALL
                                        \ 08/15/94 15:18 tjz added
                OPT_OFF1                \ no optimization for one step
        ELSE                            \ if resolved, compile literal
                DUP >COUNT INCR >RESADDR @ COMP_SINGLE
        THEN    ; IMMEDIATE
' %T['] IS T[']

I: %L[']        ( | <name> -- a1 )
                COMPILE RES_COMP_CLL F['] TT['] X,
                COMPILE RES_COMP_CLL [FORTH] ' DUP  X,
                >DTYPE C@ {S} <>
                ABORT" is NOT a subroutine, Can ONLY ['] subroutines!" ;
                IMMEDIATE
' %L['] IS L[']

H: $"           ( -<string">- )
                [COMPILE] T$" ; IMMEDIATE

I: %T."         ( | string" -- )
                [COMPILE] T$"
                F['] $TYPE RES_COMP_CALL ; IMMEDIATE
' %T." IS T."

I: %L."         ( | string" -- )
                [COMPILE] L$"
                COMPILE RES_COMP_CLL F['] $TYPE X, ; IMMEDIATE
' %L." IS L."

I: %COMP_COUNT  ( -- )
                F['] COUNT RES_COMP_CALL ; IMMEDIATE
' %COMP_COUNT IS COMP_COUNT

I: %TABORT"     ( | string" -- )
                [COMPILE] T$" F['] ?ABORT$ COMP_CALL ; IMMEDIATE
' %TABORT" IS TABORT"

I: %LABORT"     ( | string" -- )
                [COMPILE] L$"
                COMPILE <'> COMPILE ?ABORT$ COMPILE COMP_CALL ; IMMEDIATE
' %LABORT" IS LABORT"

TARGET  >LIBRARY

: ?MISSING      ( f -- )
                IF      SPACE HERE COUNT TYPE
                        TRUE ABORT"  Bad number conversion! "
                THEN    ;                       NO-INTERPRET

: NUMBER        ( a1 -- d1 )
                NUMBER? 0= ?MISSING ;           EXECUTES> NUMBER

                                \ n1 = DS: ram in bytes for target program
: SET_MEMORY    ( n1 -- )       \ adjust allocated memory for target
                pad padsize + umax              \ clip to above used ram
                dup memend !                    \ set the avail end of memory
                paragraph
                ?ds: ?cs: - +                   \ + CODE memory + segments
                ?cs: swap setblock              \ adj memory
                IF      CR ." Couldn't adjust memory size!"
                        BYE
                THEN    ;

: TAB           ( -- )
                #OUT @ TABSIZE @ MOD TABSIZE @ SWAP - SPACES ;
                                                        EXECUTES> TAB

: BEEP          ( -- )
                7 (EMIT) #OUT DECR ;                   EXECUTES> BEEP

: HOLD          ( char -- )
                HLD DECR HLD @ C!   ;                   NO-INTERPRET

: <#            ( -- )
                PAD  HLD  !  ;                          NO-INTERPRET

: #>            ( d# -- addr len )
                2DROP  HLD  @  PAD  OVER  -  ;          NO-INTERPRET

: SIGN          ( n1 -- )
                0< 0= ?EXIT
                ASCII -  HOLD  ;                        NO-INTERPRET

: #             ( d1 -- d2 )
                BASE @ MU/MOD ROT 9 OVER <
                IF  7 + THEN ASCII 0  +  HOLD  ;        NO-INTERPRET

: #S            ( d -- 0 0 )
                BEGIN  #  2DUP  OR  0=  UNTIL  ;        NO-INTERPRET

: (U.)          ( u -- a l )
                0    <# #S #>   ;                       NO-INTERPRET

: U.            ( u -- )
                (U.)   TYPE SPACE   ;                   EXECUTES> U.

: U.R           ( u l -- )
                >R   (U.)   R> OVER - SPACES   TYPE   ; EXECUTES> U.R

: (.)           ( n -- a l )
                DUP ABS 0   <# #S   ROT SIGN   #>   ;   NO-INTERPRET

: .             ( n -- )
                (.)   TYPE SPACE   ;                    EXECUTES> .

: .R            ( n l -- )
                >R   (.)   R> OVER - SPACES   TYPE   ;  EXECUTES> .R

: (UD.)         ( ud -- a l )
                <# #S #>   ;                            NO-INTERPRET

: UD.           ( ud -- )
                (UD.)   TYPE SPACE   ;                  NO-INTERPRET

: UD.R          ( ud l -- )
                >R   (UD.)   R> OVER - SPACES   TYPE  ; NO-INTERPRET

: (D.)          ( d -- a l )
                TUCK DABS   <# #S   ROT SIGN  #>   ;    NO-INTERPRET

: D.            ( d -- )
                (D.)   TYPE SPACE   ;                   NO-INTERPRET

: D.R           ( d l -- )
                >R   (D.)   R> OVER - SPACES   TYPE   ; NO-INTERPRET

: UD,.R         ( ud l -- )             \ right justified, with ','
                >R      <#              \ every 3 digits from right
                3 0 DO # 2DUP D0= ?LEAVE LOOP
                2DUP D0= 0=
                IF      ',' HOLD
                        3 0 DO # 2DUP D0= ?LEAVE LOOP
                THEN
                2DUP D0= 0=
                IF      ',' HOLD
                        3 0 DO # 2DUP D0= ?LEAVE LOOP
                THEN    #> R> OVER - SPACES TYPE ;

: U,.R          ( n1 n2 -- )
                0 SWAP UD,.R ;

: DOS_EXPECT    ( a1 n1 -- )
                AT? >R >R
                %DOSEXPECT DUP SPAN ! R> + R> AT ;      NO-INTERPRET

ALSO HTARGET DEFINITIONS TARGET

: DOEXP1        ( A1 C1 N1 -- A2 N2 )   \ n2 = loop count
                OVER $C7 =      ( HOME )        \ if Home, then clear line
                IF      DUP>R AT? >R SWAP - R> 2DUP AT R@ SPACES AT R>
                        NEGATE >R DROP R@ + R>
                        EXIT
                THEN
                OVER $08 =      ( BACKSPACE )   \ if BS then backup one
                IF      0=
                        IF      DROP BEEP 0     \ or BEEP if at beginning
                        ELSE    (EMIT)         \ backup one char
                                BL (EMIT)
                                8 (EMIT)       \ erase chars space
                                -4 #OUT +!
                                #OUT @ #LINE @ AT
                                1- -1
                        THEN    EXIT            \ leave if BACKSPACE
                THEN    DROP                    \ discard current index
                DUP $1B =       ( ESC )         \ char = ESC?, then cancel
                IF      DROP                    \ discard char
                        #EXSTRT @ ?DUP
                        IF      SPAN @ SWAP ABS SPAN !
                        ELSE    SPAN @ SPAN OFF \ skip to end
                        THEN
                        ESC_FLG ON              \ set escaped flag
                ELSE                            \ else emit, and bump to next
                        DUP EMIT OVER C! 1+ 1
                THEN    ;

: #EXSTRT_@+    ( a1 -- a2 n1 )         \ adj a1 by #exstrt
                #EXSTRT @ DUP>R + R> DUP NEGATE #EXSTRT ! ;

TARGET DEFINITIONS PREVIOUS

: #EXPECT       ( a1 n1 n1 -- )         \ EXPECT chars n1 into addr a1.
                                        \ starting at char n2 in string
                0MAX    DUP #EXSTRT ! ?DUP
                IF      2 PICK SWAP TYPE        \ display text sofar
                THEN
                ESC_FLG OFF
                DUP SPAN ! 0
        [Llong] ?DO     #EXSTRT @ 0>
                        IF      #EXSTRT_@+
                        ELSE    KEY DUP $0D =   \ if CR then leave, done
                                IF      DROP I SPAN ! LEAVE
                                ELSE    I DOEXP1
                                THEN
                        THEN
                +LOOP   DROP ;

: EXPECT        ( a1 n1 -- )            \ expect chars n1 into addr a1
                0 #EXPECT ;                             NO-INTERPRET

: QUERY         ( -- )
                TIB 80 EXPECT  SPAN @ #TIB ! >IN OFF  ; NO-INTERPRET

: UPC           ( c1 -- c2 )
                DUP 'a' 'z' BETWEEN
                IF      $5F AND
                THEN    ;                               NO-INTERPRET

: UPPER         ( addr len -- )
                BOUNDS
                ?DO     I C@ UPC I C!
                LOOP    ;                               NO-INTERPRET

: ?UPPERCASE    ( a1 -- a1 )
                CAPS @ 0= ?EXIT
                DUP COUNT UPPER ;                       NO-INTERPRET

: H.R           ( n1 n2 -- )
                BASE @ >R HEX U.R R> BASE ! ;

: H.            ( n1 -- )
                1 H.R SPACE ;                           EXECUTES> H.

M: ">$          ( a1 n1 -- a2 )
                DROP 1- ;                               NO-INTERPRET

M: U<=          ( u1 u2 -- f )   U> NOT   ;             NO-INTERPRET
M: U>=          ( u1 u2 -- f )   U< NOT   ;             NO-INTERPRET
M: <=           ( n1 n2 -- f )    > NOT   ;             NO-INTERPRET
M: >=           ( n1 n2 -- f )    < NOT   ;             NO-INTERPRET
M: 0>=          ( n1 n2 -- f )   0< NOT   ;             NO-INTERPRET
M: 0<=          ( n1 n2 -- f )   0> NOT   ;             NO-INTERPRET

: ?KEYPAUSE     ( --- )         \ Pause if key pressed
                BROKEN @         IF ABORT THEN
                KEY?
                IF      KEY 27 = IF ABORT THEN
                        KEY 27 = IF ABORT THEN
                THEN    ;                               NO-INTERPRET

0 VALUE DUMP_OFF

: DUMP_1LINE    ( seg a1 -- seg a2 )
                DUP DUMP_OFF + 6 H.R ."  | "
                2DUP 15 FOR 2DUP C@L 3 H.R 1+ NEXT 2DROP ."  | "
                     15 FOR 2DUP C@L $7F AND BL MAX EMIT 1+ NEXT ;

: %LDUMP        ( seg addr len -- )
                0
                DO      CR DUMP_1LINE ?KEYPAUSE
            16 +LOOP    2DROP   ;

: LDUMP         ( seg addr len -- )
                OFF> DUMP_OFF %LDUMP ;

: DUMP          ( addr len -- )
                ?DS: -ROT LDUMP ;                       EXECUTES> DUMP

: DS:FREE?      ( -- n1 )       \ return the amount of free ram at runtime
                MEMEND @ PAD PADSIZE + U<
                IF      0                        \ then return 0
                ELSE    MEMEND @ PAD PADSIZE + - \ else return real avail mem
                THEN    ;                       NO-INTERPRET

: DS:ALLOC      ( n1 -- a1 )    \ allocate n1 bytes of ram at runtime,
                                \ returning a1 the address of the ram
                DS:FREE? OVER U<
                ABORT" Not enough DS: memory available!"
                HERE SWAP ALLOT ;               NO-INTERPRET

: #input        ( --- n1 )
                query bl word number? 0= abort" Must be a NUMBER" drop ;

: PLACEL        ( seg off len a1 -- )           \ get string from far mem
                                                \ make into counted string
                2DUP C! 1+ ?DS: SWAP ROT CMOVEL ;

: +PLACEL       ( seg off len a1 -- )           \ append far string to a1
                2DUP 2>R COUNT + ?DS: SWAP ROT CMOVEL 2R> C+! ;

TARGET ' !> ALIAS =: IMMEDIATE
TARGET ' !> ALIAS IS IMMEDIATE

>FORTH

