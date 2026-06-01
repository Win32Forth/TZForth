
autoeditoff
\ needs codebug.seq
needs asm1600.seq

showlines
code xyz
        ret                     a;
        add     a $23           a;
        add     a r7            a;
        add     a (r2)          a;
        add     a (r2+)         a;
        add     a (r2-)         a;
        add     a (r2+!)        a;
        add     a ((r2))        a;
        add     a ((r2+))       a;
        add     a ((r2-))       a;
        add     a ((r2+!))      a;
        add     a y             a;
        addi    a 234           a;
        addi    a 1234          a;
        addi    234             a;
        and     a $23           a;
        and     a r7            a;
        and     a (r2)          a;
        and     a (r2+)         a;
        and     a (r2-)         a;
        and     a (r2+!)        a;
        and     a ((r2))        a;
        and     a ((r2+))       a;
        and     a ((r2-))       a;
        and     a ((r2+!))      a;
        and     a y             a;
        ldi     a 234           a;
        ld      a $33           a;
        ld      $33 a           a;
        mpys    (r5) (r2) 1     a;
        mpys    (r5) (r2) 1     a;
        mld     stack (r1) 0    a;
        mpya    (r5) (r3|00) 0  a;
        mld     stack (r1) c    a;
        mpya    (r5) (r3|00) d  a;
        eor     a stack         a;
        eor     a a             a;
        eor     a (r0)          a;
        eor     a 23            a;
        eori    a 23            a;
        eor     a ((r0))        a;
0 $:    eor     a r0            a;
        mod     always ror      a;
        mod     always rol      a;
        mod     always shr      a;
        mod     always shl      a;
        mod     always inc      a;
        mod     always dec      a;
        mod     always neg      a;
        mod     always abs      a;
        mod     F resl          a;
        mod     F setl          a;
        mod     F resie         a;
        mod     F setie         a;
        mod     F resop         a;
        mod     F setop         a;
        bra     usr0=0 0 $      a;
        bra     usr0=1 0 $      a;
        bra     usr1=0 0 $      a;
        bra     usr1=1 0 $      a;
        call    usr0=0 0 $      a;
        call    usr0=1 0 $      a;
        call    usr1=0 0 $      a;
        call    usr1=1 0 $      a;
        ld      a FFFF          a;
        ld      y a             a;
        ldi     r3 123          a;
        ldi     (r4) 123        a;
        ldi     (r4+) 123       a;
        ldi     (r4-) 123       a;
        ldi     (r4+!) 123      a;
        ldi     (r4) 123        a;
        end-code

