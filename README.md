simple-deodexer
===============

# What is it?

A simple deodexer for Linux, derived from @dsixda's Android Kitchen.
I made this mainly because I never had luck downloading GitHub files
over my connection, and Android Kitchen (~27 MB) took too long to download.
So I just looked at the code I needed online and adapted it for standalone use.

# What's included?

* A deodex script, help scripts, and a script for changing `baksmali/smali` version
* Zipalign
* Multiple versions of `smali` and `baksmali`

# How do I use it?

1. Make sure `deodex.sh` has been `chmod`ded to `0755`.
2. Run `./deodex.sh <option> <API level>`. Options are as follows:
* `-a` = Deodex apps
* `-b` = Deodex both apps and frameworks
* `-bb` = Deodex apps, frameworks, and priv-apps
* `-p` = Deodex priv-apps
* `-f` = Deodex frameworks
* `-h` = Display this help message
* `-hh` = Display the Android version <> API level guide
* `-j` = Change baksmali/smali version
* `-x` = Cleanup (delete all files in triage)
* `-z` = Zipalign APKs in app, priv-app, and framework
* `-zz` = Zipalign APKs in app
* `-zzz` = Zipalign APKs in framework
* `-zzzz` = Zipalign APKs in priv-app

# Is it okay if I make pull requests to this repo?

Yes! I will gladly accept bugfixes and other improvements, but keep in mind
that I will review each commit being pull-requested first. ;)