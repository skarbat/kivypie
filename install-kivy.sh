#!/bin/bash
#
#  The MIT License (MIT)
#
#  Copyright (c) 2015 Albert Casals - albert@mitako.eu
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#
#  install-kivy.sh
#
#  Script to run on the RaspberryPI to download, build and install the Kivy.org framework.
#  With additions to install additional tools, some Kivy samples, and system tweaks.
#
#  This script is targeted at Raspbian Jessie version
#

# System jail protection code
ARM_MUST_BE='armv7l'
mach=`uname -m`
if [ "$mach" != "$ARM_MUST_BE" ]; then
    echo "Careful! Looks like I am not running inside an ARM system!"
    echo "uname -m is telling me: $mach"
    exit 1
else
    # Avoid errors from stopping the script
    set +e
fi

# If no Kivy source release is provided
# install the latest unstable master branch
if [ "$1" == "" ]; then
    kivy_release="master"
else
    kivy_release="$1"
fi


# List of packages needed to build Kivy and additional tools
BUILD_PKGS="
pkg-config libgl1-mesa-dev libgles2-mesa-dev
python-pygame python-setuptools python3-setuptools libgstreamer1.0-dev git-core
gstreamer1.0-plugins-bad gstreamer1.0-plugins-base
gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly
gstreamer1.0-omx gstreamer1.0-alsa python-dev python3-dev
vim vim-python-jedi emacs python-mode mc
libmtdev1
libpng12-dev
zip unzip sshfs
libsdl2-dev
libsdl2-gfx-dev
libsdl2-image-dev
libsdl2-mixer-dev
libsdl2-net-dev
libsdl2-ttf-dev
libpcre3 libfreetype6
fonts-freefont-ttf dbus
python-docutils
libssl1.0.0 libsmbclient libssh-4
python-rpi.gpio python3-rpi.gpio raspi-gpio wiringpi
libraspberrypi-dev wget
libvncserver-dev
python-beautifulsoup
python3-bs4
"

echo ">>> KivyPie build process starts at: `date`"

# Bring APT up to date and install dependant software
echo ">>> Bringing the system up to date"
apt-get update
apt-get install -y --force-yes $BUILD_PKGS
apt-get autoclean

# upgrade to latest PIP for python 2 and 3
echo ">>> Installing pip and pip3"
easy_install3 -U pip
easy_install -U pip

# Stop services started due to the installation
/etc/init.d/dbus stop

echo ">>> Build and install Cython"
pip install cython==0.23
pip3 install cython==0.23

echo ">>> Installing pygments"
pip install pygments
pip3 install pygments

# get Kivy source code
kivy_url="https://github.com/kivy/kivy/archive/$kivy_release.zip"
sourcezip=/tmp/kivy_source.zip
cd /tmp

# cleanup previous build
rm -fv $sourcezip
rm -rfv /tmp/kivi-$kivy_release

# download and unzip sources
echo ">>> Downloading kivy source code url: $kivy_url"
curl -s -L $kivy_url > $sourcezip
unzip -o $sourcezip

# build kivy for python 3
echo ">>> PIP3 is building kivy for Python 3...."
cd /tmp/kivy-$kivy_release
pip3 install --upgrade .

# cleanup previous kivy build for python 3
rm -rfv /tmp/kivi-$kivy_release
unzip -o $sourcezip

# now build kivy for python 2
echo ">>> PIP is building kivy for Python 2...."
cd /tmp/kivy-$kivy_release
pip install --upgrade .

echo ">>> Setting Kivy to point to Python3"
ln -sfv /usr/bin/python3 /usr/bin/kivy
kivy -V


# Build screnshot tool
cd /tmp
echo "Building raspi2png screenshot tool"
rm raspi2png.zip
rm -rf raspi2png-master
curl -L -k https://github.com/AndrewFromMelbourne/raspi2png/archive/master.zip > raspi2png.zip
unzip -o raspi2png.zip
cd raspi2png-master
make
cp -fv raspi2png /usr/bin
cd /tmp
rm -rf raspi2png-master
rm raspi2png.zip


# Build a VNC server for Kivy Apps
cd /tmp
rm dispmanx_vnc.zip
rm -rf dispmanx_vnc-master
curl -L -k https://github.com/hanzelpeter/dispmanx_vnc/archive/master.zip > dispmanx_vnc.zip
unzip -o dispmanx_vnc.zip
cd dispmanx_vnc-master
make
cp -fv dispmanx_vncserver /usr/local/bin/
cd /tmp
rm -rf dispmanx_vnc-master
rm dispmanx_vnc.zip


#
# System tweaks to make Kivy play well
#
username="sysop"
echo ">> Setup input device for regular keyboard and mouse"
usernamedir="/home/$username"
kivdir=$usernamedir/.kivy
kivini=$kivdir/config.ini
mkdir $kivdir

# Create kivy configuration file
cat <<EOF > $kivini
[input]
mouse = mouse
mtdev_%(name)s = probesysfs,provider=mtdev
hid_%(name)s = probesysfs,provider=hidinput

[modules]
touchring = scale=0.3,alpha=0.7,show_cursor=1
EOF

# Allow kivy apps to be run as root
echo ">>> configuring Kivy default configurations"
mkdir -p /root/.kivy
cp -fv /home/$username/.kivy/config.ini /root/.kivy

# Many kivy apps expect a .config home directory
mkdir -p /home/$username/.config

# Explain what we built to the logs
echo "Kivy version built:"
echo "import kivy; print kivy.__version__" | python -

echo "Copying Kivy sources used to build this version"
cp -fv ${kivy_source_zip}.zip $usernamedir

echo ">>> Getting latest kivy documentation in PDF"
kivypdf=$usernamedir/kivy-documentation.pdf
wget -q http://kivy.org/docs/pdf/Kivy-latest.pdf -O $kivypdf

#
# Clone sample projects and demos included in KivyPie
#
cd /home/$username

# sample 1: mesh objects
readmefile=/home/$username/mesh-manipulation/README.txt
mkdir -p /home/$username/mesh-manipulation
curl -L -k https://raw.githubusercontent.com/kivy/kivy/master/examples/canvas/mesh_manipulation.py > /home/$username/mesh-manipulation/mesh_manipulation.py
echo "Sample 1: Mesh manipulation" > $readmefile
echo "  http://blog.tshirtman.fr/2014/1/29/kivy-image-manipulations-with-mesh-and-textures" >> $readmefile

echo "sample 2: flappykivy game"
curl -L -k https://github.com/superman3275/FlappyKivy/archive/master.tar.gz | tar zxf -

echo "sample 3: piki GPIO games"
curl -L -k https://github.com/kivy/piki/archive/master.tar.gz | tar zxf -

echo "sample 4: 3d picking objects"
curl -L -k https://github.com/nskrypnik/kivy-3dpicking/archive/master.tar.gz | tar zxf -

# http://inclem.net/pages/kivy-crash-course/
echo "sample 5: Kivy tutorial sources from Alexander Taylor"
curl -L -k https://github.com/inclement/kivycrashcourse/archive/master.tar.gz | tar zxf -

# http://inclem.net/pages/kivy-crash-course/
echo "sample 6: elUruguayo"
curl -L -k https://github.com/elParaguayo/RPi-InfoScreen-Kivy/archive/master.tar.gz | tar zxf -

# make it easier to reach the amazing examples :)
sudo ln -s /usr/local/share/kivy-examples/ /home/$username/kivy-examples


# Fix user permissions to all downloaded stuff
echo "Setting permissions for all $username home dir user files"
chown -R $username:$username $usernamedir
ls -auxlh $usernamedir

# Change the message of the day
echo "Welcome to KivyPie" > /etc/motd

echo "KivyPie build process finished at: `date`"
exit 0
