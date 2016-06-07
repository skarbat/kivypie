#!/bin/bash
#
# Test to make sure kivy and extra tools are installed
#

kivy_version="1.9.2-dev0"
xprofile="kivypie"
username="sysop"

mounted=`xsysroot -p $xprofile -m`
if [ "$?" != "0" ]; then
    echo "Kivypie profile not found"
    exit 1
fi

dispmanx=`xsysroot -p $xprofile -x "which dispman_vncserver"`
if [ "$?" != "0" ]; then
    echo "dispman_vncserver - FAILED"
else
    echo "dispman_vncserver - PASS"
fi

raspi2png=`xsysroot -p $xprofile -x "which raspi2png"`
if [ "$?" != "0" ]; then
    echo "raspi2png - FAILED"
else
    echo "raspi2png - PASS"
fi

user=`xsysroot -p $xprofile -x "@$username whoami"`
if [ "$?" != "0" ]; then
    echo "$username user - FAILED"
else
    echo "$username user - PASS"
fi

kivy=`xsysroot -p $xprofile -x "kivy -c 'import kivy; print (kivy.__version__)' 2>/dev/null" | cut -d$'\n' -f1`
if [ "$kivy" != "$kivy_version" ]; then
    echo "kivy version - FAILED"
else
    echo "kivy version - PASS"
fi

kivyconfig=`xsysroot -p $xprofile -x "ls -l /home/$username/.kivy/config.ini 2>&1"`
if [ "$?" != "0" ]; then
    echo "user $username kivy configuration file - FAILED"
else
    echo "user $username kivy configuration file - PASS"
fi

kivyconfig=`xsysroot -p $xprofile -x "ls -l /root/.kivy/config.ini"`
if [ "$?" != "0" ]; then
    echo "kivy root configuration file - FAILED"
else
    echo "kivy root configuration file - PASS"
fi

garden=`xsysroot -p $xprofile -x "@$username garden list > /dev/null 2>&1"`
if [ "$?" != "0" ]; then
    echo "kivy garden - FAILED"
else
    echo "kivy garden - PASS"
fi

requests=`xsysroot -p $xprofile -x "@$username python -c 'import requests' > /dev/null 2>&1"`
if [ "$?" != "0" ]; then
    echo "python requests - FAILED"
else
    echo "python requests - PASS"
fi

requests=`xsysroot -p $xprofile -x "@$username python -c 'import bs4' > /dev/null 2>&1"`
if [ "$?" != "0" ]; then
    echo "python BeautifulSoup - FAILED"
else
    echo "python BeautifulSoup - PASS"
fi

umounted=`xsysroot -p $xprofile -u`
exit 0
