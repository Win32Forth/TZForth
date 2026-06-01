\\ TIMEFILE.SEQ    Display the current date and time       by Tom Zimmer

  A utility that subsitutes a time and date related filename for a text
line following itself on the DOS command line and then echos the line to
the display.  Used like the following example:

        TIMEFILE PKZIP -A A:@T *.SEQ >BACKUP2.BAT [enter]

  This command line will echo: PKZIP -A A:<time_related_filename> *.SEQ to
the file BACKUP2.BAT.  It can then be executed to perform a backup to a
unique filename.

  This is primarily useful when you want to perform a series of backups
each day, onto a floppy disk, and you want each backup to have a unique
name that is related to the date and time of the backup.

  I will typically create a batch file called BACKUP.BAT that contains
the following two lines:

        @TIMEFILE PKZIP -A A:@T %1 %2 %3 %4 %5 >BACKUP2.BAT
        @BACKUP2.BAT

  This will create a unique name, and perform a backup of upto five file
specifications on the command line following BACKUP as in:

        BACKUP *.SEQ *.EXE *.COM [enter]

{
.options /opt /noinit           \ compiler directives for this program

: .TIMEFILE     ( -- )          \ generate a filename in the form:
                DTBUF OFF       \ day|hours|minutes|seconds, as 8 digits.
                GETDATE SPLIT ROT  2DROP ( ##+ ##+ ) ##+
                GETTIME SWAP SPLIT ##+ ##+ SPLIT ##+ DROP ( ##+ ) DTBUF COUNT TYPE ;

: main          ( -- )
                DECIMAL
                TT['] (EMIT)    !> EMIT           \      EMIT,
                TT['] (TYPE)    !> TYPE           \      TYPE,
                PRINTING OFF
                ?DS: SSEG !
                DOS_TO_TIB
                " @T" TIB #TIB @ SEARCH
                IF      TIB OVER 1 /STRING TYPE .TIMEFILE
                        TIB #TIB @ ROT 2+ /STRING TYPE
                ELSE    .TIMEFILE
                THEN    ;

