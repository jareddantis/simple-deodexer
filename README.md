simple-deodexer
===============

## What is it?

A simple deodexer for Linux, derived from @dsixda's Android Kitchen.
I made this mainly because I never had luck downloading GitHub files
over my connection, and Android Kitchen (~27 MB) took too long to download.
So I just looked at the code I needed online and adapted it for standalone use.

## What's included?

* The deodexer script
* Zipalign binaries for Linux and OS X
* baksmali/smali 2.1.0

## How do I use it?

1. Make sure `deodex.sh` has been `chmod`ded to `0755`.
2. Put your apps in their respective folders in triage. (triage/app, triage/framework, triage/priv-app)
3. Run `./deodex.sh <options>`.
4. If you need help, run `./deodex.sh -h`.
