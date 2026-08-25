# Packaging

Reference PKGBUILD for installing OmaBoard system-wide (`/usr/bin` plus data in `/usr/share/omaboard`) instead of running it from a repo clone. Local install: `makepkg -fi` from this directory. If OmaBoard lands in the Omarchy package repo upstream, this file is the starting point — note the packaged launcher points `qs -p` at `/usr/share/omaboard`, unlike the dev launcher in `bin/`.
