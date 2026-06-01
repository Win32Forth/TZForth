\ SEARCH.SEQ    String search routine.                  by Roger Bird

comment:

  This file may be removed, but it is used by WORDS.SEQ, and ENVIRON.SEQ,
which is itself used by EXEC.SEQ.

  The String manipulation primitives include string comparison and
searching. The string search implemented is used in the editor
to find the desired string.  The only unusual thing about it is
the presence of a variable called CAPS, which determines
whether or not to ignore the case of the subject and pattern
strings.  If case is ignored then A-Z = a-z.  The default is
ignore case.

        Much thanks to Roger Bird for this improved implementation
        of SEARCH, it is about 20 % faster than my previous improved
        version, and is 10 times faster in the case where the string
        being searched for starts with a space. It is also 140 bytes
        smaller than the old implimentation.

 11/04/91 15:00:33.61 tjz

  Modified SEARCH to perform case conversion properly, by using a
translation table rather than ORing each character with BLANK.

comment;

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

TABLE ATBL     \ Uppercase translation table
 0  C,   1  C,   2  C,   3  C,   4  C,   5  C,   6  C,   7  C,
 8  C,   9  C,  10  C,  11  C,  12  C,  13  C,  14  C,  15  C,
16  C,  17  C,  18  C,  19  C,  20  C,  21  C,  22  C,  23  C,
24  C,  25  C,  26  C,  27  C,  28  C,  29  C,  30  C,  31  C,
32  C,  '!' C,  '"' C,  '#' C,  '$' C,  '%' C,  '&' C,  ''' C,
'(' C,  ')' C,  '*' C,  '+' C,  ',' C,  '-' C,  '.' C,  '/' C,
'0' C,  '1' C,  '2' C,  '3' C,  '4' C,  '5' C,  '6' C,  '7' C,
'8' C,  '9' C,  ':' C,  ';' C,  '<' C,  '=' C,  '>' C,  '?' C,
'@' C,  'A' C,  'B' C,  'C' C,  'D' C,  'E' C,  'F' C,  'G' C,
'H' C,  'I' C,  'J' C,  'K' C,  'L' C,  'M' C,  'N' C,  'O' C,
'P' C,  'Q' C,  'R' C,  'S' C,  'T' C,  'U' C,  'V' C,  'W' C,
'X' C,  'Y' C,  'Z' C,  '[' C,  '\' C,  ']' C,  '^' C,  '_' C,
'`' C,  'A' C,  'B' C,  'C' C,  'D' C,  'E' C,  'F' C,  'G' C,
'H' C,  'I' C,  'J' C,  'K' C,  'L' C,  'M' C,  'N' C,  'O' C,
'P' C,  'Q' C,  'R' C,  'S' C,  'T' C,  'U' C,  'V' C,  'W' C,
'X' C,  'Y' C,  'Z' C,  '{' C,  '|' C,  '}' C,  '~' C,  127 C,
\ Characters above 127 are translated to below 127
 0  C,   1  C,   2  C,   3  C,   4  C,   5  C,   6  C,   7  C,
 8  C,   9  C,  10  C,  11  C,  12  C,  13  C,  14  C,  15  C,
16  C,  17  C,  18  C,  19  C,  20  C,  21  C,  22  C,  23  C,
24  C,  25  C,  26  C,  27  C,  28  C,  29  C,  30  C,  31  C,
32  C,  '!' C,  '"' C,  '#' C,  '$' C,  '%' C,  '&' C,  ''' C,
'(' C,  ')' C,  '*' C,  '+' C,  ',' C,  '-' C,  '.' C,  '/' C,
'0' C,  '1' C,  '2' C,  '3' C,  '4' C,  '5' C,  '6' C,  '7' C,
'8' C,  '9' C,  ':' C,  ';' C,  '<' C,  '=' C,  '>' C,  '?' C,
'@' C,  'A' C,  'B' C,  'C' C,  'D' C,  'E' C,  'F' C,  'G' C,
'H' C,  'I' C,  'J' C,  'K' C,  'L' C,  'M' C,  'N' C,  'O' C,
'P' C,  'Q' C,  'R' C,  'S' C,  'T' C,  'U' C,  'V' C,  'W' C,
'X' C,  'Y' C,  'Z' C,  '[' C,  '\' C,  ']' C,  '^' C,  '_' C,
'`' C,  'A' C,  'B' C,  'C' C,  'D' C,  'E' C,  'F' C,  'G' C,
'H' C,  'I' C,  'J' C,  'K' C,  'L' C,  'M' C,  'N' C,  'O' C,
'P' C,  'Q' C,  'R' C,  'S' C,  'T' C,  'U' C,  'V' C,  'W' C,
'X' C,  'Y' C,  'Z' C,  '{' C,  '|' C,  '}' C,  '~' C,  127 C,
END-TABLE

CODE SEARCH    ( sadr slen dadr dcnt -- offset found? )
        [ASSEMBLER]
        xchg si, sp
        mov cx, bx
        pop di
        pop bx   pop ax
        cmp bx, # 0     \ if search length "slen" is 0 then return true
        0= if         push bx
                      mov bx, # $FFFF   \ true
                      xchg si, sp
                      ret
        then
        cmp cx, bx
        u< if         push cx
                      mov bx, # $0000   \ false
                      xchg si, sp
                      ret
        then
        push di
        push es
        push si       push bp
        MOV ES, SSEG
        mov si, ax
        dec bx
        dec cx
        mov dx, bx
        MOV BP, BX
        MOV BX, # ATBL
        CMP CAPS # 0 WORD
 0<> IF begin                   \ handle case insensitive
            CMP BP, CX
        u<= while
            begin       mov AL, es: 0 [di+BP]
                        XLAT
                        MOV AH, AL
                        mov al,     0 [si+BP]
                        XLAT
                        CMP AH, AL
            0= while  dec BP
                   0< if     pop bp   pop si   pop es
                             pop dx   sub di, dx
                             push di  mov bx, # $ffff
                             XCHG SI, SP
                             RET
                      then
            repeat
                inc di
                jcxz 0 $        \ if CX=0 then we are all done searching
                dec cx   mov BP, dx
        repeat  jmp 0 $
    THEN
        begin                   \ handle case sensitive
            CMP BP, CX
        u<= while
            begin       mov al,     0 [si+BP]
                        CMP AL, es: 0 [di+BP]
            0= while  dec BP
                   0< if     pop bp   pop si   pop es
                             pop dx   sub di, dx
                             push di  mov bx, # $ffff
                             XCHG SI, SP
                             RET
                      then
            repeat
                inc di
                jcxz 0 $        \ if CX=0 then we are all done searching
                dec cx   mov BP, dx
        repeat
    0 $:
        pop bp      pop si       pop es
        pop dx      sub di, dx   push di
        sub bx, bx
        xchg si, sp
        ret             end-code

FORTH TARGET >TARGET

