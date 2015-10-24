#!/bin/bash
rootdir=$(pwd)
chmod 0755 tools/*
SAVEIFS=$IFS
IFS=$'\n'

if [[ $(uname -p) == "x86_64" ]] && [[ $(which lsb_release) != "" ]]; then
	if [[ $(dpkg -l | grep 'libc6-i386') == "" ]] || [[ $(dpkg -l | grep 'ia32-libs') == "" ]]; then
		if [[ $(lsb_release -r | cut -f 2 | sed -r 's/.{3}$//') -ge "13" ]]; then
			if [[ $(lsb_release -r | cut -f 2 | sed -r 's/.{3}$//') == "13" ]] && [[ $(lsb_release -r | cut -f 2 | sed -r 's/^.{3}//') == "04" ]]; then
				echo "ERROR: This script requires 32-bit compatibility packages."
				echo "To install them, type \"sudo apt-get install ia32-libs\"."
			else
				echo "ERROR: This script requires 32-bit compatibility packages."
				echo "To install them, type:"
				echo "\"sudo apt-get install lib32gcc1 libc6-i386 lib32z1 lib32stdc++6 lib32bz2-1.0 lib32ncurses5\"."
			fi
		else
			echo "ERROR: This script requires 32-bit compatibility packages."
			echo "To install them, type \"sudo apt-get install ia32-libs\"."
		fi
	else
		aligner="tools/zipalign.linux"
	fi
	exit 1
elif [[ $(uname -a | grep -i 'Darwin') != "" ]]; then
	aligner="tools/zipalign.osx"
else
	aligner="tools/zipalign.linux"
fi
chmod +x $aligner

showhelp() {
	echo ""
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
	echo "Usage: `basename $0` <options> <API level> [bootclasspath]"
	echo "        e.g. \"`basename $0` -a 19 :java.obex.jar\""
	echo "---------------------------------------------------"
	echo "Options:"
	echo "    -a       Deodex apps"
	echo "    -b       Deodex all APKs"
	echo "    -p       Deodex priv-apps"
	echo "    -f       Deodex frameworks"

	echo "    -h       Display this help message"
	echo "    -hh      Display the Android version <> API level guide"

	echo "    -x       Cleanup (delete all files in triage)"

	echo "    -z       Zipalign APKs in all folders"
	echo "    -zz      Zipalign APKs in app"
	echo "    -zzz     Zipalign APKs in framework"
	echo "    -zzzz    Zipalign APKs in priv-app"
	echo ""
	exit 0
}

if [ ! -d triage ]; then
	mkdir triage
	cd triage
	mkdir app
	mkdir framework
	mkdir priv-app
	cd ../
fi

if [[ ! $1 ]] && [[ ! $2 ]]; then
	showhelp 3
	exit 0
fi

zpln() {
	$rootdir/$aligner 4 $1 $1-temp
	rm -f $1
	mv $1-temp $1
}

deodex_file() {
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
		java -Xmx512m -jar ../../tools/baksmali.jar -a $api_level -d ../framework -c $bootclass -x $odex_file
		is_error=$?
	else     # No bootclasspath
		java -Xmx512m -jar ../../tools/baksmali.jar -a $api_level -d ../framework -x $odex_file
		is_error=$?
	fi

	# If there were no errors, then assemble it with smali
	if [ "$is_error" == "0" ] && [ -d out ]; then
		echo "- Assembling into classes.dex"
		java -Xmx512m -jar ../../tools/smali.jar -a $api_level -o classes.dex out
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

count_odex() {
	cd triage/$1

	existence=`ls -1 *.odex 2>/dev/null | wc -l`
	if [ $existence != 0 ]; then
		for f in $(ls *.odex); do
			count=$(($count+1))
		done
	else
		count=0
	fi
	echo $count
}

apiguide() {
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

if [[ ! $1 == "" ]]; then
	# Help
	if [ $1 == "-h" ]; then
		showhelp
		exit 0
	# Deodex
	elif [ $1 == "-a" ]; then
		processDirList=(app)
		printf '\033c'
		echo "$(count_odex app) odex files are in /app."
	elif [ $1 == "-b" ]; then
		processDirList=(app framework)
		printf '\033c'
		echo "$(count_odex app) odex files are in /app."
		echo "$(count_odex framework) odex files are in /framework."
		if [ -d triage/priv-app ]; then
			existence2=`ls -1 triage/priv-app/*.apk 2>/dev/null | wc -l`
			if [ $existence2 != 0 ]; then
				processDirList=(app framework priv-app)
			fi
		fi
	elif [ $1 == "-f" ]; then
		processDirList=(framework)
		printf '\033c'
		echo "$(count_odex framework) odex files are in /framework."
		cp tools/java.awt.jar triage/framework/java.awt.jar
	elif [ $1 == "-p" ]; then
		processDirList=(priv-app)
		printf '\033c'
		echo "$(count_odex priv-app) odex files are in /priv-app."
	elif [ $1 == "-x" ]; then
		printf '\033c'
		echo "Cleaning up"
		echo "- app"
		rm -fR triage/app
		mkdir triage/app
		echo "- framework"
		rm -fR triage/framework
		mkdir triage/framework
		echo "- priv-app"
		rm -fR triage/priv-app
		mkdir triage/priv-app
		echo "Done."
		exit 0
	# Zipalign options
	elif [ $1 == "-z" ]; then
		printf '\033c'
		processDirList=(app framework)
		if [ -d triage/priv-app ]; then
			existence2=`ls -1 triage/priv-app/*.apk 2>/dev/null | wc -l`
			if [ $existence2 != 0 ]; then
				processDirList=(app framework priv-app)
			fi
		fi
		
		for processDir in ${processDirList[@]}; do
			cd triage/$processDir
			for f in $(ls *.apk); do
				echo "Zipaligning $f"
				zpln $f
			done
		done
	elif [ $1 == "-zz" ]; then
		printf '\033c'
		cd triage/app
		for f in $(ls *.apk); do
			echo "Zipaligning $f"
			zpln $f
		done
	elif [ $1 == "-zzz" ]; then
		printf '\033c'
		cd triage/framework
		for f in $(ls *.apk); do
			echo "Zipaligning $f"
			zpln $f
		done
	elif [ $1 == "-zzzz" ]; then
		printf '\033c'
		cd triage/priv-app
		for f in $(ls *.apk); do
			echo "Zipaligning $f"
			zpln $f
		done
	fi
# No option specified
elif [[ ! $1 ]] && [[ $2 != "" ]]; then
	showhelp 4
# Other error
else
	showhelp 2 $1
	exit 0
fi
# Show API level guide
if [[ ! $2 ]] && [ $1 == "-hh" ]; then
	apiguide
	exit 0
elif [[ ! $2 ]] && [[ $1 != "" ]] && [ ! $(echo $1 | grep 'z') ]; then
	showhelp 1
	exit 0
else
	api_level=$2
fi

# Process
if [[ "$3" != "" ]]; then
	bootclass="$3"
fi
for processDir in ${processDirList[@]}; do
	echo ""
	echo "Entering $processDir"
	echo "************************"
	cd $rootdir/triage/$processDir
	for f in $(ls *.odex); do
		deodex_file $f
	done
	echo ""
	echo "Zipaligning APKs"
	for d in $(ls *.apk);do
		echo "- $d"
		zpln $d
	done
done

# Remove temp fw jar
echo
if [ -e $rootdir/triage/framework/java.awt.jar ]; then
	rm $rootdir/triage/framework/java.awt.jar
fi

echo "Done."
echo ""
IFS=$SAVEIFS
exit 0
