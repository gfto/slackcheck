#!/bin/sh
# SlackCheck
#
# $Id: slcheck.sh,v 1.3 2003/03/07 10:07:54 gf Exp $
#
# Copyright (c) 2002 Georgi Chorbadzhiyski, Sofia, Bulgaria
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

echo "SlackCheck v1.00"
echo

cd $(dirname $0)

INC_CONFIG="0"
. ./config.sh

if [ "$INC_CONFIG" = "0" ]
then
	echo "Error including ./config.sh"
	exit
fi

VALID_OPTS="--sync --collect --gen --dist --upgrade"

# Show usage information
usage() {
	echo "Usage: $(basename $0) [options]"
	echo
	echo " OPTIONS:"
	echo "   --sync      Get newest list of packages"
	echo "   --collect   Collect list of installed packages from hosts"
	echo "   --gen       Generate upgrade scripts"
	echo "   --dist      Copy upgrade scripts to hosts"
	echo "   --upgrade   Upgrade hosts using generated scripts"
	echo
	echo " MAIN CONFIGURATION (to change edit config.sh):"
	echo "    Hosts that will be upgraded:"
	echo "        $SLACK_HOSTS"
	echo
	echo "    Packages are downloaded from:"
	echo "        $DL_HOST"
	echo
	echo " QUICK USAGE:"
	echo "   Run:  $(basename $0) --sync --collect --gen"
	echo "   Edit: ${DIR_UPD}/${FILE_UPDATES}*"
	echo "   Run:  $(basename $0) --dist (for manual upgrade after that)"
	echo "    or"
	echo "   Run:  $(basename $0) --upgrade (for automatic upgrade)"
	echo
	exit 1
}

# Download newest package list
sync_master_list() {
	echo "Getting newest package list."
	mkdir $DIR_PKG 2>/dev/null
	cd $DIR_PKG
	TMPDIR=".Tmp"
	rm -rf $TMPDIR 2>/dev/null
	mkdir $TMPDIR && cd $TMPDIR
	# The actual download
	${DL_PRG} ${DL_PRG_OPTS} ${DL_HOST}/CHECKSUMS.md5
	# Parse file
	grep .tgz$ CHECKSUMS.md5 | cut -d" " -f3 | sed -e 's|.tgz||;s|\./||' > ../${FILE_NEWEST}
	cd ..
	rm -rf $TMPDIR 2>/dev/null
}

# Generate list of packages for every host
collect_package_lists() {
	[ -d $DIR_PKG ] || mkdir -p $DIR_PKG
	for HOST in $SLACK_HOSTS
	do
		echo -n "Collection package list from \"$HOST\". "
		# Localhost
		if [ "$HOST" == "$(hostname)" -o "$HOST" == "$(hostname -a)" ]; then
			ls /var/log/packages > ${DIR_PKG}/$HOST
		# Remote host
		else
			${RSH_LISTS} $HOST "ls /var/log/packages" > ${DIR_PKG}/${HOST}.tmp
			mv ${DIR_PKG}/${HOST}.tmp ${DIR_PKG}/${HOST} 2>/dev/null
		fi
		echo "Done."
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
	for i in $SLACK_HOSTS
	do
		# Remove directory
		host=$(echo $i | cut -d/ -f2)
		# Check if package list exist
		if [ -f ${DIR_PKG}/${host} ]
		then
			echo -n "Generating upgrade script for \"$host\". "
			# Cleanup old files
			rm ${DIR_UPD}/${FILE_UNKPACKS}${host}  >/dev/null 2>&1
			rm ${DIR_UPD}/${FILE_UPDATES}${host}   >/dev/null 2>&1
			rm ${DIR_UPD}/${FILE_UPDATES}${host}.* >/dev/null 2>&1
			# For each package
			while read mypack; do
				mypack=$(echo "$mypack" | tr -s ' ' | cut -d" " -f11)
				# Check if package exist in the distro packages
				grep $mypack ${DIR_PKG}/${FILE_NEWEST} >/dev/null 2>&1
				if [ $? != 0 ]
				then
					pkgname=$(package_name $mypack)
					newpkg=$(grep /${pkgname}-[0-9] ${DIR_PKG}/${FILE_NEWEST})
					if [ $? = 0 ]
					then
						newpkg=$(echo $newpkg | cut -f1 -d" ")
						pkgdir=$(dirname $newpkg)
						pkgname=$(basename $newpkg)
						tgz="${pkgname}.tgz"
						tgzpath="${pkgdir}/${pkgname}.tgz"
						echo "\
[ -f ${tgz} ] || ${DL_PRG} ${DL_PRG_OPTS} \${URL}/${tgzpath}" \
							>> ${DIR_UPD}/${FILE_UPDATES}${host}.get

						echo "\
[ -f ${tgz} ] && upgradepkg ${pkgname} # EXISTING: ${mypack}" \
							>> ${DIR_UPD}/${FILE_UPDATES}${host}.up
					# Add to unknown packages
					else
						echo "$mypack" >> ${DIR_UPD}/${FILE_UNKPACKS}${host}
					fi
				fi
			done < ${DIR_PKG}/$i
			# Add intereter
			if [ -f ${DIR_UPD}/${FILE_UPDATES}${host}.get ]
			then
				(echo '#!/bin/sh'
				 echo
				 echo "which ${DL_PRG} >/dev/null 2>&1"
				 echo "if [ \$? != 0 ]; then"
				 echo "	echo \"Can't find \\\"${DL_PRG}\\\" in \$PATH. Exiting.\""
				 echo "	exit 1"
				 echo "fi"
				 echo
				 echo "URL=\"${DL_HOST}\""
				 echo
				 echo "rm -rf ${REMOTE_DIR} 2>/dev/null"
				 echo "mkdir ${REMOTE_DIR} && cd ${REMOTE_DIR}"
				 echo
				 cat ${DIR_UPD}/${FILE_UPDATES}${host}.get
				 echo
				 cat ${DIR_UPD}/${FILE_UPDATES}${host}.up
				 echo
				 echo "cd .."
				 echo "rm -rf ${REMOTE_DIR} 2>/dev/null"
				 echo
				) > ${DIR_UPD}/${FILE_UPDATES}${host}
			fi
			# Cleanup
			rm ${DIR_UPD}/${FILE_UPDATES}${host}.* >/dev/null 2>&1
			echo "Done."
		fi
	done
}

# Upgrade remote hosts
upgrade_machines() {
	NOW=$(date +%Y-%m-%d)
	for HOST in $SLACK_HOSTS
	do
		if [ -f ${DIR_UPD}/${FILE_UPDATES}${HOST} ]
		then
			echo "Upgrating \"$HOST\". "
			cat ${DIR_UPD}/${FILE_UPDATES}${HOST} | \
				${RSH_UPGRADE} ${HOST} \
					"cat - > ${FILE_UPDATES}${HOST}_${NOW}; \
					/bin/sh ${FILE_UPDATES}${HOST}_${NOW};"
		fi
	done
}

# Send upgrade scripts to hosts
distribute_up_scripts() {
	NOW=$(date +%Y-%m-%d)
	for HOST in $SLACK_HOSTS
	do
		if [ -f ${DIR_UPD}/${FILE_UPDATES}${HOST} ]
		then
			echo "Copying upgrade script to \"$HOST\". "
			cat ${DIR_UPD}/${FILE_UPDATES}${HOST} | \
				${RSH_UPGRADE} ${HOST} \
					"cat - > ${FILE_UPDATES}${HOST}_${NOW}"
		fi
	done
}

# Check validity of command line arguments
[ $# -lt 1 ] && usage
for opt in $@; do
	ok="0"
	for valid in $VALID_OPTS; do
		if [ "$valid" = "$opt" ]; then
			ok="1"
			break
		fi
	done
	[ "$ok" = "0" ] && echo "Unknown parameter: $opt"
	[ "$ok" = "0" ] && usage
done

# Process command line arguments
while [ "$1" != "" ]; do
	param=$1
	shift
	case "$param" in
		--sync)
			(sync_master_list)
		;;
		--collect)
			(collect_package_lists)
		;;
		--gen)
			(generate_upgrade_scripts)
		;;
		--dist)
			(distribute_up_scripts)
		;;
		--upgrade)
			(upgrade_machines)
		;;
		*)
			usage
		;;
	esac
done

