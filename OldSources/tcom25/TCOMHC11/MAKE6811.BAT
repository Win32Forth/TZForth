@echo off
echo off
echo Copying kernel configuration file from \FPC directory.
copy \fpc\kernel.cfg
echo .
echo Building a small version of F-PC for TCOM.
echo .
kernel \tcom\src\sf-pc ok bye
echo .
echo .
echo Building a small version of TCOM6811 with SF.EXE.
echo .
sf tcom6811 ok bye
echo .
echo .
echo TCOM6811.EXE built.
echo .
