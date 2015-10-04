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
pkg-config libgl1-mesa-dev libgles2-mesa-dev emacs-nox mc
python-pygame python-setuptools libgstreamer1.0-dev git-core python-dev
gstreamer1.0-plugins-bad
gstreamer1.0-plugins-base
gstreamer1.0-plugins-good
gstreamer1.0-plugins-ugly
gstreamer1.0-omx
gstreamer1.0-alsa
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
libssl1.0.0 libsmbclient libssh-4
"

echo "KivyPie build process starts at: `date`"

# On some packages, mandb needs to see the paths below upfront
mkdir /var/cache/man/tr
mkdir /var/cache/man/it
mkdir /var/cache/man/sv
mkdir /var/cache/man/fr.ISO8859-1

# Bring APT to latest sources
echo "Bringing the system up to date"
apt-get update
apt-get -y -f install
apt-get upgrade -y

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
apt-get autoclean

# Stop all automatically started services during upgrade
/etc/init.d/dbus stop
/etc/init.d/cron stop
/etc/init.d/ssh stop
/etc/init.d/ntp stop
/etc/init.d/rsyslog stop
kill $(cat /var/run/rsyslogd.pid)

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
curl -L https://github.com/AndrewFromMelbourne/raspi2png/archive/master.zip > raspi2png.zip
unzip raspi2png.zip
cd raspi2png-master
make
cp -fv raspi2png /usr/bin
cd /tmp
rm -rf raspi2png-master

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
rm -rf RPIO

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
echo "acert230h = mtdev,/dev/input/event0" >> $kivini
echo "mtdev_%(name)s = probesysfs,provider=mtdev" >> $kivini
echo "hid_%(name)s = probesysfs,provider=hidinput" >> $kivini

echo "[modules]" >> $kivini
echo "touchring = scale=0.3,alpha=0.7,show_cursor=1" >> $kivini

# Allow kivy apps to be run as root
mkdir -p /root/.kivy
cp -fv /home/sysop/.kivy/config.ini /root/.kivy

# Explain what we built to the logs
echo "Kivy version built:"
echo "import kivy; print kivy.__version__" | python -

echo "Installing omxplayer"
cd /tmp
curl -L http://omxplayer.sconde.net/builds/omxplayer_0.3.6~git20150912~d99bd86_armhf.deb > omxplayer_0.3.6~git20150912~d99bd86_armhf.deb
dpkg -i omxplayer_0.3.6~git20150912~d99bd86_armhf.deb
rm omxplayer_0.3.6~git20150912~d99bd86_armhf.deb

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
curl -L https://github.com/kivy/kivy/blob/master/examples/canvas/mesh_manipulation.py > /home/sysop/mesh-manipulation/mesh_manipulation.py
echo "Mesh manipulation from Gabriel Pettier" > $readmefile
echo "  http://blog.tshirtman.fr/2014/1/29/kivy-image-manipulations-with-mesh-and-textures" >> $readmefile

echo "sample 2: flappykivy game"
curl -L https://github.com/superman3275/FlappyKivy/archive/master.tar.gz | tar zxf -

echo "sample 3: piki GPIO games"
curl -L https://github.com/kivy/piki/archive/master.tar.gz | tar zxf -

echo "sample 4: 3d picking objects"
curl -L https://github.com/nskrypnik/kivy-3dpicking/archive/master.tar.gz | tar zxf -

# http://inclem.net/pages/kivy-crash-course/
echo "sample 5: Kivy tutorial sources from Alexander Taylor"
curl -L https://github.com/inclement/kivycrashcourse/archive/master.tar.gz | tar zxf -

#
# Bring the RaspberryPI firmware and kernel up to date
#
chmod +x /usr/bin/rpi-update
/usr/bin/rpi-update

echo "Current linux kernel:"
uname -a

# Fix regular user permissions
echo "Setting permissions for all sysop home dir user files"
chown -R 1000:1000 $sysopdir
usermod -aG input sysop
ls -auxlh $sysopdir

echo "Adding local binary path to regular user"
printf "PATH=\$PATH:/usr/local/bin\n" >> /home/sysop/.bashrc

echo "KivyPie build process finished at: `date`"
exit 0
