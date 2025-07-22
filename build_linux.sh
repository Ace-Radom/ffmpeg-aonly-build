#!/usr/bin/bash

set -eu

: ${ARCH?}

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

OUTPUT_DIR=$ARTIFACTS_DIR/ffmpeg-$FFMPEG_VERSION-aonly-$ARCH-linux-gnu
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
)
# prepare common configure flags

case $ARCH in
    x86_64)
        ;;
    i686)
        FFMPEG_CONFIGURE_FLAGS+=(--cc="gcc -m32")
        ;;
    arm64)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=aarch64-linux-gnu-
            --target-os=linux
            --arch=aarch64
        )
        ;;
    arm*)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=arm-linux-gnueabihf-
            --target-os=linux
            --arch=arm
        )
        case $ARCH in
            armv7-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv7-a
                )
                ;;
            armv8-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv8-a
                )
                ;;
            armhf-rpi2)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a7
                    --extra-cflags='-fPIC -mcpu=cortex-a7 -mfloat-abi=hard -mfpu=neon-vfpv4 -mvectorize-with-neon-quad'
                )
                ;;
            armhf-rpi3)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a53
                    --extra-cflags='-fPIC -mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mvectorize-with-neon-quad'
                )
                ;;
        esac
        ;;
    *)
        echo "Unknown architecture: $ARCH"
        exit 1
        ;;
esac
# prepare arch configure flags

FFMPEG_BUILD_DIR=$(mktemp -d -p $BUILD_DIR ffmpeg-build.XXXXXXXX)
trap 'rm -rf $FFMPEG_BUILD_DIR' EXIT
cd $FFMPEG_BUILD_DIR
tar --strip-components=1 -xf $FFMPEG_TARBALL
./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || exit 1
make
make install
chown $(stat -c '%u:%g' $BASE_DIR) -R $OUTPUT_DIR
# build
