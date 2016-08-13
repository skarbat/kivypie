## KivyPie build

Welcome to KivyPie build sources, which allow to run Kivy.org on the RaspberryPI.

The scripts detailed allow to take a pipaOS image and install the Kivy framework on it.
It should be straight forward to use a Raspbian too.

PipaOS is available at http://pipaos.mitako.eu/

The latest features on Kivy 1.9 are [detailed here](http://kivy.org/planet/2015/04/kivy-1-9%C2%A0released/).

### Requirements and preparation

A Linux, i686 based system with `nbd` support in the kernel. Debian is tested to run smoothly.
Download [xsysroot](https://github.com/skarbat/xsysroot) somewhere on your path, and create a python symbolic link:

```
$ curl https://raw.githubusercontent.com/skarbat/xsysroot/master/xsysroot > ~/bin/xsysroot
$ chmod +x ~/bin/xsysroot ; ln -s ~/bin/xsysroot ~/bin/xsysroot.py
```

Copy the file `xsysroot.conf` from this repo on your home directory, and download
the pipaOS image. This will allow xsysroot to prepare the image and install Kivy in it.

```
$ mkdir -p ~/osimages ~/xtmp
$ curl http://pipaos.mitako.eu/download/pipaos-3.3-wheezy.img.gz > ~/osimages/pipaos-3.3-wheezy.img.gz
```

Run `xsysroot -l`, it should display the profile `KivyPie`. Then, make sure you have additional system tools
available by running `xsysroot -t`. If it complains, install the suggested packages.

### Building KivyPie

The build process is separated in 2 parts. 

 * `build-kivypie.py` is responsible for preparing the OS, install Kivy, and give you a bootable image
 * `install-kivy.sh` The KivyPie build and installation script

Execute `build.sh` to build KivyPie from scratch. Follow the progress via the logfile with `tail -f build.log`.

You could actually run `install-kivy.sh` directly on the RaspberryPI and it should install Kivy as well.
Make sure you do `sudo umount /tmp` to use the full sd card available space to build all sources.

The latest version of KivyPie and additional info can be found at http://kivypie.mitako.eu

###Build debian packages

TODO: Explain how to build them

Enjoy!
