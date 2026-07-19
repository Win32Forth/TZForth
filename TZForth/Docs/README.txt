TZForth Docs (Resources/docs)
=============================

Rich Text (.rtf) copies of the repository root Markdown manuals, for viewing
in TextEdit (or any RTF-capable app). The .app cannot write these files;
edit the source .md files in the git repo, then regenerate:

  cd /path/to/TZForth-repo
  textutil -convert rtf -inputencoding UTF-8 -output TZForth/Docs/README.rtf README.md
  textutil -convert rtf -inputencoding UTF-8 -output TZForth/Docs/ANS_COMPLIANCE.rtf ANS_COMPLIANCE.md
  textutil -convert rtf -inputencoding UTF-8 -output TZForth/Docs/THROW_CODES.rtf THROW_CODES.md

Build: Copy Docs phase → YourApp.app/Contents/Resources/docs/

  README.rtf           Project overview (from README.md)
  ANS_COMPLIANCE.rtf   ANS word-set notes (from ANS_COMPLIANCE.md)
  THROW_CODES.rtf      Exception / throw codes (from THROW_CODES.md)
  README.txt           This note

Tools → DOCS → VIEW Documents Folder opens Resources/docs in Finder.
