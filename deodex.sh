#!/bin/bash
SAVEIFS=$IFS
IFS=$'\n'
rootdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
chmod 0755 $rootdir/tools/*

# Variables
sysApp=0
privApp=0
framework=0
bootclass=
api=0
processDirList=0
custom=0
triage="$rootdir/triage"

# Set zipalign version
if [[ $(uname -a | grep -i 'Linux') != "" ]]; then
    aligner="$rootdir/tools/zipalign.linux"
elif [[ $(uname -a | grep -i 'Darwin') != "" ]]; then
    aligner="$rootdir/tools/zipalign.osx"
else
    echo "Error: Unsupported operating system."
    exit 1
fi

# Check Java - http://stackoverflow.com/questions/7334754/correct-way-to-check-java-version-from-bash-script
if type -p java >/dev/null; then
    _java=java
elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then 
    _java="$JAVA_HOME/bin/java"
else
    echo "This script requires Java 1.7 or later to run properly."
    exit 1
fi
if [[ "$_java" ]]; then
    version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    if [[ "$version" < "1.7" ]]; then
        echo "This script requires Java 1.7 or later to run properly."
        exit 1
    fi
fi

show_api() {
    echo
    echo "Android Version    API Level     Codename"
    echo "--------------------------------------------------------"
    echo "8.0.x                 26         Oreo"
    echo "7.1.x                 25         Nougat"
    echo "7.0.x                 24"
    echo "6.0.x                 23         Marshmallow"
    echo "5.1 - 5.1.1           22         Lollipop"
    echo "5.0 - 5.0.2           21"
    echo "4.4W.x                20         KitKat for Android Wear"
    echo "4.4.x                 19         KitKat"
    echo "4.3.x                 18         Jellybean"
    echo "4.2 - 4.2.2           17"
    echo "4.1 - 4.1.1           16"
    echo "4.0.3 - 4.0.4         15         Ice Cream Sandwich"
    echo "4.0 - 4.0.2           14"
    echo "3.2                   13         Honeycomb"
    echo "3.1.x                 12"
    echo "3.0.x                 11"
    echo "2.3.3 - 2.3.7         10         Gingerbread"
    echo "2.3 - 2.3.2           9"
    echo "2.2 - 2.2.3           8          Froyo"
    echo "2.1                   7          Éclair"
    echo "2.0.1                 6"
    echo "2.0                   5"
    echo "1.6                   4          Donut"
    echo "1.5                   3          Cupcake"
    echo "1.1                   2          N/A"
    echo "1.0                   1          N/A"
    echo
}

show_help() {
    echo
    echo "Usage: `basename $0` <options>"
    echo "        e.g. \"`basename $0` -l 19\""
    echo "---------------------------------------------------"
    echo "Options:"
    echo "    -d <dir>   Use <dir> as base directory instead of triage/"
    echo "    -f <dir>   Only deodex apps in triage/<dir>."
    echo "    -g         Display API level list"
    echo "    -h         Display this help message"
    echo "    -l <num>   Use API level <num>. REQUIRED!"
    echo "    -z         Only zipalign apps and exit"
    echo
}

build_list() {
    if [[ $sysApp == 1 ]]; then
        if [[ $privApp == 1 ]]; then
            if [[ $framework == 1 ]]; then
                processDirList=(app priv-app framework)
            else
                processDirList=(app priv-app)
            fi
        else
            if [[ $framework == 1 ]]; then
                processDirList=(app framework)
            else
                processDirList=(app)
            fi
        fi
    elif [[ $privApp == 1 ]]; then
        if [[ $framework == 1 ]]; then
            processDirList=(priv-app framework)
        else
            processDirList=(priv-app)
        fi
    elif [[ $framework == 1 ]]; then
        processDirList=(framework)
    else
        processDirList=0
    fi
}

count_odex() {
    cd "$triage/$1"
    count="$(ls -1 *.odex 2>/dev/null | wc -l | sed 's/       //')"
    if [[ $count != 0 ]]; then
        for f in *.odex; do
            count=$((count+1))
        done
    else
        count=0
    fi
    echo $count
}

zpln() {
    "$aligner" 4 "$1" "$1-temp"
    rm -f "$1"
    mv "$1-temp" "$1"
}

zpln_all() {
    build_list
    if [[ $processDirList == 0 ]]; then
        echo "No apps to zipalign."
        exit 0
    fi

    cd $triage
    for i in ${processDirList[@]}; do
        cd "$i"
        for j in *.apk; do
            echo "Zipaligning $i/$j"
            zpln $f
        done
        cd ../
    done
}

deodex() {
    odex_file=$1

    if [[ -e $odex_file ]];  then
        odex_no_ext=$(echo $odex_file | sed 's/.odex//')
        if [ "$api" -ge "26" ] && [[ ! -e "$odex_no_ext.vdex" ]]; then
            echo "[*] Error: $odex_file exists, but $odex_no_ext.vdex doesn't"
            exit 1
        else
            if [[ -e "$odex_no_ext.apk" ]] || [[ -e "$odex_no_ext.jar" ]]; then
                echo "Processing $odex_file"
            else
                echo "[*] Error: $odex_no_ext.odex exists, but $odex_no_ext.apk doesn't"
                exit 1
            fi
        fi
    else
        echo "[*] Error: Invalid file \"$odex_file\""
        exit 1
    fi
    
    # Call baksmali
    java -Xmx512m -jar "$rootdir/tools/baksmali.jar" x $odex_file -a $api "${bootclass[@]}"
    is_error=$?

    # If there were no errors, then assemble it with smali
    if [ "$is_error" == "0" ] && [ -d out ]; then
        java -Xmx512m -jar "$rootdir/tools/smali.jar" a -a $api -o classes.dex out
        rm -rf out

        # Ensure classes.dex was produced
        if [[ -e "classes.dex" ]]; then
            # Ensure the .odex file's .apk or .jar is found
            no_ext=$(echo $odex_file | sed 's/.odex//')
            main_file=$no_ext.apk
            error_found=0

            if [[ -e $main_file ]];then
                ext=apk
            else
                main_file=$no_ext.jar
              
                if [[ -e $main_file ]]; then
                    ext=jar
                else          
                    echo "[*] Error: $no_ext.jar or $no_ext.apk unexpectedly removed!"
                    error_found=1
                fi
            fi

            if [[ $error_found == 1 ]]; then
                rm -f classes.dex
            else
                rm -f $odex_file
                zip -r -q $main_file classes.dex
                rm -f classes.dex
                if [[ ! -e $main_file ]]; then
                    echo "[*] Error: $no_ext.jar or $no_ext.apk unexpectedly removed!"
                fi    
            fi
        else
            echo "[*] Error: unable to generate classes.dex!"
        fi
    else
        echo ""
        rm -rf out
    fi
}

getfullpath() {
    if [[ $(uname -a | grep -i 'Linux') != "" ]]; then
        echo $(readlink -f "$1")
    elif [[ $(uname -a | grep -i 'Darwin') != "" ]] && [[ $(which greadlink) != "" ]]; then
        echo $(greadlink -f "$1")
    else
        echo $(cd $(dirname "$1") && pwd -P)/$(basename "$1")
    fi
}

while getopts "d:hgzl:f:" opt; do
    case "$opt" in
        d)
            newdir="$(getfullpath $OPTARG)"
            if [[ -d "$newdir" ]]; then
                triage="$newdir"
            else
                echo "Folder \"$OPTARG\" does not exist, defaulting to $rootdir/triage".
            fi
            ;;
        f)
            custom=1
            if [[ -d "$triage/$OPTARG" ]] && [[ "$(count_odex $OPTARG)" != 0 ]]; then
                processDirList=("$OPTARG")
            else
                echo "Invalid folder \"$OPTARG\" specified."
                exit 1
            fi
            ;;
        h)
            show_help
            exit 0
            ;;
        g)
            show_api
            exit 0
            ;;
        z)
            if [[ -d "$triage/app" ]] && [[ "$(count_odex app)" != 0 ]]; then sysApp=1; fi
            if [[ -d "$triage/priv-app" ]] && [[ "$(count_odex priv-app)" != 0 ]]; then privApp=1; fi
            if [[ -d "$triage/framework" ]] && [[ "$(count_odex framework)" != 0 ]]; then framework=1; fi
            zpln_all
            IFS=$SAVEIFS
            exit 0
            ;;
        l)
            api="$OPTARG"
            ;;
        \?)
            echo "Invalid option -\"$OPTARG\"."
            echo
            show_help
            exit 1
            ;;
        :)
            echo "Option -\"$OPTARG\" requires an argument."
            echo
            show_help
            exit 1
            ;;
    esac
done

# Check for apps to deodex
if [[ $custom == 0 ]]; then
    if [[ -d "$triage/app" ]] && [[ "$(count_odex app)" != 0 ]]; then sysApp=1; fi
    if [[ -d "$triage/priv-app" ]] && [[ "$(count_odex priv-app)" != 0 ]]; then privApp=1; fi
    if [[ -d "$triage/framework" ]] && [[ "$(count_odex framework)" != 0 ]]; then framework=1; fi
    build_list
    if [[ $processDirList == 0 ]]; then
        echo "No apps to deodex."
        exit 0
    else
        # Check for valid API level
        if [[ $api == 0 ]]; then
            echo "Error: Please specify a valid API level."
            show_help
            exit 0
        fi

        # Build bootclasspath
        if [ "$api" -lt "20" ]; then
            bootclass=("-d" "../framework")
            echo "Please remember to copy your bootclass files to $triage/framework!"
        elif [ "$api" -ge "20" ] && [ "$api" -le "23" ]; then
            bootclass=("-b" "../framework/boot.oat")
            echo "Please remember to copy your boot.oat to $triage/framework!"
        else
            [ -d "$triage/framework/arm64" ] && bootclass=("-d" "../framework/arm64") || bootclass=("-d" "../framework/arm")
            echo "Please remember to copy /system/framework/arm* to $triage/framework!"
        fi

        if [[ $sysApp == 1 ]] || [[ $privApp == 1 ]]; then
            if [[ ! -d "$triage/framework" ]]; then
                echo "Error: Framework files must be present when deodexing apps."
            fi
        fi

        for f in ${processDirList[@]}; do
            echo "$(count_odex $f) odex files are in /$f."
        done
    fi
fi

# Deodex!
for processDir in ${processDirList[@]}; do
    echo -e "\nDeodexing files in /$processDir"
    echo "-------------------------"
    cd "$triage/$processDir"
    for f in *.odex; do
        deodex $f
    done
    echo "Zipaligning apps"
    for d in *.apk; do
        zpln $d
    done
done

echo -e "\nDone."
IFS=$SAVEIFS
exit 0
