#!/bin/bash
#
#  Builds KivyPie from scratch, then runs basic tests.
#

logfile=build.log

echo "Building KivyPie - follow progress at $logfile..."
python -u build_kivypie.py --build-all > $logfile 2>&1
./test_image.sh >> $logfile 2>&1
