\ TENVIRON.SEQ   Environment manipulation words          by Tom Zimmer

>FORTH FORTH DECIMAL TARGET >LIBRARY       \ a Library file

: evseg         ( --- n1 )      \ Return the segment of environment $.
                ?cs: 44 @L ;

: envsize       ( --- n1 )      \ Calculate the environment $ size.
                ?cs: evseg - 2047 min 16 * ;

: "envfind      ( a1 n1 --- n2 bool )   \ n2 is offset into environment
                caps dup @ >r off       \  where string a1,n1 was found.
                evseg sseg dup @ >r !   \ Set the search segment
                0 envsize search
                r> SSEG !               \ Restore the search segment
                r> caps ! ;

: .envchr       ( i -- )
                >r evseg r@ c@l 0=
                if      cr
                else    evseg r@ c@L emit
                then    r>drop ;

: .env          ( --- )         \ print the environment string
                envsize 0 cr
               ?do      i .envchr
                        evseg i @L 0= ?leave
                loop    ;

HANDLE COMSPEC$

: com_extract   ( a1 -- )
                8 + envsize swap
                comspec$ dup clr-hcb >nam -rot
                do      evseg i c@l 0= ?leave
                        evseg i c@l over c! 1+
                        1 comspec$ c+!
                loop    drop ;

: comspec@      ( --- )         \ extract the command spec
                " COMSPEC=" "envfind 0=
                if      drop comspec$ off
                else    com_extract
                then    ;

: .comspec      ( --- ) comspec@ comspec$ count type ;

: comspec_init  ( -- )
                comspec@ comspec$ count dup     \ init command specification
                                                \ for DOS shell operations
                if      cmdpath place
                else    2drop
                        " \COMMAND.COM" cmdpath place
                then    ;

132 ARRAY  PATH$

: path_extract  ( a1 -- )
                5 + envsize swap
                path$ dup clr-hcb >nam -rot
                do      evseg i c@l 0= ?leave
                        evseg i c@l over c! 1+
                        1 path$ c+!
                loop    drop    ;

: path@         ( --- )         \ extract the command spec
                " PATH=" "envfind 0=
                if      drop path$ off
                else    path_extract
                then    ;

: .path         ( --- ) path@ path$ count type ;

HANDLE ME$

: me_extract    ( a1 -- )
                4 + envsize swap
                me$ dup clr-hcb >nam -rot
                do      evseg i c@l 0= ?leave
                        evseg i c@l over c! 1+
                        1 me$ c+!
                loop    drop ;

: me@           ( --- ) \ extract my own execution name string
                        \ returns a null ME$ if it fails
                me$ off dosver 3 >=     \ need DOS version 3 or greater
                if      me$ 2 "envfind
                        if      me_extract
                        else    drop
                        then
                then            ;

: .me           ( --- ) me@ me$ count type ;

FORTH TARGET >TARGET

