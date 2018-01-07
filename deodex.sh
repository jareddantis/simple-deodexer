#!/bin/bash
SAVEIFS=$IFS
IFS=$'\n'
rootDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
triage="$rootDir/triage"

# Initialize
chmod -R a+x "$rootDir/tools"
source "$rootDir/tools/tools.sh"
checkJava
checkZpln

# Parse options
while getopts "d:hgzl:f:" opt; do
    case "$opt" in
        d)
            if [[ ! -d "$OPTARG" ]]; then
                echo "Error: Folder \"$OPTARG\" does not exist"
                abort
            fi
            triage="$OPTARG"
            ;;
        f)
            processDir="$triage/$OPTARG"
            if [[ -d "$processDir" ]]; then
                odexCount="$(find $processDir -type f -name '*.odex' | wc -l | tr -d ' ')"
                if [[ "$odexCount" == "0" ]]; then
                    echo "Error: No odex files found in $OPTARG."
                    abort
                fi
                processDirList=("$OPTARG")
            else
                echo "Error: $triage/$OPTARG does not exist."
                abort
            fi
            ;;
        h)
            show_help
            ;;
        g)
            show_api
            ;;
        z)
            zpln_all
            ;;
        l)
            api="$OPTARG"
            ;;
        \?)
            echo "Error: Invalid option -$OPTARG."
            echo
            show_help
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument."
            echo
            show_help
            ;;
    esac
done

# Build bootclasspath
[[ $api == 0 ]] && echo "Error: Please specify a valid API level." && abort
if [ "$api" -lt "20" ]; then
    bootclasspath="$triage/framework"
    echo "Please remember to copy your bootclass files to $triage/framework!"
elif [[ "$api" == "21" ]] || [[ "$api" == "22" ]]; then
    echo "Sorry, Lollipop apps cannot be deodexed (unsupported oat version 45)."
    quit
else
    [ -d "$triage/framework/arm64" ] && arch="arm64" || arch="arm"
    bootclasspath="$triage/framework/$arch"
    echo "Please remember to copy /system/framework/$arch to $triage/framework!"
fi

# Begin
for folder in ${processDirList[@]}; do
    baseDir="$triage/$folder"
    odexCount="$(find $baseDir -type f -name '*.odex' | wc -l | tr -d ' ')"

    if [[ "$odexCount" == "0" ]]; then
        echo "No apps to deodex in /$folder"
    else
        echo -e "\nDeodexing files in /$folder"
        deodexDir "$folder"
    fi
done

quit
