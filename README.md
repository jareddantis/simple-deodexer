simple-deodexer
===============

A simple Android application deodexer for Linux & macOS.

## Includes

* zipalign binaries for Linux and macOS (from android build-tools 27.0.2)
* baksmali/smali 2.2.2
* oat2dex 0.88

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

Android 8.0 and below are currently supported. (7.1.x and below have been tested.)

To check the currently supported versions:

```bash
$ ./deodex -g
```
