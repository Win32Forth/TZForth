\ SZ-EDITOR.fth — Small Zimmer Editor for TZForth (port driver)
\
\ Phases 1-4: host, buffer, mono screen, minimal interactive edit.
\ Reference (read-only): Legacy/SmallZimmerEditor.fth
\
\ Load (from Resources/Library):
\   FROMLIB FLOAD Editor/SZ-EDITOR.fth
\
\ Try:
\   SZ-HOST-SMOKE
\   SZ-BUFFER-SMOKE
\   SZ-SCREEN-SMOKE
\   SZ-EDIT-SMOKE
\   S" my.txt" SZ-EDIT-FILE
\
\ Keys in editor: ^S save  ^Q quit  ^B^F left/right  ^P^N up/down
\                 type to insert  Enter newline  BS delete
\
\ Nested modules: named FLOAD chdirs to this file's folder (Editor/), so
\ sibling names need no Editor/ prefix.

ANEW SZ-EDITOR

FLOAD sz-host.fth
FLOAD sz-buffer.fth
FLOAD sz-screen.fth
FLOAD sz-edit.fth

: SZ-BANNER  ( -- )
   CR
   .( === SZ-EDITOR TZForth port ===) CR
   .( Phases 1-5: edit + navigation + framed screen) CR
   .( SZ-BUFFER-SMOKE  SZ-EDIT-SMOKE  or  S" file" SZ-EDIT-FILE) CR
   .( Keys: ^S save ^Q quit  arrows  Home/End  ^Home/^End  PgUp/Dn  BS Del type) CR
   .( Note: use Control key, not Command/Apple key) CR
   CR
;

SZ-BANNER
