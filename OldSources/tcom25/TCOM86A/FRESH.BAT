@echo off
cd \tcom\tcom86a
cd
echo Freshening TCOM86A.ZIP file. Press a key.
pause
pkzip -f \tcom\tcom86a\tcom86a.zip \tcom\tcom86a\*.*
copy \tcom\tcom86a\*.zip \35\tcom
