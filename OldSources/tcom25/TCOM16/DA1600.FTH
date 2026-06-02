\\ DA1600.SEQ            SSP1600 Disassembler           by Tom Zimmer
========================================================================

                 This program is a SSP1600 disassembler.

        Originally written for the SAM8 by Jerry Boutelle.

        Portions of this disassembler have been extracted from the
        above work.

{

}

                      旼컴컴컴컴컴컴컴컴컴컴컴컴커
                      쿛rinting of symbolic names�
                      읕컴컴컴컴컴컴컴컴컴컴컴컴켸

{

: .DATA ( <im> -- )
        dup a-data-symbol?                           \ in symbol table ?
        IF drop
           sym-name> 1+ sym-seg over 1- c@l
           lst-file-handle sym-seg
           exbwrite SPACE
        ELSE h.
        THEN ;

: .DAshort ( a1 -- )
        dup a-function-symbol?
        IF drop
           sym-name> 1+ sym-seg over 1- c@l
           lst-file-handle sym-seg
           exbwrite
        ELSE h.\
        THEN ;

: call.ia   ( <im> -- )
        ." #" dup h.\ ." =[ " d-t@
        dup a-function-symbol?
        IF drop
           sym-name> 1+ sym-seg over 1- c@l
           lst-file-handle sym-seg
           exbwrite
        ELSE h.\
        THEN ."  ]" ;

\ *************************************************************************
\ HERE GOES THE ACTUAL DISASSEMBLER
\ *************************************************************************

: %DISASM ( <opc> -- )
       dis1 +cptr ;               \ advance the code pointer


: %.INST-BYTES ( -- )
        hex
        cptr d-tc@                      \ get the opcode for this instruction
        byte-count + c@ 1-
        dup !> #inst-bytes              \ save the number of bytes in inst
        dup >r                          \ get the number of bytes to print
        0
        ?DO                             \ space before to conform with MDF
           cptr i + d-tc@ 2 0.r space   \ print a byte
        LOOP
        cptr r> + d-tc@ 2 0.r ;          \ print last byte

\ ==== hex file ======================================================

\+ on-mds \s    \ stop loading here if on MDS


CODE place-hex-record ( -- ) \ move a hex record, outbuf -> to object memory
\tcom   save_bx
        push    es
        mov     ax, &> obj-seg
 512 $: mov     es, ax
        push    si
        push    bp
        mov     bx, # outbuf            \ get the size of the hex record
        mov     al, 3 [bx]
        cmp     al, # 'A'
        jl      0 $
        sub     al, # '7'
        jmp     1 $
   0 $: sub     al, # '0'
   1 $: mov     cl, al
        sub     ch, ch
        mov     al, 2 [bx]
        cmp     al, # 'A'
        jl      2 $
        sub     al, # '7'
        jmp     3 $
   2 $: sub     al, # '0'
   3 $: sub     ah, ah
        mov     dx, # $10
        mul     ax, dx
        add     cx, ax
        mov     al, 7 [bx]              \ get data address
        cmp     al, # 'A'
        jl      4 $
        sub     al, # '7'
        jmp     5 $
   4 $: sub     al, # '0'
   5 $: sub     ah, ah
        mov     di, ax
        mov     al, 6 [bx]
        cmp     al, # 'A'
        jl      6 $
        sub     al, # '7'
        jmp     7 $
   6 $: sub     al, # '0'
   7 $: sub     ah, ah
        mov     dx, # $10
        mul     ax, dx
        add     di, ax
        mov     al, 5 [bx]
        cmp     al, # 'A'
        jl      8 $
        sub     al, # '7'
        jmp     9 $
   8 $: sub     al, # '0'
   9 $: sub     ah, ah
        mov     dx, # $100
        mul     ax, dx
        add     di, ax
        mov     al, 4 [bx]
        cmp     al, # 'A'
        jl      10 $
        sub     al, # '7'
        jmp     11 $
  10 $: sub     al, # '0'
  11 $: sub     ah, ah
        mov     dx, # $1000
        mul     ax, dx
        add     di, ax
\ \+ on-mds add   di, &> extent-byte-offset
        sub     si, si
        sub     ah, ah
  12 $: mov     bp, cx                          \ save loop counter
        mov     cl, $0b [bx+si]                 \ get lower nibble
        cmp     cl, # 'A'
        jl      13 $
        sub     cl, # '7'
        jmp     14 $
  13 $: sub     cl, # '0'
  14 $: mov     al, $0a [bx+si]                 \ get upper nibble
        cmp     al, # 'A'
        jl      15 $
        sub     al, # '7'
        jmp     16 $
  15 $: sub     al, # '0'
  16 $: shl     al, # 1
        shl     al, # 1
        shl     al, # 1
        shl     al, # 1
        or      al, cl
        mov     es: 0 [di], al
        inc     si
        inc     si
        inc     di
        mov     cx, bp                          \ restore loop counter
        loop    12 $
        pop     bp
        pop     si
\tcom   load_bx
        pop     es
\tcom   ret
\fpc    next
        END-CODE

\fpc CODE place-ext-record ( -- ) \ move a hex record to ext memory
\fpc         push    es
\fpc         mov     ax, &> ext-seg
\fpc         jmp 512 $                  \ use a global label
\fpc         512 01lab                  \ clear the global label
\fpc         END-CODE

: CLOSE-HEX-FILE ( -- )
        seqhandle hclose drop ;

: OPEN-HEX-FILE ( -- )
        " hex" ">$ file-name $>ext              \ get the file name
        file-name $file
        IF screen-output
           help-them
           ." Couldn't open hex file, extension: .hex"
           ls-abort
        THEN ibreset ;

\+ on-mds true
\- on-mds false
#if
: %LOAD-OBJ-FILE ( -- )
        open-hex-file
        begin   lineread c@              \ get an object line
        while   outbuf 8 + @             \ get the HEX record type
                dup  " 20" drop @ =      \    record type 20
                over " 00" drop @ = or   \ or record type 00
                if place-hex-record      \ place the bytes in obj memory
                then
                dup " 22" drop @ =      \ or record type 22 extent-bytes
                if place-ext-record      \ place the bytes in ext memory
                then    drop
        repeat close-hex-file ;
#else
: %LOAD-OBJ-FILE ( -- )
        open-hex-file
        begin   lineread c@              \ get an object line
        while   outbuf 8 + @             \ get the HEX record type
                dup  " 20" drop @ =      \    record type 20
                swap " 00" drop @ = or   \ or record type 00
                if place-hex-record      \ place the bytes in obj memory
                then
        repeat  close-hex-file ;

: PROCESSOR-INIT ( -- )                 \ perform precessor specific init
        false !> ignore-library-code
        ;
#then

