\\ ZZ.SEQ                Mini Shell                      Tom Zimmer

  A very small program that just processes commands from the file
ZZ.CFG which contains programs and parameters passed between shelled
programs.

  Compile as follows:   TCOM ZZ /OPT /NOINIT enter

{
        .options /opt /noinit

\ ***************************************************************************
\ the next few lines define immediate words that allow definitions to
\ select what will be compiled from source lines for either F-PC or TCOM.

\F true  #IF  \ Test for NOT target compiling
\T false #IF  \ Test for NOT target compiling

only forth also definitions hidden also

: DS:ALLOC      ( n1 -- a1 )    \ allocate n1 bytes of ram at runtime,
                                \ returning a1 the address of the ram
                HERE SWAP ALLOT ;

: SET_MEMORY    drop ;
: DOS_TO_TIB         ;  immediate
: COMSPEC_INIT       ;  immediate

#ENDIF

CHECK_/NOINIT

\ ***************************************************************************
\ now start the Mini Shell program

handle mshndl

 256 constant cmd_max
 64  constant cmd_item
4096 constant cfg_max
  50 constant cfg_max_lines
   0    value cfg_len
   0    value cfg_#lines
   0    value cfg_buf
   0    value cmd_buf
   0    value cmx_buf
   0    value nam_buf
   0    value na2_buf
   0    value cfg_row
   0    value cfg_col

cfg_max_lines 2* array cfg_lines

\ ***************************************************************************
\ When the editor returns, it "may", place a command in the file ZZ.CMD to
\ pass back to Mini-Shell. If MS gets a command, it will try to process
\ it. If no command is received, then it will quit.

: cmd_set       ( -- )
                " ZZ.CMD" ">$ mshndl $>handle ;

: read_item     ( a1 -- )
                bl word count cmd_item min rot place ;

: read_cmd      ( -- n1 )               \ read the command byte
                cmd_set
                mshndl hopen
                if      0       exit
                then
                pad 'tib !      \ make sure there is room for 256 bytes
                tib cmd_max mshndl hread #tib ! >in off
                bl word c@
                if      here 1+ c@
                        nam_buf read_item
                        cfg_row read_item
                        cfg_col read_item
                        na2_buf read_item
                else    0
                        nam_buf off
                        na2_buf off
                        cfg_row off
                        cfg_col off
                then    mshndl hclose drop
                sp0 @ 2+ 'tib ! ;

: del_cmd       ( -- )                  \ delete the command byte file
                cmd_set
                mshndl hdelete drop ;

\ ***************************************************************************
\ read the configuration file into memory

: no_cfg        ( -- )
                ." Cannot find ZZ.CFG, creating.."
                mshndl hcreate
                if      cr ." Can't create ZZ.CFG, quitting."
                        bye
                else    " NEWZ %1 %2 %3 /cmd||" mshndl hwrite drop
                                     2573 sp@ 2 mshndl hwrite 2drop
                                                mshndl hclose drop
                                                mshndl hopen drop
                then    ;

: read_cfg      ( -- )                  \ read the configuration file
                " ZZ.CFG" ">$ mshndl $>handle
                mshndl hopen if no_cfg then
                cfg_buf cfg_max mshndl hread =: cfg_len
                mshndl hclose drop
                cfg_len 0=
                if      cr ." ZZ.CFG has invalid length=0, quitting"
                        bye
                then    ;

: cfg_next_lf   ( a1 -- a2 f1 )         \ find next LF in CFG file
                begin   1+ dup c@ $0A =                 \ an LF
                        over cfg_buf cfg_len + u>= or   \ or buf end
                until   dup cfg_buf cfg_len + u>= ;

: cfg_lcalc     ( -- )                  \ calculate the line starts
                off> cfg_#lines
                cfg_buf
                cfg_max_lines 2 - 0
                do      dup cfg_lines i 2* + !
                        cfg_next_lf ?leave 1+
                        incr> cfg_#lines
                loop    drop ;

: >cmd_buf      ( c1 -- )
                cmd_buf count + c! cmd_buf incr ;

: ">cmd_buf     ( a1 n1 -- )
                cmd_buf +place ;

: params>cmd_buf ( n1 a1 -- n2 )   \ prompt for parameters for command line
                0 rows 1- at cols 1- spaces
                0 rows 1- at                    \ set start of line
                1+ dup c@
                dup $20 = swap '|' = or 0=      \ if not blank or "|"
                if      40 2dup '"' scan nip -  \ scan for " delimited $
                        dup 1+ >r ?dup 0=
                else    true 0 >r
                then
                if      drop " Command line: "
                then
                type
                r> +                    \ adjust offset for next char
                tib 40 expect           \ get the command line
                tib span @ ">cmd_buf ;  \ append it to command buffer

: do_esc        ( n1 a1 -- n2 ) \ test char at a1, process then return n2,
                                \ an adjusted n1 the number of characters
                                \ to skip.
                >r
                r@ c@ '1' = if  nam_buf count ">cmd_buf then
                r@ c@ '2' = if  cfg_row count ">cmd_buf then
                r@ c@ '3' = if  cfg_col count ">cmd_buf then
                r@ c@ '4' = if  na2_buf count ">cmd_buf then
                r@ c@ 'P' = if  r@ params>cmd_buf       then
                r@ c@ 'F' = if  nam_buf count 2dup '.' scan nip -    \ no EXT
                                ">cmd_buf               then
                r>drop ;

: to_cmd_buf    ( a1 n1 -- )
                2dup $0D scan nip -                     \ strip off CRLF
                cmd_buf off
                bounds
                ?do     i c@ '%' =
                        if      2 i 1+ do_esc      \ process 7 skip ESC strng
                        else    i c@ >cmd_buf   1  \ do next char
                        then
               +loop    ;

: >cfg_line"    ( n1 -- a1 n2 )         \ get addr & len of line n1
                2* cfg_lines + dup @ swap 2+ @ over - ;

comment:

: "sys          ( a1 n1 a2 n2 --- f1 )         \ spawn a program
                exec.param 16 erase
                dup
        if      exec.buf place
                exec.buf count + off
        else    2drop exec.buf off
        then    ?CS: 44 @L  exec.param      !   \ environment segmnt
                ?ds:        exec.param  4 + !   \ command line seg
                exec.buf    exec.param  2 + !   \ and offset
                $0D exec.buf count + c!         \ append a carraige return
                cmdpath place
                cmdpath count + off
                cmdpath 1+ exec.param execf ;

comment;

: run_cmd_buf   ( -- )  \ process multiple commands seperated by '|' chars
                cmd_buf count
                begin   2dup '|' scan 2dup 2>r nip - dup
                while   cmx_buf place
                        cmx_buf count + 1- c@ $0A =
                        if      -2 cmx_buf c+!
                        then    bl cmx_buf count + c!
\ savescr
\ cls cmx_buf 40 dump key drop
\ restscr
                        cmx_buf $sys drop       \ process DOS command
                        2r> 1 /string
                repeat  2drop 2r> 2drop ;

: do_cfgline    ( n1 -- )
                dup cfg_#lines <
                if      >cfg_line" 255 min to_cmd_buf space
                        run_cmd_buf
                else    drop            \ ignore greater than lines
                then    ;

: do_cmd        ( c1 -- )
                upc
                dup 'Q' =               if drop bye             then
                dup '1' '9' between     if dup '0' - do_cfgline then
                dup '0' =               if      10   do_cfgline then
                dup 'A' 'H' between     if dup 'A' - 11 + do_cfgline    then
                drop ;

: main          ( -- )
                DECIMAL                         \ always select decimal
                cfg_max  1+ ds:alloc =: cfg_buf \ allocate buffer space
                cmd_max  1+ ds:alloc =: cmd_buf
                cmd_max  1+ ds:alloc =: cmx_buf
                cmd_item 1+ ds:alloc =: nam_buf
                cmd_item 1+ ds:alloc =: na2_buf
                cmd_item 1+ ds:alloc =: cfg_row
                cmd_item 1+ ds:alloc =: cfg_col
                ?DS: SSEG !                     \ set search segment
                0 SET_MEMORY                    \ reduce memory usage
                dosio_init                      \ init DOS I/O for DEBUGGING
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                read_cfg                        \ read configuration file
                cfg_lcalc                       \ calculate line starts
                bl word count cmd_item min nam_buf place \ get filename
                bl word count cmd_item min cfg_row place \ starting row and
                bl word count cmd_item min cfg_col place \ starting column
                bl word count cmd_item min na2_buf place \ second filename
                nam_buf c@ 0=                     \ if no cmdline parameters
                if      read_cmd drop             \ then use most recent
                then
                begin   del_cmd
                        0 do_cfgline
                        read_cfg
                        cfg_lcalc
                        read_cmd ?dup
                while   do_cmd
                repeat  ;

