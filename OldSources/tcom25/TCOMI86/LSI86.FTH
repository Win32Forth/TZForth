\\ LS86.SEQ      Create a 8086 program listing program  by Jerry Boutelle
\ Modification by Tom Zimmer
============================================================================

    80x86 listing generator program for TCOM86 Indirect threaded target!!

        .options /opt /noinit /tailopton                \ compiler options
{

        fpath+ \tcom;\tcom\samples

        65000 value maxobj              \ allow more space for 8086 target

        fload tfileio.seq
        fload ls1.seq
        fload disi86.seq
        fload ls2.seq

