#!/usr/bin/env python
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
#  build-kivypie.py
#
#  Program that runs the KivyPie installation script inside a pipaOS Raspbian image.
#  You need to download and setup xsysroot to run this script, see README for details.
#

import os
import sys
import time

# Release version of KivyPie
__version__='0.7'

# Kivy source release branch to build - latest as of today: 1.9.0
__kivy_github_version__='master'


def import_xsysroot():
    '''
    Find path to XSysroot and import it
    You need to create a symlink xsysroot.py -> xsysroot
    '''
    which_xsysroot=os.popen('which xsysroot').read().strip()
    if not which_xsysroot:
        print 'Could not find xsysroot tool'
        print 'Please install from https://github.com/skarbat/xsysroot'
        return None
    else:
        print 'xsysroot found at: {}'.format(which_xsysroot)
        sys.path.append(os.path.dirname(which_xsysroot))
        import xsysroot
        return xsysroot



if __name__ == '__main__':

    output_image='kivy-pie-{}.img'.format(__version__)
    prepare_only=False

    # Xsysroot profile name that holds the original pipaOS image
    # (See the file xsysroot.conf for details)
    xsysroot_profile_name='kivypie'

    # --prepare-only will not install any software, but expand the image
    cmd_options='--build-all, --prepare-only'
    if len(sys.argv) > 1:
        if sys.argv[1] == '--prepare-only':
            prepare_only=True
            print 'Running in --prepare-only mode'
        elif sys.argv[1] == '--build-all':
            print 'Running in --build-all mode'
        else:
            print 'Unrecognized option, use one of {}'.format(cmd_options)
            sys.exit(1)
    else:
        print 'Please specify mode: {}'.format(cmd_options)
        sys.exit(1)

    # import the xsysroot module
    xsysroot=import_xsysroot()
    if not xsysroot:
        sys.exit(1)

    # Find and activate the xsysroot profile
    try:
        kivypie=xsysroot.XSysroot(profile=xsysroot_profile_name)
    except:
        print 'You need to create a Xsysroot kivypie profile'
        print 'Please see the README file'
        sys.exit(1)

    # start timer
    time_start=time.time()

    # make sure the image is not mounted, or not currently in use
    if kivypie.is_mounted():
        if not kivypie.umount():
            sys.exit(1)

    # renew the image so we start from scratch
    if not kivypie.renew():
        sys.exit(1)
    else:
        # once renewed, expand it to grow in size
        kivypie.umount()
        if not kivypie.expand():
            print 'error expanding image size to {}'.format(kivypie.query('qcow_size'))
            sys.exit(1)
        else:
            kivypie.mount()

    if not prepare_only:

        # baptize the kivypie version
        kivypie.edfile('/etc/kivypie_version', 'kivypie v{} - {}'.format(__version__, time.ctime()))

        # set the system hostname
        kivypie_hostname='kivypie'
        kivypie_hosts_file='/etc/hosts'
        kivypie.edfile('/etc/hostname', kivypie_hostname)
        kivypie.edfile(kivypie_hosts_file, '127.0.0.1 localhost')
        kivypie.edfile(kivypie_hosts_file, '127.0.0.1 {}'.format(kivypie_hostname), append=True)

        # firmware config.txt contains special settings to make Kivy run smoother
        src_config_txt='config.txt'
        dst_config_txt=os.path.join(kivypie.query('sysboot'), src_config_txt)
        rc=os.system('sudo cp -fv {} {}'.format(src_config_txt, dst_config_txt))
        if rc:
            print 'WARNING: could not copy config.txt rc={}'.format(rc)

        # Copy kivypie readme file to user home directory
        rc=os.system('sudo cp -fv {} {}'.format('README-kivypie', kivypie.query('sysboot')))
        rc=os.system('sudo cp -fv {} {}'.format('LICENSE', os.path.join(kivypie.query('sysboot'), 'LICENSE-kivypie')))

        # make the KivyPie installation script available in the image through /tmp
        src_install_script='install-kivy.sh'
        dst_install_script=os.path.join(kivypie.query('tmp'), src_install_script)
        print 'Copying kivy installation script {} -> {}'.format(src_install_script, dst_install_script)
        rc=os.system('cp {} {}'.format(src_install_script, dst_install_script))

        # run the KivyPie build and installation script
        rc=kivypie.execute('/bin/bash -c "cd /tmp ; ./{} {}"'.format(src_install_script, __kivy_github_version__))
        if rc:
            print 'ERROR: kivy installation script reported problems rc={}'.format(rc)

        # unmount the image
        if not kivypie.umount():
            print 'WARNING: Image is busy, most likely installation left some running processes, skipping conversion'
            sys.exit(1)

        # Convert the xsysroot image to a raw format ready to flash and boot
        qcow_image=kivypie.query('qcow_image')
        print 'Converting image {}...'.format(qcow_image)
        if os.path.isfile(output_image):
            os.unlink(output_image)

        rc = os.system('qemu-img convert {} {}'.format(qcow_image, output_image))

    time_end=time.time()
    print 'Process finished in {} secs - image ready at {}'.format(time_end - time_start, output_image)
    sys.exit(0)
