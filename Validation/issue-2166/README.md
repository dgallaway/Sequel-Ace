# Issue 2166 validation evidence

The images render the actual `ImageAndTextCell` and `SPTableTextFieldCell` implementations in a small AppKit fixture with invented table names and comments. Before uses the unmodified upstream drawing code; after uses the patch at `2347e612834221cb57b06d27544f38e15342eb89`. These are isolated cell-rendering captures, not screenshots of the full application.

The patched complete app was also built with Xcode 26.6 on a GitHub macOS runner, then launched separately on macOS 26.6.2 (Apple silicon) and connected to a local MariaDB 10.6.22 sample database. Manual checks passed for selection, sidebar resizing, pinned tables, filtering, and empty comments.

The Unit Tests scheme completed 1,407 tests with 64 skipped and zero failures, including all 12 new SATableListCellRendererTests.

- [Unit tests](https://github.com/dgallaway/Sequel-Ace/actions/runs/33882703532)
- [Full app build](https://github.com/dgallaway/Sequel-Ace/actions/runs/33882794189)

This validation directory and the one-off build workflow live only on the fork's validation branch. They are excluded from the upstream fix.
