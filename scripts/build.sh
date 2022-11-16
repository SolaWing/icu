#!/bin/bash
set -xe

################## SETUP BEGIN
THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')
HOST_ARC=$( uname -m )
XCODE_ROOT=$( xcode-select -print-path )
ICU_VER=maint/maint-72
DATA_PACKAGE=""
# DATA_PACKAGE="--with-data-packaging=archive"
DATA_TRACING=""
# DATA_TRACING="--enable-tracing"

################## SETUP END

SDKROOT_ios=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
SDKROOT_ios_sim=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
SDKROOT_macos=$XCODE_ROOT/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
SDKROOT_catalyst="$SDKROOT_macos"

SDKROOT_ios_min_ver=11.0
SDKROOT_ios_sim_min_ver=11.0
SDKROOT_macos_min_ver=11.0
SDKROOT_catalyst_min_ver=13.4

Platform_ios=ios
Platform_ios_sim=ios-simulator
Platform_macos=macos
Platform_catalyst=mac-catalyst

SDKROOT_ios_sdk_ver=$(plutil -extract Version raw $SDKROOT_ios/SDKSettings.plist)
SDKROOT_ios_sim_sdk_ver=$SDKROOT_ios_sdk_ver
SDKROOT_macos_sdk_ver=$(plutil -extract Version raw $SDKROOT_macos/SDKSettings.plist)
SDKROOT_catalyst_sdk_ver=$SDKROOT_macos_sdk_ver


ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"
export ICU_DATA_FILTER_FILE="$ROOT/icu4c/filter.json"
BUILD_DIR="$ROOT/build"
ICU_VER_NAME=$BUILD_DIR/icu4c-${ICU_VER//\//-}
INSTALL_DIR="$BUILD_DIR/product"
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

        cd lib
        local SDKROOT_key=SDKROOT_$1
        local min_ver_key=SDKROOT_$1_min_ver
        local platform_key=Platform_$1
        local sdk_ver_key=SDKROOT_$1_sdk_ver
        # -platform_version ios 14.0.0 16.0
        ld  -v -dylib -dead_strip -exported_symbol _icu_msgSample1 \
            -arch $2 -syslibroot ${!SDKROOT_key} -platform_version ${!platform_key} ${!min_ver_key} ${!sdk_ver_key} \
            -lc++ -lSystem *.a -o libicu_lark.dylib
        strip -x libicu_lark.dylib
        # FISH_PS="wait: " fish

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
        lipo -create $ICU_VER_NAME-$1-arm64-build/source/lib/libicu_lark.dylib $ICU_VER_NAME-$1-x86_64-build/source/lib/libicu_lark.dylib -output $ICU_VER_NAME-$1-build/source/lib/libicu_lark.dylib
    
        touch $ICU_VER_NAME-$1-build.success
    fi
}

################### BUILD FOR TOOLS
if [[ ! -d $BUILD_DIR ]]; then
    mkdir -p "$BUILD_DIR"
fi
ICU_BUILD_FOLDER=$BUILD_DIR/tool-build
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

#################### CROSS BUILD
generic_double_build macos
generic_double_build catalyst "-isysroot $SDKROOT_macos --target=apple-ios$SDKROOT_catalyst_min_ver-macabi"
generic_double_build ios_sim "-isysroot $SDKROOT_ios_sim -mios-simulator-version-min=$SDKROOT_ios_sim_min_ver "
generic_build ios arm64 arm "-fembed-bitcode -isysroot $SDKROOT_ios -mios-version-min=$SDKROOT_ios_min_ver"

#################### Frameworks
if [ -d $INSTALL_DIR/frameworks ]; then
    rm -rf $INSTALL_DIR/frameworks
fi
mkdir $INSTALL_DIR/frameworks

# xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicudata.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios_sim-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios-arm64-build/source/stubdata/libicudata.a -output $INSTALL_DIR/frameworks/icudata.xcframework
xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicudata.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios_sim-build/source/lib/libicudata.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicudata.a -output $INSTALL_DIR/frameworks/icudata.xcframework

xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicui18n.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicui18n.a -library $ICU_VER_NAME-ios_sim-build/source/lib/libicui18n.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicui18n.a -output $INSTALL_DIR/frameworks/icui18n.xcframework

xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicuio.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicuio.a -library $ICU_VER_NAME-ios_sim-build/source/lib/libicuio.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicuio.a -output $INSTALL_DIR/frameworks/icuio.xcframework

xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicuuc.a -library $ICU_VER_NAME-catalyst-build/source/lib/libicuuc.a -library $ICU_VER_NAME-ios_sim-build/source/lib/libicuuc.a -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicuuc.a -output $INSTALL_DIR/frameworks/icuuc.xcframework

xcodebuild -create-xcframework -library $ICU_VER_NAME-macos-build/source/lib/libicu_lark.dylib -library $ICU_VER_NAME-catalyst-build/source/lib/libicu_lark.dylib -library $ICU_VER_NAME-ios_sim-build/source/lib/libicu_lark.dylib -library $ICU_VER_NAME-ios-arm64-build/source/lib/libicu_lark.dylib -output $INSTALL_DIR/frameworks/icu_lark.xcframework
