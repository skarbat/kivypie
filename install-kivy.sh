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
    # Name of the Kivy source zip package at github
    # by default: https://github.com/kivy/kivy/archive/master.zip
    kivy_source_zip='master'
else
    kivy_source_zip=$1
fi

# List of packages needed to build Kivy and additional tools
BUILD_PKGS="
pkg-config libgl1-mesa-dev libgles2-mesa-dev
python-pygame python-setuptools libgstreamer1.0-dev git-core
gstreamer1.0-plugins-bad gstreamer1.0-plugins-base
gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly
gstreamer1.0-omx gstreamer1.0-alsa python-dev
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
"

echo "KivyPie build process starts at: `date`"

# Bring APT up to date and install dependant software
echo "Bringing the system up to date"
apt-get update
apt-get install -y --force-yes $BUILD_PKGS
apt-get autoclean

# Stop services started due to the installation
/etc/init.d/dbus stop

# Download and uncompress the Kivy sources
cd /tmp
kivy_dirname="kivy-${kivy_source_zip}"
kivy_download_url="https://github.com/kivy/kivy/archive/${kivy_source_zip}.zip"
if [ -d "$kivy_dirname" ]; then
    echo "removing previous dir $kivy_dirname"
    rm -rf $kivy_dirname
fi

echo "Downloading Kivy sources $kivy_download_url"
curl -L -k -s $kivy_download_url > ${kivy_source_zip}.zip
echo "uncompressing source code..."
unzip -o ${kivy_source_zip}.zip

echo "Installing PIP"
wget -q https://raw.github.com/pypa/pip/master/contrib/get-pip.py
python ./get-pip.py
rm -fv ./get-pip.py

echo "Build and install Cython"
pip install cython==0.21.2

echo "Installing pygments"
pip install pygments

# Build and install Kivy!
cd /tmp/$kivy_dirname
python setup.py install
cd ..
rm -rf $kivy_dirname
ln -s /usr/bin/python2.7 /usr/bin/kivy


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
chmod +x ./makeit
./makeit
cp -fv dispman_vncserver /usr/local/bin/
cd /tmp
rm -rf dispmanx_vnc-master
rm dispmanx_vnc.zip


#
# System tweaks to make Kivy play well
#
echo "Setup input device for regular keyboard and mouse"
sysopdir=/home/sysop
kivdir=$sysopdir/.kivy
kivini=$kivdir/config.ini
mkdir $kivdir
echo "[input]" > $kivini
echo "mouse = mouse" >> $kivini
echo "device_%(name)s = probesysfs,provider=mtdev" >> $kivini
echo "%(name)s = probesysfs,provider=mtdev" >> $kivini
echo "%(name)s = probesysfs,provider=hidinput" >> $kivini
echo "acert230h = mtdev,/dev/input/event0" >> $kivini
echo "mtdev_%(name)s = probesysfs,provider=mtdev" >> $kivini
echo "hid_%(name)s = probesysfs,provider=hidinput" >> $kivini

echo "[modules]" >> $kivini
echo "touchring = scale=0.3,alpha=0.7,show_cursor=1" >> $kivini

# Allow kivy apps to be run as root
mkdir -p /root/.kivy
cp -fv /home/sysop/.kivy/config.ini /root/.kivy

# Many kivy apps expect a .config home directory
mkdir -p /home/sysop/.config

# Explain what we built to the logs
echo "Kivy version built:"
echo "import kivy; print kivy.__version__" | python -


echo "Get the latest kivy source code for later builds"
kivyzip=$sysopdir/kivy-1.9.0.zip
cd /tmp
wget -q https://github.com/kivy/kivy/archive/1.9.0.zip -O $kivyzip

echo "Get latest kivy documentation in PDF"
kivypdf=$sysopdir/kivy-documentation.pdf
wget -q http://kivy.org/docs/pdf/Kivy-latest.pdf -O $kivypdf

#
# Clone sample projects and demos included in KivyPie
#
cd /home/sysop

# sample 1: mesh objects
readmefile=/home/sysop/mesh-manipulation/README.txt
mkdir -p /home/sysop/mesh-manipulation
curl -L -k https://raw.githubusercontent.com/kivy/kivy/master/examples/canvas/mesh_manipulation.py > /home/sysop/mesh-manipulation/mesh_manipulation.py
echo "Mesh manipulation from Gabriel Pettier" > $readmefile
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

# make it easier to reach the amazing examples :)
sudo ln -s /usr/local/share/kivy-examples/ /home/sysop/kivy-examples


# Fix user permissions to all downloaded stuff
echo "Setting permissions for all sysop home dir user files"
chown -R 1000:1000 $sysopdir
ls -auxlh $sysopdir

# Change the message of the day
echo "Welcome to KivyPie" > /etc/motd

echo "KivyPie build process finished at: `date`"
exit 0
