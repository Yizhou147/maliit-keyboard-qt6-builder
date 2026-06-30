#!/bin/bash
set -euo pipefail

# ============================================================
# maliit-keyboard-qt6-builder
# Build Qt6 version of maliit-keyboard for arm64/aarch64
# Uses unmerged PRs:
#   - maliit/framework PR #125 (Qt6 support v2)
#   - maliit/keyboard PR #235 (Qt6 support)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/build}"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/output}"
PREFIX="${PREFIX:-/usr}"
JOBS="${JOBS:-$(nproc)}"

# PR branch/commit info
FRAMEWORK_REPO="https://github.com/cordlandwehr/framework.git"
FRAMEWORK_BRANCH="qt6-support_v2"
KEYBOARD_REPO="https://github.com/cordlandwehr/keyboard.git"
KEYBOARD_BRANCH="qt6-support"

echo "=== maliit-keyboard Qt6 builder ==="
echo "Build dir: ${BUILD_DIR}"
echo "Output dir: ${OUTPUT_DIR}"
echo "Jobs: ${JOBS}"
echo ""

# -----------------------------------------------------------
# 1. Install build dependencies
# -----------------------------------------------------------
install_deps() {
    echo ">>> Installing build dependencies..."
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y --no-install-recommends \
        build-essential cmake pkg-config git \
        qt6-base-dev qt6-base-dev-tools \
        qt6-declarative-dev \
        qt6-tools-dev qt6-tools-dev-tools \
        libqt6dbus6 qt6-base-private-dev \
        qt6-declarative-private-dev \
        libglib2.0-dev libgio-3.0-cil-dev \
        libpango1.0-dev \
        libhunspell-dev \
        libchewing3-dev \
        libpinyin-dev libpinyin13-dev \
        libpresage-dev \
        libxcb1-dev \
        gettext \
        wget ca-certificates \
        devscripts debhelper \
        qt6-virtualkeyboard-dev \
        libqt6virtualkeyboard6 \
        qml6-module-qtquick-virtualkeyboard \
        libqt6waylandclient6 qt6-wayland-dev \
        wayland-protocols libwayland-dev

    echo "    Dependencies installed."
}

# -----------------------------------------------------------
# 2. Build maliit-framework (Qt6)
# -----------------------------------------------------------
build_framework() {
    echo ""
    echo ">>> Building maliit-framework (Qt6)..."
    local src_dir="${BUILD_DIR}/maliit-framework"
    local build_dir="${BUILD_DIR}/maliit-framework-build"

    if [ ! -d "$src_dir" ]; then
        git clone --depth=1 -b "$FRAMEWORK_BRANCH" "$FRAMEWORK_REPO" "$src_dir"
    fi

    cd "$src_dir"

    mkdir -p "$build_dir"
    cd "$build_dir"

    cmake "$src_dir" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_WITH_QT6=ON \
        -Denable-inputcontext-qt4=OFF \
        -Denable-input-context-link=OFF \
        -Denable-wayland-gtk=OFF \
        -Denable-docs=OFF \
        -Denable-tests=OFF \
        -Denable-examples=OFF

    make -j"$JOBS"

    echo "    Installing maliit-framework (Qt6) to staging..."
    make install DESTDIR="${BUILD_DIR}/framework-install"

    # Also install to system for maliit-keyboard to find
    make install

    echo "    maliit-framework (Qt6) built and installed."
}

# -----------------------------------------------------------
# 3. Build maliit-keyboard (Qt6)
# -----------------------------------------------------------
build_keyboard() {
    echo ""
    echo ">>> Building maliit-keyboard (Qt6)..."
    local src_dir="${BUILD_DIR}/maliit-keyboard"
    local build_dir="${BUILD_DIR}/maliit-keyboard-build"

    if [ ! -d "$src_dir" ]; then
        git clone --depth=1 "$KEYBOARD_REPO" -b "$KEYBOARD_BRANCH" "$src_dir"
    fi

    cd "$src_dir"

    mkdir -p "$build_dir"
    cd "$build_dir"

    cmake "$src_dir" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_WITH_QT6=ON \
        -Denable-hunspell=ON \
        -Denable-tests=OFF

    make -j"$JOBS"

    echo "    Installing maliit-keyboard (Qt6) to staging..."
    make install DESTDIR="${BUILD_DIR}/keyboard-install"

    echo "    maliit-keyboard (Qt6) built."
}

# -----------------------------------------------------------
# 4. Package as .deb
# -----------------------------------------------------------
package_deb() {
    echo ""
    echo ">>> Packaging as .deb..."
    local pkg_dir="${BUILD_DIR}/maliit-keyboard-qt6-pkg"
    local deb_name="maliit-keyboard-qt6_2.3.1_arm64"

    rm -rf "$pkg_dir"
    mkdir -p "${pkg_dir}/DEBIAN"
    mkdir -p "${pkg_dir}/usr"

    # Copy installed files
    cp -a "${BUILD_DIR}/keyboard-install/${PREFIX}/"* "${pkg_dir}/usr/"

    # Create control file
    cat > "${pkg_dir}/DEBIAN/control" << EOF
Package: maliit-keyboard-qt6
Version: 2.3.1
Section: utils
Priority: optional
Architecture: arm64
Depends: libqt6virtualkeyboard6, qml6-module-qtquick-virtualkeyboard, qt6-wayland, libmaliit6-plugins2, libhunspell-dev, libchewing3, libpinyin15, libpresage1v5
Maintainer: Droidspaces Builder
Description: Maliit Keyboard (Qt6 version) - Virtual on-screen keyboard
 Qt6 build of maliit-keyboard for Plasma Mobile / Wayland.
 Built from maliit/keyboard PR #235 and maliit/framework PR #125.
EOF

    # Create postinst to update desktop file
    cat > "${pkg_dir}/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
set -e
# Update the desktop file to point to the Qt6 binary
if [ -f /usr/share/applications/com.github.maliit.keyboard.desktop ]; then
    sed -i 's|Exec=maliit-keyboard|Exec=maliit6-keyboard|' \
        /usr/share/applications/com.github.maliit.keyboard.desktop
fi
POSTINST
    chmod 755 "${pkg_dir}/DEBIAN/postinst"

    mkdir -p "$OUTPUT_DIR"
    dpkg-deb --build "$pkg_dir" "${OUTPUT_DIR}/${deb_name}.deb"

    echo "    Package built: ${OUTPUT_DIR}/${deb_name}.deb"
}

# -----------------------------------------------------------
# Main
# -----------------------------------------------------------
main() {
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

    install_deps
    build_framework
    build_keyboard
    package_deb

    echo ""
    echo "=== Build complete ==="
    echo "Output: ${OUTPUT_DIR}/"
    ls -la "$OUTPUT_DIR"
}

main "$@"
