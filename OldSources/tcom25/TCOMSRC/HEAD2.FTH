\\ HEAD2.SEQ           Make a second HEADer 2 the word following

  When these words are used, they create a new header (alias) with the
  same name in the current vocabulary.

  This was designed for use with the TCOM compiler, to build a list of
  normal forth words that are needed during compiling, while only making
  those words needed available.

  A warning is issued for any word that doesn't already exist, but the
  load is not aborted.

  If a head is made for an immediate word, the new header will be
  immediate like the original header.

  An example of how to use this word follows the definition of HEAD2.

{

I: head2        ( -<name>- )            \ make an alias of name as name
                false save!> warning            \ no redef warning
                >in @ defined dup>r             \ make if word is defined
                if      swap >in !              \ restore >IN
                        alias                   \ make new header
                        r@ 1 =
                        if      immediate       \ make new head immediate
                        then
                else    nip count cr type
                        ."  was not defined"
                then    r>drop
                restore> warning ;      \ restore warning flag
\s
I: head2        ( | name -- )           \ make an alias of name as name
                false save!> warning            \ no redef warning
                >in @ defined dup 1 =           \ make if word is defined
                if      drop swap >in !         \ restore >IN
                        alias                   \ make new header
                        immediate               \ make new head immediate
                else    if      swap >in !
                                alias
                        else    nip count cr type ."  was not defined"
                        then
                then    restore> warning ;      \ restore warning flag

\ .( Type )  loadline @ 3 + . .( LOAD to compile an example. )
}
\ **********************************************************************
\ ***************** THE FOLLOWING IS NOT LOADED ************************
\ **********************************************************************

        only forth root also definitions
        forth also                      \ select ROOT for new definitions
                                        \ also search Forth
        vocabulary FWORDS               \ make a voc for a special list
        only fwords definitions also forth also
                                        \ search is ROOT, FWORDS & FORTH

        head2 if                head2 else              head2 then
        head2 begin             head2 while             head2 repeat
        head2 again             head2 do                head2 ?do
        head2 loop              head2 +loop             head2 i
        head2 until             head2 for               head2 next
        head2 \\                head2 (                 head2 .(
        head2 \                 head2 '                 head2 bye
        head2 see               head2 forth             head2 root
        head2 directive         head2 assembler

        only forth definitions fwords also


