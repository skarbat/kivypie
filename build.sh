#!/bin/bash
#
#  Builds KivyPie from scratch, then runs basic tests.
#
#  TODO: unify xsysroot profile name, it is spread around
#

logfile=build.log
xprofile="kivypie"

echo "Building KivyPie - follow progress at $logfile..."
python -u build_kivypie.py --build-all > $logfile 2>&1
./test_image.sh >> $logfile 2>&1

if [ "$?" == "0" ]; then
    mounted=`xsysroot -p $xprofile -m`
    if [ "$?" != "0" ]; then
	echo "Error debianizing - Kivypie profile not found"
	exit 1
    else
	echo "Debianizing Kivypie..."
	python debian_kivypie.py $(xsysroot -q sysroot)
    fi
fi
