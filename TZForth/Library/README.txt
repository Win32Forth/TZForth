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
  README.txt          This note

Usage
-----
  FROMLIB FLOAD big-int.fth
  ALSO BIG-INTEGER

  FROMLIB FLOAD pi-test.fth     \ full π demo
  FROMLIB FLOAD bi-test.fth     \ unit tests
  FROMLIB EDIT pi-test.fth      \ open library file in TextEdit
  FROMLIB DIR                   \ list Resources/Library
  FROMLIB DIR *.fth             \ filtered list

  VIEW-LIBRARY                  \ Finder on Resources/Library
  Tools → LIBRARY → VIEW Library Folder

In a *file*, multi-line is allowed:
  FROMLIB
  FLOAD big-int.fth

In the *console*, keep FROMLIB on the same line as the load/EDIT/DIR word.

See repository README.md: "Library and FROMLIB" and "BIG-INTEGER".
