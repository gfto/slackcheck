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

which $DL_PRG >/dev/null 2>&1
if [ $? != 0 ]; then
	echo "*** Can't find \"$DL_PRG\" in $PATH. Exiting."
	echo
	exit 1
fi

if [ "$MD5_CHECK" == "1" ]; then
	which md5sum >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "*** Can't find \"md5sum\" MD5 sums will not be checked"
		echo
		MD5_CHECK="0"
	fi
fi

if [ "$SIG_CHECK" == "1" ]; then
	which gpg >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "*** Can't find \"gpg\" digital signatures will not be checked"
		echo
		SIG_CHECK="0"
	fi
fi

if [ "$SIG_CHECK" == "1" ]; then
	gpg --list-sigs | grep security@slackware.com >/dev/null
	if [ $? != 0 ]; then
		echo "*** You don't have the public key of 'security@slackware.com'"
		echo "*** Digital signatures can not be verified"
		echo "*** Download slackware's public key from here:"
		echo "*** http://www.slackware.com/gpg-key"
		echo "*** After obtaining the key, execute 'gpg --import gpg-key'"
		echo
		SIG_CHECK="0"
	fi
fi

mkdir ${REMOTE_DIR} 2>/dev/null

(
	# Download, verify and update packages
	set -e # Halt on any error
	cd ${REMOTE_DIR}
	if [ "$MD5_CHECK" == "1" ]; then
		if [ ! -f CHECKSUMS.md5 ]; then
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/CHECKSUMS.md5
		fi
	fi

	echo "===> Downloading packages..."
	for PKG in $UPDATE; do
		pkgfile=`basename $PKG`
		if [ ! -f $pkgfile ]; then
			echo "   - Downloading $PKG"
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$PKG
		else
			echo " -> $pkgfile already exists."
		fi
		if [ "$SIG_CHECK" == "1" ]; then
			if [ ! -f $pkgfile.asc ]; then
				$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$PKG.asc
			fi
		fi
	done

	if [ "$MD5_CHECK" == "1" ]; then
		echo "===> Checking MD5 sums..."
		for PKG in $UPDATE; do
			pkgfile=`basename $PKG`
			if [ "$SIG_CHECK" == "1" ]; then
				grep /$pkgfile CHECKSUMS.md5 | sed -e 's|\./.*/||' > ${pkgfile}.md5
			else
				grep /$pkgfile CHECKSUMS.md5 | sed -e 's|\./.*/||' | grep -v .asc$ > ${pkgfile}.md5
			fi
			md5sum -c ${pkgfile}.md5
		done
	fi

	if [ "$SIG_CHECK" == "1" ]; then
		echo "===> Checking digital signatures..."
		for PKG in $UPDATE; do
			pkgfile=`basename $PKG`
			echo " -> Checking digital signature of $pkgfile:"
			gpg --verify ${pkgfile}.asc
		done
	fi

	echo "===> Upgrating packages..."
	for PKG in $UPDATE; do
		pkgfile=`basename $PKG`
		upgradepkg ${pkgfile}
		# UGLY HACK! sed was split from 'bin' package and
		# upgrading 'bin' package will cause sed to dissapear
		# however sed is used by pkgtools so this hack is needed
		# to allow clear 8.1 -> 9.0 upgrading
		if [ "`which sed 2>/dev/null`" != "/usr/bin/sed" ]; then
			echo "Bin upgraded! sed needs to be installed."
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$SED_PKG.tgz
			installpkg `basename $SED_PKG`
		fi
	done

	# Workaround for coreutils, for more info see
	# slackware-crrent ChangeLog (Wed May 21 16:05:37 PDT 2003)
	if [ "$COREUTILS_PKG" != "" ]; then
		# If coreutils are not yet installed, install them
		# and remove fileutils, textutils and sh-utils packages
		if [ "`ls /var/adm/packages/coreutils-* 2>/dev/null`" = "" ]
		then
			echo "Coreutils package is not installed! Installing it."
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$COREUTILS_PKG.tgz
			installpkg `basename $COREUTILS_PKG`
			removepkg fileutils
			removepkg textutils
			removepkg sh-utils
		fi
	fi

	if [ "$REMOTE_DIR_DEL" = "1" ]; then
		echo "===> Deleting '${REMOTE_DIR}' directory..."
		cd ..
		rm -rfv ${REMOTE_DIR}
	fi

	if [ "$SMART_UPGRADE" = "1" ]; then
		echo "===> Finishing upgrades..."
		LILO_UPGRADED="0"
		KERNEL_UPGRADED="0"
		echo $UPDATE | grep lilo-   >/dev/null 2>&1 && LILO_UPGRADED="1"
		echo $UPDATE | grep kernel- >/dev/null 2>&1 && KERNEL_UPGRADED="1"
		if [ "$LILO_UPGRADED" = "1" -o "$KERNEL_UPGRADED" = "1" ]; then
			echo " -> lilo or kernel were upgraded. Running '/sbin/lilo'..."
			/sbin/lilo
		fi
	fi
)

