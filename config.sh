#!/bin/sh
# SlackCheck configuration file
#
# $Id: config.sh,v 1.1 2003/01/05 08:26:12 gf Exp $
#

PATH="/bin:/usr/bin:/usr/local/bin"

# Hosts that will be updated
SLACK_HOSTS="router ns work man host gf pl300 sounder game noname"

# Where to look for updates
DL_HOST="http://mirrors.unixsol.org/slackware/current/slackware"
#DL_HOST="http://www.slackware.at/data/slackware-current/slackware"
#DL_HOST="http://ftp.planetmirror.com/pub/slackware/slackware-current/slackware"
#DL_HOST="ftp://ftp.slackware.com/pub/slackware/slackware-current/slackware"

# This program will be used to download files from web
DL_PRG="wget"
DL_PRG_OPTS="-nv"

# Used for ftp downloads
echo $DL_HOST | grep ^ftp://
if [ $? = 0 ]
then
	DL_PRG="wget"
	DL_PRG_OPTS="-nv --passive"
fi

# These programs will be used in collection and updating hosts
RSH_LISTS="ssh"
RSH_UPGRADE="ssh -l root"

# NO NEED TO TOUCH ANYTHING BELLOW THIS LINE :)
DIR_PKG="packages"        # Package lists directory
DIR_UPD="updates"         # Update scripts directory

FILE_NEWEST="PKG_LAST"    # Latest packages filename
FILE_UNKPACKS="Non_dist-" # Non distro packages per host
FILE_UPDATES="Updates-"   # Update script per host

REMOTE_DIR="Updates"      # Upgrated packages will be DLed here (on the remote machine)

if [ "$INC_CONFIG" != "0" ]
then
	echo "Do not run $0 directly. Run ./slcheck.sh instead!"
fi
INC_CONFIG="1"

