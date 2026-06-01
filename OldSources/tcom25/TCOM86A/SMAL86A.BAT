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
sf targ86a ok bye
echo .
echo .
echo TCOM86A.EXE build complete..
echo .
