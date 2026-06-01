\\ LZX.SEQ       LZ eXecutable header program            by Tom Zimmer

  LZX is a primitive program that is prepended to a compressed image of a
.COM file that was compressed by LZ.COM.  LZX performs the function of
expanding the attached compressed image into its original form and then
calls the expanded program.

  This code is based on the 1992 FORML paper by Will Baden on Lempel Ziv
compression.  The idea of attaching a small program to perform the
expansion came from both PKZIP's PKLITE and a freeware program called DIET.

  A new commandline option called /CUSTOM_INIT is used, to specify a
special version of the normal TCOM program initialization routine.

  It took many hours to get LZ to work properly, so you will most
certainly encounter problems if you modify this code.

  LZX.SEQ compiles with TCOM to under 1k bytes.

        .options /opt /custom_init /tailopton
{

LABEL ENTRY-POINT ( -- )
                MOV AX, CS              \ get a copy of the CODE segment
                ADD AX, # $E4F6         \ patched later to adjust for
                JMP 0 $ a;

                ,"-T LZX.COM by Tom Zimmer"     \ a marker for LZ

          0 $:  MOV DS, AX              \ Set the data segment
                MOV SS, AX              \ set hardware stack segment to DS
                MOV ES, AX              \ and extra register to DS
                mov bx, DP              \ get current end of dictionary
                sub ax, ax              \ preclear AX for a byte load and add
                mov al, 0 [bx]          \ count byte of filename
                add bx, ax              \ adj to last char of name
                add bx, 1 [bx]          \ adjust for length of compressed img
                add bx, # $103          \ adjust up to location of data stack
                mov si, bx              \ set stack pointer
\               mov SP0 bx              \ set data stack top pointer
                add bx, # $100          \ adjust to end of return stack
                mov sp, bx              \ set return stack
\               mov RP0 bx              \ set return stack TOP
                add bx, # 2             \ adjust past return stack
\ ****************************************************************************
\ We are NOT adjusting DP past the compressed image, so you MUST NOT use HERE!
\ ****************************************************************************
\               mov DP bx               \ re adjust DP to end of stacks
\ ****************************************************************************
                MOV BX, # 0             \ and top of stack register with zero
                MOV BP, BX              \ !!!!!BP WILL ALWAYS BE ZERO!!!!!
                JMP MAIN  word  a;
                END-CODE

    0 value  inseg
    0 value outseg
    0 value  inlen
    0 value outlen
    0 value  inoff

4096 constant lookBack#
  18 constant lookAhead#
  19 array    holding

M: fill_holding ( -- n1 )       \ fill and return byte count in holding
                inseg inoff inlen inoff - >r
                ?ds: holding count lookAhead# swap /string r> umin dup>r
                cmovel r> dup +!> inoff holding c+!
                holding c@ ;

MACRO hi4split+3 ( n1 -- n2 n3 )        \ n2=low 12 bits
                                        \ n3=high 4 bits + 3.
                mov ax, bx
                and bx, # $FFF          \ clip off upper 4 bits
                save_bx                 \ push on stack
                mov bl, ah              \ high byte of AX to low byte of BX
                shr bl, # 1             \ shift right 4 bits
                shr bl, # 1
                shr bl, # 1
                shr bl, # 1
                and bx, # $0F           \ clip off upper 12 bits
                add bx, # 3     END-MACRO

\ fetch a byte from memory at a1, append byte to OUTSEG as OUTLEN,
\ bump OUTLEN, and bump a1.

MACRO c@>outseg++ ( a1 n1 -- a1+1 n1 )
                mov dx, es              \ save ES
                mov es, &> outseg       \ get destination segment
                mov di, 0 [si]          \ get address from second stack item
                mov al, 0 [di]          \ fetch a byte from that memory addr
                mov di, &> outlen       \ get the pointer to where byte goes
                mov es: 0 [di], al      \ put byte to destination
                mov es, dx              \ restore ES
                add &> outlen # 1 word  \ bump output pointer
                add 0 [si], # 1 word    \ bump input pointer
                END-MACRO

: expand_holding ( -- )
        holding 1+ count
        8 0
        do      dup $80 and             \ if MSB set
[long]          if      over @  hi4split+3 ( 0 4096 um/mod 3 + ) >r
                        outlen  lookBack# u>
                        if      outlen lookBack# - +
                        then
                        outseg swap outseg outlen r@ cmovel r> +!> outlen
                        swap 2+ swap
                else    c@>outseg++
\                       over c@ outseg outlen c!L incr> outlen
\                       swap 1+ swap
                then    2*
                over holding count + u>= ?leave    \ limit to holdings length
        loop    drop
        holding 1+ - holding count rot /string holding place ;

create $100exp  $100 , 0 ,
create lzwexp   $100 , 0 ,

MACRO to>$100    ( -- )
                jmp far [] $100exp
                END-MACRO

MACRO ?ds:?cs:-16*DP@+!>inoff           \ adj to end of dict
                mov cx, ds
                mov ax, cs
                sub cx, ax
                mov ax, # $10
                mul cx
                add ax, dp
                mov &> inoff ax
                END-MACRO

: lz_expand     ( -- )
                0 !> outlen                     \ start laying in code at 0
                ?ds:?cs:-16*DP@+!>inoff                 \ adj to end of dict
                DP @ c@ 3 + DP @ +                      \ len upto compressed
                DP @ count + @ + inoff + !> inlen       \ len of   compressed
                inseg inoff c@L 3 +     +!> inoff       \ skip filename
                holding 17 erase                        \ put NULL in holding
                begin   fill_holding
                while   expand_holding
                repeat  to>$100 ;-             \ go to the expanded program

code lz_expand2
                mov ax, ds
                add ax, # $1000
                mov ds, ax
                mov es, ax
                mov ss, ax
                jmp lz_expand
                end-code

MACRO to>lz_expand ( -- )
                jmp far [] lzwexp
                END-MACRO

: MAIN          ( -- )
                ?DS: SSEG !                     \ init search segment
                ?cs:          $100exp 2+ !      \ init near code pointer
                ?cs: $1000 +   lzwexp 2+ !      \ init segment of pointer
                ['] lz_expand2 lzwexp    !      \ init offset  of pointer
                ?cs:   $10 + !> outseg          \ skip first 256 bytes of mem
                ?cs: $1000 + !> inseg           \ next 64k segment in memory
                ?cs: 0 inseg 0 $FFFF cmovel   \ copy 64k higher
                to>lz_expand ;-


