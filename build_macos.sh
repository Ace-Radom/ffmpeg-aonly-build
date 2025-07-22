#!/bin/bash

set -eux

: ${TARGET?}
case $TARGET in
    x86_64-*)
        ARCH="x86_64"
        ;;
    arm64-*)
        ARCH="arm64"
        ;;
    *)
        echo "Unknown target: $TARGET"
        exit 1
        ;;
esac
# parse target to arch

cd $(dirname $0)
BASE_DIR=$(pwd)
BUILD_DIR=$BASE_DIR/build
if [ ! -d $BUILD_DIR ]
then
    mkdir $BUILD_DIR
fi
ARTIFACTS_DIR=$BUILD_DIR/artifacts
if [ ! -d $ARTIFACTS_DIR ]
then
    mkdir $ARTIFACTS_DIR
fi
# prepare build dir

FFMPEG_VERSION=7.1.1
FFMPEG_TARBALL_FILENAME=ffmpeg-$FFMPEG_VERSION.tar.gz
FFMPEG_TARBALL=$BASE_DIR/$FFMPEG_TARBALL_FILENAME
FFMPEG_TARBALL_URL=http://ffmpeg.org/releases/$FFMPEG_TARBALL_FILENAME
if [ ! -e $FFMPEG_TARBALL ]
then
	curl -s -L -O $FFMPEG_TARBALL_URL
fi
# prepare src

OUTPUT_DIR=$ARTIFACTS_DIR/ffmpeg-$FFMPEG_VERSION-aonly-$TARGET-clang
if [ -d $OUTPUT_DIR ]
then
    rm -rf $OUTPUT_DIR
fi
# prepare output dir

ENABLE_DECODER=$(tr '\n' ',' < "enable_decoder.txt")
ENABLE_ENCODER=$(tr '\n' ',' < "enable_encoder.txt")
ENABLE_DEMUXER=$(tr '\n' ',' < "enable_demuxer.txt")
ENABLE_MUXER=$(tr '\n' ',' < "enable_muxer.txt")
ENABLE_FILTER=$(tr '\n' ',' < "enable_filter.txt")
ENABLE_PARSER=$(tr '\n' ',' < "enable_parser.txt")
# read enabled decoder, encoder, demuxer, muxer, filter, parser

FFMPEG_CONFIGURE_FLAGS=(
    --prefix=$OUTPUT_DIR
    --disable-everything
    --enable-avformat
    --enable-avcodec
    --enable-avutil
    --enable-swresample
    --enable-protocol=file,pipe
    --disable-programs
    --disable-doc
    --disable-debug
    --disable-static
    --enable-shared
    --enable-pic
    --enable-decoder=$ENABLE_DECODER
    --enable-encoder=$ENABLE_ENCODER
    --enable-demuxer=$ENABLE_DEMUXER
    --enable-muxer=$ENABLE_MUXER
    --enable-filter=$ENABLE_FILTER
    --enable-parser=$ENABLE_PARSER
    --cc=/usr/bin/clang
    --enable-cross-compile
    --target-os=darwin
    --arch=$ARCH
    --extra-ldflags="-target $TARGET"
    --extra-cflags="-target $TARGET"
    --enable-runtime-cpudetect
)
# prepare configure flags

FFMPEG_BUILD_DIR=$(mktemp -d $BUILD_DIR/ffmpeg-build.XXXXXXXX)
trap 'rm -rf $FFMPEG_BUILD_DIR' EXIT
cd $FFMPEG_BUILD_DIR
tar --strip-components=1 -xf $FFMPEG_TARBALL
./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || exit 1
perl -pi -e 's{HAVE_MACH_MACH_TIME_H 1}{HAVE_MACH_MACH_TIME_H 0}' config.h
make V=1
make install
chown -R $(stat -f '%u:%g' $BASE_DIR) $OUTPUT_DIR
