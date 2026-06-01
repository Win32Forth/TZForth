\\ SAMPLE.SEQ        Some Sample Stuff to target Compile

    Two examples are included in this file. The first one makes a larger
  .COM file and lets the compile do any needed initialization. The second
  version performs the initialization in the program, and omits those
  initialization operations not needed by this program. The result is a
  MUCH smaller .COM file. Change the TRUE below to FALSE then enter the
  second command line example to see the difference.

{

                \ test for whether the /NOINIT option was specified
                \ and load the proper version

?DEFINIT #IF    \ load this version if using default initialization

}

  Compile this file with the following command line:

        C:>TCOM SAMPLE /OPT <Enter>
{

: MAIN          ( -- )
                ." Hello world! " ;

#ELSE   \ else load this version if the /NOINIT option was specified.

}

  Here is a similar example, that creates a smaller .COM file and only
  does the initialization needed, rather than all of the normal
  initialization.

  Compile this example with the following command line:

        C:>TCOM SAMPLE /OPT /NOINIT <Enter>

{

: MAIN          ( -- )
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                ." Hello world!" ;

#THEN

}

    More notes:

    You should see in the above examples that a substantial size
  difference will occur between the three possible compile variations.

        TCOM SAMPLE /OPTOFF             produces a 2889 byte .COM file.

        TCOM SAMPLE /OPT (the default)  produces a 2345 byte .COM file.

        TCOM SAMPLE /OPT /NOINIT        produces a 973 byte .COM file on
                                        the second example.

    When you specify the /NOINIT option, in this example ONLY, the
  ?DEFINIT flag is tested, and the second version of the program is
  compiled that does the needed initialization.

    While it is possible to target compile the first example with the
  command line of the second example and get a smaller .COM file, The
  resulting program will not function.

    As you can see there are several options available while building a
  program. The simplest example (without /OPT), is mostly useful when
  debugging, and making listings that are easy to follow.


