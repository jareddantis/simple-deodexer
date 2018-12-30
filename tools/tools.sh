##################################
#            Variables           #
##################################
api=0
arch="arm"
aligner=
processDirList=(framework app priv-app vendor/app)
baksmali="$rootDir/tools/baksmali-2.2.2.jar"
smali="$rootDir/tools/smali-2.2.2.jar"
oat2dex="$rootDir/tools/oat2dex.jar"

##################################
#          Help methods          #
##################################
show_help() {
    echo
    echo "Usage: deodex.sh <options>"
    echo "        e.g. \"deodex.sh -l 19\""
    echo "---------------------------------------------------"
    echo "Options:"
    echo "    -d <dir>   Use <dir> as base directory instead of triage/"
    echo "    -f <dir>   Only deodex apps in triage/<dir>."
    echo "    -g         Display API level list"
    echo "    -h         Display this help message"
    echo "    -l <num>   Use API level <num>. REQUIRED!"
    echo "    -z         Only zipalign apps and exit"
    echo
    quit
}

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
    quit
}

##################################
#          Init methods          #
##################################
abort() {
    IFS=$SAVEIFS
    exit 1
}

quit() {
    IFS=$SAVEIFS
    exit 0
}

checkJava() {
    # https://stackoverflow.com/a/7335524/3350320
    if type -p java >/dev/null; then
        _java=java
    elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then 
        _java="$JAVA_HOME/bin/java"
    else
        echo "This script requires Java 1.7 or later to run properly."
        abort
    fi
    if [[ "$_java" ]]; then
        version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
        if [[ "$version" > "1.7" ]]; then
            echo "This script requires Java 1.7 or later to run properly."
            abort
        fi
    fi

    unset version
    unset _java
}

checkZpln() {
    # Set zipalign version
    if [[ $(uname -a | grep -i 'Linux') != "" ]]; then
        aligner="$rootDir/tools/zipalign.linux"
    elif [[ $(uname -a | grep -i 'Darwin') != "" ]]; then
        aligner="$rootDir/tools/zipalign.darwin"
    else
        echo "Error: Unsupported operating system."
        abort
    fi
}

##################################
#          Main methods          #
##################################
zpln() {
    [[ "$2" != "silent" ]] && echo "Zipaligning $1"
    "$aligner" 4 "$1" "$1-temp"
    rm -f "$1"
    mv "$1-temp" "$1"
}

zpln_all() {
    find "$triage" -type f -name '*.apk' | while read apk; do
        zpln $apk
    done
}

deoptBoot() {
    for plat in arm arm64; do
        fwDir="$triage/framework/$plat"
        if [[ -e "$fwDir/boot.oat" ]] && [[ ! -d "$fwDir/odex" ]]; then
            java -Xmx512m -jar "$oat2dex" boot "$fwDir/boot.oat" >> $triage/oat2dex.log
            exitCode=$?

            if [[ "$exitCode" != "0" ]]; then
                echo "- error while deoptimizing framework/$plat/boot.oat"
                echo "  check $triage/oat2dex.log"
                error=1
                exit
            else
                cd $fwDir/odex
                for f in *.dex; do
                    nf="$(echo $f | sed 's/.dex/.odex/')"
                    [[ ! -e "../$nf" ]] && mv $f ../$nf
                done
            fi
            echo "- framework/$plat/boot.oat deoptimized"
        else
            echo "- framework/$plat/boot.oat not found or is already deoptimized"
        fi
    done
}

deodex() {
    baseDir="$1"
    apk="$2"
    odexFile="$3"
    error=0

    echo "- $apk"
    odexName="$(echo $odexFile | sed 's/.odex//')"
    [ "$api" -ge "26" ] && [[ -e "$odexName.vdex" ]] && odexFile="$odexName.vdex"

    if [[ "$api" == "21" ]] || [[ "$api" == "22" ]]; then
        # Convert odex to dex
        odexBase="$(echo $odexName | rev | cut -f1 -d/ | rev)"
        echo "  * deoptimizing $odexFile"
        java -Xmx512m -jar "$oat2dex" $odexFile "$triage/framework/$arch" >> $triage/oat2dex.log
        exitCode=$?

        if [[ "$exitCode" == "0" ]] && [[ -f "$odexName.dex" ]]; then
            mv $odexName.dex classes.dex
            [[ -e "$odexName-classes2.dex" ]] && mv "$odexName-classes2.dex" classes2.dex
            [[ -e "$odexName-classes3.dex" ]] && mv "$odexName-classes3.dex" classes3.dex
        else
            echo "  ! unable to generate classes.dex, check $triage/oat2dex.log"
            [[ -e "$odexName.dex" ]] && rm -f $odexName.dex
            [[ -e "$triage/framework/$odexBase.odex" ]] && rm -f $triage/framework/$odexBase.odex
            error=1
        fi
    else
        # Disassemble odex
        echo "  * baksmaling $odexFile"
        java -Xmx512m -jar "$baksmali" x $odexFile -a $api -d "$bootclasspath"
        exitCode=$?

        # If there were no errors, then assemble classes.dex
        if [ "$exitCode" == "0" ] && [[ -d "out" ]]; then
            echo "  * smaling $odexFile"
            java -Xmx512m -jar "$smali" a -a $api -o classes.dex out
            rm -rf out

            # Ensure classes.dex was produced
            if [[ ! -e "classes.dex" ]]; then
                echo "  ! unable to generate classes.dex"
                error=1
            fi
        else
            echo "  ! unable to decompile $odexFile"
            error=1
        fi
    fi

    if [[ "$error" == "0" ]]; then
        echo "  * zipping classes.dex into apk"
        zip -r -q $apk classes*.dex
        rm -f $odexFile classes*.dex

        extension="$(echo $apk | rev | cut -f1 -d. | rev)"
        if [[ "$extension" == "apk" ]]; then
            echo "  * zipaligning apk"
            zpln $apk silent
        fi
    fi
}

##################################
#         Helper methods         #
##################################
deodexDir() {
    baseDir="$triage/$1"
    cd "$baseDir"

    # Parse directory structure
    if [[ "$1" == "framework" ]]; then
        # Framework folder
        odexCount="$(find . -maxdepth 1 -type f -name '*.odex' | wc -l | tr -d ' ')"
        
        # Determine odex location
        if [[ "$odexCount" == "0" ]]; then
            [[ -d "oat" ]] && plat=3 || plat=2
        else
            plat=1
        fi

        # Deodex framework files first
        for fwFile in *.apk *.jar; do
            odexFile="$(findOdex $fwFile $plat)"
            if [[ "$odexFile" == "false" ]]; then
                echo "- $fwFile: no odex file"
            else
                deodex "$baseDir" "$fwFile" "$odexFile"
            fi
        done

        # Sometimes, the OEM puts extra framework APKs in this folder,
        # so we have to check for them (especially for Android 5.x+ structure)
        apkCount="$(find . -mindepth 2 -name '*.apk' | wc -l | tr -d ' ')"
        if [[ "$apkCount" != "0" ]] && [ "$plat" -gt "1" ]; then
            find . -mindepth 2 -name '*.apk' | while read fw; do
                apkFolder="$(echo $fw | rev | cut -f2- -d/ | rev | sed 's/.\///')"
                apk="$apkFolder.apk"
                cd "$baseDir/$apkFolder"
                odexFile="$(findOdex $apk $plat)"
                if [[ "$odexFile" == "false" ]]; then
                    echo "- $apk: no odex file"
                else
                    deodex "$baseDir" "$apk" "$odexFile"
                fi
            done
        fi
    else
        # App/priv-app folder
        apkCount="$(find . -maxdepth 1 -name '*.apk' | wc -l | tr -d ' ')"

        if [[ "$apkCount" == "0" ]]; then
            # Android 5.x and beyond: apk files are located within subfolders
            for apkFolder in */; do
                cd "$baseDir/$apkFolder"
                apk="$(echo $apkFolder | cut -f1 -d/).apk"
                if [[ -e "$apk" ]]; then
                    [[ -d "oat" ]] && plat=3 || plat=2
                    odexFile="$(findOdex $apk $plat)"
                    if [[ "$odexFile" == "false" ]]; then
                        echo "- $apk: no odex file"
                    else
                        deodex "$baseDir" "$apk" "$odexFile"
                    fi
                else
                    echo "- $apk not found in $apkFolder"
                fi
            done
        else
            # Pre-Android 5.x: apk files are lumped together within the directory
            for apk in *.apk; do
                odexFile="$(findOdex $apk 1)"
                if [[ "$odexFile" == "false" ]]; then
                    echo "- $apk: no odex file"
                else
                    deodex "$baseDir" "$apk" "$odexFile"
                fi
            done
        fi
    fi
}

findOdex() {
    apkName="$(echo $1 | sed 's/.apk//' | sed 's/.jar//')"
    odexFile=

    case $2 in
        1)
            # Pre-Android 5.x: odex file is in same directory
            odexFile="$apkName.odex"
            ;;
        2)
            # Android 5.x: odex file is in <arch> subdirectory
            odexFile="$arch/$apkName.odex"
            ;;
        3)
            # Android 6.x and beyond: odex file is in oat/<arch> subdirectory
            odexFile="oat/$arch/$apkName.odex"
            ;;
    esac

    [[ ! -e "$odexFile" ]] && odexFile="false"
    echo $odexFile
}
