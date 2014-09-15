#!/bin/bash

printf '\033c'
echo "Current version: $(cat tools/version.txt)"
echo "Available versions:"
echo "      1  -  1.3.3"
echo "      2  -  1.4.2"
echo "      3  -  2.0.3"
echo ""
echo "Choose number corresponding to desired version."
echo -n "Leave blank for default (1.4.2): "
read choice

if [[ $choice != "" ]]; then
	if [ $choice == "1" ]; then
		echo "1.3.3" > tools/version.txt
	elif [ $choice == "2" ]; then
		echo "1.4.2" > tools/version.txt
	else
		echo "2.0.3" > tools/version.txt
	fi
else
	echo "1.4.2" > tools/version.txt
fi

echo ""
echo "Done. Run ./deodex again."

exit 0

