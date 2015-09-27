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

# List of packages needed to build Kivy
BUILD_PKGS="
pkg-config libgl1-mesa-dev libgles2-mesa-dev emacs23-nox mc
python-pygame python-setuptools libgstreamer1.0-dev git-core python-dev
gstreamer1.0-plugins-bad
gstreamer1.0-plugins-base
gstreamer1.0-plugins-good
gstreamer1.0-plugins-ugly
gstreamer1.0-omx
gstreamer1.0-alsa
libmtdev1
libpng12-dev
zip unzip
"

echo "KivyPie build process starts at: `date`"

# Bring APT to latest sources
echo "Bringing the system up to date"
apt-get update
apt-get -y -f install

# Add Vontaene apt gpg key
# See this thread to understand what this means:
# https://www.raspberrypi.org/forums/viewtopic.php?f=28&t=87139
#
apt-get install debian-keyring
gpg --keyserver pgp.mit.edu --recv-keys 0C667A3E
gpg --armor --export 0C667A3E | apt-key add -

# Adding Vontaene source repository so we can pull gstreamer packages
echo "Adding extra apt sources"
echo "deb http://vontaene.de/raspbian-updates/ . main" > /etc/apt/sources.list.d/gstreamer-sources.list
apt-get update

# Extra tools we need unzip
apt-get install -y --force-yes $BUILD_PKGS

# Download and uncompress the Kivy sources
kivy_dirname="kivy-${kivy_source_zip}"
kivy_download_url="https://github.com/kivy/kivy/archive/${kivy_source_zip}.zip"

if [ -d "$kivy_dirname" ]; then
    echo "removing previous dir $kivy_dirname"
    rm -rf $kivy_dirname
fi

echo "Downloading $kivy_download_url"
curl -L -s $kivy_download_url > ${kivy_source_zip}.zip
echo "uncompressing source code..."
unzip ${kivy_source_zip}.zip
cd $kivy_dirname && pwd && ls -l

echo "Building raspi2png screenshot tool"
git clone https://github.com/AndrewFromMelbourne/raspi2png.git
cd raspi2png
make
cp -fv raspi2png /usr/bin
cd /
rm -rf raspi2png

echo "Installing PIP"
cd /tmp
wget -q https://raw.github.com/pypa/pip/master/contrib/get-pip.py
python ./get-pip.py
rm -fv ./get-pip.py

#
# WARNING: RPIO Libraries are currently experiencing problems on RPI model 2.
#
#  https://github.com/metachris/RPIO/issues/53
#  https://www.raspberrypi.org/forums/viewtopic.php?t=98466
#
# Installing Weimin Ouyang changes for RPI2 support until officially fixed.
#
echo "Building and installing RPIO - Weimin branch support for RPI2"
cd /tmp
git clone https://github.com/tylerwowen/RPIO.git
cd RPIO
git checkout tylerwowen-pi2
python setup.py install


echo "Building and install Cython"
pip install cython==0.21.2

echo "Installing pygments"
pip install pygments

# It's time to build Kivy
echo "Executing Kivy build and installation steps"
cd /tmp/$kivy_dirname

# Build and install Kivy!
python setup.py install
cd ..
rm -rf $kivy_dirname
ln -s /usr/bin/python2.7 /usr/bin/kivy

# System tweaks to make Kivy play nice
echo "Adding raspberry PI firmware paths"
echo "export LD_LIBRARY_PATH=/opt/vc/lib" >> /etc/bash.bashrc
echo "export PATH=$PATH:/opt/vc/bin" >> /etc/bash.bashrc

echo "Adjusting input device permissions"
echo 'SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"' > /etc/udev/rules.d/10-vchiq-permissions.rules
echo 'SUBSYSTEM=="input", KERNEL=="event[0-9]*", GROUP="users"' > /etc/udev/rules.d/10-input.rules
usermod -a -G video sysop
usermod -a -G audio sysop
usermod -a -G users sysop

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
echo "acert230h = mtdev,/dev/input/input1" >> $kivini
echo "[modules]" >> $kivini
echo "touchring = scale=0.3,alpha=0.7,show_cursor=1" >> $kivini

echo "Kivy version built:"
echo "import kivy; print kivy.__version__" | python -

echo "Get the latest kivy source code for later builds"
kivyzip=$sysopdir/kivy-1.9.0.zip
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
mv -fv /usr/local/bin/mesh-manipulations.py /home/sysop/mesh-manipulation
echo "Mesh manipulation from Gabriel Pettier" > $readmefile
echo "  http://blog.tshirtman.fr/2014/1/29/kivy-image-manipulations-with-mesh-and-textures" >> $readmefile

# sample 2: flappykivy game
git clone https://github.com/superman3275/FlappyKivy.git

# sample 3: piki GPIO games
git clone https://github.com/kivy/piki.git

# sample 4: 3d picking objects
git clone https://github.com/nskrypnik/kivy-3dpicking.git

# sample 5: Kivy tutorial sources from Alexander Taylor
# http://inclem.net/pages/kivy-crash-course/
git clone https://github.com/inclement/kivycrashcourse.git

# TODO: rpi-update to get the latest Raspberry firmware
# xsysroot needs to provide a correct link to /boot
# rpi-update

echo "Current linux kernel:"
uname -a

# Fix regular user permissions
echo "Setting permissions for all sysop home dir user files"
chown -R 1000:1000 $sysopdir
ls -auxlh $sysopdir

echo "Adding local binary path to regular user"
printf "PATH=\$PATH:/usr/local/bin\n" >> /home/sysop/.bashrc

echo "KivyPie build process finished at: `date`"
exit 0
