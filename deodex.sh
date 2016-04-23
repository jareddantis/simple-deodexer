#!/bin/bash
rootdir=$(pwd)
chmod 0755 tools/*
SAVEIFS=$IFS
IFS=$'\n'

sysApp=0
privApp=0
framework=0
bootclass=
api=0
processDirList=0
custom=0

if [[ $(uname -a | grep -i 'Linux') != "" ]]; then
	aligner="$rootdir/tools/zipalign.linux"
elif [[ $(uname -a | grep -i 'Darwin') != "" ]]; then
	aligner="$rootdir/tools/zipalign.osx"
else
	echo "Error: Unsupported operating system."
	exit 1
fi
chmod +x $aligner

if [ ! -d triage ]; then
	mkdir triage
	cd triage
	touch put_apps_here
	cd ../
fi

show_api() {
	echo
	echo "Android Version    API Level     Codename"
	echo "--------------------------------------------------------"
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
	echo "    -b <file>  Use bootclass tools/<file>"
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
	cd "triage/$1"
	existence=`ls -l *.odex 2>/dev/null | wc -l`
	if [ $existence != 0 ]; then
		for f in $(ls *.odex); do
			count=$(($count+1))
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

	cd triage
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
	echo
	odex_file=$1

	if [ "$odex_file" == "" ]; then
		echo "Error: No .odex file specified"
	elif [ -e $odex_file ];  then
	  	echo "Working on $odex_file"
	  	echo "- Disassembling $odex_file"
	else
	  	echo "Error: $odex_file not found"
	fi
	
	# Call baksmali
	if [[ "$bootclass" != "" ]]; then    # Call baksmali with bootclasspath
		java -Xmx512m -jar ../../tools/baksmali.jar -a $api -d ../framework -c $bootclass -x $odex_file
		is_error=$?
	else     # No bootclasspath
		java -Xmx512m -jar ../../tools/baksmali.jar -a $api -d ../framework -x $odex_file
		is_error=$?
	fi

	# If there were no errors, then assemble it with smali
	if [ "$is_error" == "0" ] && [ -d out ]; then
		echo "- Assembling into classes.dex"
		java -Xmx512m -jar ../../tools/smali.jar -a $api -o classes.dex out
	  	rm -rf out

		# Ensure classes.dex was produced
		if [ -e classes.dex ]; then
			# Ensure the .odex file's .apk or .jar is found
			no_ext=`echo $odex_file | sed 's/.odex//'`
			main_file=$no_ext.apk
			error_found=no

			if [ -e $main_file ];then
				ext=apk
			else
				main_file=$no_ext.jar
			  
				if [ -e $main_file ]; then
					ext=jar
				else          
					echo "ERROR: Can't find $no_ext.jar or $no_ext.apk"
					error_found=yes
			  	fi
			fi

			if [ $error_found == yes ]; then
			  	echo "- Removing classes.dex"
			  	rm -f classes.dex
			else
			  	echo "- Removing $odex_file"
			  	rm -f $odex_file

			  	echo "- Putting classes.dex into $main_file"
			  	zip -r -q $main_file classes.dex
			  	rm -f classes.dex
			  	if [ -e $main_file ]; then
					echo "$main_file has been deodexed"
			  	fi	
			fi
	  	else
			echo "WARNING: Unable to produce classes.dex!"
	  	fi
	else
	  echo "WARNING: Cannot deodex $odex_file"
	  rm -rf out
	fi
}

while getopts "b:hgzl:f:" opt; do
	case "$opt" in
		b)
			bootclass="$rootdir/tools/$OPTARG"
			;;
		f)
			custom=1
			if [[ -d "triage/$OPTARG" ]] && [[ "$(count_odex $OPTARG)" != 0 ]]; then
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
			if [[ -d "triage/app" ]] && [[ "$(count_odex app)" != 0 ]]; then sysApp=1; fi
			if [[ -d "triage/priv-app" ]] && [[ "$(count_odex priv-app)" != 0 ]]; then privApp=1; fi
			if [[ -d "triage/framework" ]] && [[ "$(count_odex framework)" != 0 ]]; then framework=1; fi
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
	if [[ -d "triage/app" ]] && [[ "$(count_odex app)" != 0 ]]; then sysApp=1; fi
	if [[ -d "triage/priv-app" ]] && [[ "$(count_odex priv-app)" != 0 ]]; then privApp=1; fi
	if [[ -d "triage/framework" ]] && [[ "$(count_odex framework)" != 0 ]]; then framework=1; fi
	build_list
	if [[ $processDirList == 0 ]]; then
		echo "No apps to deodex."
		exit 0
	fi
fi

# Check for valid API level
if [[ $api == 0 ]]; then
	echo "Error: Please specify a valid API level."
	show_help
	exit 0
fi

# Deodex!
for processDir in ${processDirList[@]}; do
	echo ""
	echo "Entering $processDir"
	echo "************************"
	cd "$rootdir/triage/$processDir"
	for f in *.odex; do
		deodex $f
	done
	echo "Zipaligning APKs"
	for d in *.apk; do
		zpln $d
	done
done

echo "Done."
IFS=$SAVEIFS
exit 0
