\\ BASHOST.SEQ         Words target gets to use from host

{

        only host definitions also forth also compiler also
                                        \ search is ROOT, HOST & FORTH

        head2 \                 head2 directive         head2 host
        head2 a;
        head2 long_branch       head2 short_branch
        head2 \fpc              head2 \tcom             head2 \f
        head2 \t
        head2 \s
        head2 needs

        head2 vocs              head2 order             head2 definitions
        head2 forth             head2 previous          head2 also
        head2 [                 head2 here-t            head2 allot-t
\+ debug head2 debug

: only          ( -- )
                ['] host >body  context #vocs 1- 2* 2dup erase + ! host ;

forth
\ create vocsave_buf #vocs 2* allot
\
\ : ||            ( | line -- )   \ execute the line following
\                 context vocsave_buf #vocs 2* cmove
\                 only forth also compiler also host also target also
\                 >console                        \ reslect console
\                 interpret
\                 vocsave_buf context #vocs 2* cmove ; immediate
\
\ : |             ( | line -- )   \ execute the line following
\                 context vocsave_buf #vocs 2* cmove
\                 only forth also compiler also host also target also
\                 interpret
\                 vocsave_buf context #vocs 2* cmove ; immediate

host only forth also definitions

}
