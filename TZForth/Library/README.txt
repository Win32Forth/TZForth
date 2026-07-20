TZForth Library (Resources/Library)
==================================

Shipped Forth modules for FROMLIB FLOAD / INCLUDE / REQUIRE.

At build time this folder is copied to:

  YourApp.app/Contents/Resources/Library/

Layout
------
  Editor/             SZ-EDITOR port (SZ-EDITOR.fth + sz-*.fth)
  BigInteger/         Multiprecision integers (big-int.fth, bi-test.fth)
  PI/                 High-precision π (pi-chudnovsky.fth, pi-test.fth)
  HayesTest.fth       John Hayes forth2012 full suite driver
  HayesTest/          Suite sources (src/), docs (doc/), README.md
  README.txt          This note

Usage
-----
  FROMLIB FLOAD BigInteger/big-int.fth
  ALSO BIG-INTEGER

  FROMLIB FLOAD PI/pi-test.fth              \ full π demo
  FROMLIB FLOAD BigInteger/bi-test.fth      \ unit tests
  FROMLIB FLOAD Editor/SZ-EDITOR.fth        \ text editor
  FROMLIB FLOAD HayesTest.fth               \ full Hayes ANS suite
  FROMLIB EDIT PI/pi-test.fth               \ open library file in TextEdit
  FROMLIB DIR                               \ list Resources/Library
  FROMLIB DIR Editor                        \ list editor modules
  FROMLIB DIR BigInteger
  FROMLIB DIR PI
  FROMLIB DIR HayesTest/src

  VIEW-LIBRARY                              \ Finder on Resources/Library
  Tools → LIBRARY → VIEW Library Folder

In a *file*, multi-line is allowed:
  FROMLIB
  FLOAD BigInteger/big-int.fth

In the *console*, keep FROMLIB on the same line as the load/EDIT/DIR word.

Nested FLOAD / REQUIRE paths are relative to Resources/Library/ (not the
subfolder of the file that is currently loading). Example from pi-test.fth:

  FROMLIB REQUIRE BigInteger/big-int.fth
  FROMLIB REQUIRE PI/pi-chudnovsky.fth

Read-only bundle / writable data
--------------------------------
Resources/Library is inside the app package (read-only). FLOAD/INCLUDE/REQUIRE
read sources from there. CREATE-FILE, OPEN-FILE (for writes), RENAME-FILE,
DELETE-FILE, FILE-STATUS, and default/relative .blk volumes that would land
*inside the .app* are remapped by the *host* to:

  Application Support/TZForth/<filename>

This is not a Forth dictionary word — see README.md section
"Bundle is read-only; Application Support for data".

For durable user data, prefer explicit paths or CHDIR to a writable folder
(Documents, or a folder authorized with bare FLOAD), not the remapped scratch area.

See repository README.md: "Library and FROMLIB", "Bundle is read-only…", and
"BIG-INTEGER".
