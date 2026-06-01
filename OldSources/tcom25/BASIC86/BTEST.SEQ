
        dim ab3(23)

rem     command debug @let
        poke $0B800:0,3  : REM put a 3 into video memory
        let ab1=peek($0B800:ab3(4))
        let ab3(1)=ab3(2)
rem     END

rem     let akey=inkey$
rem     if akey = 0 then akey=akey+3
rem     let sp0=3 +  -2 * 4 - +6
        let sp0=2 * 4 - +6
        sp0=-$0FEF1
        sp0=not sp0
        let ab1=12 : let ab2=23
        bozo=ab1 and ab2 or sp0 xor ab2
        let bozo=ab1+ab2*sp0-ab2

bongo:
        if sp0>=not$0fef0 then let ab1=43
        if -1 then gosub bingo
        if (sp0<>$0fef0) then gosub bingo
        goto bongo

        let ab1=peek(ab3(4))

bingo:
        let ab1=ab1+1
        let ab3(1)=ab3(2)
        return



