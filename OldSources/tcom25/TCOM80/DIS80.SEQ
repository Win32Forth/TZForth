\\ DIS80.SEQ            An 8080 Disassembler            by Tom Zimmer

        A disassembler for the 8080 processor

        .options /opt /definit
{

\t 0 value cptr
\t variable dumpseg
\t : t@  @t ;   \ dumpseg @ swap  @L ;
\t : tc@ c@t ;  \ dumpseg @ swap c@L ;


\f \- cptr         0 value cptr

\f VARIABLE RELOC  0 reloc !

\f : +RELOC ( a ) RELOC @ + DUMPSEG @ SWAP ;
\f : (T@) ( a - w ) +RELOC @L ;
\f : (TC@) ( a - n ) +RELOC C@L ;

\f DEFER T@ ( a - w )
\f DEFER TC@ ( a - n )
\f : MEMORY  ['] (TC@) IS TC@  ['] (T@)  IS T@ ; MEMORY

: cptr_c@+      ( -- b1 )
                cptr tc@ incr> cptr ;

: cptr_@+       ( -- w1 )
                cptr t@ 2 +!> cptr ;

\ 7 CONSTANT A
\ 0 CONSTANT B   1 CONSTANT C      2 CONSTANT D   3 CONSTANT E
\ 0 CONSTANT I   1 CONSTANT I'     2 CONSTANT W   3 CONSTANT W'
\ 0 CONSTANT IP  1 CONSTANT IP'    4 CONSTANT H   5 CONSTANT L
\ 6 CONSTANT M   6 CONSTANT PSW    6 CONSTANT SP  6 CONSTANT S

: 1mi           ( -<name>- )
                ( n1 -- )
                create ," does> count type space drop ;

        1MI .B B"       1MI .C C"       1MI .D D"       1MI .E E"
        1MI .H H"       1MI .L L"       1MI .M M"       1MI .A A"
        1MI .I I"       1MI .I' I'"     1MI .W W"       1MI .W' W'"
        1MI .IP IP"     1MI .IP' IP'"   1MI .PSW PSW"   1MI .SP SP"
        1MI .S S"       1MI .BAD BAD"

: .reg1         ( n1 -- )
                $07 and dup exec:
                .b      .c      .d      .e
                .h      .l      .m      .a      ;

: .reg2         ( n1 -- )
                $08 / $07 and dup exec:
                .ip     .ip'    .d      .e
                .h      .l      .m      .a      ;

: .reg3         ( n1 -- )               \ LXI MVI DAD
                $3F AND $08 / dup exec:
                .b      .b      .d      .d
                .h      .h      .sp     .sp     ;

: 2mi           ( -<name>- )
                create ," does> count type space .reg1 ;

: 3mi           ( -<name>- )
                create ," does> count type space .reg2 ;

: 4mi           ( -<name>- )
                create ," does> count type space drop cptr_c@+ h. ;

: 5mi           ( -<name>- )
                create ," does> count type space drop cptr_@+ h. ;

: 6mi           ( b1 -- )
                create ," does> count type space ( $3F and 8 / ) .reg3
                                cptr_c@+ h. ;

: 7mi           ( b1 -- )
                create ," does> count type space ( $3F and 8 / ) .reg3 ;

: 8mi           ( b1 -- )
                create ," does> count type space ( $3F and 8 / ) .reg3
                                cptr_@+ h. ;

        1MI .NOP NOP"   3MI .STAX STAX" 3MI .INX INX"
        3MI .INR INR"   3MI .DCR DCR"   1MI .RLC RLC"
        3MI .LDAX LDAX" 3MI .DCX DCX"   1MI .RRC RRC"
        1MI .RAL RAL"   1MI .RAR RAR"   5MI .SHLD SHLD" 1MI .DAA DAA"
        5MI .LHLD LHLD" 1MI .CMA CMA"   5MI .STA STA"   1MI .STC STC"
        5MI .LDA LDA"   1MI .CMC CMC"   1MI .HLT HLT"   2MI .ADD ADD"
        2MI .ADC ADC"   2MI .SUB SUB"   2MI .SBB SBB"   2MI .ANA ANA"
        2MI .XRA XRA"   2MI .ORA ORA"   2MI .CMP CMP"   1MI .RNZ RNZ"
        3MI .POP POP"   5MI .JNZ JNZ"   5MI .JMP JMP"   3MI .PUSH PUSH"
        4MI .ADI ADI"   3MI .RST RST"   1MI .RZ RZ"     1MI .RET RET"
        5MI .JZ JZ"     5MI .CALL CALL" 4MI .ACI ACI"   1MI .RNC RNC"
        5MI .JNC JNC"   4MI .OUT OUT"   4MI .SUI SUI"   1MI .RC RC"
        5MI .JC JC"     4MI .IN IN"     4MI .SBI SBI"   1MI .RPO RPO"
        5MI .JPO JPO"   1MI .XTHL XTHL" 4MI .ANI ANI"   1MI .RPE RPE"
        1MI .PCHL PCHL" 5MI .JPE JPE"   1MI .XCHG XCHG" 4MI .XRI XRI"
        5MI .JP JP"     1MI .DI DI"     4MI .ORI ORI"   1MI .RM RM"
        1MI .SPHL SPHL" 5MI .JM JM"     1MI .EI EI"     4MI .CPI CPI"
        6MI .MVI MVI"   8MI .LXI LXI"   5MI .CC CC"     5MI .CNC CNC"
        7MI .DAD DAD"   5MI .CZ CZ"     5MI .CNZ CNZ"   5MI .CP CP"
        5MI .CM CM"     5MI .CPE CPE"   5MI .CPO CPO"   1MI .RP RP"

: .MOV          ( b1 -- )
                ." MOV " dup $07 and .reg1 $3F and 8 / .reg1 ;

: dis1          ( b1 -- )
                $FF and dup exec:
        ( $00 ) .NOP    .LXI    .STAX   .INX    .INR    .DCR    .MVI    .RLC
        ( $08 ) .bad    .DAD    .LDAX   .DCX    .INR    .DCR    .MVI    .RRC
        ( $10 ) .bad    .LXI    .STAX   .INX    .INR    .DCR    .MVI    .bad
        ( $18 ) .bad    .DAD    .LDAX   .DCX    .INR    .DCR    .MVI    .bad
        ( $20 ) .bad    .LXI    .SHLD   .INX    .INR    .DCR    .MVI    .DAA
        ( $28 ) .bad    .DAD    .LHLD   .DCX    .INR    .DCR    .MVI    .CMA
        ( $30 ) .bad    .LXI    .STA    .INX    .INR    .DCR    .MVI    .STC
        ( $38 ) .bad    .DAD    .LDA    .DCX    .INR    .DCR    .MVI    .CMC
        ( $40 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV
        ( $48 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV
        ( $50 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV
        ( $58 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV
        ( $60 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV
        ( $68 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV
        ( $70 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .HLT    .MOV
        ( $78 ) .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV    .MOV
        ( $80 ) .ADD    .ADD    .ADD    .ADD    .ADD    .ADD    .ADD    .ADD
        ( $88 ) .ADC    .ADC    .ADC    .ADC    .ADC    .ADC    .ADC    .ADC
        ( $90 ) .SUB    .SUB    .SUB    .SUB    .SUB    .SUB    .SUB    .SUB
        ( $98 ) .SBB    .SBB    .SBB    .SBB    .SBB    .SBB    .SBB    .SBB
        ( $A0 ) .ANA    .ANA    .ANA    .ANA    .ANA    .ANA    .ANA    .ANA
        ( $A8 ) .XRA    .XRA    .XRA    .XRA    .XRA    .XRA    .XRA    .XRA
        ( $B0 ) .ORA    .ORA    .ORA    .ORA    .ORA    .ORA    .ORA    .ORA
        ( $B8 ) .CMP    .CMP    .CMP    .CMP    .CMP    .CMP    .CMP    .CMP
        ( $C0 ) .RNZ    .POP    .JNZ    .JMP    .CNZ    .PUSH   .ADI    .RST
        ( $C8 ) .RZ     .RET    .JZ     .bad    .CZ     .CALL   .ACI    .RST
        ( $D0 ) .RNC    .POP    .JNC    .OUT    .CNC    .PUSH   .SUI    .RST
        ( $D8 ) .RC     .bad    .JC     .IN     .CC     .bad    .SBI    .RST
        ( $E0 ) .RPO    .POP    .JPO    .XTHL   .CPO    .PUSH   .ANI    .RST
        ( $E8 ) .RPE    .PCHL   .JPE    .XCHG   .CPE    .bad    .XRI    .RST
        ( $F0 ) .RP     .POP    .JP     .DI     .CP     .PUSH   .ORI    .RST
        ( $F8 ) .RM     .SPHL   .JM     .EI     .CM     .bad    .CPI    .RST
        ;

: inst          ( -- )
                SAVE> BASE HEX
                CPTR
                0 <# # # # # #> TYPE SPACE
                cptr_c@+ DUP
                0 <# # # #> TYPE SPACE
                RESTORE> BASE
                dis1 ;

: DIS           ( a1 -- )
                !> cptr
                begin   cr inst
                        50 ms
                        ?keypause
                again   ;

\f CR .( 8080 Disassembler Loaded )

\f ONLY FORTH ALSO DEFINITIONS

\f WARNING ON

