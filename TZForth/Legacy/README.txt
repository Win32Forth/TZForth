Legacy sources (read-only references)
====================================

Shipped in the app at:

  YourApp.app/Contents/Resources/Legacy/

via the Xcode "Copy Legacy" Run Script phase (same pattern as AutoLoad /
Library / Docs). In the Xcode project this folder lives at:

  TZForth/Legacy/

SmallZimmerEditor.fth
  Original F-PC / TCOM "Small Zimmer's Editor" by Tom Zimmer (public domain).
  Kept for reference while porting to TZForth as SZ-EDITOR.

  DO NOT MODIFY this file for the port — work only in the new SZ-* modules
  under TZForth/Library/Editor/.

The active editor is:

  TZForth/Library/Editor/SZ-EDITOR.fth
  (and sibling sz-host / sz-buffer / sz-screen / sz-edit modules)

Load at runtime:

  FROMLIB FLOAD Editor/SZ-EDITOR.fth
