\\ HOST.SEQ             Words target gets to use from host

{

        only host definitions also forth also compiler also
                                        \ search is ROOT, HOST & FORTH

        head2 \\                head2 (                 head2 .(
        head2 \                 head2 directive         head2 host
        head2 #if               head2 #else             head2 #then
        head2 /*                head2 comment:          head2 .comment:
        head2 }                 head2 \u                head2 \unless
        head2 \+                head2 \-                head2 ?definit
        head2 [long]            head2 [Llong]           head2 a;
        head2 c,-t              head2 ,-t               head2 s,-t
        head2 long_branch       head2 short_branch      head2 long_library
        head2 short_library     head2 does>             head2 alias
        head2 \fpc              head2 \tcom             head2 \f
        head2 \t                head2 ?dis              head2 ?dbg
        head2 ?interpretive     head2 #endif            head2 \s
        head2 check_/noinit     head2 check_/definit    head2 needs
        head2 /stack            head2 /nostack          head2 /nostack1
        head2 [short]           head2 [compile]         head2 {
        head2 L:                head2 executes>         head2 !-t

        head2 vocs              head2 order             head2 definitions
        head2 forth             head2 previous          head2 also
        head2 fload    F' fload alias include           head2 f[']
        head2 [                 head2 here-t            head2 allot-t
\+ debug head2 debug

: only          ( -- )
                ['] host >body  context #vocs 1- 2* 2dup erase + ! host ;

forth
create vocsave_buf #vocs 2* allot

: ||            ( | line -- )   \ execute the line following
                context vocsave_buf #vocs 2* cmove
                only forth also compiler also host also target also
                >console                        \ reslect console
                interpret
                vocsave_buf context #vocs 2* cmove ; immediate

host only forth also definitions

}
