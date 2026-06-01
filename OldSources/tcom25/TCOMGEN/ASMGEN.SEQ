\\ ASMGEN.SEQ            An GENERIC Assembler            09/09/91 TJZ

A GENERIC assembler for TCOM by Tom Zimmer

{

WARNING OFF

ONLY FORTH ALSO DEFINITIONS VOCABULARY ASMGEN
' ASMGEN ALIAS [ASMGEN] IMMEDIATE
ONLY FORTH ALSO ASSEMBLER ALSO ASMGEN DEFINITIONS ALSO

\ some alias headers so we dont have to redefine these words in
\ the new target assembler.

        ' a;            alias a;
        ' a;!           alias a;!
        ' $             alias $
        ' $:            alias $:
        ' ll-global?    alias ll-global?
        ' ll-errs?      alias ll-errs?
        ' end-code      alias end-code  immediate
        ' end-code      alias c;        immediate
        ' c,            alias c,
        ' ,             alias ,
        ' here          alias here
        ' tc@           alias tc@
        ' tc!           alias tc!
        ' t!            alias t!
        ' IC,           ALIAS IC,
        ' OC,           ALIAS OC,
        ' CC,           ALIAS CC,
        ' O,            ALIAS O,
        ' OFFSET_16,    ALIAS OFFSET_16,
        ' OFFSET_8,     ALIAS OFFSET_8,

FORTH DEFINITIONS

: DOASSEMX      ( --- )
                @> RUN =: ARUNSAVE
                  ['] RUN-A; IS RUN
                0 ['] DROP A;!
                APRIOR 4 + 2@ APRIOR 2!
                LIHERE =: LINESTRT
                ll-global? 0=
                if      llab-init               \ in case labels used
                then
                ALSO ASMGEN ;

: SETASMGEN       ['] DOASSEMX IS SETASSEM  ;

SETASMGEN

ONLY FORTH ALSO ASMGEN DEFINITIONS ALSO

}

  Use "IC," in place of "," to compile the first byte of each instruction
with the exception of CALLs which are compiled with "CC,".  Other bytes
of instructions are compiled with "OC,".

  The defined words "OFFSET_16," and "OFFSET_8," are used to compile the
data associated with instructions that may contain forward references.
You will probably need to study PASM.SEQ in F-PC to see how these words
work. Essentially they compile the data from the stack, but in the case
of a forward reference, they also invoke the NEWLAB.SEQ functions to
create a forward reference record so they can be resolved automatically
at a later time when the label referenced is defined.

  Here is an extract (with minor modifications) from PASM.SEQ:

  These first words are the resolvers, which get used to resolve a
forward reference that be resolved now that its destination is available.

: reserr        ( -- )
                true abort" Illegal forward resolution type" ;

: res_byte/rel  ( targ_addr -- )        \ resolve a byte relative targ addr
                here over 1+ - dup $-80 $7F between 0=
                ABORT"  Address out of range "
                swap TC! ;

: res_word/rel  ( targ_addr -- )        \ resolve a word relative targ addr
                here over 2+ - swap T! ;

: res_signed_byte/off  ( targ_addr -- )
                here dup $-80 $7F between 0=
                ABORT"  Address out of range "
                swap TC! ;              \ resolve a byte OFFSET targ addr

: res_byte/off  ( targ_addr -- )
                here dup $00 $FF between 0=
                ABORT"  Address out of range "
                swap TC! ;              \ resolve a byte OFFSET targ addr

: res_word/off  ( targ_addr -- )
                here swap T! ;          \ resolve a word OFFSET targ addr

  Main resolve word is passed a target address, and a target resolution
type. The target address is resolved to HERE in the target.

: resolve_X     ( targ_addr res_type -- )       \ resolve a for ref
                0max 5 min exec:
                reserr                                  \ any lower = error
                res_byte/rel                            \ type 1
                res_word/rel                            \ type 2
                res_byte/off                            \ type 3
                res_word/off                            \ type 4
                res_signed_byte/off                     \ type 5
                reserr ;                                \ any higher = error

' resolve_X    is resolve_ref   \ link your resolver into local label
                                \ mechanism

  These words actually compile data into the target where a forward
reference may be occuring.  The word "ASM!LREF" sets up the forward
reference record if one is needed.  ASM!LREF knows if a forward reference
is needed by the fact that a "$" local label was used in the instruction.
The "$" word knows if a forward reference is occuring, and sets a flag if
needed for ASM!LREF to use.

: RELATIVE_8,   ( a1 -- )
                here 1+ - dup $-80 $7F between 0=
                ABORT"  RELATIVE Address out of range"
                here 1 asm!lref                         \ res type 1
                OC, ;                                   \ 8bit RELATIVE

: RELATIVE_16,  ( a1 -- )
                here 2+ -
                here 2 asm!lref                         \ res type 2
                O, ;                                    \ 16bit RELATIVE

: SIGNED_8,     ( a1 -- )
                dup $-80 $7F between 0=
                ABORT"  SIGNED_OFFSET Address out of range"
                here 5 asm!lref                         \ res type 5
                OC, ;                                   \ 8bit SIGNED OFFSET

: OFFSET_8,     ( a1 -- )
                dup $00 $FF between 0=
                ABORT"  OFFSET Address out of range"
                here 3 asm!lref                         \ res type 3
                OC, ;                                   \ 8bit OFFSET

: OFFSET_16,    ( a1 -- )
                here 4 asm!lref                         \ res type 4
                O, ;                                    \ 16bit OFFSET

  These previous words are just used in your assembler in place of "," to
compile bytes of instructions subsequent to the OPCODE byte or word.  If
an instruction opcode actually contains data, then a special forward
reference word (like the ones above) must be created to compile the data
into the opcode itself.

{

CR .( Your target assembler is Loaded HERE)
CR CR

ONLY FORTH ALSO DEFINITIONS

WARNING ON

