#!/bin/bash
set -e

#
# Trivial Gallery - https://github.com/tokee/trigal
#
# Very simple gallery generator that produces static web pages.
#
# Requirements
# - bash
# - GraphicsMagic (fastest) or ImageMagic
#
# Toke Eskildsen, te@ekot.dk
#

pushd $(dirname "$0") > /dev/null
TRI="`pwd`"
popd > /dev/null

if [ -s $TRI/trigal.conf ]; then
    source $TRI/trigal.conf
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

-h
Show the usage text.
EOF
}

function dump_settings()  {
    cat <<EOF
export SOURCE="$SOURCE"
export DEST="$DEST"
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
    while [[ "$#" > 0 ]]; do
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
            -h) echo ffo;;
            *) echo "Unknown parameter: $1" ; exit 2;;
        esac; shift
    done

    _=${SOURCE:="$DEST"}
    _=${DEST:="$SOURCE"}
    if [ -z "$SOURCE" -a -z "$DEST" ]; then
        # No source or dest
        if [ "$TRI" == "`pwd`" ]; then
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

    # Full paths
    RSOURCE="$(cd "$SOURCE"; pwd)"
    RDEST="$(cd "$DEST"; pwd)"

    if [ -z `which gm` ]; then
        if [ -z `which convert` ]; then
            >&2 echo "Could not locate GraphicsMagic or ImageMagick. Unable to proceed."
            exit 3
        fi
        # ImageMagick
        CONVERT="convert"
        IDENTIFY="identify"
    else
        # GraphicsMagick
        CONVERT="gm convert"
        IDENTIFY="gm identify"
    fi
}

# Iterates all sub folders. If they contain trigal structures,
# add them to the generated list of folders.
# When finished, the variable SUBFOLDERS will contain the subfolders.
# Arguments: folder
function get_sub_folders() {
    local FOLDER="$1"
    SUBFOLDERS=""

    if [ "." == ".`ls -d $FOLDER/*/ 2> /dev/null`" ]; then
        return
    fi
    local SUBS=$(find $FOLDER/*/ -not -path '*/\.*' -type d)
    
    for SUB in $SUBS; do
        if [ ! "." == ".`ls -d $SUB/trigal/ 2> /dev/null`" ]; then
            continue
        fi
        local DS="${SUB%/*}"
        local DS="${DS##*/}"
        if [ "trigal" == "$DS" ]; then
            continue
        fi
        if [ ! "." == ".$SUBFOLDERS" ]; then
            SUBFOLDERS="$SUBFOLDERS"$'\n'
        fi
        SUBFOLDERS="${SUBFOLDERS}${DS}"
    done
}

# For each image in the folder, ensure there are thumbs and presentation
# versions in the destination folder an add its data to a list.
# When finished, the variable IMAGES will contain a list of lines with
# full fullW fullH presentation presentation_W presentation_H thumb
# If there are no images, no structures will be created.
# Arguments: source dest
function get_images() {
    local S="$1"
    local D="$2"
    IMAGES=""

    echo "Img: $S -> $D"
    pushd "$S" > /dev/null
    local IMGS="`ls *.jpg *.JPG *.jpeg *.JPEG 2> /dev/null`"
    popd > /dev/null
    if [ "." == ".$IMGS" ]; then
        return
    fi

    mkdir -p "$D/trigal/cache"
    for IMAGE in $IMGS; do
        if [ "$FULL_COPY" == "true" ]; then
            echo cp -n "$S/$IMAGE" "$D/$IMAGE"
        fi
        local BASE="${IMAGE%.*}"
        if [ ! -s "$D/trigal/cache/${BASE}.thumb.jpg" ]; then
            echo "Generating $D/trigal/cache/${BASE}.thumb.jpg"
        fi
        if [ ! -s "$D/trigal/cache/${BASE}.jpg" ]; then
            echo "Generating $D/trigal/cache/${BASE}.jpg"
        fi
        if [ ! -s "$D/trigal/cache/${BASE}.info" ]; then
            echo "Generate info for $BASE" > "$D/trigal/cache/${BASE}.info"
        fi
        if [ "$TRIGAL_COPY" == "true" -a ! -s "$D/trigal/trigal.sh" ]; then
            cp -r $TRI/* "$D/trigal/"
            (SOURCE="$S" DEST="$D" dump_settings > "$D/trigal/trigal.conf")
             echo $SOURCE
             exit
        fi
    done

    if [ ! -s "$D/trigal/cache/_trigal_folder.jpg" ]; then
        cp "`ls $D/trigal/cache/*.thumb.jpg | head -n 1`" "$D/trigal/cache/_trigal_folder.jpg"
    fi
    if [ "$REVERSE_SORT" == "true" ]; then
        local IL="`ls -r \"$D/trigal/cache/*.info\" 2> /dev/null`"
    else
        local IL="`ls \"$D/trigal/cache/*.info\" 2> /dev/null`"
    fi
    echo "Img: Done"
    IMAGES=`cat $IL`
}
       
# Arguments: source destination
function generate() {
    local S="$1"
    local D="$2"
    echo "Gen: $S -> $D"
    # Generate all sub folders
    if [ ! "." == ".`ls -d $S/*/ 2> /dev/null`" ]; then
        for SUB in $( find $S/*/ -not -path '*/\.*' -type d); do
            local DS="${SUB%/*}"
            local DS="${DS##*/}"
            if [ "trigal" == "$DS" ]; then
                continue
            fi
            generate "$SUB" "$D/$DS"
        done
    fi
    get_sub_folders "$D" # SUBFOLDERS
    get_images "$S" "$D"  # $IMAGES

    
    # Create list of sub-folders with images
    # Create list of images
    
}

get_arguments $@
generate "$RSOURCE" "$RDEST"
