\ THANDLES.SEQ          Handle impementation file       by Tom Zimmer

\ This file contains some handle manipulation primitives

FORTH DECIMAL TARGET >LIBRARY       \ A library file

70 CONSTANT B/HCB
VARIABLE RWERR

                \ Attrib is normally  zero (0) for Read/Write.
                \ Attrib may be set to one (1) for Write ONLY.
                \ Attrib may be set to two (2) for Read  ONLY.
M: >ATTRIB      ( handle --- attrib-addr )      66 + ;
M: >HNDLE       ( handle --- handle-addr )      68 + ;
M: >NAM         ( handle --- name-string-addr ) 1+   ;
 : CLR-HCB      ( HANDLE - ) DUP B/HCB ERASE -1 SWAP >HNDLE ! ;

FORTH DECIMAL TARGET >TARGET

