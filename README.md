simple-deodexer
===============

A simple Android application deodexer for Linux & macOS, derived from @dsixda's Android Kitchen.

## Contents

* The deodexer script
* Zipalign binaries for Linux and OS X
* baksmali/smali 2.2.1

## Usage

```bash
$ chmod a+x ./deodex.sh
$ ./deodex.sh -h
  Usage: ./deodex.sh <options>
         e.g. "./deodex.sh -l 19"
  ---------------------------------------------------
  Options:
      -d <dir>   Use <dir> as base directory instead of triage/
      -f <dir>   Only deodex apps in triage/<dir>.
      -g         Display API level list
      -h         Display this help message
      -l <num>   Use API level <num>. REQUIRED!
      -z         Only zipalign apps and exit
```

## Supported Android versions

To check the currently supported versions:

```bash
$ ./deodex -g
```
