#!/bin/bash
#
# Test to make sure kivy and extra tools are installed
#

kivy_version="1.10.0"
default_python="python2.7"
xprofile="kivypie"
username="sysop"

failed=0

mounted=`xsysroot -p $xprofile -m`
if [ "$?" != "0" ]; then
    echo "Kivypie profile not found"
    exit 1
fi

dispmanx=`xsysroot -p $xprofile -x "which dispmanx_vncserver"`
if [ "$?" != "0" ]; then
    failed=1
    echo "dispmanx_vncserver - FAILED"
else
    echo "dispmanx_vncserver - PASS"
fi

raspi2png=`xsysroot -p $xprofile -x "which raspi2png"`
if [ "$?" != "0" ]; then
    failed=1
    echo "raspi2png - FAILED"
else
    echo "raspi2png - PASS"
fi

user=`xsysroot -p $xprofile -x "@$username whoami"`
if [ "$?" != "0" ]; then
    failed=1
    echo "$username user - FAILED"
else
    echo "$username user - PASS"
fi

python_link=`readlink $(which python)`
if [ "$python_link" != "$default_python" ]; then
    failed=1
    echo "default python version - FAILED"
else
    echo "default python version - PASS"
fi

kivy=`xsysroot -p $xprofile -x "kivy -c 'import kivy; print (kivy.__version__)' 2>/dev/null" | cut -d$'\n' -f1`
if [ "$kivy" != "$kivy_version" ]; then
    failed=1
    echo "kivy for default python - FAILED"
else
    echo "kivy for default python - PASS"
fi

kivy=`xsysroot -p $xprofile -x "python2 -c 'import kivy; print (kivy.__version__)' 2>/dev/null" | cut -d$'\n' -f1`
if [ "$kivy" != "$kivy_version" ]; then
    failed=1
    echo "kivy for python2 - FAILED"
else
    echo "kivy for python2 - PASS"
fi

kivy=`xsysroot -p $xprofile -x "python3 -c 'import kivy; print (kivy.__version__)' 2>/dev/null" | cut -d$'\n' -f1`
if [ "$kivy" != "$kivy_version" ]; then
    failed=1
    echo "kivy for python3 - FAILED"
else
    echo "kivy for python3 - PASS"
fi

kivyconfig=`xsysroot -p $xprofile -x "ls -l /home/$username/.kivy/config.ini 2>&1"`
if [ "$?" != "0" ]; then
    failed=1
    echo "user $username kivy configuration file - FAILED"
else
    echo "user $username kivy configuration file - PASS"
fi

kivyconfig=`xsysroot -p $xprofile -x "ls -l /root/.kivy/config.ini"`
if [ "$?" != "0" ]; then
    failed=1
    echo "kivy root configuration file - FAILED"
else
    echo "kivy root configuration file - PASS"
fi

garden=`xsysroot -p $xprofile -x "@$username garden list > /dev/null 2>&1"`
if [ "$?" != "0" ]; then
    failed=1
    echo "kivy garden - FAILED"
else
    echo "kivy garden - PASS"
fi

requests=`xsysroot -p $xprofile -x "@$username python3 -c 'import requests' > /dev/null 2>&1"`
if [ "$?" != "0" ]; then
    failed=1
    echo "python requests - FAILED"
else
    echo "python requests - PASS"
fi

bs=`xsysroot -p $xprofile -x "@$username python3 -c 'import bs4' > /dev/null 2>&1"`
if [ "$?" != "0" ]; then
    failed=1
    echo "python BeautifulSoup - FAILED"
else
    echo "python BeautifulSoup - PASS"
fi

pip3=`xsysroot -p $xprofile -x "@$username pip3 -V | grep 'python 3.4'> /dev/null 2>&1"`
if [ "$?" != "0" ]; then
    failed=1
    echo "pip3 - FAILED"
else
    echo "pip3 - PASS"
fi

umounted=`xsysroot -p $xprofile -u`

if [ "$failed" != "0" ]; then
    exit 1
else
    exit 0
fi
