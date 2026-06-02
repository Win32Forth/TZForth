\ THANDLES.SEQ          Handle impementation file       by Tom Zimmer

\ This file contains the code to talk to a file with the
\ DOS 2.00+ handle routines.

FORTH DECIMAL TARGET >LIBRARY       \ A library file

TABLE DEFEXT    0 C,                                    \ length is zero
                0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,      \ extra space
END-TABLE

: ?DEF.EXT      ( handle --- )    \ maybe add an extension to file
                 dup c@ 60 > if drop exit then
                 >r true r@ count over + 1- over umax
               ?do      i c@ ASCII . =
                        if      drop false leave
                        then
                        i c@ ASCII \ = ?leave
            -1 +loop    \ returns true if no decimal point found
                if      defext c@
                        if      defext count r@ count + 1+ swap cmove
                                ASCII . r@ count + c!
                                defext c@ 1+ r@ c@ + r@ c!
                        then
                then    r>drop ;

: ">HANDLE       ( a1 n1 a2 --- )       \ move string a1,n1 into handle a2
                 DUP>R CLR-HCB
                 63 MIN R@ PLACE 0 R@ COUNT + C!
                 R> ?DEF.EXT ;

: $>HANDLE      ( a1 a2 -- )            \ move counted string into handle a2
                >R COUNT R> ">HANDLE ;

: HANDLE>EXT    ( handle -- a1 )
                count + dup dup 4 -
                do      i c@ '.' =
                        if      drop i leave  then
                loop    ; \ points to final decimal point if present

: $>EXT         ( string-extension handle --- )
                dup c@ 60 > if 2drop exit then
                dup>r handle>ext
                '.' over c! 1+ >r count r@ over >r
                swap cmove r> r> + 0 over c! r@ - 1- r> c! ;

ICODE HDOS1     ( cx dx fun -- ax cf | error-code 1 )
                [ASSEMBLER]
                LODSW
                XCHG BX, AX
                MOV DX, BX
                MOV CX, 0 [SI]
                int $21
                MOV 0 [SI], AX
             U< IF      MOV AL, # 1
                ELSE    MOV AL, # 0
                THEN
                SUB AH, AH
                MOV BX, AX
                RET             END-ICODE

ICODE HDOS3     ( bx cx dx ds fun -- ax cf | error-code 1 )
                [ASSEMBLER]
                PUSH DS
                MOV CX, BX
                LODSW           PUSH AX
                LODSW           MOV DX, AX
                LODSW           XCHG CX, AX
                MOV BX, 0 [SI]
                POP DS
                INT $21
                POP DS
                MOV 0 [SI], AX
             U< IF      MOV AL, # 1
                ELSE    MOV AL, # 0
                THEN
                SUB AH, AH
                MOV BX, AX
                RET             END-ICODE

ICODE HDOS4     ( bx cx dx fun -- ax cf | error-code 1 )
                [ASSEMBLER]
                LODSW           MOV DX, AX
                LODSW           MOV CX, AX
                MOV AX, BX
                MOV BX, 0 [SI]
                int $21
                MOV 0 [SI], AX
             U< IF      MOV AL, # 1
                ELSE    MOV AL, # 0
                THEN
                SUB AH, AH
                MOV BX, AX
                RET             END-ICODE

ICODE MOVEPOINTER ( double-offset handle --- )
                [ASSEMBLER]
                ADD BX, # 68
                MOV BX, 0 [BX]
                LODSW           MOV CX, AX
                LODSW           MOV DX, AX
                MOV AX, # $4200  \ FROM START OF FILE
                INT $21
                LODSW           MOV BX, AX
                RET             END-ICODE

ICODE ENDFILE   ( handle --- double-end )
                [ASSEMBLER]
                ADD BX, # 68
                MOV BX, 0 [BX]
                MOV CX, # 0
                MOV DX, # 0
                MOV AX, # $4202         \ from end of file
                INT $21
             U< IF
                        SUB AX, AX
                THEN
                DEC SI
                DEC SI
                MOV 0 [SI], AX
                MOV BX, DX
                RET             END-ICODE

ICODE <HRENAME> ( handle1 handle2 --- ax cf=0 | error-code 1 )
                [ASSEMBLER]
                MOV DI, BX
                ADD DI, # 1
                MOV DX, 0 [SI]
                PUSH ES                 \ save ES for later restoral
                MOV AX, DS
                MOV ES, AX              \ set es to DS
                ADD DX, # 1
                MOV AX, # $5600         \ from start of file
                INT $21
                POP ES                  \ restore ES
                MOV 0 [SI], AX
             U< IF      MOV BX, # 1
                ELSE    MOV BX, # 0
                THEN
                RET             END-ICODE
                        \ returns 18 if the rename was good, not zero.

: HRENAME       ( handle1 handle2 --- return-code )
                <HRENAME>
                if      $0FF and
                else    drop 0
                then    ;

: HCREATE       ( handle --- error-code )
                dup >hndle >r           \     save handle address
                0 swap >nam             \ --- bx attrib name
                $3C02 hdos1 0=
                if      r@ ! 0          \ stuff handle, ret 0
                else    $0FF and
                then    r>drop ;

0 VALUE R/W-MODE                \ current read/write mode
0 VALUE R/W-DMODE               \ default read/write mode

\ This word allow you to set the default read/write mode used by F-PC.
\ It is used as follows:
\                               READ-WRITE DEF-RWMODE
\                       or      READ-ONLY  DEF-RWMODE
\
\ All further file open operations will be in the newly specified mode.

: DEF-RWMODE    ( -- )          \ use current mode as the default.
                r/w-mode !> r/w-dmode ;

\ The following words effect only the next HOPEN operation to be performed.
\ After the open is done, R/W-MODE reverts to the the default mode for later
\ file opens.

: READ-ONLY     ( -- )          \ open a file for read only
                0 !> r/w-mode ;

: READ-WRITE    ( -- )          \ open a file for read and write operations
                2 !> r/w-mode ;

: WRITE-ONLY    ( -- )          \ open a file for write only.
                1 !> r/w-mode ;

: HOPEN         ( handle --- error-code )
                DUP PATHSET ?dup if  nip exit then
                dup >hndle >r           \ save handle address
                dup >attrib @           \ hndl --- hndl attib
                swap >nam               \ --- attrib name
                $3D00 r/w-mode or
                hdos1 0=                \   read/write attribs
                if      r@ ! 0          \ stuff handle, ret 0
                else    $0FF and        \ else error code
                then    r>drop          \ clean rstack
                r/w-dmode !> r/w-mode ;  \ revert to default mode

: HCLOSE        ( handle --- return-code )
                >hndle dup @ -1 rot ! dup 0<
                if      drop 0
                        exit            \ LEAVE NOW
                then
                0 0 $3E00 hdos4
                if      $0FF and
                else    drop 0
                then    ;

: HDELETE       ( handle --- return-code )
                0 0 rot >nam $4100 hdos4
                if $0FF and else drop 0 then ;

                \ extended read
: EXHREAD       ( a1 n1 handle segment -- length-read )
                >r >hndle @ -rot swap r> $3F00 hdos3
                if      $0FF and rwerr ! 0 then ;

                \ extended write
: EXHWRITE      ( a1 n1 handle segment -- length-written )
                >r >hndle @ -rot swap r> $4000 hdos3
                if      $0FF and rwerr ! 0 then ;

: HWRITE        ( a1 n1 handle --- length-written )
                >hndle @ -rot swap    \ handle count addr
                $4000 hdos4 if   $0FF and rwerr ! 0 then ;

: HREAD         ( a1 n1 handle --- length-read )
                >hndle @ -rot swap    \ handle count addr
                $3F00 hdos4 if   $0FF and rwerr ! 0 then ;

\ In the following definition, "attr" defines what type of special files
\ (besides normal files) are to be found by FIND-FIRST. The lower six bits
\ of "attr" are defined to control the find as follows:
\
\                 0       read-only
\                 1       hidden
\                 2       system
\                 3       volume label
\                 4       directory
\                 5       archive
\
\ The upper three bits are reserved, and should always be zero.

CODE FIND-FIRST ( adr attr -- t/f )     \ find first file including type attr
                mov     cx, bx
                xor     bx, bx          \ adr is null terminated filename
                lodsw
                mov dx, ax
                mov     ax, # $4E00     \ return FALSE if name was found
                int     $21
                jnc     1 $
                dec     bx      \ error. in BX set true
        1 $:    ret             end-code

CODE FIND-NEXT  ( -- t/f )              \ find next occurance of name above
                save_bx
                xor     bx, bx          \ return FALSE if another was found
                mov     ax, # $4F00
                int     $21
                jnc     1 $
                dec     bx      \ error
        1 $:    ret             end-code

CODE DTA@       ( -- seg offset )       \ get the data transfer seg&offset
                save_bx
                mov     ah, # $2F
                mov     cx, es
                int     $21
                dec si
                dec si
                mov 0 [si], es
                mov     es, cx
                ret             end-code

CODE DTA!       ( seg offset -- )       \ set the data transfer seg&offset
                mov     cx, ds
                mov     dx, bx
                lodsw
                mov     ds, ax
                mov     ax, # $1A00
                int     $21
                mov     ds, cx
                load_bx
                ret             end-code

: SET-DTA       ( a1 --- )
                ?ds: swap dta! ;

CODE SETDIR     ( counted_string -- f1 )        \ f1 <> 0 = error code
                [ASSEMBLER]
                MOV DX, BX
                inc dx
                mov ax, # $3B00
                int $21
             U< IF      MOV BX, ax
                ELSE    MOV BX, # 0
                THEN
                RET             END-CODE

CODE SETDRIVE   ( n1 -- )       \ set drive n1 (0=A:) as the current drive
                mov dx, bx              \ drive into DL
                mov ax, # $0E00
                int $21
                load_bx
                RET             END-CODE

CODE GETDISKFREE        \ return free space from disk
                ( dv --- avail.clusters bytes/sec secs/cluster )
                MOV AH, # 54
                MOV DX, BX
                INT $21
                SAVE_BX
                MOV BX, CX
                SAVE_BX
                MOV BX, AX
                RET             END-CODE

FORTH DECIMAL TARGET >TARGET

