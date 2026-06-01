\\ TETRA.SEQ     The game of Tetris

        Try to simulate the Nintendo game Tetris using character graphics.


      This version of FPC like 2.5 blanks a whole line after doing a screen
      print. This makes it no good for doing character graphics. Perhaps this
      feature can be disabled.

      Can't find a way to disable, however if AT command is used to get cursor
      to bottom of screen the problem can be avoided.



        Need a way to rotate the figures while moving them.
        Plan: 1) keep the x,y position of a central square.
              2) build the figure from three additional x,y
                 coordinates offset, such as -1,0 1,0 0,1 for the tee.
              3) But each has 4 different subconfigurations

        Is it necessary to store all the subconfigs? Or can the rotations
        be calculated? 0,0 is unchanged. For a rotation to the right,
        +x becomes +y (top = y0), +y -> -x,
                                  -x -> -y,
                                  -y -> +x
                                  +x -> +y
        i.e. change the y sign, keep the  x sign.

{

\ ***************************************************************************
\ Some compatibility code so this file will load on either F-PC or TCOM.
\ ***************************************************************************

\tcom .options /opt /definit           \ compiler options for TETRA
\fpc    ' noop alias [long] immediate

\ ***************************************************************************


: SQ   32  EMIT 32  EMIT ;  \ print a square dark

: BLSQ  219 EMIT 219 EMIT ; \ print a square white

: MY.AT ( x y -- x' y') \ move at to center
        5 +
        SWAP
        30 +
        SWAP
      AT
        ;


: FIELD ( -- )
\fpc    STATOFF
      CLS
    16 0 DO
        20 0 DO I J MY.AT  BLSQ 2  +LOOP CR
      LOOP

      ;


: BORDER
        -1 -1 MY.AT 42 EMIT
        -1 16 MY.AT 42 EMIT
        21 -1 MY.AT 42 EMIT
        21 16 MY.AT 42 EMIT
        17 0 DO -1 I MY.AT 42 EMIT 21 I MY.AT 42 EMIT LOOP
        21 0 DO I -1 MY.AT 42 EMIT I 16 MY.AT 42 EMIT LOOP


        ;
COMMENT:
        It might be better to use position variables rather than vectors
        except when doing a rotate. The position information is needed to
        check the validity of every down, left and right moves.
COMMENT;

CREATE FIGURE
        8 , 0 , 10 , 0 ,  8 , 1 , 10 , 1 ,      \ block   figure.no 0
        8 , 0 ,  6 , 0 , 10 , 0 , 12 , 0 ,      \ rod  x0,y0 is center of rot
        8 , 0 , 10 , 0 ,  6 , 0 ,  8 , 1 ,      \ tee               2
        8 , 0 ,  6 , 0 ,  8 , 1 , 10 , 1 ,      \ zee               3
        8 , 0 , 10 , 0 ,  8 , 1 ,  6 , 1 ,      \ es                4
        8 , 0 ,  8 , -1 , 8 , 1 , 10 , 1 ,      \ el                5
        8 , 0 ,  8 , -1 , 8 , 1 ,  6 , 1 ,      \ jay               6


CREATE CURR    16 ALLOT                        \ 1 word per coordinate

0 VALUE FIGURE.NO       \ figures 0 through 6

: FILL.CURR      ( -- )
        FIGURE.NO 16 *              \ offset into figure array
        FIGURE +
        CURR                        \ destination
        16 CMOVE                    \ from to bytes   byte move
        ;




: DRAW.CURR ( -- )
        CURR                    \ c
        DUP   DUP               \ c c c
        2+                      \ c c c+2
        @ SWAP @ SWAP MY.AT SQ     \ c         draw first square

        DUP 4 + DUP 2+          \ c c+4 c+6
        @ SWAP @ SWAP  MY.AT SQ    \ c         draw 2nd

        DUP 8 + DUP 2+          \ c c+8 c+10
        @ SWAP @ SWAP MY.AT SQ     \ c         draw 3rd

        12 + DUP 2+             \ c+12 c+14
        @ SWAP @ SWAP MY.AT SQ     \  --       draw 4th
        0 22 AT
        ;

: UNDRAW.CURR ( -- )
        CURR                 \ c
        DUP   DUP               \ c c c
        2+                      \ c c c+2
        @ SWAP @ SWAP MY.AT BLSQ   \ c         draw first square

        DUP 4 + DUP 2+          \ c c+4 c+6
        @ SWAP @ SWAP  MY.AT BLSQ  \ c         draw 2nd

        DUP 8 + DUP 2+          \ c c+8 c+10
        @ SWAP @ SWAP MY.AT BLSQ   \ c         draw 3rd

        12 + DUP 2+             \ c+12 c+14
        @ SWAP @ SWAP MY.AT BLSQ   \  --       draw 4th
        0 22 AT
        ;


: SEE.CURR
        CR ." offset |  x  ,  y  " CR
        8 0 DO
        I 2* .   8 SPACES
        CURR I 2* + @ .  6 SPACES
        CURR 2+ I 2* + @ .
        CR
    2   +LOOP
        ;

\ we need some validity checking

COMMENT:
        On advantage of this vector method is that once the vector words
        were debugged left rotate followed trivially from right rotate
        and both rotate words worked immediately for all figures.

        Now we need validity checking. Basicly we need to check whether
        drawing a figure into the proposed location would overwrite any
        existing figure - EXCEPT for the current figure. That is, it is ok
        and common to overwrite part of the current figure.

        My original plan was to do modifications on an array called PROPOSED
        and check it before writing into CURRent. But now that all the move-
        ment words are working, I hate to do that. So I think I will copy
        the current array into something like BACKUP before doing a move.
        Check the validity of CURRent before drawing it and if not valid
        restoring the previous values from the backup.

        Testing might be done thus: 1) look MY.AT each entry in current
        2) find those that are NOT also in backup 3) save those
        4) of those check if the locations are clear 5) return a TRUE for
        valid or a false for not valid.

        These testing words need to be moved to the beginning of the file
        to be used within the movement words.

COMMENT;


      CREATE BACKUP.ARRAY 16 ALLOT

: BACKUP.CURR ( -- ) \ copy current array into backup array
        CURR BACKUP.ARRAY 16 CMOVE
        ;                               \ that was easy
: RESTORE.CURR
        BACKUP.ARRAY CURR 16 CMOVE
        ;


: SEE.BACK
        CR ." offset |  x  ,  y  " CR
        8 0 DO
        I 2* .   8 SPACES
        BACKUP.ARRAY I 2* + @ .  6 SPACES
        BACKUP.ARRAY 2+ I 2* + @ .
        CR
    2   +LOOP
        ;



COMMENT:
        Should I store the points themselves or just the point numbers ?
        Storing pairs seems always to get into a lot of SWAPing and ROTing.
        Let's try storing offsets into the CURR array.

: CHECK.CURR ( -- ) \ for each point, check for same in BACKUP.ARRAY
                    \ keep those NOT duplicated
        16 0 DO
        CURR I + @              \ x0
        BACKUP.ARRAY I + @      \ X0
        =                       \ tf
        CURR I + 2 + @          \ y0
        BACKUP.ARRAY I + 2 + @  \ Y0
        =                       \ tf tf
        AND                     \ TF  true if x0=X0 and y0=Y0


        ;


        Hold on a sec. here. To check whether there are any matches we neen
        to check c0=b0 ? c0=b1 ? c0=b2 ? c0=b3 ?
                 c1=b0 ? c1=b1 ? c1=b2 ? etc. etc. etc.
        sixteen combinations to check.

        COMP.NM  ( n m -- tf )
        Let's first make a general cross checking word for comparing a pair
        in CURRent with a pair in BACKUP. It should compare any xn,yn in
        CURR with any Xm,Ym in BACKUP. If they do not match an F flag should
        be left on the stack.

        CHECK   (  -- n or nothing )
        The next level word could COMP all entries in BACKUP for each
        entry in CURR. If NO match is found ( no T flags ) then the offset
        for that entry in CURR is saved to stack.

        VALID?    ( nothing or n0 n1 n2 n3 -- tf )
        The highest level word would then check all those entries on the
        stack for available space to move to, i.e. whether it is currently
        ASCII 219, and return T if valid.

        A left right or rotate that is not valid is simply not performed,
        perhaps with a beep. CURR is restored  with BACKUP. A down which is
        not valid is also not performed but triggers the end of movement for
        that figure, a check for full rows , etc.
COMMENT;


: COMP.NM ( n m -- tf ) \ whether CURRnx=BACKmx  AND  CURRny=BACKmy
        2DUP                    \ n m n m --
        4 * BACKUP.ARRAY + @    \ n m n BACKmx --
        SWAP                    \ n m BACKmx n --
        4 * CURR +  @           \ n m BACKmx CURRnx --
        =                       \ n m tf --
        ROT ROT                 \ tf n m --
        4 * 2 + BACKUP.ARRAY + @         \ tf n BACKmy
        SWAP                    \ tf BACKmy n
        4 * 2 + CURR +   @      \ tf BACKmy CURRny
       =                        \ tf tf
       AND                      \ tf     only if the x's are = and y's are =
       ;

COMMENT:

: CHECK.CURR  ( -- n's or nothing ) \ check each entry in CURR
        4 0 DO                  \ 0 1 2 3   the n's for CURR  J
         I 0 COMP.NM
         I 1 COMP.NM  OR
         I 2 COMP.NM  OR
         I 3 COMP.NM  OR        \ true if any match for this n
        NOT IF I THEN           \ save n if no match
        LOOP
        ;
 This word no longer used. See VALID?.CURR which incorporated it.


        I don't find a Forth word to read the character at a certain screen
        position, I need this or else I will have to maintain some kind of
        separate array and update it for every  move.

        BIOS int 10h sevice 8 reads attribute and char at current cursor pos.
                input BH=page no.  AH=8
                output AL=character read (ASCII)  AH=Attribute(alphanumerics)


COMMENT;



HEX
CODE GET-CHAR
\tcom   save_bx
        MOV BX, # 0000
        MOV AX, # 0800
                PUSH BP  PUSH SI
                INT 10
                POP SI  POP BP
        SUB AH, AH
\fpc    1PUSH
\fpc    NEXT
\tcom   mov bx, ax
\tcom   ret
        END-CODE

DECIMAL

COMMENT:
        This can be used with AT or MY.AT to set the cursor, read the ASCII
        value at tha position then return the cursor to the bottom of the
        screen out of the way of the game.

        VALID? takes the n's from the stack ( CURR entries w/o duplicates
        in BACK ) then uses GET-CHAR to check for ASCII, returning TRUE
        then ANDing, finally leaving a TRUE only if all checks are true.


        It may be better to test each entry in CURR which does not have
        a match in BACK immediately. That is, it is valid if matched OR
        if open.

COMMENT;

: CURR.OPEN? ( n -- tf ) \ check nth entry for ascii 219
        DUP                     \ n n        --
        4 * CURR + @            \ n CURRx    --
        SWAP                    \ CURRx n    --
        4 * 2 + CURR + @        \ CURRx CURRy--
        MY.AT                   \ --
        GET-CHAR                \ ASCII --
        219 =                   \ tf --    true if open
        ;

: VALID?.CURR  ( -- tf ) \ check each entry in CURR for validity
        4 0 DO                  \ 0 1 2 3   the n's for CURR  J
         I 0 COMP.NM
         I 1 COMP.NM  OR
         I 2 COMP.NM  OR
         I 3 COMP.NM  OR        \ true if any match for this n
         I CURR.OPEN?   OR      \ true if match OR open
        LOOP AND AND AND        \ they ALL have to be valid
      0 23 AT                   \ move cursor
        ;

COMMENT:
        This combination looks much better that the separate words.
        No need to store the non-matches then go back and look for
        openings. An entry is tested for match and for opening.
        Then found valid if there is a match OR an opening.
COMMENT;




: DOWN.CURR  ( -- ) \ increase y's by one
        CURR 2 + DUP @ 1 +  SWAP !
        CURR 6 + DUP @ 1 + SWAP !
        CURR 10 + DUP @ 1 + SWAP !
        CURR 14 + DUP @ 1 + SWAP !
        ;

 0 value paused
 0 value alldown

: DOWN
        paused alldown 0= and ?exit
        BACKUP.CURR
        UNDRAW.CURR
        DOWN.CURR
        VALID?.CURR
        IF DRAW.CURR
        ELSE RESTORE.CURR DRAW.CURR
        THEN
        ;

: 2INC! ( -- ) \ increase variable by 2
        DUP @ 2 + SWAP !
        ;

: 2DEC! ( -- ) \ DEcrease variable by 2
        DUP @ 2 - SWAP !
        ;


: RIGHT.CURR  ( -- ) \ INcrease x's by 2
        CURR     2INC!
        CURR 4 + 2INC!
        CURR 8 + 2INC!
        CURR 12 + 2INC!
        ;

: RIGHT
        BACKUP.CURR
        UNDRAW.CURR
        RIGHT.CURR
        VALID?.CURR
        IF DRAW.CURR
        ELSE RESTORE.CURR DRAW.CURR
        THEN
        ;


: LEFT.CURR  ( -- ) \  DECrease x's by 2
        CURR     2DEC!
        CURR 4 + 2DEC!
        CURR 8 + 2DEC!
        CURR 12 + 2DEC!
        ;

: LEFT
        BACKUP.CURR
        UNDRAW.CURR
        LEFT.CURR
        VALID?.CURR
        IF DRAW.CURR
        ELSE RESTORE.CURR DRAW.CURR
        THEN
        ;


COMMENT:
        Keeping positions rather than vectors makes rotation more complicated.
        One way to do it is to calculate vectors, rotate vectors, the re-
        calculate positions.
COMMENT;






: VECTOR.CURR ( n -- Dxn Dyn )
        CURR            \  n start of CURR array --
        SWAP 4 *        \ curr 4n --   offset to nth pair
        +               \ start of nth word
        DUP             \ start start
        @               \ start xn --
        SWAP            \ xn start
        2 + @           \ xn yn --
        CURR 2+ @       \ xn yn y0 --
        -               \ xn Dy --
        SWAP            \ Dy xn --
        CURR @          \ Dy xn x0 --
        -               \ Dy Dx --
        SWAP            \ Dx Dy --
        ;

: RROT.VECTOR ( Dx Dy -- DX DY ) \ rotate right
        2*              \ Dx 2Dy
        NEGATE          \ Dx -2Dy
        SWAP            \ -2Dy Dx
        2/              \ -2Dy Dx/2   = new Dx Dy
        ;

: LROT.VECTOR ( Dx Dy -- DX DY ) \ rot left
        2*
        SWAP            \ 2Dy Dx
        2/
        NEGATE          \ 2Dy -Dx/2    new Dx Dy
        ;



: NEW.CURR ( Dx Dy n -- ) \ make new entry in CURR
        DUP >R >R       \ save n twice
        CURR
        2@  SWAP        \ Dx Dy x0 y0
        ROT             \ Dx x0 y0 Dy
        +               \ Dx x0 Yn
        ROT ROT         \ Yn Dx x0
        +               \ Yn Xn
        R>              \ Yn Xn n
        4 *             \ Yn Xn 4n
        CURR +          \ Yn Xn CURRnx
        !               \ Yn
        R>              \ Yn n
        4 *  2 +       \ Yn offst.ny  (4n+2)
        CURR +          \ Yn CURRny
        !               \ --
        ;

: RROT.CURR
      4 1 DO
        I VECTOR.CURR
        RROT.VECTOR
        I NEW.CURR
      LOOP
        ;

: RROT
        BACKUP.CURR
        UNDRAW.CURR
        RROT.CURR
        VALID?.CURR
        IF DRAW.CURR
        ELSE RESTORE.CURR DRAW.CURR
        THEN
        ;

: LROT.CURR
        4 1 DO
        I VECTOR.CURR
        LROT.VECTOR
        I NEW.CURR
        LOOP
        ;

: LROT
        BACKUP.CURR
        UNDRAW.CURR
        LROT.CURR
        VALID?.CURR
        IF DRAW.CURR
        ELSE RESTORE.CURR DRAW.CURR
        THEN
        ;


COMMENT:
        On advantage of this vector method is that once the vector words
        were debugged left rotate followed trivially from right rotate
        and both rotate words worked immediately for all figures.

        Now we need validity checking. Basicly we need to check whether
        drawing a figure into the proposed location would overwrite any
        existing figure - EXCEPT for the current figure. That is, it is ok
        and common to overwrite part of the current figure.

        My original plan was to do modifications on an array called PROPOSED
        and check it before writing into CURRent. But now that all the move-
        ment words are working, I hate to do that. So I think I will copy
        the current array into something like BACKUP before doing a move.
        Check the validity of CURRent before drawing it and if not valid
        restoring the previous values from the backup.

        Testing might be done thus: 1) look MY.AT each entry in current
        2) find those that are NOT also in backup 3) save those
        4) of those check if the locations are clear 5) return a TRUE for
        valid or a false for not valid.

        These testing words need to be moved to the beginning of the file
        to be used within the movement words.

COMMENT;

\ : TEST ( n -- )
\         =: FIGURE.NO
\         FILL.CURR
\         DOWN
\         ;

5 VALUE TIME.LIMIT

: cnum 262  ;
: bnum cnum 15 * 16 / ;
: anum cnum 15 * 18 / ;
: gnum cnum 15 * 20 / ;
: fnum cnum 15 * 22 / ;
: enum cnum 15 * 24 / ;
: rest 30000 ;

CREATE NOTES 48 allot
0 value ncnt

: !,    ( n1 -- )
        notes ncnt + !
        2 +!> ncnt ;

: fill-notes            \ fill in the note array
        off> ncnt
     CNUM !, CNUM !, BNUM !, GNUM !, ANUM !, REST !,
     ANUM !, ANUM !, GNUM !, ENUM !, FNUM !, REST !,
     FNUM !, FNUM !, GNUM !, ANUM !, GNUM !, REST !,
     GNUM !, GNUM !, ANUM !, BNUM !, CNUM !, REST !, ;

\ original music by Marc Hawley. Rights reserved.


 0 VALUE NOTENUM
-1 value sound_on

: MUSIC
        sound_on
        if      NOTENUM NOTES + @ 1 TONE
                NOTENUM 2+ 48 MOD =: NOTENUM
        else    1 tenths
        then    ;

: whistle
        sound_on
        if      8000 1 tone
        then    ;


: MOVEMENT
        down
        off> alldown
    BEGIN
        TIME-RESET
        BEGIN
     KEY?
 [long] IF
        KEY  CASE
                203 OF LEFT  whistle            ENDOF
                205 OF RIGHT whistle            ENDOF
                200 OF RROT  whistle            ENDOF
                208 OF LROT  whistle            ENDOF
                $20 of on> alldown              endof
                $1B of 0 23 at bye              endof
                upc
                'S' of sound_on 0= !> sound_on  endof
                'P' of paused   0= !> paused    endof
                DROP 1000 1 TONE ENDCASE
      THEN
                10TH-ELAPSED
                TIME.LIMIT >
                alldown or
                UNTIL    DOWN
                alldown 0= if MUSIC then
                BACKUP.CURR DOWN.CURR VALID?.CURR NOT RESTORE.CURR
                UNTIL
                  ;

0 VALUE ROW.NUM

: ROW.FULL? ( n -- tf ) \ check if row n is full of 32 's   for a y vary x
        =: ROW.NUM                      \
        TRUE                            \ t
        20 0 DO                         \ t each x is I
        I ROW.NUM MY.AT                 \ t x y --
        GET-CHAR                        \ t ascii --
        32 =                            \ t tf --
        AND                             \ tf --
        LOOP
        ;                               \ TRUE IF FULL


0 VALUE SCORE
40 VALUE HIGH.SCORE   \ by M. Hawley 2-10-90
0 VALUE LEVEL

: ROW.DROP ( n  -- )                      \ use ROW.NUM
    =: ROW.NUM                          \ the row to be eliminated
      BEGIN
        20 0 DO                         \  x's    each x in the row
        I                               \ x --
        ROW.NUM 1-                      \ x y-1 --  the position above it
        MY.AT GET-CHAR                  \ ASCII     read that
        I ROW.NUM                       \ ascii x y --  write to space below
        MY.AT EMIT                      \ --
        LOOP                            \     next higher row
      ROW.NUM 1- DUP =: ROW.NUM         \ r   continue to zero
      1 < UNTIL
      80 2 TONE
      SCORE 1+ =: SCORE
      SCORE 10 / =: LEVEL
      5 LEVEL - =: TIME.LIMIT
      6 6 AT LEVEL .
       5 10 AT SCORE .
      SCORE HIGH.SCORE >
                IF SCORE =: HIGH.SCORE
                THEN
      3 16  AT HIGH.SCORE .

          ;
COMMENT:
        This is close. Appears to copy lower row onto upper.
COMMENT;

: ROW.CHECK
        17 0 DO                         \ rows y
          I ROW.FULL?
          IF
             20 0 DO
              I J MY.AT 219 EMIT            \ whites the full row
             LOOP
          I ROW.DROP
          THEN
        LOOP
        ;

: SETUP
        0 =: SCORE
        27 0 AT ."    ***   T E T R A   ***"
        5 9 AT  ." *SCORE*"
        5 5 AT  ." *LEVEL*"
        6 6 AT   LEVEL  .
        3 12 AT ." you must score 10 "
        2 13 AT ." to move to next level"
        3 15 AT ." *HIGH SCORE*"
        3 16 AT HIGH.SCORE .
        55 13 AT ." Control With"
        55 14 AT ." Arrow Keys"
        55 16 at ." DROP PIECE - SPACE"
        55 18 at ." SOUND TGL  - S"
        55 19 at ." PAUSE TGL  - P"
        55 17 at ." QUIT       - ESC"
        55 10 AT ." by Marc Hawley"
        ;



: GAME
        fill-notes
      FIELD SETUP BORDER BEGIN          \ make field , mark beginning
        FIGURE.NO 1+ 6 MOD =: FIGURE.NO  \ new figure
        FILL.CURR                        \ new figure into array
        BACKUP.CURR                     \ copy into BACK array
        DOWN.CURR                       \ inc CURR y's
        VALID?.CURR  NOT                   \ is this valid  ( -- tf )
        MOVEMENT                          \ run the movement for this figure
        ROW.CHECK
      UNTIL                               \ continue till NOT valid
    ;

\fpc    cr .( Type GAME to play the game.)

