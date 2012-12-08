# pk3check

Badly written perl script to determine local files overwriting core warsow
(should work for other quake games too though) files.

The script requires Archive::Zip which can be installed from cpan.

## Options

* install-dir: path to the game's installation directory.
* personal-dir: path to your personal game directory.
* coremod: the game's default mod name.
* pure-only: only check files from pure core pk3 files.
* packed-only: only check files from core pk3 files.
* strip: strip wrong files from personal pk3 files.
* rename-suffix: extra suffix for stripped pk3 files (before the dot-suffix,
  the old file will still be deleted though).
* delete: delete wrong files.
* full-delete: delete wrong files and pk3 files containing wrong files.
* backup: backup changed or removed files by appending this suffix.
