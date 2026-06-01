\\ ZIF.SEQ               IF-NOT (Zero Equal IF)         for Jerry Boutelle

    Jerry wanted a conditional word that would branch like IF, but
    on the opposite condition (branch on non-zero).

    This file provides this functionality, for both F-PC and TCOM.

{

\FPC    TRUE    #IF     \ load the #IF   part for F-PC
\TCOM   FALSE   #IF     \ load the #ELSE part for TCOM

CODE ?0BRANCH   ( f -- )  \ Branch if flag is zero
                POP AX
                CMP AX, # 0
             0= IF      ADD IP, # 2
                        NEXT
                THEN
                MOV ES: IP, 0 [IP]
                NEXT            END-CODE

: IF-NOT        ( n -- )
                COMPILE  ?0BRANCH  ?>MARK       ; IMMEDIATE

' IF-NOT ALIAS 0=IF IMMEDIATE

#ELSE

M: IF-NOT       ( -- )
                0= IF ;

>FORTH
' IF-NOT ALIAS 0=IF
>TARGET

#THEN

}

