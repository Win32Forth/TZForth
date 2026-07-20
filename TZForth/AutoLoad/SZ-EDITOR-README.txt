SZ-EDITOR — TZForth port of Small Zimmer's Editor
=================================================

Status
------
  Phase 0  Scaffolding                 done
  Phase 1  sz-host.fth                 done
  Phase 2  sz-buffer.fth               done
  Phase 3  sz-screen.fth               done mono redraw/scroll
  Phase 4  sz-edit.fth                 done minimal edit loop

Files
-----
  SZ-EDITOR.fth           ANEW driver + load chain
  sz-host.fth             Host shims
  sz-buffer.fth           Buffer + load/save
  sz-screen.fth           PAGE/AT-XY display
  sz-edit.fth             Interactive keys
  SZ-EDITOR-README.txt    This note

Reference: Legacy/SmallZimmerEditor.fth — DO NOT MODIFY

How to load
-----------
  FLOAD ANEW.fth
  FLOAD SZ-EDITOR.fth     \ full path to Resources/AutoLoad if needed

  Reload after source edits: FLOAD SZ-EDITOR.fth again

Quick test
----------
  CHDIR to a writable folder if needed, then:
  SZ-BUFFER-SMOKE
  SZ-EDIT-SMOKE
    - type text, move with Ctrl-B/F/P/N
    - Ctrl-S save, Ctrl-Q quit

  Or:
  S" /path/to/file.txt" SZ-EDIT-FILE

Editor keys
-----------
  Use the Control key (⌃), NOT the Command/Apple key (⌘).
  ⌘Q quits the whole macOS app; editor quit is ⌃Q.

  Ctrl-S     save to current name
  Ctrl-Q     quit (asks if modified)
  Ctrl-B/F   left / right
  Ctrl-P/N   up / down
  Arrow keys same as Ctrl-B/F/N/P when KEY routing is active
  Enter      newline CRLF
  BS / Del   backspace
  other printable  insert

After quit
----------
  Editor calls FACILITY-OFF and CLS so PAGE/AT-XY mode ends and the
  normal console/menu work again. If the screen keeps clearing, type CLS.

Main words
----------
  SZ-LOAD  SZ-SAVE  SZ-SAVE-AS  SZ-.INFO
  SZ-EDIT  SZ-EDIT-FILE  SZ-EDIT"
  SZ-REDRAW  SZ-VIEW-RESET

Limits
------
  Buffer max 262144 bytes
  Display 80 cols, text rows 1..22
  No color, no dual file yet, no search
