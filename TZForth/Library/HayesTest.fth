\ HayesTest.fth — John Hayes forth2012-test-suite full driver (in-app)
\
\ Canonical run (bundled under Resources/Library):
\   FROMLIB FLOAD HayesTest.fth
\
\ Or after entering Library as cwd:
\   FROMLIB CHDIR .
\   FLOAD HayesTest.fth
\
\ 1) prepare-blocks.fth — USE-BLOCK-FILE a *writable* .blk under
\    Application Support (bundle Resources/Library is read-only; FLUSH would
\    fail on HayesTest/src/blocks.blk).
\ 2) test.fth — full suite; nested FLOAD sets logical cwd to HayesTest/src/
\    so relative names (core*.fth, fp/runfptests.fth, …) resolve.
\
\ Pass criteria: HayesTest/src/test.fth and HayesTest/src/HAYES-RESULTS.txt.
\ Docs: HayesTest/README.md, HayesTest/doc/, HayesTest/prelimtest.md

FLOAD HayesTest/src/prepare-blocks.fth
FLOAD HayesTest/src/test.fth
