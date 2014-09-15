#!/bin/bash

if [[ $1 = "1" ]]; then
	echo "ERROR: API level not specified."
elif [[ $1 == "2" ]]; then
	echo "ERROR: Invalid option \"$2\"."
elif [[ $1 == "3" ]]; then
	echo "ERROR: No parameters specified."
elif [[ $1 == "4" ]]; then
	echo "ERROR: No options specified."
fi

echo
echo "Usage: deodex <options> <API level>"
echo "------------------------------------"
echo "Options:"
echo "    -a       Deodex apps"
echo "    -b       Deodex both apps and frameworks"
echo "    -bb      Deodex apps, frameworks, and priv-apps"
echo "    -p       Deodex priv-apps"
echo "    -f       Deodex frameworks"

echo "    -h       Display this help message"
echo "    -hh      Display the Android version <> API level guide"

echo "    -j       Change baksmali/smali version (currently $(cat tools/version.txt))"
echo "    -x       Cleanup (delete all files in triage)"

echo "    -z       Zipalign APKs in app, priv-app, and framework"
echo "    -zz      Zipalign APKs in app"
echo "    -zzz     Zipalign APKs in framework"
echo "    -zzzz    Zipalign APKs in priv-app"
echo ""
exit 0
