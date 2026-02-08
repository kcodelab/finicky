#!/bin/bash

# Exit on error
set -e


# Build config-api
(
    cd packages/config-api
    npm run build
    npm run generate-types

    # Copy config API to finicky
    cd ../../
    cp packages/config-api/dist/finickyConfigAPI.js apps/finicky/src/assets/finickyConfigAPI.js
)

# Build finicky-ui
(
    cd packages/finicky-ui
    npm run build

    # Copy finicky-ui dist to finicky
    cd ../../

    # Ensure destination directory exists
    mkdir -p apps/finicky/src/assets/templates

    # Copy templates from dist to finicky app
    cp -r packages/finicky-ui/dist/* apps/finicky/src/assets/templates
)

# Determine app name based on target architecture (for CI builds)
if [ -n "$BUILD_TARGET_ARCH" ]; then
    APP_NAME="Finicky-${BUILD_TARGET_ARCH}.app"
else
    APP_NAME="Finicky.app"
fi

# Build Swift native shell library for cgo link
(
    SWIFT_SRC_DIR="apps/finicky/src/native"
    SWIFT_BUILD_DIR="${SWIFT_SRC_DIR}/build"
    SWIFT_CACHE_DIR="apps/finicky/build-cache/swift-module-cache"
    GO_HOST_ARCH=$(go env GOARCH)
    if [ "${GO_HOST_ARCH}" = "amd64" ]; then
        SWIFT_ARCH="x86_64"
    else
        SWIFT_ARCH="${GO_HOST_ARCH}"
    fi
    SWIFT_TARGET="${SWIFT_ARCH}-apple-macos12.0"
    mkdir -p "${SWIFT_BUILD_DIR}"
    mkdir -p "${SWIFT_CACHE_DIR}"
    swiftc \
        -parse-as-library \
        -target "${SWIFT_TARGET}" \
        -module-cache-path "${SWIFT_CACHE_DIR}" \
        -import-objc-header "${SWIFT_SRC_DIR}/bridge.h" \
        -emit-library -static \
        -module-name FinickyNativeUI \
        -emit-objc-header \
        -emit-objc-header-path "${SWIFT_BUILD_DIR}/FinickyNativeUI-Swift.h" \
        -o "${SWIFT_BUILD_DIR}/libFinickyNativeUI.a" \
        "${SWIFT_SRC_DIR}/SwiftAppShell.swift" \
        "${SWIFT_SRC_DIR}/NativePages.swift"
)


# Build the application
(
    # Get build information
    COMMIT_HASH=$(git rev-parse --short HEAD)
    BUILD_DATE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    API_HOST=$(cat .env | grep API_HOST | cut -d '=' -f 2)
    GOCACHE_PATH="$(pwd)/apps/finicky/build-cache/go-build"
    SWIFT_LIB_PATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx"
    SWIFT_SDK_LIB_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib/swift"
    mkdir -p "${GOCACHE_PATH}"


    export CGO_CFLAGS="-mmacosx-version-min=12.0"
    export CGO_LDFLAGS="-mmacosx-version-min=12.0 -L${SWIFT_LIB_PATH} -L${SWIFT_SDK_LIB_PATH} -Wl,-rpath,/usr/lib/swift -Wl,-force_load,${SWIFT_LIB_PATH}/libswiftCompatibility51.a -Wl,-force_load,${SWIFT_LIB_PATH}/libswiftCompatibilityConcurrency.a -Wl,-force_load,${SWIFT_LIB_PATH}/libswiftCompatibility56.a ${SWIFT_LIB_PATH}/libswiftCompatibilityPacks.a"
    export CGO_LDFLAGS_ALLOW='-Wl,.*|/Applications/.*'
    export GOCACHE="${GOCACHE_PATH}"

    cd apps/finicky
    mkdir -p build/${APP_NAME}/Contents/MacOS
    mkdir -p build/${APP_NAME}/Contents/Resources
    go build -C src \
        -ldflags \
        "-X 'finicky/version.commitHash=${COMMIT_HASH}' \
        -X 'finicky/version.buildDate=${BUILD_DATE}' \
        -X 'finicky/version.apiHost=${API_HOST}'" \
        -o ../build/${APP_NAME}/Contents/MacOS/Finicky
)

# Copy static assets
cp packages/config-api/dist/finicky.d.ts apps/finicky/build/${APP_NAME}/Contents/Resources/finicky.d.ts
cp -r apps/finicky/assets/* apps/finicky/build/${APP_NAME}/Contents/

# Only replace existing app if not in CI (BUILD_TARGET_ARCH not set)
if [ -z "$BUILD_TARGET_ARCH" ]; then
    # Replace existing app
    rm -rf /Applications/Finicky.app
    cp -r apps/finicky/build/Finicky.app /Applications/
fi

echo "Build complete ✨"
