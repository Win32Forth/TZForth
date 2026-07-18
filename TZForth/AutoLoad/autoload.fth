\ autoload.fth — product boot (lowercase name required)

\ .( Hi, this is a demo autoload.fth that does pretty much nothing.) CR

\ Required: define MAIN so the host can start the app after load.
: APP-RUN  ( -- )
\   .( AutoLoad APP-RUN finished.) CR
  ;

: MAIN  ( -- )
  ['] APP-RUN CATCH
  ?DUP IF
    .( AutoLoad MAIN: exception ) CR
    .ERROR CR
  THEN
  ;
