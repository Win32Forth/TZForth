\ LZ.SEQ   A revision of BADEN's file compression facility

        .options /opt /noinit /tailopton

\ include profile.seq           \ uncomment this out to profile LZ.COM

needs allspecs.seq
needs tpoint.seq

    4096 constant lookBack#
      18 constant lookAhead#
       3 constant breakEven#
   65535 constant segmax
segmax 0 pointer  inseg
segmax 0 pointer  outseg
       0 value    insegment
       0 value    inlen
       0 value    outlen
       0 value    inoff
       0 value    filecnt
       0 value    ?keep
       0 value    ?executable
       0 value    ?existing
      19 array    holding
     128 array    spec_buf      \ a place to hold the file specs
         variable phraseFlag
        2variable read_ptr
        2variable write_ptr

create LZX-start        here /nostack1  \ create array of a file and
                                        \ disable stack depth checking once.
BINLOAD-DATA LZX.COM                    \ Insert the executable file LZX.COM
                                        \ into DATA space
here swap - constant LZX-length         \ define a constant for its length

handle inhndl
handle outhndl

: ?.lzhelp      ( f1 -- )       \ if true, show help
                0= ?exit cls
   ."  LZ.COM - Version: 2.01 - Date: 07/13/93 - by Tom Zimmer"
cr
cr ."  Usage: LZ /A file.LZ filespec <enter>   Add files to the file.LZ"
cr ."         LZ /D file.LZ file.ext <enter>   Delete file.ext from file.LZ"
cr ."         LZ /E file.COM         <enter>   Compress Executable file.COM"
cr ."         LZ /V file.LZ          <enter>   View a files in file.LZ"
cr ."         LZ /X file.COM         <enter>   Expand compressed file.COM"
cr ."         LZ /X file.LZ file.ext <enter>   Extract file.ext from file.LZ"
cr ."         LZ /X file.LZ          <enter>   Extract ALL files from file.LZ"
cr
cr ." LZ.COM is a public domain program by Tom Zimmer, based on work by Will Baden."
cr ." LZ was written in Forth and compiled with the TCOM Target Compiler."
cr ." If you would like to have the source for LZ and other TCOM example programs,"
cr ." send a check for US$60 to:"
cr
cr ." Address: Tom Zimmer             Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive             (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035    Outside US orders add 20 dollars."
cr
cr ." You will receive the newest TCOM compiler, its source, the source for LZ"
cr ." and more than 70 other TCOM utility programs on 3.5 inch 1.44 meg disks."
cr
cr ." Also included is F-PC, the FULL PC Forth system on which TCOM is built."
cr ." This package totals almost five megabytes installed, with source."
                bye ;

: compressable? ( -- )
                outlen 100 + ?executable abs LZX-length * + inlen u>
                if      cr true
                        abort"  ** SORRY! ** This file cannot be compressed! **"
                then    ;

0 value spinval

: ?spincomp     ( -- )          \ video spinner, doesn't effect cursor
                                \ positon or I/O redirection. It is however
                                \ VERY HARDWARE SPECIFIC TO IBM'S & CLONES
                spinval 15 and 0=
[long]  if      at? ." [" inoff u2/ 100 inlen u2/ */ 100 min 2 .r ." %]" at
                broken @ if bye then            \ cancel compress?
        then    incr> spinval ;

: .%orig        ( -- )
                ." by: " outlen u2/ 100 inlen u2/ */ 100 min 100 swap -
                3 .r ." % to: " outlen 6 u.r ;

0 value loff
0 value llen

CODE LONGEST   ( DS: sadr slen ES: dadr dcnt -- address length )
        mov &> loff # 0 word            \ init LOFF to zero
        xchg si, sp
        mov cx, bx                      \ cx=dcnt
        pop di                          \ di=dadr
        pop bx                          \ bx=slen
        dec bx
        mov &> llen bx                  \ init LLEN to full length
        pop ax                          \ ax=sadr
        cmp cx, bx
        u< if         push cx           /nostack1
                      mov bx, # $0000   \ false
                      xchg si, sp
                      ret
        then
        push es                 \ save ES
        push si                 \ save SI
        push bp                 \ save BP
        push ds                 \ a copy of DS
        MOV ES, &> INSEGMENT    \ searching in INSEG
        mov si, ax              \ si=sadr
        jcxz 0 $                \ if CX=0 then we are all done searching
        dec cx                  \ dcnt=dcnt-1
        jcxz 0 $                \ if CX=0 then we are all done searching
        mov dx, bx              \ dx=slen-1
        mov bp, si              \ save SI in BP for restoral

1 $:    mov ax, es
        mov ds, ax              \ set DS back to ES where we are searching
2 $:    mov si, bp
        mov al, 0 [si]          \ look for a matching char
        repnz scasb             \ scan for first char of source string
        jcxz 0 $                \ exit if at end of buffer
        inc si                  \ bump source to second byte of source
        mov ax, di              \ save offset to next character after this
        xchg bx, cx             \ save remaining length to search
        mov cx, dx              \ exchange source and destination lengths
        rep cmpsb               \ compare the strings
        xchg bx, cx             \ save unmatched length
        cmp bx, # lookAhead# breakEven# -       \ if we matched at least this
                                \ recover CX, remaining length to search
        mov di, ax              \ recover pointer to next character
        jge 2 $                 \ of match too short, branch back try again

        mov ax, ss
        mov ds, ax              \ recover DS for the following
        cmp bx, &> llen         \ was a shorter unmatching length found
        jge 1 $

        dec di                  \ backup to start of matching string
        mov &> loff di          \ save offset to longest match
        mov &> llen bx          \ and length of shortest unmatching
        inc di                  \ bump to next character
        jmp 1 $

0 $:    pop ds
        pop bp
        pop si                  \ we searched whole buffer, so exit with
        pop es                  \ the longest matching string
        push &> loff            \ push relative offset
        mov bx, dx              \ subtract longest unmatching from full length
        sub bx, &> llen         \ load bx with length of match
        cmp bx, # breakEven#    \ unless we matched at least breakEven#
        jnl 3 $
        sub bx, bx
3 $:    xchg si, sp
        nop
        ret             end-code

macro 16*       ( n -- 16*n )
                shl bx, # 1
                shl bx, # 1
                shl bx, # 1
                shl bx, # 1     end-macro

: .handle       ( a1 -- )
                ?uppercase >pathend" 12 over - spaces type ."   " ;

: Setup_compress1 ( -<filename.LZ>- )
                bl word ?uppercase outhndl $>handle
                here c@ 0= abort"  No FILENAME.LZ given!"
                " LZ" ">$ outhndl $>ext
                read-write outhndl hopen
                if      outhndl hcreate abort"  Failed to create output file"
                else    on> ?existing
                then    ;

: Setup_compress2 ( -- )
                inhndl handle>ext " .LZ" caps-comp 0=
                abort"  This is already a compressed file!"
                ."  Compressing: " inhndl .handle
                inhndl hopen ?.lzhelp
                ." of:"
                inhndl endfile 2dup 6 d.r space
                nip abort"  File length limited to 65k!"
                0.0 inhndl movepointer                  \ reset to file start
                here 20 erase
                here 20 inhndl hread drop               \ read header
                here 8 + " LZX.COM" comp 0=             \ already compressed?
                abort"  This is already a compressed .COM file!"
                0.0 inhndl movepointer                  \ reset to file start
                0 segmax inhndl inseg exhread !> inlen  \ read the file
                outseg 0 segmax 0 LFILL                 \ clear output
                0 !> inoff                              \ clear input offset
                holding 17 erase                        \ put NULL in holding
                1 holding c!
                128 phraseFlag ! ;

: Setup_executable ( -<filename>- )
                " COM" defext place
                bl word ?uppercase inhndl $>handle
                inhndl handle>ext " .COM" caps-comp
                abort"  Only .COM files can become compressed executables!"
                inhndl handle>ext " .LZ" caps-comp 0=
                abort"  This is already a compressed file!"
                ."  Compressing: " inhndl .handle
                inhndl hopen ?.lzhelp
                ." of:"
                inhndl endfile 2dup 6 d.r space
                nip abort"  File length limited to 65k!"
                0.0 inhndl movepointer                  \ reset to file start
                here 20 erase
                here 20 inhndl hread drop               \ read header
                here 8 + " LZX.COM" comp 0=             \ already compressed?
                abort"  This is already a compressed .COM file!"
                0.0 inhndl movepointer                  \ reset to file start
                inhndl outhndl $>handle
                " LZ" ">$ outhndl $>ext
                0 segmax inhndl inseg exhread !> inlen  \ read the file
                outseg 0 segmax 0 LFILL                 \ clear output
                0 !> inoff                              \ clear input offset
                holding 17 erase                        \ put NULL in holding
                1 holding c!
                128 phraseFlag ! ;

: output_header ( -- )          \ build the output file header
                inhndl >pathend" here place     \ start output with filename
                ?ds: here dup c@ 1+ >r outseg 0 r@ cmovel
                r> !> outlen                    \ set outlen to end of name
                0 outseg outlen !L              \ lay in dummy compressed len
                2 +!> outlen ;                  \ adjust output length by 2

: complete_header ( -- )        \ complete the header information
                outseg 0 countl dup>r + outlen r> 3 + - -rot !L ;

: find_filename ( -- )
                0.0 inhndl movepointer                  \ reset to file start
        begin   inhndl curpointer 2>r
                here 36 inhndl hread 36 =       \ read the filename
[long]  while   here ?uppercase count outhndl >pathend" rot max
                caps-comp 0=
                if              \ adjust just past name and length word
                        2r> here c@ 3 + 0 d+ inhndl movepointer
                        EXIT            \ **** EXITS HERE ****
                then    here count dup>r + @ r> + 3 + 0 2r> d+
                inhndl movepointer
        repeat  2r> 2drop ." for: " outhndl .handle
                true abort" Couldn't find it!" ;

: read_file     ( -- f1 )       \ return f1=true if there is a next file
                read_ptr 2@ inhndl movepointer
                here 36 inhndl hread 36 =               \ read the filename
[long]  if      inhndl curpointer 36. d- inhndl movepointer
                here count dup>r + @ r> + 3 + !> inlen  \ set file len
                0 inlen inhndl inseg exhread            \ read the file
                inlen <> abort"  This .LZ file is corrupted!"
                inhndl curpointer read_ptr 2!
                true
        else    false
        then    ;

: write_file    ( -- )  \ write file in memory to postion of prev file
                write_ptr 2@ inhndl movepointer
                0 inlen inhndl inseg exhwrite           \ write the file
                inlen <> abort"  Write error during Delete!"
                inhndl curpointer write_ptr 2! ;

: truncate_file ( -- )  \ shorten file to current length
                write_ptr 2@ or 0=              \ if truncated to zero length
                if      inhndl hclose drop
                        inhndl hdelete drop
                        BYE                     \ nothing else to delete, so
                                                \ lets just return to DOS
                else    write_ptr 2@ inhndl movepointer
                        here 0 inhndl hwrite drop
                then    ;

: Setup_expand1 ( -<filename.LZ>- f1 )  \ f1=true=expanding a .COM file
                bl word ?uppercase inhndl $>handle
                inhndl handle>ext " .COM" caps-comp dup>r
                if      " LZ" ">$ inhndl $>ext          \ if not.COM, use .LZ
                        ."  Searching: "
                else    ."  Expanding: "
                then    inhndl .handle
                inhndl hopen abort" Failed to open input file"
                ." of:"
                inhndl endfile 6 d.r space
                0.0 inhndl movepointer                  \ reset to file start
                r> 0=                   \ if flag says YES we are a .COM file
[long]          if      here 20 erase
                        here 20 inhndl hread drop       \ read header
                        here 8 + " LZX.COM" comp
                        abort"  This file was not compressed by LZ.COM!"
                        here 3 + @ 16 * $100 - dup>r 0 inhndl movepointer
                        here 30 erase
                        here 30 inhndl hread drop       \ read DP
                        here @                          \ addr of START
                        r> + dup>r 0 inhndl movepointer \ start of compressed
                        here 36 inhndl hread drop       \ read the filename
                        here c@ 3 + r> + 0 inhndl movepointer
                        false
                else    true
                then    ;

: Setup_expand2 ( -<filename>- )
                here count + @ !> inlen         \ set compressed length
                here outhndl $>handle           \ put filename in OUTHNDL
                 inseg 0 segmax 0 LFILL         \ clear output segment
                outseg 0 segmax 0 LFILL         \ clear output segment
                0 inlen inhndl inseg exhread    \ read the file
                inlen <> abort"  Compressed file read error!"
                off> outlen                     \ clear input offset
                off> inoff
                holding 17 erase                \ put NULL in holding
                ;

: fill_holding  ( -- n1 )       \ fill and return byte count in holding
                inseg inoff inlen inoff - >r
                ?ds: holding count lookAhead# swap /string r> umin dup>r
                cmovel r> dup +!> inoff holding c+!
                holding c@ dup lookAhead# <>
                if      noop
                then    ;

: expand_holding ( -- )
        holding 1+ count
        8 0
        do      dup $80 and             \ if MSB set
                if      over @ 0 4096 um/mod 3 + >r
                        outlen  lookBack# u>
                        if      outlen lookBack# - +
                        then
                        outseg swap outseg outlen r@ cmovel r> +!> outlen
                        swap 2+ swap
                else    over c@ outseg outlen c!L
                        incr> outlen
                        swap 1+ swap
                then    2*
                over holding count + u>= ?leave \ limit to holdings length
        loop    drop
        holding 1+ - holding count rot /string holding place ;

M: findBestMatch ( -- location matched )
                inoff inlen inoff - lookAhead# umin   \ searching for this
                inoff lookBack# u>
                if      inoff lookBack# - lookBack#
                else    0 inoff
                then    longest ;

: RunOut        ( -- )
                holding c@ 1 >
                if      ?ds: holding count >r outseg outlen r@ cmovel
                        r> +!> outlen
                then
                holding 17 erase                \ put NULLs in holding
                1 holding c!
                128 phraseFlag !
                ?spincomp ;

code char>holding+ ( -- )
                mov dx, es
                mov es, &> insegment
                mov di, &> inoff
                mov al, es: 0 [di]
                sub cx, cx
                add holding # 1         \ a byte add
                mov cl, holding
                add cx, # holding
                mov di, cx
                mov 0 [di], al
                mov es, dx
                ret     end-code

macro phraseflag/2@ ( -- n1 )           \ speedup routine
                save_bx
                mov bx, phraseFlag
                shr bx, # 1
                mov phraseFlag bx
                end-macro

macro phraseFlag>holding+1 ( -- )
                mov al, phraseFlag
                or holding 1+ al
                end-macro

code token>holding+ ( location matched -- matched )
                sub cx, cx
                mov ch, bl
                xchg bx, 0 [si]
                cmp &> inoff # lookBack# word   \ if INOFF greater than
                jb  0 $                         \ then
                sub bx, &> inoff                \ adjust by INOFF and
                add bx, # lookBack#             \ by LOOKBACK#
           0 $: sub ch, # breakEven#            \ reduce matched by breakEven#
                shl ch, # 1                     \ and shift into high nibble
                shl ch, # 1
                shl ch, # 1
                shl ch, # 1
                or bx, cx               \ merge in length nibble to offset
                sub cx, cx
                mov di, # &> holding
                mov cl, holding         \ pick up current length
                add di, cx              \ adjust to current text end
                inc di                  \ adjust to just past last character
                mov 0 [di], bx          \ append char to string
                add holding # 2         \ adj current length plus cnt
                load_bx
                ret     end-code


: PutMatchingPhraseCode ( location matched -- matched )
                dup \ breakEven# >=                       \ location matched flg
                if      token>holding+ >r
                        phraseFlag>holding+1
                else    2drop char>holding+
                        1 >r                            \ matched
                then    phraseFlag/2@                   \ shift and fetch
                0= if  runout   then                    \ may need to flush
                r> ;                                    \ matched

M: UpdateInOff  ( matched -- )
                +!> inoff ;

: LZ_view       ( -<filename>- )
                off> filecnt
                bl word inhndl $>handle
                " LZ" ">$ inhndl $>ext
                ." File: " inhndl .handle
                inhndl hopen abort" Failed to open input file"
        begin   inhndl curpointer 2>r
                here 36 inhndl hread 36 =       \ read the filename
[long]  while   cr 7 spaces
                here .handle                    \ display name of orig file
                here count + @ 6 u.r
                here count dup>r + @ r> + 3 + 0 2r> d+
                inhndl movepointer
                incr> filecnt
        repeat  2r> 2drop
                cr ."  Contains: " filecnt u. ." Files totaling: "
                inhndl curpointer 1 ud,.r ."  bytes"
                inhndl  hclose drop             \ close input file
                ;

: expand_one    ( f1 -- )
                >r Setup_expand2
                begin   fill_holding
                while   expand_holding
\                        ?keypause
                repeat
                outhndl hcreate abort"  Failed to create output file"
                0 outlen outhndl outseg exhwrite drop
                r>
                if      cr ."  Expanding: "
                else    ." Into: "
                then    outhndl .handle ." as: " outlen 6 u.r ."  bytes"
                outhndl hclose drop ;

: expand_all    ( -- )          \ expand all files in .LZ
                begin   inhndl curpointer
                        here 36 inhndl hread 36 = -rot  \ read the filename
                        here c@ 3 + 0 d+ 2>r
                while   2r> inhndl movepointer
                        true expand_one
                        ?keypause
                repeat  2r> 2drop
                inhndl hclose drop ;

: LZ_expand     ( -<filename...>- )
                Setup_expand1 dup>r
                if      bl word c@ 0=
                        if      expand_all
                                r>drop
                                EXIT            \ ***** EXITS HERE *****
                        then
                        here ?uppercase outhndl $>handle
                then
        begin   here c@
[long]  while   r@
                if      find_filename
                then    r@ expand_one
                r@
                if      bl word ?uppercase outhndl $>handle
                else    cr
                        inhndl hclose drop
                        >in @ bl word c@ swap >in ! 0=
                        if      bye             \ terminate at end of list
                        then
                        setup_expand1 abort"  We are doing Executables!"
                then
        repeat  r>
                if      inhndl  hclose drop     \ close input file
                then    ;

: LZ_delete     ( -<filename...>- )
                Setup_expand1 drop
                bl word c@ 0= abort"  No delete filename given!"
                here ?uppercase outhndl $>handle
        begin   inhndl hclose read-write inhndl hopen or
                abort"  Failed to open the .LZ as a READ-WRITE file!"
                find_filename
                inhndl curpointer here c@ 3 + 0 d-
                                        2dup read_ptr 2! write_ptr 2!
                read_file drop
                begin   read_file
                while   write_file
                repeat  cr ."    Deleted: "  outhndl .handle
                truncate_file
                bl word ?uppercase outhndl $>handle
                here c@ 0=
        until   inhndl  hclose drop ;           \ close input file

: %LZ_compress  ( -- )
                output_header
                begin   inlen inoff u>          \ While input to process
        [long]  while   findBestMatch           \ location matched
                        PutMatchingPhraseCode   \ matched
                        UpdateInOff
                repeat  RunOut
                complete_header
                inhndl  hclose drop ;

: compress_inhndl ( -- )
                Setup_compress2
                %LZ_compress
                ." into: " outhndl .handle .%orig cr
                outhndl endfile 2drop
                0 outlen outhndl outseg exhwrite drop ;

: $do_1spec     ( a1 | -- )             \ do all files in a filespec
                count spec_buf place    \ put in spec buffer
                spec_buf $getdir                \ read the directory files.
                #fls 0
        [long]  ?do     i dup >fadr 1+ c@l '.' -
                        if      >fadr dir>pad >r
                                spec_buf inhndl $>handle
                                inhndl >pathend
                                dup inhndl 1+ - r@ + inhndl c! r> cmove
                                inhndl count + off
                                compress_inhndl
                        else    drop
                        then    ?keypause
                loop    ;

   700 constant maxfiles        \ only hold upto 700 filenames in list
                                \ from any given directory.

: LZ_compress   ( -<filename>- )
                maxfiles =: maxdir      \ up to "maxfiles" directory entries
                dirinit                 \ initialize directory words
                diralloc                \ allocate directory name space
                dirseg
[long]  if      Setup_compress1
                bl word ?uppercase inhndl $>handle
                here c@ 0= abort"  No filename to compress given!"
                begin   here c@
                while   inhndl $do_1spec
                        bl word ?uppercase inhndl $>handle
                repeat  outhndl hclose drop
                dirrelease              \ release directory name space
        else    cr ." Not enough memory"
        then    ;

: LZ_executable ( -<filename>- )
        begin   on> ?executable
                Setup_executable
                %LZ_compress
                compressable?           \ file MUST be compressable!
                ?keep 0=
                if      " COM" ">$    outhndl $>ext
                else    " LZTEMP.COM" outhndl ">handle
                then    ." into: " outhndl .handle
                outhndl hcreate abort" Failed to create output file"
                LZX-start LZX-length                    \ write LZX.COM
                outhndl hwrite drop                     \ plus stack space,
                0 outlen outhndl outseg exhwrite drop   \ then write the
                outhndl hclose drop                     \ compressed image.
                ." by " outlen LZX-length + u2/
                100 inlen u2/ */ 100  min 100 swap - 3 .r ." % to: "
                outlen LZX-length + 6 u.r
                >in @ bl word c@ swap >in !
        while   cr
        repeat  ;

: LZ_init     ( -- )            \ some additional default initialization
                                \ done for all applications
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $0 SET_MEMORY                   \ default to min code space
                DOS_TO_TIB                      \ move command tail to TIB
                ['] (emit) is emit              \ use normal EMIT
                ;

: /test         ( -<name>- )    \ define a word that tests commandline options
                ( -- f1 )       \ test string a1, n1 commandline option
                                \ and return boolean flag f1 true if found
                create
                does>   >in @ bl word 1+ rot count caps-comp 0=
                        if      drop  true
                        else    >in ! false
                        then    ;

/test ?/xpand   ," /X"  ( -- f1 )       \ /Xpand the compressed file
/test ?/view    ," /V"  ( -- f1 )       \ /View  the compressed file
/test ?/add     ," /A"  ( -- f1 )       \ /Add to a compressed file
/test ?/delete  ," /D"  ( -- f1 )       \ /Delete a file
/test ?/execute ," /E"  ( -- f1 )       \ /Executable file creation
/test ?/keep    ," /K"  ( -- f1 )       \ /Keep executable, make LZTEMP.COM

/test ?-xpand   ," -X"  ( -- f1 )       \ /Xpand the compressed file
/test ?-view    ," -V"  ( -- f1 )       \ /View  the compressed file
/test ?-add     ," -A"  ( -- f1 )       \ /Add to a compressed file
/test ?-delete  ," -D"  ( -- f1 )       \ /Delete a file
/test ?-execute ," -E"  ( -- f1 )       \ /Executable file creation
/test ?-keep    ," -K"  ( -- f1 )       \ /Keep executable, make LZTEMP.COM

: LZ77          ( -- )
                LZ_init
                inseg  0=
                outseg 0= or abort"  Failed to allocate memory!"
                inseg !> insegment      \ needed for use in a CODE word
\+ prostart     prostart
                ?/xpand    if   LZ_expand       [long]  else
                ?/view     if   LZ_view         [long]  else
                ?/execute  if   ?/keep !> ?keep
                                LZ_executable           else
                ?/add      if   LZ_compress             else
                ?/delete   if   LZ_delete               else
                ?/xpand    if   LZ_expand               else
                ?-view     if   LZ_view                 else
                ?-execute  if   ?-keep !> ?keep
                                LZ_executable           else
                ?-add      if   LZ_compress             else
                ?-delete   if   LZ_delete               else
                                true ?.lzhelp
                then then then then then
                then then then then then
\+ proend       proend
                ;


