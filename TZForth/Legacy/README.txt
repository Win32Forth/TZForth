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
  under TZForth/AutoLoad/ (later Library/).

The active editor is TZForth/AutoLoad/SZ-EDITOR.fth (and sz-*.fth modules).
