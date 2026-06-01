\ SET50.SEQ            Set 50 line mode for VGA
.options /opt /0init

code set50     ( -- )
               mov ah, # $0F           \ determine the active page
               int $10
               mov bl, bh
               push bx

               mov ax, # $0500         \ make page 0 active
               int $10

               mov ax, # $1202         \ select 50 lines, 400 scan lines
               mov bl, # $30
               int $10
                                       \ perform mode set without changing mode
               mov ah, # $0F           \ determine the current mode
               int $10                 \ return mode in AL
               mov ah, # $00           \ set mode
               int $10
                                       \ load the 8X8 character set
               mov ax, # $1112         \ set to 8X8 character set
               mov bl, # 0             \ block number (vga=0-7, ega=0-3)
               int $10
                                       \ set to 1 bit 0 of Misc Info byte in
                                       \ host mem to enable cursor emulation
               call set487
                                       \ set the cursor position to a block
               mov cx, # $0600         \ begin at 6 end at 0
               mov ah, # $01
               int $10                 \ set the cursor
                                       \ reset to 0 bit 0 of Misc Info byte in
                                       \ host memory to disable cursor emulation
               call reset487

               mov dx, # $03D4         \ adjust the underline location
               mov al, # $14
               out dx, al
               inc dx
               mov al, # $07           \ set underline to line 7
               out dx, al
                                       \ reset active page to its prev value
               pop ax                  \ get original page
               mov ah, # $05           \ get old active page
               int $10

               int $20                 \ return to DOS
               end-code

code set487    ( -- )
               push ds
               sub ax, ax
               mov ds, ax              \ clear DS:
               mov al, $487            \ get physical byte $487
               or al, # $01            \ set bit 0
               mov $487 al             \ put the byte back to $487
               pop ds
               ret             end-code

code reset487  ( -- )
               push ds
               sub ax, ax
               mov ds, ax              \ clear DS:
               mov al, $487            \ get physical byte $487
               and al, # $FE           \ clear bit 0
               mov $487 al             \ put the byte back to $487
               pop ds
               ret             end-code

