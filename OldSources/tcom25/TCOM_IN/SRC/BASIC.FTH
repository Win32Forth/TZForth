\ BASIC.SEQ            A BASIC Tokenizer               by Tom Zimmer

\  **********************************************************************
\  A Character Evaluator
\  **********************************************************************
\
\   A Character evaluator
\
\         ?CHAR get a character from "TIB + >IN" and returns a value n1
\         in the range 0 to 11 defining the group in which the character
\         belongs.
\
\                 BLANK           = 0
\                  0  to 31       = 1
\                 '!' to '/'      = 2
\                 '0' to '9'      = 3
\                 ':' to '@'      = 4
\                 'A' to 'Z'      = 5
\                 '[' to '`'      = 6
\                 'a' to 'z'      = 7
\                 '{' to '~'      = 8
\                 DELETE          = 9
\                 GRAPHIC         = 10
\                 '_'             = 11
\
\         Execution time in clock cycles for this CODE are as follows:
\
\                 BLANK           155 cycles
\                 Alpha Upper     207 cycles
\                 Alpha Lower     229 cycles
\                 GRAPHIC         252 cycles
\
\         Repeated checks of the same character offset, use 110 cycles.

-1 value last_>in               \ previous value for >in
 0 value last_type              \ previous value of character type

CODE ?CHAR      ( -- n1 )       \ analyze the character at "TIB+>IN"
                                \ return the character type code n1.
                                        \ CALL                  19 cycles
                MOV DI, >IN             \ get line offset       15 cycles
                CMP DI, &> LAST_>IN     \ compare with prev     15 cycles
                JNE 2 $                 \ no match, do the test 4/16 cycles
                MOV AX, &> LAST_TYPE    \ recover prev type     15 cycles
        0 $:                    \
                MOV &> LAST_TYPE AX     \ save the type         9 cycles
                1PUSH           \
        2 $:    MOV &> LAST_>IN DI      \ save DI for later     13 cycles
                ADD DI, 'TIB    \ add buf addr to line offset   15
                MOV CL, 0 [DI]  \ get the char from TIB+>IN     15 cycles
                SUB CH, CH      \ clear the high byte of char   3 cycles
                SUB AX, AX      \ clear the type counter        3 cycles
                CMP CX, # $20   \ blank      returns 0          4 cycles
                JE 0 $          \                               4/16 cycles
                MOV AX, # 1     \  0  to 31  returns 1          4 cycles
                JL 0 $          \                               4/16 cycles
                INC AX          \                               3 cycles
                CMP CX, # '/'   \ '!' to '/' returns 2          4 cycles
                JLE 0 $         \                               4/16 cycles
                INC AX          \                               3 cycles
                CMP CX, # '9'   \ '0' to '9' returns 3          4 cycles
                JLE 0 $         \                               4/16 cycles
                INC AX          \                               3 cycles
                CMP CX, # '@'   \ ':' to '@' returns 4          4 cycles
                JLE 0 $         \                               4/16 cycles
                INC AX          \                               3 cycles
                CMP CX, # 'Z'   \ 'A' to 'Z' returns 5          4 cycles
                JLE 0 $         \                               4/16 cycles
                CMP CX, # '_'   \ UNDERSCORE returns 11         4 cycles
                JE 1 $          \                               16 cycles
                INC AX          \                               3 cycles
                CMP CX, # '`'   \ '[' to '`' returns 6          4 cycles
                JLE 0 $         \                               4/16 cycles
                DEC AX          \                               3 cycles
                CMP CX, # 'z'   \ 'a' to 'z' returns 7          4 cycles
                JLE 0 $         \                               4/16 cycles
                INC AX          \                               3 cycles
                CMP CX, # '~'   \ '{' to '~' returns 8          4 cycles
                JLE 0 $         \                               4/16 cycles
                INC AX          \                               3 cycles
                CMP CX, # 127   \ DELETE     returns 9          4 cycles
                JE 0 $          \                               4/16 cycles
                INC AX          \ GRAPHIC    returns 10         3 cycles
                JMP 0 $         \                               15 cycles
        1 $:    MOV AX, # 11    \ UNDERSCORE returns 11         4 cycles
                JMP 0 $         \ jump to exit routine          15 cycles
                END-CODE

\ **********************************************************************
\ Start of the tokenizer
\ **********************************************************************

0 value ttype           \ token type

256 array token$        \ token string buffer as big as possible (256 bytes)

: |blank        ( a1 -- a1 false )      \ ignore blanks
                false ;

: make-class    ( n1 -<name>- ) \ compile time  \ define name with value n1
                ( -- n1 )       \ runtime       \ append char at TIB+>IN to
                                                \ token$ return value n1
                create , does>  @ dup !> ttype  \ most recent type gotten
                                tib >in @ + 1 token$ +place ;

 1 make-class |cntrl    ( -- 1  )
 2 make-class |punc1    ( -- 2  )
 3 make-class |numbr    ( -- 3  )
 4 make-class |punc2    ( -- 4  )
 5 make-class |upper    ( -- 5  )
 5 make-class |under    ( -- 5  )  \ underscore character treat as type 5
 6 make-class |punc3    ( -- 6  )
 7 make-class |lower    ( -- 7  )
 8 make-class |punc4    ( -- 8  )
 9 make-class |delete   ( -- 9  )
10 make-class |graph    ( -- 10 )

: do-punct      ( -- n1 )               \ return type number of character
                ?char 0max 11 min exec:
                |blank  |blank  |punc1  |blank  |punc2
                |blank  |punc3  |blank  |punc4  |blank
                |blank  |blank ;

: do-alpha      ( -- n1 )               \ return non-zero if alphabetic
                ?char 0max 11 min exec:
                |blank  |blank  |blank  |blank  |blank
                |upper  |blank  |lower  |blank  |blank
                |blank  |under  ;

: do-numeric    ( -- n1 )               \ return non-zero if numeric
                base @ $10 =                    \ if HEX number base
                if      false ?char 3 =
                        tib >in @ + c@ upc 'A' 'F' between or
                        if      drop |numbr
                        then
                else    false ?char 3 =
                        if      drop |numbr
                        then
                then    ;

: do-alpha-num  ( -- n1 )               \ return non-zero if alphanumeric
                ?char 0max 11 min exec:
                |blank  |blank  |blank  |numbr  |blank
                |upper  |blank  |lower  |blank  |blank
                |blank  |under  ;

: skip_blanks   ( -- )
                ?char ?exit
                begin   >in incr
                        ?char
                until   ;

create pairs    ," <<  >>  <>  ++  --  @@  \\  >=  <=  "        \ 12-20
create puncts   ," !#$%&'()*+,-./:;<=>?[\]^`{|}~" '"' c,        \ 21-50
create maths    ," NOT     AND     OR      XOR     MOD     "    \ 51-55

: ?pair#        ( -- f1 )       \ find a punctuation pair type 12 to 20
                false                                   \ start false
                token$ count pairs count search
                if      u2/ u2/ 12 + !> ttype           \ if a pair
                        0=                              \ invert flag
                else    drop                            \ discard offset
                then    ;

: ?punct#       ( -- )          \ find a punctuaton types 21 to 50
                off> ttype
                token$ count puncts count 1+ search
                if      dup 21 + !> ttype
                then    drop ;

: ?math#        ( -- f1 )       \ find a math word type 51 to 55
                false                                   \ start false
                token$ count maths count search
                if      u8/ 51 + !> ttype               \ if a pair
                        0=                              \ invert flag
                else    drop                            \ discard offset
                then    ;

: pair>token    ( -<pair>- token ) \ return the token for pair
                bl word count token$ place
                ?pair# 0= abort" Not a valid character pair"
                ttype ;

: char>token    ( -<char>- token ) \ return the token for char
                bl word count token$ place
                ?punct#
                ttype 0= abort" Must be a punctuation character"
                ttype ;

: math>token    ( -<math>- token ) \ return the token for math word
                bl word count token$ place
                ?math# 0= abort" Not a valid math word"
                ttype ;

: %token        ( -- )         \ parse out a token at "TIB+>IN", set TTYPE
                                \ and fill the TOKEN$ buffer.
                 0 !> token$
                -1 !> ttype
                -1 !> last_>in
                 0 !> last_type
                skip_blanks
                ?char !> ttype
                do-alpha
                if      save> ttype
                        begin   >in incr
                                do-alpha-num 0=
                        until
                        restore> ttype
                        ?math# drop
                        exit                    \ **** EXITS HERE
                then    do-numeric
                if      begin   >in incr
                                do-numeric 0=
                        until   exit            \ **** EXITS HERE
                then    do-punct                \ punctuaton?
                if      >in incr
                        do-punct                \ second also punctuation?
                        if      ?pair#          \ then check for pair
                                if      >in incr
                                else    -1 token$ c+!   \ shorten by one
                                        ?punct#
                                then
                        else    ?punct#
                        then
                then    ;

0 value backup-one

: -token        ( -- )  \ backup one, but only one token
                on> backup-one ;

: token         ( -- )
                backup-one
                if      off> backup-one
                else    %token
                        listvar
                        if      token$ count type space
                        then
                then    ;

\ **********************************************************************
\ Token type testers, either return a flag, or essue an error message
\ **********************************************************************

: "symerr       ( cfa a1 n1 -- )
                token$ count here place "errmsg ;

: tchk?         ( -<name char>- )       \ defining word for character checks
                ( -- f1 )
                create char>token c,
\               does> c@ ttype = ;
                ;code   pop bx
                        sub ax, ax
                        mov al, 0 [bx]
                        sub ax, &> ttype
                        sub ax, # 1
                        sbb ax, ax
                        1push           end-code

        tchk? ,?  ,     tchk? $?  $     tchk? (?  (     tchk? )?  )

: eol? ttype 1 = ;

0 value ?continuation

char>token : constant ':'token

: :?            ( -- f1 )       \ continue with next statment?
                ?continuation
                if      -token    true
                else    ttype ':'token =
                then    off> ?continuation ;

: tcheck        ( n1 -<name>- )         \ defining word for character checks
                                        \ it is a hard error if no match
                create  char>token c, token$ 1+ c@ c,
                does> dup c@ ttype -
                if      dup 1+ 1 token$ place
                        0 " Expected!" "symerr
                then    drop ;

        tcheck ,??  ,   tcheck (??  (   tcheck )??  )
        tcheck =??  =   tcheck "??  "

\ **********************************************************************
\ Token processing for BASIC
\ **********************************************************************

defer comp_*
defer comp_+
defer comp_-
defer comp_/
defer comp_<
defer comp_<<
defer comp_<=
defer comp_<>
defer comp_=
defer comp_>
defer comp_>=
defer comp_>>
defer comp_and
defer comp_cfetch
defer comp_cfetchL
defer comp_cstore
defer comp_cstoreL
defer comp_exchange
defer comp_mod
defer comp_negate
defer comp_not
defer comp_or
defer comp_pc!
defer comp_pc@
defer comp_ret
defer comp_rot
defer comp_-rot
defer comp_swap
defer comp_xor
defer comp_do
defer comp_loop

defer comp_?branch
defer comp_branchres
defer comp_resolve

\ **********************************************************************

: symbol_find   ( a1 n1 -- a2 f1 )      \ prepend string a1,n1 to token$
                                        \ and search for the word
                here place                      \ prepend string a1,n1
                token$ count here +place        \ append token$ to it
                $2020 here count + !            \ add a couple of blanks
                here ?uppercase find ;

: prepend_char  ( a1 c1 -- a1 )
                >r                              \ save character for later
                dup count over 1+ swap cmove>   \ expand string by one char
                r> over 1+ c!                   \ insert the '_' char
                1 over c+! ;                    \ bump string count by one

: makedata      ( -- a1 )
                token$ '_' prepend_char ?uppercase
                fhere >r
                {d} $new_symbol         \ +0    BYTE type of symbol
                here-d , 2 allot-d      \ +6    WORD resolved address
                -1 ,                    \ +8    WORD unresolved chain
                1 ,                     \ +10   WORD reference count
                2 ,                     \ +12   data size=0
                0 ,
                r@ index_constant       \ include in sym tbl
                r> ;    \ return address of symbol

: makelabel     ( -- )
                fhere >r
                token$ ':' prepend_char ?uppercase
                {S} $new_symbol         \ +0    BYTE type of symbol
                here-t ,                \ +6    WORD resolved address
                -1 ,                    \ +8    WORD unresolved chain
                1 ,                     \ +10   WORD reference count
                0 ,                     \ +12   data size=0
                0 ,
                r> out_symbol ;         \ include in sym tbl

128 array $buf

defer do-token                  \ allow forward references to DO-TOKEN

char>token : constant ':'type

: set_continuation ( -- )
                on> ?continuation ;

\ **********************************************************************
\ Precedence control for binary operators
\ **********************************************************************

}
  Precedence is controlled by using the following constants that
determine how deep into the EXP_DELIMITERS array the search will be
performed, while deciding whether to terminate expression processing.

  A precedence one higher than the current operator is set by each
operator, to prevent any other operators equal or lower than itself from
getting processed before it does.  If an binary operator of higher
precedence than the one being processed is found, then "expression"
iterates and processes the next token, which typically causes a recursive
call to "expression" to process the argument of the following binary
operator.  This continues until a terminating condition is detected, like
a colon, or a left parenthesis, which causes the recursive nesting to
fall out and finish processing the lower precedence operators.

{

 0 constant prec9
 2 constant prec8
11 constant prec7
12 constant prec6
14 constant prec5
16 constant prec4
18 constant prec3

prec3 value prec-max            \ default to lowest precedence
    0 value ?binary

\ ---------------------------------------------------------------------
create exp_delimiters           \ continue expresion on these tokens
\ ---------------------------------------------------------------------
        char>token $    c,      math>token NOT  c,      \ precedence 8
\ ---------------------------------------------------------------------
                                                        \ precedence 7
        pair>token >=   c,      pair>token <=   c,      pair>token <>   c,
        char>token <    c,      char>token >    c,      char>token =    c,
        math>token AND  c,      math>token OR   c,      math>token XOR  c,
\ ---------------------------------------------------------------------
        math>token MOD  c,                              \ precedence 6
\ ---------------------------------------------------------------------
        pair>token >>   c,      pair>token <<   c,      \ precedence 5
\ ---------------------------------------------------------------------
        char>token *    c,      char>token /    c,      \ precedence 4
\ ---------------------------------------------------------------------
        char>token +    c,      char>token -    c,      \ precedence 3
\ ---------------------------------------------------------------------

: make>prec     ( n1 -<name>- )         \ define a save switch precedence word
                create ,
                ;code   mov ax, &> prec-max             \ save precedence
                        sub rp, # 2
                        mov 0 [rp], ax
                        pop bx
                        mov bx, 0 [bx]
                        mov &> prec-max bx
                        next            end-code

prec9 make>prec >precedence9
prec8 make>prec >precedence8
prec7 make>prec >precedence7
prec6 make>prec >precedence6
prec5 make>prec >precedence5
prec4 make>prec >precedence4
prec3 make>prec >precedence3

code precedence> ( -- )                 \ restore the saved precedence
                mov ax, 0 [rp]
                add rp, # 2
                mov &> prec-max ax              \ restore previous precedence
                next            end-code

\ **********************************************************************

: ?end-expr     ( -- )          \ check for end of current expression
                exp_delimiters prec-max ttype scan nip 0= ;

: expression    ( -- )          \ process an expression
                token
                begin   " @" symbol_find        \ keyword?
                        if      execute
                        else    drop            \ or variable/number
                                do-token
                        then    off> ?binary    \ clear binary operator flag
                                                \ its valid for one token only
                        token                   \ get another token
                        ?end-expr               \ check for expression done
                until   -token ;

: binary-expression ( -- )      \ process an expression on a possible
                                \ unary oparator following.  We are already
                                \ processing a binary operator.
                on> ?binary expression ;

\ **********************************************************************
\ The mostly BINARY operators follow
\ **********************************************************************

: |<>   >precedence8     binary-expression comp_<>   precedence> ;
: |>=   >precedence8     binary-expression comp_>=   precedence> ;
: |<=   >precedence8     binary-expression comp_<=   precedence> ;
: |$    >precedence9 hex binary-expression decimal   precedence> ;
: |(    >precedence3     binary-expression token )?? precedence> ;
: |)    ;
: |*    >precedence5     binary-expression comp_*    precedence> ;
: |+    >precedence4     binary-expression comp_+    precedence> ;
: |,    ;
: |-    >precedence4     binary-expression comp_-    precedence> ;
: |/    >precedence5     binary-expression comp_/    precedence> ;
: |:    ;
: |<    >precedence8     binary-expression comp_<    precedence> ;
: |=    >precedence8     binary-expression comp_=    precedence> ;
: |>    >precedence8     binary-expression comp_>    precedence> ;
: |not  >precedence9            expression comp_not  precedence> ;
: |and  >precedence8     binary-expression comp_and  precedence> ;
: |or   >precedence8     binary-expression comp_or   precedence> ;
: |xor  >precedence8     binary-expression comp_xor  precedence> ;
: |mod  >precedence7     binary-expression comp_mod  precedence> ;

\ : |&    >precedence8       expression comp_and precedence> ;
\ : ||    >precedence8       expression comp_or  precedence> ;
\ : |#    >precedence8       expression comp_xor precedence> ;
\ : |>>   >precedence6       expression comp_>>  precedence> ;
\ : |<<   >precedence6       expression comp_<<  precedence> ;
\ : |"            '"' word count $buf place $buf count token ;

: %anumber      ( -- n1 )       \ process a number, return on stack
                $2020 token$ count + !                  \ trailing blanks
                token$ ?uppercase number? 0= or
                if      0 " Invalid number for the current number base"
                        "errmsg
                then    ;

: anumber       ( -- )          \ detected a number, compile as literal
                %anumber comp_single ;

: |number       ( -- n1 )       \ get a token and convert to number
                token
                save> base
                $? if hex token then    \ allow user to specify HEX
                %anumber
                restore> base ;

: symbol?       ( -- f1 )
                ttype   dup  5 =        \    upper case & underscore char
                        swap 7 = or ;   \ or lower case char

: ?getmakevar   ( -- cfa )
                symbol? 0=
        if      0 " Variables must start with a A to Z, or _ (underscore)"
                "symerr here
        else    " _" symbol_find 0=             \ look it up
                if      drop
                        makedata
                then
        then    ;

: avarble       ( -- )          \ find a variable
                " _" symbol_find 0=             \ start with '@' symbol
                if      0 " Undefined variable!" "symerr
                then    >resaddr @ comp_single
                token (?
                if      expression comp_+ token )??
                else    -token
                then    comp_fetch ;            \ variable, return contents

: >in_word!     ( -- )
                >in @ dup !> >in_word           \ WORD source pointer
                          !> asm->in ;          \ ASM source pointer

defer imm_before

0 value branching?
0 value foring?
0 value thening?

: ?FOR-err      ( -- )
                foring? 0=
                if      0 " Must follow FOR on the same line!" "symerr
                then    ;

ALSO TARGET DEFINITIONS

: bonly         ( -- )
                ['] host >body  context #vocs 1- 2* 2dup erase + ! host ;

create vocsave_buf #vocs 2* allot

\ **********************************************************************
\ Special Keyword Definition, allows a Forth command line to be performed
\ **********************************************************************
\
\           Useful mainly in the form:  COMMAND DEBUG @word
\
\ **********************************************************************

: @command      \ Allows entry of a Forth command line
                context vocsave_buf #vocs 2* cmove
                bonly forth also compiler also host also target also
                >console                        \ reslect console
                interpret
                vocsave_buf context #vocs 2* cmove ; immediate

\ **********************************************************************
\ Keyword Definitions
\ **********************************************************************

: @+            \ +expression(unary)   or   expression+expression(binary)
                ?binary 0=
                if      >precedence4    binary-expression comp_+
                else    >precedence9    expression
                then    precedence> ;

: @-            \ -expression(unary)   or   expression-expression(binary)
                ?binary 0=
                if      >precedence4    binary-expression comp_-
                else    >precedence9    expression comp_negate
                then    precedence> ;

: @var          \ VAR name,name,name    \ create one or more variables
                begin   token ?getmakevar drop
                        token ,? 0=
                until   -token ;

: @let          \ LET variable=expression
                token ?getmakevar >resaddr @ >r token (?
                if      r> -1 >r comp_single
                        expression comp_+ token )?? token then
                =??     binary-expression
                r@ -1 <>
                if      r@ comp_single
                else    comp_swap
                then    r>drop comp_store ;

: @dim          \ DIM variable(subscripts),variable(subscripts),...
                begin   token
                        ?getmakevar >r          \ make var and discard addr
                        token (?? |number token )??
                        2- 0max dup allot-d
                        r> >dsize +!
                        token ,? 0=
                until   -token ;

: @data         \ DATA 23,24,35,45,56   \ compile data into memory
                begin   |number ,-d
                        token ,? 0=
                until   -token ;

: @varptr       \ VARPTR variable   \ return address of variable following
                token   symbol? dup
                if      drop " _" symbol_find
                then    0=
                if      drop
                        0 " Expected a variable!" "symerr
                else    >resaddr @ comp_single
                then    ;

: @label        \ LABEL labelname       \ define a new label with "labelname"
                token symbol? 0=
                if      0 " Expected a label!" "symerr
                then
                " :" symbol_find                \ start with ':' symbol
                if      res_symbol
                else    drop
                        makelabel
                        set_continuation
                then    opt_off1 ;

: @goto         \ GOTO labelname        \ branch to "labelname"
                branching? thening? 0= and
                if      comp_?branch
                then    token
                eol?
                if      0 " GOTO must be followed by a labelname" "symerr
                        exit
                then
                state on
                " :" symbol_find                \ find the word
                if      comp_jmp                \ compile a jump
                else    {S} $add_symbol         \ or add to symbol table
                        compile unnest          \ undefined, so NOOP it
                        dup >count incr
                            comp_jmp
                then    >in_word! ;

: @if           \ IF expression THEN statment(s) ELSE statment(s)
                branching?
                if      0 " IF statments are not nestable!" "symerr
                then
                on> branching?
                off> thening?
                binary-expression
                >in @ token$ c@ - 0max !> >in_word      \ source pointer
                token ,? 0=                             \ ignore a comma char
                if      -token
                else    >in_word!                       \ source pointer
                then
                set_continuation ;

: @then         \ IF expression THEN statment(s) ELSE statment(s)
                branching? 0=
                if      0 " THEN must be used on the same line as IF!" "symerr
                then    comp_?branch
                on> thening?
                set_continuation
                >in_word! ;

: @else         \ IF expression THEN statment(s) ELSE statment(s)
                branching? 0=
                if      0 " ELSE must be used on the same line as IF!" "symerr
                then    comp_branchres set_continuation ;

: @gosub        \ GOSUB labelname
                token
                eol?
                if      0 " GOSUB must be followed by a labelname" "symerr
                        exit
                then
                state on
                " :" symbol_find        \ find the word
                if      comp_call       \ compile a jump
                else    {S} $add_symbol \ or add to symbol table
                        compile unnest  \ undefined, so NOOP it
                        dup >count incr
                            comp_call
                then    ;

: @return       \ RETURN
                comp_ret ;

: @for          ( -- I-addr start )
                \ FOR I = start TO end STEP cnt .....  NEXT
                token ?getmakevar >resaddr @
                token =?? |number
                /nostack1
                incr> foring?
                set_continuation ;

: @to           ( I-addr start -- direction )
                \ FOR I = start TO end STEP cnt......  NEXT
                ?FOR-err
                |number 1+ 2dup < dup>r 0=
                if      1-
                then    comp_single comp_single
                ( I-addr -- ) comp_do r>
                if      1
                else    -1
                then    set_continuation ;

: @step         ( direction -- increment&direction )
                \ FOR I = start TO end STEP cnt .....  NEXT
                ?FOR-err
                |number swap 0<
                if      negate
                then    ;

: @next         ( direction -- )
                \ FOR I = start TO end STEP cnt .....  NEXT
                ?FOR-err foring? 0= ?exit
                ( -- direction ) comp_single comp_loop
                token :?                \ discard any following word, unless
                if      -token          \ it is a ':' for continuation
                then    ;

: @rem          \ REM following text is a comment to end of line
                begin   token eol?
                until   ;

: @swap         \ SWAP var,var          \ swap contents of two variables
                @varptr ,?? @varptr
                comp_exchange ;

: @poke         \ set value into memory
                \ POKE memaddr,value   -or-   POKE segment:offset,value
                expression token :? dup>r               \ ':' indicates FAR
                if      expression token                \ handle OFFSET
                then    ,?? expression r>               \ and VALUE
                if      comp_-rot comp_cstoreL          \ use FAR or
                else    comp_swap comp_cstore           \ use NEAR
                then    ;

: @peek         \ read a byte from memory
                \ PEEK(memaddr)   -or-   \PEEK(segment:offset)
                token (?? expression token :? dup>r     \ ':' indicated FAR
                if      expression token
                then    )?? r>
                if      comp_cfetchL
                else    comp_cfetch
                then    ;

: @out          \ OUT port,value        \ set a byte value into port
                expression token ,?? expression comp_swap comp_pc! ;

: @inp          \ INP(port)             \ input a byte from a port
                token (?? expression token )?? comp_pc@ ;

PREVIOUS DEFINITIONS

\ **********************************************************************
\ End of Keyword Definitions
\ **********************************************************************

: |err          ( -- )
                0 " Unknown token!" "symerr ;

: %do-token     ( -- )
        ttype 0max 56 min exec:
\       0       1       2       3       4       5       6       7
\ 0     BL      CTRL    NONE    NUMBER  NONE    upperc  NONE    lowerc
        |err    noop    |err    anumber |err    avarble |err    avarble
\ 8     NONE    DELETE  GRAPH   uscore  <<      >>      <>      ++
        |err    |err    |err    avarble |err    |err    |<>     |err
\ 16    --      |@      \\      >=      <=      !       #       $
        |err    |err    |err    |>=     |<=     |err    |err    |$
\ 24    %       &       '       (       )       *       +       ,
        |err    |err    |err    |(      |)      |*      |+      |,
\ 32    -       .       /       :       ;       <       =       >
        |-      |err    |/      |:      |err    |<      |=      |>
\ 40    ?       [       \       ]       ^       `       {       |
        |err    |err    |err    |err    |err    |err    |err    |err
\ 48    }       ~       "       not     and     or      xor     mod
        |err    |err    |err    |not    |and    |or     |xor    |mod
\ 56    unknown
        |err
        ;

' %do-token is do-token

: do-keyword    ( -- )
                [target]
                eol? ?exit                      \ ignore null tokens
                " @" symbol_find 0=             \ start with '@' symbol
                if      drop                    \ discard bad address
                        -token                  \ treat as assignment
                        tib >in @ + c@ ':' =    \ followed by a ':'?
                        if      @label          \ LABEL name
                                token           \ discard following ':' char
                        else    @let            \ LET variable=expression
                        then
                else    execute                 \ keyword, execute it
                then    ;

\ **********************************************************************
\ Test word
\ **********************************************************************

: brun          ( -- )          \ process one line of input
                prec3 !> prec-max       \ restore default precedence level
                branching?              \ if branching, resolve previous label
                if      comp_resolve
                        off> branching?
                then    ':'token !> ttype               \ set to continuing
                #tib @ 2 >                              \ does line have text?
                if      listvar
                        if      cr                      \ display a new line
                        then
                        tib #tib @ + off                \ null terminate
                        begin   skip_blanks             \ bypass blanks
                                ttype ':'token =
                                if   >in_word!          \ set source pointer
                                then
                                token :? 0=             \ get the next token
                                if      do-keyword      \ process the token
                                        token
                                then    :? 0=           \ repeat if a colon
                        until   eol? 0=                 \ if not end of line
                        if      |err                    \ error if not the
                        then                            \ end of line
                then    a; ;

