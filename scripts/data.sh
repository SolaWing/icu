# 只增量更新data, sim arm64
set -xe
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"
BUILD_DIR="$ROOT/build"
export ICU_DATA_FILTER_FILE="$ROOT/icu4c/filter.json"

pushd "$BUILD_DIR/icu4c-maint-maint-72-ios.sim-arm64-build/source"
PYTHONPATH=python python3 -m icutools.databuilder \
        --mode=gnumake --src_dir=data --filter_file "$ICU_DATA_FILTER_FILE" > data/rules.mk

cd data
make clean; make;
popd
# break duplicate arch, only for test
cp -f "$BUILD_DIR/icu4c-maint-maint-72-ios.sim-arm64-build/source/lib/libicudata.a" "$BUILD_DIR/product/frameworks/icudata.xcframework/ios-arm64_x86_64-simulator/"

