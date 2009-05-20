#!/bin/sh
# Upgrade script template
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

PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"
export PATH

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
		echo "*** Get slackware's public key from here:"
		echo "*** http://www.slackware.com/gpg-key"
		echo "*** After obtaining the key, execute 'gpg --import gpg-key'"
		echo
		SIG_CHECK="0"
	fi
fi

pkg_install() {
	MSG="$1"
	PKG="$2"
	echo $MSG
	$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$PKG
	installpkg `basename $PKG`
}

pkg_upgrade() {
	MSG="$1"
	PKG="$2"
	OLD="$3"
	echo $MSG
	$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$PKG
	upgradepkg ${OLD}%`basename $PKG`
}

mkdir ${REMOTE_DIR} 2>/dev/null

(
	# Get, verify and update packages
	set -e # Halt on any error
	cd ${REMOTE_DIR}
	if [ "$MD5_CHECK" == "1" ]; then
		if [ ! -f CHECKSUMS.md5 ]; then
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/CHECKSUMS.md5
		fi
	fi

	echo "===> Getting packages..."
	for PKG in $UPDATE; do
		pkgfile=`basename $PKG`
		if [ ! -f $pkgfile ]; then
			echo "   - Getting $PKG"
			$DL_PRG $DL_PRG_OPTS ${DL_HOST}/$PKG
		else
			echo "  -> $pkgfile already exists."
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
				grep /$pkgfile CHECKSUMS.md5 | head -1 | sed -e 's|\./.*/||' > ${pkgfile}.md5
			else
				grep /$pkgfile CHECKSUMS.md5 | head -1 | sed -e 's|\./.*/||' | grep -v .asc$ > ${pkgfile}.md5
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
	# UGLY HACK #2, to upgrade from 12.1 to -current you need
	# libxz because of lzma compression of newer packages
	if [ "$PKG_XZ" != "" -a ! -x "/bin/xz" ]; then
		pkg_install "xz is not installed. Installing it." $PKG_XZ
	fi
	if [ "$PKG_LIBCAP" != "" -a ! -f "lib/libcap.a" ]; then
		pkg_install "libcap is not installed. Installing it." $PKG_LIBCAP
	fi
	for PKG in $UPDATE; do
		pkgfile=`basename $PKG | sed -e 's|\.t[a-z]z$||'`
		upgradepkg ${pkgfile}.t?z
		# UGLY HACK! sed was split from 'bin' package and
		# upgrading 'bin' package will cause sed to dissapear
		# however sed is used by pkgtools so this hack is needed
		# to allow clear 8.1 -> 9.0 upgrading
		if [ ! -x "/usr/bin/sed" ]; then
			pkg_install "Sed is not installed. Installing it." $PKG_SED
		fi
	done

	# Workaround for aaa_elflibs, for more info see
	# slackware-current ChangeLog (Mon Dec 15 17:49:23 PST 2003)
	if [ "$PKG_AAAELFLIBS" != "" ]; then
		if [ "`ls /var/adm/packages/aaa_elflibs-* 2>/dev/null`" = "" -a \
		     "`ls /var/adm/packages/elflibs-* 2>/dev/null`" != "" ]
		then
			pkg_upgrade "Replacing elflibs packaet with aaa_elflibs." $PKG_AAAELFLIBS elflibs
		fi
	fi

	# Workaround for coreutils, for more info see
	# slackware-current ChangeLog (Wed May 21 16:05:37 PDT 2003)
	if [ "$PKG_COREUTILS" != "" ]; then
		if [ "`ls /var/adm/packages/coreutils-* 2>/dev/null`" = "" ]; then
			pkg_install "Coreutils package is not installed! Installing it." $PKG_COREUTILS
			removepkg fileutils
			removepkg textutils
			removepkg sh-utils
		fi
	fi

	# Replace modutils with module-init-tools, for more info see
	# slackware-current ChangeLog (Thu Sep 4 19:40:01 PDT 2003)
	if [ "$PKG_MODULEINITTOOLS" != "" ]; then
		if [ "`ls /var/adm/packages/module-init-tools-* 2>/dev/null`" = "" -a \
		     "`ls /var/adm/packages/modutils-* 2>/dev/null`" != "" ]; then
			pkg_upgrade "module-init-tools package is not installed! Installing it." $PKG_MODULEINITTOOLS modutils
		fi
	fi

	# Workaround for utempter, for more info see
	# slackware-current ChangeLog (Sun Jun 8 20:53:01 PDT 2003)
	if [ "$PKG_UTEMPTER" != "" ]; then
		if [ "`ls /var/adm/packages/utempter-* 2>/dev/null`" = "" ]; then
			pkg_install "Utempter package is not installed! Installing it." $PKG_UTEMPTER
		fi
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

	if [ "$REMOTE_DIR_DEL" = "1" ]; then
		echo "===> Deleting '${REMOTE_DIR}' directory..."
		cd ..
		rm -rfv ${REMOTE_DIR}
	fi
)
