#!/bin/bash
#
# Build PixelOS for redwood with the 6.18 kernel.
#
# Run it from the root of the PixelOS tree, after setup.sh:
#   ~/redwood-pixelos-setup/build.sh [-i] [userdebug|user|eng]
#
# -i runs an installclean first: use it for every build you publish, since an
# incremental build keeps the old build date. The build type defaults to
# userdebug. Set RELEASE for another release config (default cp2a).
#
# The flashable zip ends up in the tree root, boot, vendor_boot and dtbo for
# fastboot in images/.

set -eo pipefail

die() { echo "build: $*" >&2; exit 1; }

clean=
variant=userdebug
for arg in "$@"; do
    case "$arg" in
    -i) clean=1 ;;
    user | userdebug | eng) variant=$arg ;;
    *) die "unknown argument $arg" ;;
    esac
done

[ -f build/envsetup.sh ] && [ -d vendor/custom ] ||
    die "run this from the root of a PixelOS tree"
grep -q "redwood-kernel-6.18" device/xiaomi/redwood/BoardConfig.mk ||
    die "device/xiaomi/redwood isn't the 6.18 device tree, run setup.sh first"
[ -f device/xiaomi/redwood-kernel-6.18/Image ] || die "no 6.18 kernel prebuilt, run setup.sh first"

source build/envsetup.sh
lunch "custom_redwood-${RELEASE:-cp2a}-$variant"
[ -n "$clean" ] && m installclean
m pixelos

out=out/target/product/redwood
zip=$(ls -t "$out"/PixelOS*redwood*.zip 2>/dev/null | grep -viE "ota|target_files|img" | head -n 1 || true)
[ -n "$zip" ] || die "no PixelOS zip in $out, the build failed"
cp "$zip" .

mkdir -p images
for img in boot vendor_boot dtbo; do
    cp "$out/$img.img" images/
done

echo
echo "Kernel: $(sed -n 's/^release=//p' device/xiaomi/redwood-kernel-6.18/build-info.txt)"
echo "ROM:    $(pwd)/$(basename "$zip")"
echo "Images: $(pwd)/images/{boot,vendor_boot,dtbo}.img"
