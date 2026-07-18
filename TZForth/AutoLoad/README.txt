TZForth AutoLoad (product boot)
===============================

At build time this folder is copied into:

  YourApp.app/Contents/Resources/AutoLoad/

On launch, if Resources/AutoLoad/autoload.fth exists, TZForth loads it and runs
MAIN when defined (silent if missing). No Application Support copy.

  autoload.fth          Product boot file (required name, lowercase)
  AutoLoad-Sample.fth   Example (NOT loaded unless renamed to autoload.fth)
  README.txt            This note

Tools → AUTOLOAD → VIEW AutoLoad Folder opens the bundle Resources/AutoLoad/
in Finder so you can add/edit/remove files (typical for zip distribution).

To ship an application:
  1. Put autoload.fth (and helpers) in project TZForth/AutoLoad/.
  2. Define : MAIN ( -- ) ... ; if you want a startup entry.
  3. Archive / build Release.
