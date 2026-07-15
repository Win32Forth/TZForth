echo off
echo Copying kernel configuration file from \FPC directory.
copy \fpc\kernel.cfg
echo .
echo Building a small version of F-PC for TCOM.
echo .
kernel sf-pc ok bye
echo .
echo .
echo Building a small version of TCOM with SF.EXE.
echo .
sf starget ok bye
echo .
echo .
echo Smaller TCOM.EXE built. It needs less than 300k free ram to compile.
echo .
