#!/bin/bash
set -xe

DATA_PACKAGE=""
# DATA_PACKAGE="--with-data-packaging=archive"
DATA_TRACING=""
# DATA_TRACING="--enable-tracing"

################## SETUP BEGIN
THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')
HOST_ARC=$( uname -m )
XCODE_ROOT=$( xcode-select -print-path )
ICU_VER=maint/maint-72
################## SETUP END
DEVSYSROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
SIMSYSROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
MACSYSROOT=$XCODE_ROOT/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"
BUILD_DIR="$ROOT/build"
ICU_VER_NAME=$BUILD_DIR/icu4c-${ICU_VER//\//-}
INSTALL_DIR="$BUILD_DIR/product"
export ICU_DATA_FILTER_FILE="$ROOT/icu4c/filter.json"
ICU4C_FOLDER=icu4c

if [ "$HOST_ARC" = "arm64" ]; then
	BUILD_ARC=arm
    FOREIGN_ARC=x86_64
    FOREIGN_BUILD_ARC=x86_64
else
	BUILD_ARC=$HOST_ARC
    FOREIGN_ARC=arm64
    FOREIGN_BUILD_ARC=arm
fi

#explicit 72.1
# pushd icu
# git reset --hard ff3514f257ea10afe7e710e9f946f68d256704b1
# popd

# (type, arc, build-arc, cflags, ldflags)
generic_build()
{
    if [ ! -f $ICU_VER_NAME-$1-$2-build.success ]; then
        echo preparing build folder $ICU_VER_NAME-$1-$2-build ...
        if [ -d $ICU_VER_NAME-$1-$2-build ]; then
            rm -rf $ICU_VER_NAME-$1-$2-build
        fi
        cp -r $ICU4C_FOLDER $ICU_VER_NAME-$1-$2-build
        echo "building icu ($1 $2)..."
        pushd $ICU_VER_NAME-$1-$2-build/source

        COMMON_CFLAGS="-Oz -arch $2 $4"
        ./configure $DATA_PACKAGE $DATA_TRACING --disable-tools --disable-extras --disable-tests --disable-samples --disable-dyload --enable-static --disable-shared prefix=$INSTALL_DIR --host=$BUILD_ARC-apple-darwin --build=$3-apple --with-cross-build=$ICU_BUILD_FOLDER/source CFLAGS="$COMMON_CFLAGS" CXXFLAGS="$COMMON_CFLAGS -stdlib=libc++ -Wall --std=c++17" LDFLAGS="-stdlib=libc++ $5 -Wl,-dead_strip -lstdc++"

        make -j$THREAD_COUNT
        popd
        touch $ICU_VER_NAME-$1-$2-build.success
    fi
}

# (type, coomon_cflags, arm-cflags, x86_64-cflags, ldflags)
generic_double_build()
{
    if [ ! -f $ICU_VER_NAME-$1-build.success ]; then
        echo preparing build folder $ICU_VER_NAME-$1-build ...
        if [ -d $ICU_VER_NAME-$1-build ]; then
            rm -rf $ICU_VER_NAME-$1-build
        fi
        mkdir -p $ICU_VER_NAME-$1-build/source/lib

        generic_build $1 arm64 arm "$2 $3" "$5"
        generic_build $1 x86_64 x86_64 "$2 $4" "$5"

        # lipo -create $ICU_VER_NAME-$1-arm64-build/source/stubdata/libicudata.a $ICU_VER_NAME-$1-x86_64-build/source/stubdata/libicudata.a -output $ICU_VER_NAME-$1-build/source/lib/libicudata.a
        lipo -create $ICU_VER_NAME-$1-arm64-build/source/lib/libicudata.a $ICU_VER_NAME-$1-x86_64-build/source/lib/libicudata.a -output $ICU_VER_NAME-$1-build/source/lib/libicudata.a
        lipo -create $ICU_VER_NAME-$1-arm64-build/source/lib/libicui18n.a $ICU_VER_NAME-$1-x86_64-build/source/lib/libicui18n.a -output $ICU_VER_NAME-$1-build/source/lib/libicui18n.a
        lipo -create $ICU_VER_NAME-$1-arm64-build/source/lib/libicuio.a $ICU_VER_NAME-$1-x86_64-build/source/lib/libicuio.a -output $ICU_VER_NAME-$1-build/source/lib/libicuio.a
        lipo -create $ICU_VER_NAME-$1-arm64-build/source/lib/libicuuc.a $ICU_VER_NAME-$1-x86_64-build/source/lib/libicuuc.a -output $ICU_VER_NAME-$1-build/source/lib/libicuuc.a
    
        touch $ICU_VER_NAME-$1-build.success
    fi
}

build_catalyst_libs()
{
    generic_double_build catalyst "-isysroot $MACSYSROOT --target=apple-ios13.4-macabi"
    # "--target=arm-apple-ios13.4-macabi" "--target=x86_64-apple-ios13.4-macabi" "-L$MACSYSROOT/System/iOSSupport/usr/lib/"
}

build_sim_libs()
{
    CFLAGS="-isysroot $SIMSYSROOT/SDKs/iPhoneSimulator.sdk -mios-simulator-version-min=13.4 "
    generic_double_build ios.sim "$CFLAGS"
}

################### BUILD FOR MAC OSX
if [[ ! -d $BUILD_DIR ]]; then
    mkdir -p "$BUILD_DIR"
fi
ICU_BUILD_FOLDER=$ICU_VER_NAME-build
if [ ! -f $ICU_BUILD_FOLDER.success ]; then
    echo preparing build folder $ICU_BUILD_FOLDER ...
    if [ -d $ICU_BUILD_FOLDER ]; then
        rm -rf $ICU_BUILD_FOLDER
    fi
    cp -r $ICU4C_FOLDER $ICU_BUILD_FOLDER

    echo "building icu (mac osx)..."
    pushd $ICU_BUILD_FOLDER/source

    if [ ! -d $INSTALL_DIR ]; then
        mkdir -p $INSTALL_DIR
    fi

    ./runConfigureICU MacOSX $DATA_PACKAGE $DATA_TRACING --enable-static --disable-shared prefix=$INSTALL_DIR CXXFLAGS="--std=c++17" CPPFLAGS="-DUCONFIG_NO_CONVERSION=0"
    make -j$THREAD_COUNT
    make install
    popd
    touch $ICU_BUILD_FOLDER.success
fi

generic_build macos $FOREIGN_ARC $FOREIGN_BUILD_ARC
if [ -d $ICU_VER_NAME-macos-build ]; then
    rm -rf $ICU_VER_NAME-macos-build
fi
mkdir -p $ICU_VER_NAME-macos-build/source/lib
# lipo -create $INSTALL_DIR/lib/libicudata.a $ICU_VER_NAME-macos-$FOREIGN_ARC-build/source/stubdata/libicudata.a -output $ICU_VER_NAME-macos-build/source/lib/libicudata.a
lipo -create $INSTALL_DIR/lib/libicudata.a $ICU_VER_NAME-macos-$FOREIGN_ARC-build/source/lib/libicudata.a -output $ICU_VER_NAME-macos-build/source/lib/libicudata.a
lipo -create $INSTALL_DIR/lib/libicui18n.a $ICU_VER_NAME-macos-$FOREIGN_ARC-build/source/lib/libicui18n.a -output $ICU_VER_NAME-macos-build/source/lib/libicui18n.a
lipo -create $INSTALL_DIR/lib/libicuio.a $ICU_VER_NAME-macos-$FOREIGN_ARC-build/source/lib/libicuio.a -output $ICU_VER_NAME-macos-build/source/lib/libicuio.a
lipo -create $INSTALL_DIR/lib/libicuuc.a $ICU_VER_NAME-macos-$FOREIGN_ARC-build/source/lib/libicuuc.a -output $ICU_VER_NAME-macos-build/source/lib/libicuuc.a

build_catalyst_libs
build_sim_libs

generic_build ios arm64 arm "-fembed-bitcode -isysroot $DEVSYSROOT/SDKs/iPhoneOS.sdk -mios-version-min=13.4"

if [ -d $INSTALL_DIR/frameworks ]; then
    rm -rf $INSTALL_DIR/frameworks
fi
mkdir $INSTALL_DIR/frameworks

# xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicudata.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios.sim-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios-arm64-build/source/stubdata/libicudata.a -output $INSTALL_DIR/frameworks/icudata.xcframework
xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicudata.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios.sim-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicudata.a -output $INSTALL_DIR/frameworks/icudata.xcframework

xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicui18n.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicui18n.a -library $ICU_VER_NAME-ios.sim-build/source/lib/libicui18n.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicui18n.a -output $INSTALL_DIR/frameworks/icui18n.xcframework

xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicuio.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicuio.a -library $ICU_VER_NAME-ios.sim-build/source/lib/libicuio.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicuio.a -output $INSTALL_DIR/frameworks/icuio.xcframework

xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicuuc.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicuuc.a -library $ICU_VER_NAME-ios.sim-build/source/lib/libicuuc.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicuuc.a -output $INSTALL_DIR/frameworks/icuuc.xcframework
