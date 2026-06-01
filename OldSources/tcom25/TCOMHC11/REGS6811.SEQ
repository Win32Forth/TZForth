\ needs to be converted from 6805 to 6811

\ 6805 Registers Definitions

HEX

00 CONSTANT PORTA       \ Port A Data Register
01 CONSTANT PORTB       \ Port B Data Register
02 CONSTANT PORTC       \ Port C Data Register
03 CONSTANT PORTD       \ Port D Data Register
04 CONSTANT DDRA        \ Port A Data Direction Register
05 CONSTANT DDRB        \ Port B Data Direction Register
06 CONSTANT DDRC        \ Port C Data Direction Register

0A CONSTANT SPCR        \ SPI Control Register
0B CONSTANT SPSR        \ SPI Status Register
0C CONSTANT SPDR        \ SPI Data Register

0D CONSTANT BAUD        \ SCI Baud Rate Register
0E CONSTANT SCCR1       \ SCI Control Register 1
0F CONSTANT SCCR2       \ SCI Control Register 2
10 CONSTANT SCSR        \ SCI Status Register
11 CONSTANT SCDAT       \ SCI Data Register

12 CONSTANT TCR         \ Timer Control Register
13 CONSTANT TSR         \ Timer Status Register
14 CONSTANT ICRH        \ Input Capture Register low
15 CONSTANT ICRL        \ Input Capture Register high
16 CONSTANT OCRH        \ Ourput Compare Register high
17 CONSTANT OCRL        \ Ourput Compare Register low
18 CONSTANT CTRH        \ Counter Register high
19 CONSTANT CTRL        \ Counter Register low
1A CONSTANT CARH        \ Counter Alternate Register high
1B CONSTANT CARL        \ Counter Alternate Register low

1C CONSTANT PROG        \ EPROM Program Register
1D CONSTANT COPRST      \ COP Reset Register
1E CONSTANT COPCR       \ COP Control Register

1FDF CONSTANT OPTION    \ EPROM option Register


\ Register bit equates

SCCR1 7 2CONSTANT R8    \ Receive data bit 8
SCCR1 6 2CONSTANT T8    \ Transmit data bit 8
SCCR1 4 2CONSTANT M     \ SCI character word length
SCCR1 3 2CONSTANT WAKE  \ Wake-up select

SCCR2 7 2CONSTANT TIE   \ Transmit interrupt enable
SCCR2 6 2CONSTANT TCIE  \ Transmit complete interrupt enable
SCCR2 5 2CONSTANT RIE   \ Receive interrupt enable
SCCR2 4 2CONSTANT ILIE  \ Idle line interrupe enable
SCCR2 3 2CONSTANT TE    \ Transmit enable
SCCR2 2 2CONSTANT RE    \ Receive enable
SCCR2 1 2CONSTANT RWU   \ Receiver wake-up
SCCR2 0 2CONSTANT SBK   \ Send break

SCSR 7 2CONSTANT TDRE   \ Transmit data register empty
SCSR 6 2CONSTANT TC     \ Transmit complete
SCSR 5 2CONSTANT RDRF   \ Receive data register full
SCSR 4 2CONSTANT IDLE   \ Idle line detect
SCSR 3 2CONSTANT ORE    \ Overrun error
SCSR 2 2CONSTANT NF     \ Noise flag
SCSR 1 2CONSTANT FE     \ Framing error

TCR 7 2CONSTANT ICIE    \ Input capture interrupt enable
TCR 6 2CONSTANT OCIE    \ Output compare interrupt enable
TCR 5 2CONSTANT TOIE    \ Timer overflow interrupt enable
TCR 1 2CONSTANT IEDG    \ Input edge
TCR 0 2CONSTANT OLVL    \ Output level

TSR 7 2CONSTANT ICF     \ Input capture flag
TSR 6 2CONSTANT OCF     \ Output compare flag
TSR 5 2CONSTANT TOF     \ Timer overflow flag

DECIMAL

