#!/bin/sh
# SlackCheck configuration file
#
# $Id: config.sh,v 1.7 2003/04/09 14:25:10 gf Exp $
#

PATH="/bin:/usr/bin:/usr/local/bin"

# Can be 8.1, 9.0 or current
SLACK_VER="current"

# Where to look for upgrades
# *** If you want patches directory to be checked this directory
# *** must point to / directory of the slackware mirror. Not slackware/
# *** directory.
DL_HOST="http://mirrors.unixsol.org/slackware/slackware-${SLACK_VER}"
#DL_HOST="http://www.slackware.no/slackware/slackware-${SLACK_VER}"
#DL_HOST="http://www.slackware.at/data/slackware-${SLACK_VER}"
#DL_HOST="ftp://ftp.slackware.com/pub/slackware/slackware-${SLACK_VER}"
#DL_HOST="http://ftp.planetmirror.com/pub/slackware/slackware-${SLACK_VER}"

# Set variable to "0" if you dont want some of the functionality

MD5_CHECK="1"             # Check md5 sums of downloaded packages
SIG_CHECK="1"             # Check digital signatures of downloaded packages
HOSTS_FILE="update_hosts" # In this file are listed hosts that will be upgraded
REMOTE_DIR="Updates"      # Upgraded packages will be downloaded in this
                          # directory on the remote machine.
                          # Make sure it has enough disk space!
                          # After generating upgrade scripts you can change
                          # this variable per host
REMOTE_DIR_DEL="1"        # Delete directory with downloaded packages after
                          # finishing updates

SMART_UPGRADE="1"         # When lilo-* or kernel-* packages are updated run
                          # "lilo" command. If lilo is not run after upgrading
                          # these packages, your system probably wont boot.

# This program will be used to download files from web
DL_PRG="wget"

# Non-verbose mode of the new wget is fucked up. It shows what is downloaded
# after finishing the download and I think thats very irritating
#DL_PRG_OPTS="-nv"

# Used for ftp downloads
echo $DL_HOST | grep ^ftp://
if [ $? = 0 ]; then
	DL_PRG="wget"
	DL_PRG_OPTS="--passive"
#	DL_PRG_OPTS="-nv --passive"
fi

# These programs will be used in collection and updating hosts
RSH_LISTS="ssh"
RSH_UPGRADE="ssh -l root"

# NO NEED TO TOUCH ANYTHING BELLOW THIS LINE :)

SLACK_HOSTS=`grep -v ^# $HOSTS_FILE`
[ $? = 0 ] || exit

DIR_PKG="packages"        # Package lists directory
DIR_UPD="updates"         # Update scripts directory

FILE_NEWEST="PKG_LAST"    # Latest packages filename
FILE_UNKPACKS="Non_dist-" # Non distro packages per host
FILE_UPDATES="Updates-"   # Update script per host

if [ "$INC_CONFIG" != "0" ]
then
	echo "Do not run $0 directly. Run ./slcheck.sh instead!"
fi
INC_CONFIG="1"

