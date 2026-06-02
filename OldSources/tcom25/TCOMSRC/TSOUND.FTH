\ TSOUND.SEQ            Some Sound code for TCOM

comment:

  A simple sound generator for F-PC, programs the timer chip for the
proper frequency, then enables the tone to the speaker for "duration"
number of tenths of a second.

comment;

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

\ port addresses pulled from:
\        "The Peter Norton Programmer's Guide to the IBM-PC"

66 constant timerdata           \ timer data port
67 constant timerctrl           \ timer control port
97 constant tonegate            \ tone gate

                                                \ freq     = frequency in Hz
: tone          ( freq duration -- )            \ duration = tenths of sec
                >r                              \ save duration
                182 timerctrl pc!               \ prepare for new frequency
                1193280. rot um/mod nip                 \ calculate timer vals
                256 /mod swap                           \ for desired freq.
                timerdata pc! timerdata pc!             \ set counter values
                tonegate pc@ $03 or  tonegate pc!       \ tone on
                r> tenths                               \ for duration
                tonegate pc@ $FC and tonegate pc! ;     \ tone off

FORTH TARGET >TARGET

