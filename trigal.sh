#!/bin/bash

#
# Trivial Gallery - https://github.com/tokee/trigal
#
# Very simple gallery generator that produces static web pages.
#

pushd $(dirname "$0") > /dev/null
PWD="`pwd`"
popd > /dev/null

if [ -s $PWD/trigal.conf ]; then
    source $PWD/trigal.conf
fi
if [ -s trigal.conf ]; then
    source trigal.conf
fi

function usage() {
    cat <<EOF
./trigal.sh [-s sourcefolder]

-s source
The source of the images. If not present, this will be the same as the 
destination. If neither the source, nor the destination is specified, they
will both be the current folder.

-d destination
Where to generate the gallery. If not present, this will be the same as the
source. If neither the source, nor the destination is specified, they will 
both be the current folder.

-f
If defined, copy the full version of the source images to the destination and 
provide links to the full versions. If source == destination, the files will 
not be touched.

-z
If defined, provide a ZIP file with the source images.

-t WxH
The thumbnail size, for example 240x180. The thumbnail is padded to force the
exact size. Default is 240x180.

-p WxH
The presentation size, for example 2000x2000. These are maximum sizes.
Source image ascpects will be preserved. Default is 2000x2000

-qt quality
JPEG quality (1-100) for thumbs. 50-80 are sane values. Default=70.

-qp quality
JPEG quality (1-100) for presentation images. 60-90 are sane values. Default=80.

-r
If defined, the order of sub-folders and images will be reverse alphanumerical.

-n
If defined, attempt to create safe file names (no spaces, ASCII-letters etc.).

-t template
The folder with the template used for generating the web pages.

-nc
If defined, don't copy script, setup and all support files to destination folder.
Copying makes it possible to update the generated gallery by executing 
trigal/trigal.shin the destination folder.
EOF
}

function dump_settings()  {
    cat <<EOF
export SOURCE="$SOURCE"
export DEST="$SOURCE"
export FULL_COPY=$FULL_COPY
export ZIP=$ZIP
export THUMB_SIZE=$THUMB_SIZE
export THUMB_QUALITY=$THUMB_QUALITY
export PRESENTATION_SIZE=$PRESENTATION_SIZE
export PRESENTATION_QUALITY=$PRESENTATION_QUALITY
export REVERSE_SORT=$REVERSE_SORT
export SANE_NAMES=$SANE_NAMES
export TEMPLATE="$TEMPLATE"
export TRIGAL_COPY=$TRIGAL_COPY
EOF
}

function get_arguments() {
    # http://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    while [[ "$#" > 1 ]]; do
        case $1 in
            -s) SOURCE="$2"; shift;;
            -d) DEST="$2"; shift;;
            -f) FULL_COPY=true;;
            -z) ZIP=true;;
            -t) THUMB_SIZE=$2; shift;;
            -qt) THUMB_QUALITY=$2; shift;;
            -p) PRESENTATION_SIZE=$2; shift;;
            -qp) PRESENTATION_QUALITY=$2; shift;;
            -r) REVERSE_SORT=true;;
            -n) SANE_NAMES=true;;
            -t) TEMPLATE="$2"; shift;;
            -nc) TRIGAL_COPY=false; shift;;
            *) echo "Unknown parameter: $1" ; break;;
        esac; shift
    done
    
    _=${SOURCE:="$DEST"}
    _=${DEST:="$SOURCE"}
    if [ -z "$SOURCE" -a -z "$DEST" ]; then
        # No source or dest
        if [ "$PWD" == "`pwd`" ]; then
            # Inside trigal folder. Get out!
            pushd ../ > /dev/null
            SOURCE="`pwd`"
            popd > /dev/null
        else
            SOURCE="`pwd`"
        fi
        DEST="$SOURCE"
    fi
    _=${FULL_COPY:=false}
    _=${ZIP:=false}
    _=${THUMB_SIZE:=240x180}
    _=${THUMB_QUALITY:=70}
    _=${PRESENTATION_SIZE:=2000x2000}
    _=${PRESENTATION_QUALITY:=80}
    _=${REVERSE_SORT:=false}
    _=${SANE_NAMES:=false}
    _=${TEMPLATE:="simple"}
    _=${TRIGAL_COPY:=true}
}

get_arguments $@
dump_settings
