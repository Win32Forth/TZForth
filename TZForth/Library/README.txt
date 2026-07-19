TZForth Library (Resources/Library)
==================================

Shipped Forth modules for FROMLIB FLOAD / INCLUDE / REQUIRE.

At build time this folder is copied to:

  YourApp.app/Contents/Resources/Library/

Modules (current)
-----------------
  big-int.fth         Multiprecision integers (BIG-INTEGER vocabulary)
  pi-chudnovsky.fth   High-precision π (needs big-int + ALSO BIG-INTEGER)
  pi-test.fth         Demo: π to 20/50/100 places
  bi-test.fth         Unit tests for big-int + π smoke test
  HayesTest.fth       John Hayes forth2012 full suite driver
  HayesTest/          Suite sources (src/), docs (doc/), README.md
                      (prepare-blocks.fth → writable App Support .blk)
  README.txt          This note

Usage
-----
  FROMLIB FLOAD big-int.fth
  ALSO BIG-INTEGER

  FROMLIB FLOAD pi-test.fth     \ full π demo
  FROMLIB FLOAD bi-test.fth     \ unit tests
  FROMLIB FLOAD HayesTest.fth   \ full Hayes ANS suite (Block + Float)
  FROMLIB EDIT pi-test.fth      \ open library file in TextEdit
  FROMLIB DIR                   \ list Resources/Library
  FROMLIB DIR *.fth             \ filtered list
  FROMLIB DIR HayesTest/src     \ list Hayes sources

  VIEW-LIBRARY                  \ Finder on Resources/Library
  Tools → LIBRARY → VIEW Library Folder

In a *file*, multi-line is allowed:
  FROMLIB
  FLOAD big-int.fth

In the *console*, keep FROMLIB on the same line as the load/EDIT/DIR word.

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
