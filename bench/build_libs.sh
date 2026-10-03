#!/bin/sh
# Downloads and builds zlib, libpng and libjpeg-turbo for the 68030 with
# m68k-atari-mint-gcc, installing libraries and headers into <prefix>.
#
# Usage: build_libs.sh <prefix>
#
# Needs m68k-atari-mint-gcc, cmake, curl and xz.

set -e

PREFIX=$(realpath -m "${1:?usage: build_libs.sh <prefix>}")
CFLAGS="-m68030 -msoft-float -O2 -fomit-frame-pointer"
WORK="$PREFIX/src"

ZLIB=zlib-1.3.2
LIBPNG=libpng-1.6.44
TURBO=libjpeg-turbo-3.0.1

mkdir -p "$PREFIX/lib" "$PREFIX/include" "$WORK"
cd "$WORK"

[ -f $ZLIB.tar.gz ] || curl -sSL -o $ZLIB.tar.gz https://www.zlib.net/$ZLIB.tar.gz
[ -f $LIBPNG.tar.xz ] || curl -sSL -o $LIBPNG.tar.xz https://sourceforge.net/projects/libpng/files/libpng16/1.6.44/$LIBPNG.tar.xz/download
[ -f $TURBO.tar.gz ] || curl -sSL -o $TURBO.tar.gz https://sourceforge.net/projects/libjpeg-turbo/files/3.0.1/$TURBO.tar.gz/download
tar xzf $ZLIB.tar.gz
tar xJf $LIBPNG.tar.xz
tar xzf $TURBO.tar.gz

# zlib

cd "$WORK/$ZLIB"
SRCS="adler32.c crc32.c deflate.c infback.c inffast.c inflate.c inftrees.c trees.c zutil.c compress.c uncompr.c gzclose.c gzlib.c gzread.c gzwrite.c"
for f in $SRCS; do m68k-atari-mint-gcc $CFLAGS -c $f; done
m68k-atari-mint-ar rcs "$PREFIX/lib/libz.a" $(echo $SRCS | sed 's/\.c/.o/g')
cp zlib.h zconf.h "$PREFIX/include/"

# libpng

cd "$WORK/$LIBPNG"
cp scripts/pnglibconf.h.prebuilt pnglibconf.h
SRCS="png.c pngerror.c pngget.c pngmem.c pngpread.c pngread.c pngrio.c pngrtran.c pngrutil.c pngset.c pngtrans.c pngwio.c pngwrite.c pngwtran.c pngwutil.c"
for f in $SRCS; do m68k-atari-mint-gcc $CFLAGS -I"$PREFIX/include" -c $f; done
m68k-atari-mint-ar rcs "$PREFIX/lib/libpng.a" $(echo $SRCS | sed 's/\.c/.o/g')
cp png.h pngconf.h pnglibconf.h "$PREFIX/include/"

# libjpeg-turbo (no SIMD for m68k, built with its default release flags, -O3)

cat > "$WORK/mint.cmake" <<EOT
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR m68k)
set(CMAKE_C_COMPILER m68k-atari-mint-gcc)
set(CMAKE_AR m68k-atari-mint-ar CACHE FILEPATH "")
set(CMAKE_RANLIB m68k-atari-mint-ranlib CACHE FILEPATH "")
set(CMAKE_C_FLAGS_RELEASE "$CFLAGS" CACHE STRING "")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
EOT
rm -rf "$WORK/turbo-build"
mkdir "$WORK/turbo-build"
cd "$WORK/turbo-build"
cmake "$WORK/$TURBO" -DCMAKE_TOOLCHAIN_FILE="$WORK/mint.cmake" -DCMAKE_BUILD_TYPE=Release \
	-DWITH_SIMD=0 -DENABLE_SHARED=0 -DENABLE_STATIC=1 -DWITH_TURBOJPEG=0 > /dev/null
make jpeg-static > /dev/null
cp libjpeg.a "$PREFIX/lib/"
cp jconfig.h "$WORK/$TURBO/jpeglib.h" "$WORK/$TURBO/jmorecfg.h" "$WORK/$TURBO/jerror.h" "$PREFIX/include/"

echo "Libraries installed in $PREFIX"
