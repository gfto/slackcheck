#!/bin/sh
# SlackCheck
#
# $Id: slcheck.sh,v 1.29 2005/01/31 15:44:16 gf Exp $
#
# Copyright (c) 2002-2004 Georgi Chorbadzhiyski, Sofia, Bulgaria
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

echo "SlackCheck v3.40"
echo

cd $(dirname $0)

INC_CONFIG="0"
. ./config.sh

if [ "$INC_CONFIG" = "0" ]
then
	echo "*** Error including ./config.sh"
	exit
fi

# Show usage information
usage() {
	echo "Usage: $(basename $0) [options]"
	echo
	echo " OPTIONS:"
	echo
	echo "   --local           Operate on local machine"
	echo "   --host h1 h2 h3   Upgrade this host(s)"
	echo "     --file filename Read list of hosts from this file"
	echo
	echo "   --sync            Get latest list of packages from the WWW/FTP/Local file"
	echo
	echo "   --collect         Build package lists for hosts that'll be upgraded"
	echo
	echo "   --gen             Generate upgrade scripts"
	echo
	echo "   --upgrade         Upgrade hosts using generated scripts"
	echo "   --dist            Only copy upgrade scripts to hosts, do not updgrade"
	echo
	echo " HOW TO UPGRADE CURRENT HOST"
	echo "   Run:  $(basename $0) --local --sync --collect --gen --upgrade"
	echo
	echo " HOW TO UPGRADE MULTIPLE HOSTS:"
	echo "   Edit: \"update_hosts\" file to add your slackware machines"
	echo "   Run:  $(basename $0) --sync --collect --gen"
	echo "   Edit: ${DIR_UPD}/${FILE_UPDATES}*"
	echo "   Run:  $(basename $0) --upgrade (for automatic upgrade)"
	echo "    or"
	echo "   Run:  $(basename $0) --dist (for manual upgrade after that)"
	echo
	echo " HOW TO UPGRADE SINGLE HOST:"
	echo "   Run:  $(basename $0) --host blah.example.org --sync --collect --gen --upgrade"
	echo
	exit 1
}

# Get newest package list
sync_master_list() {
	echo "===> Getting newest package list..."
	mkdir $DIR_PKG 2>/dev/null
	cd $DIR_PKG
	TMPDIR=".Tmp"
	rm -rf $TMPDIR 2>/dev/null
	mkdir $TMPDIR && cd $TMPDIR

	${DL_PRG} ${DL_PRG_OPTS} ${DL_HOST}/CHECKSUMS.md5

	# Parse file
	grep .tgz$ CHECKSUMS.md5 | grep patches | cut -d" " -f3 | sed -e 's|.tgz||;s|\./||' > ../${FILE_NEWEST}
	grep .tgz$ CHECKSUMS.md5 | grep slackware | cut -d" " -f3 | sed -e 's|.tgz||;s|\./||' >> ../${FILE_NEWEST}
	if [ $(LANG=C ls -l ../${FILE_NEWEST} | tr -s ' ' | cut -d" " -f 5) = "0" ]
	then
		grep .tgz$ CHECKSUMS.md5 | cut -d" " -f3 | sed -e 's|.tgz||;s|\./||' >> ../${FILE_NEWEST}
	fi
	cd ..
	rm -rf $TMPDIR 2>/dev/null
}

# Generate list of packages for every host
collect_package_lists() {
	[ -d $DIR_PKG ] || mkdir -p $DIR_PKG
	echo "===> Collecting package lists..."
	for HOST in $SLACK_HOSTS
	do
		echo "  ---> $HOST"
		# Localhost
		if [ "$HOST" == "$(hostname)" -o \
		     "$HOST" == "$(hostname -f)" -o \
		     "$HOST" == "localhost" ]
		then
			ls /var/log/packages > ${DIR_PKG}/$HOST
		# Remote host
		else
			${RSH_LISTS} $HOST "ls /var/log/packages" > ${DIR_PKG}/${HOST}.tmp
			mv ${DIR_PKG}/${HOST}.tmp ${DIR_PKG}/${HOST} 2>/dev/null
		fi
	done
}

# Used by generate_upgrade_scripts()
package_name() {
	name=$(echo $1 | rev | cut -d- -f4- | rev)
	if [ "$name" = "" ]; then
		echo $1
	else
		echo $name
	fi
}

# Generate upgrade scripts
generate_upgrade_scripts() {
	mkdir ${DIR_UPD} 2>/dev/null
	echo "===> Generating upgrade scripts..."
	for HOST in $SLACK_HOSTS
	do
		# Check if package list exist
		if [ -f ${DIR_PKG}/${HOST} ]
		then
			echo -n "$HOST "
			# Cleanup old files
			rm ${DIR_UPD}/${FILE_UNKPACKS}${HOST}  >/dev/null 2>&1
			rm ${DIR_UPD}/${FILE_UPDATES}${HOST}   >/dev/null 2>&1
			rm ${DIR_UPD}/${FILE_UPDATES}${HOST}.* >/dev/null 2>&1
			# For each package, hostpkg is only package name, NO directories!
			cat ${DIR_PKG}/$HOST | grep -v aaa_elflibs | \
			while read hostpkg; do
				# Get package from the distro packages
				# This contains FULL directory + package name
				distro_package=$(grep /`package_name $hostpkg`-[0-9] ${DIR_PKG}/${FILE_NEWEST} | head -1 2>/dev/null)
				if [ "$distro_package" != "" ]
				then # Host package exist in the distro packages
					distropkg=$(basename $distro_package) # Strip directory
					if [ "$distropkg" != "$hostpkg" ]
					then
						echo "\
UPDATE=\"\$UPDATE ${distro_package}.tgz\" # EXISTING: ${hostpkg} \
" >> ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs
#						echo "New: $hostpkg -> $distropkg"
#					else
#						echo "Same: $hostpkg -> $distropkg"
					fi
				else # Add to unknown packages
#					echo "Unknown: $hostpkg"
					echo "$hostpkg" >> ${DIR_UPD}/${FILE_UNKPACKS}${HOST}
				fi
			done
			# Add intereter
			if [ -f ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs ]
			then
				sort ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs > .newpkgs.tmp
				cat .newpkgs.tmp > ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs
				rm .newpkgs.tmp
				(echo '#!/bin/sh'
				 echo
				 echo "DL_HOST=\"${DL_HOST}\""
				 echo "DL_PRG=\"${DL_PRG}\""
				 echo "DL_PRG_OPTS=\"${DL_PRG_OPTS}\""
				 echo
				 echo "MD5_CHECK=\"${MD5_CHECK}\""
				 echo "SIG_CHECK=\"${SIG_CHECK}\""
				 echo
				 echo "REMOTE_DIR=\"${REMOTE_DIR}\""
				 echo "REMOTE_DIR_DEL=\"${REMOTE_DIR_DEL}\""
				 echo
				 echo "SMART_UPGRADE=\"${SMART_UPGRADE}\""
				 echo
				 echo "GENERATED=\"1\""
				 echo
				 echo "# If you don't want package to be updated just delete the line."
				 echo
				 # Put glibc and elflibs updates first, otherwise
				 # something may broke
				 cat ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs | grep a/glibc
				 cat ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs | grep a/elflibs
				 cat ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs | grep a/pkgtools
				 cat ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs | \
					grep -v a/glibc | \
					grep -v a/elflibs | \
					grep -v a/pkgtools
				 # workarounds
				 echo "PKG_SED=\"`grep sed- ${DIR_PKG}/${FILE_NEWEST} 2>/dev/null`\"";
				 echo "PKG_COREUTILS=\"`grep coreutils- ${DIR_PKG}/${FILE_NEWEST} 2>/dev/null`\"";
				 echo "PKG_UTEMPTER=\"`grep utempter- ${DIR_PKG}/${FILE_NEWEST} 2>/dev/null`\"";
				 echo "PKG_MODULEINITTOOLS=\"`grep module-init-tools- ${DIR_PKG}/${FILE_NEWEST} 2>/dev/null`\"";
				 echo "PKG_AAAELFLIBS=\"`grep aaa_elflibs- ${DIR_PKG}/${FILE_NEWEST} 2>/dev/null`\"";
				 echo
				 grep -v ^# update_script.sh
				) > ${DIR_UPD}/${FILE_UPDATES}${HOST}
			fi
			# Cleanup
			rm ${DIR_UPD}/${FILE_UPDATES}${HOST}.newpkgs >/dev/null 2>&1
		fi
	done
	echo
}

# Upgrade remote hosts
upgrade_machines() {
	NOW=$(date +%Y-%m-%d)
	echo "===> Upgrating hosts..."
	for HOST in $SLACK_HOSTS
	do
		if [ -f ${DIR_UPD}/${FILE_UPDATES}${HOST} ]
		then
			# Localhost
			if [ "$HOST" == "$(hostname)" -o \
			     "$HOST" == "$(hostname -f)" -o \
			     "$HOST" == "localhost" ]
			then
				echo "  ---> $HOST (Local machine)"
				# Use su if we're running not as root
				if [ "$(id -u)" != "0" ]; then
					echo "       Enter root password"
					su -c "/bin/sh ${DIR_UPD}/${FILE_UPDATES}${HOST}"
				else
					/bin/sh ${DIR_UPD}/${FILE_UPDATES}${HOST}
				fi
			# Remote host
			else
				echo "  ---> $HOST"
				cat ${DIR_UPD}/${FILE_UPDATES}${HOST} | \
					${RSH_UPGRADE} ${HOST} \
						"cat - > ${FILE_UPDATES}${HOST}_${NOW}; \
						/bin/sh ${FILE_UPDATES}${HOST}_${NOW};"
			fi
		fi
	done
}

# Send upgrade scripts to hosts
distribute_up_scripts() {
	NOW=$(date +%Y-%m-%d)
	echo "===> Copying upgrade scripts..."
	for HOST in $SLACK_HOSTS
	do
		if [ -f ${DIR_UPD}/${FILE_UPDATES}${HOST} ]
		then
			# Localhost
			if [ "$HOST" == "$(hostname)" -o \
			     "$HOST" == "$(hostname -f)" -o \
			     "$HOST" == "localhost" ]
			then
				echo "  ---> $HOST (Local machine - no need to copy upgrade script)"
			# Remote host
			else
				echo "  ---> $HOST"
				cat ${DIR_UPD}/${FILE_UPDATES}${HOST} | \
					${RSH_UPGRADE} ${HOST} \
						"cat - > ${FILE_UPDATES}${HOST}_${NOW}"
			fi
		fi
	done
}

if [ "$1" = "" ]; then
	usage
fi

# Process command line arguments
while [ "$1" != "" ]; do
	param=$1
	shift
	case "$param" in
		--local)
			SLACK_HOSTS="localhost"
		;;
		--host)
			if [ "$1" != "" ]; then
				SLACK_HOSTS=""
			fi
			while [ "$1" != "" ]; do
				param=$1
				case "$param" in
					--*)
						break
					;;
					*)
						SLACK_HOSTS="$SLACK_HOSTS $param"
					;;
				esac
				shift
			done
		;;
		--file)
			HOSTS_FILE="$1"
			if [ "$HOSTS_FILE" = "" -o ! -f "$HOSTS_FILE" ]; then
				echo "*** --file parameter is missing or file not found."
				echo
				usage
				exit 1
			fi
			SLACK_HOSTS=`grep -v ^# $HOSTS_FILE`
			shift
		;;
		--sync)
			DO_SYNC="1"
		;;
		--collect)
			DO_COLLECT="1"
		;;
		--gen)
			DO_GEN="1"
		;;
		--dist)
			DO_DIST="1"
		;;
		--upgrade)
			DO_UPGRADE="1"
		;;
		*)
			usage
		;;
	esac
done

if [ "$SLACK_HOSTS" = "" ]; then
	echo "*** No hosts. Check --host parameter, --file parameter ot 'upgrade_hosts' file."
	echo
	exit 1
fi

echo -n "---> Hosts: "
echo $SLACK_HOSTS
echo

[ "$DO_SYNC"    = "1" ] && (sync_master_list)
[ "$DO_COLLECT" = "1" ] && (collect_package_lists)
[ "$DO_GEN"     = "1" ] && (generate_upgrade_scripts)
[ "$DO_DIST"    = "1" ] && (distribute_up_scripts)
[ "$DO_UPGRADE" = "1" ] && (upgrade_machines)

