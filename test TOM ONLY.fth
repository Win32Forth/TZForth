
fload debug-bootstrap.fth
TRUE VERBOSE !
VARIABLE cperrors  0 #ERRORS ! fload coreplustest.fth  .( #ERRORS @ = ) #ERRORS @  cperrors !
VARIABLE cerrors  0 #ERRORS ! fload coreexttest.fth .( #ERRORS @ = ) #ERRORS @  cerrors !
VARIABLE derrors  0 #ERRORS ! fload doubletest.fth .( #ERRORS @ = ) #ERRORS @  derrors !
VARIABLE eerrors  0 #ERRORS ! fload exceptiontest.fth .( #ERRORS @ = ) #ERRORS @  eerrors !
VARIABLE ferrors  0 #ERRORS ! fload filetest.fth .( #ERRORS @ = ) #ERRORS @  ferrors !
VARIABLE lerrors  0 #ERRORS ! fload localstest.fth .( #ERRORS @ = ) #ERRORS @  lerrors !
VARIABLE merrors  0 #ERRORS ! fload memorytest.fth .( #ERRORS @ = ) #ERRORS @  merrors !
VARIABLE terrors  0 #ERRORS ! fload toolstest.fth .( #ERRORS @ = ) #ERRORS @  terrors !
VARIABLE soerrors  0 #ERRORS ! fload searchordertest.fth .( #ERRORS @ = ) #ERRORS @  soerrors !
VARIABLE serrors  0 #ERRORS ! fload stringtest.fth .( #ERRORS @ = ) #ERRORS @  serrors !
VARIABLE faerrors  0 #ERRORS ! fload facilitytest.fth .( #ERRORS @ = ) #ERRORS @  faerrors !
VARIABLE berrors  0 #ERRORS ! fload blocktest.fth .( #ERRORS @ = ) #ERRORS @  berrors !
VARIABLE fperrors  0 #ERRORS ! fload fp/runfptests.fth .( #ERRORS @ = ) #ERRORS @  fperrors !

.( CPERRORS @ = ) cperrors @ .
.( CERRORS @ = ) cerrors @ .
.( DERRORS @ = ) derrors @ .
.( EERRORS @ = ) eerrors @ .
.( FERRORS @ = ) ferrors @ .
.( LERRORS @ = ) lerrors @ .
.( MERRORS @ = ) merrors @ .
.( TERRORS @ = ) terrors @ .
.( SOERRORS @ = ) soerrors @ .
.( SERRORS @ = ) serrors @ .
.( FAERRORS @ = ) faerrors @ .
.( BERRORS @ = ) berrors @ .
.( FPERRORS @ = ) fperrors @ .
.( #ERRORS @ = ) #ERRORS @ .
 
File-echo on
 
\s
 
Continue TZForth from session “TZForth — Hayes tests + console fixes”. Float Tier A done; next is Float Ext (FVARIABLE, 0e, F>D, …). Repo is pushed at 284239e. Do not edit test.fth. 


FORK Instructions

Your goal maps cleanly to /fork — that is the built-in “duplicate this session, then go somewhere else” command.

What /fork does

It creates a new session that is a copy of everything up to this point (full conversation, tool history, context). The original session stays unchanged. You can switch between them later with /dashboard or /resume.

What to run (from this chat)

1. Rename this session first (optional but useful):

/rename TZForth — Hayes + console fixes (archive)

2. Fork into a new session with your new direction:

/fork --no-worktree New project: <short name>. Same stack/patterns as TZForth (Swift Forth host, Hayes-style testing, sandbox FLOAD, etc.) but NOT fixing TZForth. Goal: <what you actually want to build>. Working directory: <path to new project>.

Use --no-worktree unless you want a separate git worktree copy of TZForth. For a different repo/project, --no-worktree is usually right.

If prompted about worktree, choose no — you are branching the conversation, not cloning the TZForth tree.

3. Rename the fork:

/rename <New project name> — from TZForth session

After the fork

┌─────────────────────────────┬──────────────────────────────────────┐
│ Session                     │ Use for                              │
├─────────────────────────────┼──────────────────────────────────────┤
│ Original (archived TZForth) │ Resume TZForth later with /resume    │
├─────────────────────────────┼──────────────────────────────────────┤
│ Fork                        │ Your new, similar-but-different work │
└─────────────────────────────┴──────────────────────────────────────┘

Switch between active sessions:

/dashboard

(alias: /sessions)

Important nuance

The fork carries the full TZForth thread, not just a summary. That is good for “we already solved FLOAD line numbers, cwd restore, console caret…” but it also uses context window. On the fork’s first message, you can add:

Treat TZForth history as background only. Primary task is \<new goal\>. Do not modify TZForth unless I ask.

If the new work is a totally different folder

After forking, chdir / open that project in the IDE and tell the fork:

Work in <path>. Read its README / structure first. Ignore TZForth repo except as reference.

───

Short version: /fork --no-worktree + a directive describing the new project is the duplicate-and-redirect path. The one-line paste prompt I gave earlier is only a lightweight fallback when you cannot resume or fork.