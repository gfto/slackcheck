#!/bin/sh
# Upgrade script template
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

	# *******************
	#  THE UPDATE SCRIPT
	# *******************
if [ "$GENERATED" != "1" ]; then
	echo "Use slcheck.sh to generate upgrade scripts!"
	exit
fi

which wget >/dev/null 2>&1
if [ $? != 0 ]; then
	echo "Can't find \"wget\" in $PATH. Exiting."
	exit 1
fi

which md5sum >/dev/null 2>&1
if [ $? != 0 ]; then
	echo "WARN: Can't find \"md5sum\" MD5 sums will not be checked"
	MD5_CHECK="0"
fi

which gpg >/dev/null 2>&1
if [ $? != 0 ]; then
	echo "WARN: Can't find \"gpg\" digital signatures will not be checked"
	SIG_CHECK="0"
fi

if [ "$SIG_CHECK" == "1" ]; then
	gpg --list-sigs | grep security@slackware.comm >/dev/null
	if [ $? != 0 ]; then
		echo "WARN: You don't have the public key of 'security@slackware.com'"
		echo "WARN: Digital signatures can not be verified"
		echo "WARN: Download slackware's public key from here:"
		echo "WARN: ftp://ftp.slackware.com/pub/slackware/slackware-current/GPG-KEY"
		echo "WARN: After obtaining the key, execute 'gpg --import GPG-KEY'"
		SIG_CHECK="0"
	fi
fi

function sig_check() {
	fname=$1
	if [ "$SIG_CHECK" == "1" ]; then
		echo "INFO: Checking digital signature of $fname"
		gpg --verify ${fname}.asc
	fi
}

function md5_check() {
	if [ "$MD5_CHECK" == "1" ]; then
		grep $pkgfile CHECKSUMS.md5 | sed -e 's|\./.*/||' > ${pkgfile}.md5
		echo "INFO: Checking MD5 sums"
		md5sum -c ${pkgfile}.md5
	fi
}

mkdir ${REMOTE_DIR} 2>/dev/null

(
	# Download, verify and update packages
	set -e # Halt on any error
	cd ${REMOTE_DIR}
	if [ ! -f CHECKSUMS.md5 ]; then
		$DL_PRG $DL_PRG_OPTS ${DL_HOST}/CHECKSUMS.md5
	fi

	echo "*** Downloading packages *** "
	for PKG in $UPDATE
	do
		pkgfile=`basename $PKG`
		if [ ! -f $pkgfile ]; then
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$PKG
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$PKG.asc
		fi
		md5_check ${pkgfile}
		sig_check ${pkgfile}
	done

	echo "*** Upgrating packages *** "
	for PKG in $UPDATE
	do
		pkgfile=`basename $PKG`
		if [ ! -f $pkgfile ]; then
			upgradepkg ${pkgfile}
		fi
	done
	if [ "$REMOTE_DIR_DEL" = "1" ]; then
		echo "INFO: Cleanup"
		cd ..
		rm -rfv ${REMOTE_DIR}
	fi
)

