#!/bin/sh
# Get the online version of the GnuPG software version database
# Copyright (C) 2014  Werner Koch
#
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# The URL of the file to retrieve.
urlbase="https://www.gnupg.org/"

WGET=wget
GPGV=gpgv

srcdir=$(dirname "$0")
distsigkey="$srcdir/../g10/distsigkey.gpg"

# Convert a 3 part version number it a numeric value.
cvtver () {
  awk 'NR==1 {split($NF,A,".");X=1000000*A[1]+1000*A[2]+A[3];print X;exit 0}'
}

# Prints usage information.
usage()
{
    cat <<EOF
Usage: $(basename $0) [OPTIONS]
Get the online version of the GnuPG software version database
Options:
    --skip-download  Assume download has already been done.
    --help           Print this help.
EOF
    exit $1
}

#
# Parse options
#
skip_download=no
while test $# -gt 0; do
    case "$1" in
	# Set up `optarg'.
	--*=*)
	    optarg=`echo "$1" | sed 's/[-_a-zA-Z0-9]*=//'`
	    ;;
	*)
	    optarg=""
	    ;;
    esac

    case $1 in
        --help|-h)
	    usage 0
	    ;;
        --skip-download)
            skip_download=yes
            ;;
	*)
	    usage 1 1>&2
	    ;;
    esac
    shift
done

# Get GnuPG version from VERSIOn file.  For a GIT checkout this means
# that ./autogen.sh must have been run first.  For a regular tarball
# VERSION is always available.
if [ ! -f "$srcdir/../VERSION" ]; then
    echo "VERSION file missing - run autogen.sh first." >&2
    exit 1
fi
version=$(cat "$srcdir/../VERSION")
version_num=$(echo "$version" | cvtver)

#
# Download the list and verify.
#
if [ $skip_download = yes ]; then
  if [ ! -f swdb.lst ]; then
      echo "swdb.lst is missing." >&2
      exit 1
  fi
  if [ ! -f swdb.lst.sig ]; then
      echo "swdb.lst.sig is missing." >&2
      exit 1
  fi
else
  if ! $WGET -q -O swdb.lst "$urlbase/swdb.lst" ; then
      echo "download of swdb.lst failed." >&2
      exit 1
  fi
  if ! $WGET -q -O swdb.lst.sig "$urlbase/swdb.lst.sig" ; then
      echo "download of swdb.lst.sig failed." >&2
      exit 1
  fi
fi
if ! $GPGV --keyring "$distsigkey" swdb.lst.sig swdb.lst; then
    echo "list of software versions is not valid!" >&2
    exit 1
fi

#
# Check that the online version of GnuPG is not less than this version
# to help detect rollback attacks.
#
gnupg_ver=$(awk '$1=="gnupg21_ver" {print $2;exit}' swdb.lst)
if [ -z "$gnupg_ver" ]; then
    echo "GnuPG 2.1 version missing in swdb.lst!" >&2
    exit 1
fi
gnupg_ver_num=$(echo "$gnupg_ver" | cvtver)
if [ $(( $gnupg_ver_num >= $version_num )) = 0 ]; then
    echo "GnuPG version in swdb.lst is less than this version!" >&2
    echo "  This version: $version" >&2
    echo "  SWDB version: $gnupg_ver" >&2
    exit 1
fi