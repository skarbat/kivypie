#!/usr/bin/env python
#
#  Simple script to collect KivyPie binaries into Debian packages.
#
#  Two versions are generated, one for python2 and python3.
#  The output files are: python2-kivypie.deb and python3-kivypie.deb
#
#  NOTE: Initial version with bare dependencies, likely more are missing.
#

import os
import sys
import build_kivypie

# This is Debian control file
debian_control='''
Maintainer: Albert Casals <skarbat@gmail.com>
Section: graphics
Package: {pkg_name}
Version: {pkg_version}
Architecture: armhf
Depends: debconf (>= 0.5.00), {pkg_depends}
Priority: optional
Description: {pkg_description}
'''

packages=[

    # Kivypie debian package for Python2
    { 'fileset': [ '/usr/local/lib/python2.7/dist-packages/kivy/*' ],  
      'pkg_name': 'python2-kivypie',
      'pkg_version': build_kivypie.__version__,
      'pkg_depends': 'python2.7 libsdl2-2.0-0, libsdl2-image-2.0-0, libsdl2-mixer-2.0-0, '\
                     'libsdl2-ttf-2.0-0, python-beautifulsoup',
      'pkg_description': 'Python2 Kivy libraries for the RaspberryPI'
    },

    # Kivypie debian package for Python3
    { 'fileset': [ '/usr/local/lib/python3.4/dist-packages/kivy/*' ],  
      'pkg_name': 'python3-kivypie',
      'pkg_version': build_kivypie.__version__,
      'pkg_depends': 'python3.4 libsdl2-2.0-0, libsdl2-image-2.0-0, libsdl2-mixer-2.0-0, '\
                     'libsdl2-ttf-2.0-0, python3-bs4',
      'pkg_description': 'Python3 Kivy libraries for the RaspberryPI'
    },

    # Kivypie debian package for official Kivy examples
    { 'fileset': [ '/usr/local/share/kivy-examples/*' ],  
      'pkg_name': 'python-kivypie-examples',
      'pkg_version': build_kivypie.__version__,
      'pkg_depends': 'python2-kivypie | python3-kivypie',
      'pkg_description': 'Python Kivy examples for the RaspberryPI'
    }
]



if __name__ == '__main__':

    help='debianize-kivypie.py <rootfs path>'
    pkgsdir='pkgs'

    if len(sys.argv) < 2:
        print help
        sys.exit(1)
    else:
        rootfs=sys.argv[1]

    if not os.path.isdir(rootfs):
        print 'cannot access', rootfs
        sys.exit(1)

    for pkg in packages:
        # allocate a versioned directory for the package
        versioned_pkg_name = '{}_{}'.format(pkg['pkg_name'], build_kivypie.__version__)
        pkg_target=os.path.join(pkgsdir, versioned_pkg_name)
        print 'Processing package {}... into {}'.format(versioned_pkg_name, pkg_target)

        if not os.path.isdir(pkg_target):
            os.makedirs(pkg_target)

        # populate the files for packaging
        for f in pkg['fileset']:
            source_files='{}/{}'.format(rootfs, f)
            target_tree='{}/{}'.format(pkg_target, os.path.dirname(f))
            if not os.path.isdir(target_tree):
                os.makedirs(target_tree)

            print 'Extracting {}...'.format(source_files)
            os.system('cp -rP {} {}'.format(source_files, target_tree))

        # create a DEBIAN control file for building
        debian_dir=os.path.join(pkg_target, 'DEBIAN')
        if not os.path.exists(debian_dir):
            os.makedirs(debian_dir)
        with open(os.path.join(debian_dir, 'control'), 'w') as control_file:
            control_file.writelines(debian_control.format(**pkg))

        # run the magic
        rc=os.system('dpkg-deb --build {}'.format(pkg_target))
        if not rc:
            print 'Package {} created correctly'.format(pkg_target)
        else:
            print 'WARNING: Error creating package {}'.format(pkg_target)
