\\ LS86.SEQ      Create a 8086 program listing program  by Jerry Boutelle
============================================================================
.options /opt /noinit /nostack

        8086 modifications by Tom Zimmer

{

\fpc HEADERS
\fpc HWORDS-

\fpc fpath+ \tcom

\fpc \+ autoeditoff autoeditoff
\fpc warning off

\tcom   fload tfileio.seq
\fpc    fload fileio.seq
        fload c:\tcom\samples\ls1.seq
        fload da96.seq
        fload c:\tcom\samples\ls2.seq

