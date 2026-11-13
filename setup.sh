#!/bin/bash
#
# Set up redwood with the 6.18 kernel in a PixelOS (seventeen) tree.
#
# Run it from the root of a synced PixelOS tree:
#   ~/redwood-pixelos-setup/setup.sh
#
# It adds the redwood local manifest, syncs the redwood repos and checks that
# the device tree, the 6.18 kernel prebuilt, the vendor blobs, Dolby and the
# MIUI camera are in place. A path the ROM's own manifest already has is
# left to the ROM, except hardware/dolby: that one is always ours.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
LOCAL=.repo/local_manifests/redwood.xml

die() { echo "setup: $*" >&2; exit 1; }

[ -d .repo ] && [ -f build/envsetup.sh ] ||
    die "run this from the root of a synced PixelOS tree"
[ -d vendor/custom ] || die "no vendor/custom here: this isn't a PixelOS tree"

echo "==> Adding the redwood local manifest"
mkdir -p .repo/local_manifests
cp "$HERE/redwood.xml" "$LOCAL"

rom_name() {
    { grep -rhs "path=\"$1\"" .repo/manifests/ || true; } |
        grep -o 'name="[^"]*"' | head -n 1 | cut -d'"' -f2 || true
}

for path in $(grep -oE 'path="[^"]+"' "$LOCAL" | cut -d'"' -f2); do
    name=$(rom_name "$path")
    [ -n "$name" ] || continue
    if [ "$path" = hardware/dolby ]; then
        sed -i "s|^</manifest>|  <remove-project name=\"$name\" />\n</manifest>|" "$LOCAL"
        echo "    hardware/dolby: replacing the ROM's $name with ours"
    else
        sed -i "\|path=\"$path\"|d" "$LOCAL"
        echo "    $path comes from the ROM's manifest"
    fi
done

echo "==> Syncing the redwood repos"
paths=$(grep -oE 'path="[^"]+"' "$LOCAL" | cut -d'"' -f2)
# shellcheck disable=SC2086
repo sync -c --no-tags --force-sync -j"$(nproc --all)" $paths

grep -q "redwood-kernel-6.18" device/xiaomi/redwood/BoardConfig.mk ||
    die "device/xiaomi/redwood isn't the 6.18 device tree; check $LOCAL"
[ -f device/xiaomi/redwood/custom_redwood.mk ] ||
    die "device/xiaomi/redwood has no PixelOS product (custom_redwood.mk)"
[ -f device/xiaomi/redwood-kernel-6.18/Image ] ||
    die "no 6.18 kernel in device/xiaomi/redwood-kernel-6.18"
[ -f vendor/xiaomi/redwood/redwood-vendor.mk ] || die "no vendor blobs in vendor/xiaomi/redwood"
[ -f hardware/dolby/dolby.mk ] || die "no Dolby in hardware/dolby"
[ -f hardware/redwood-compat/Android.bp ] || die "no redwood compat shims in hardware/redwood-compat"
[ -f vendor/xiaomi/redwood-miuicamera/device.mk ] ||
    echo "    note: no MIUI camera in vendor/xiaomi/redwood-miuicamera, building without it"

echo "    kernel $(sed -n 's/^release=//p' device/xiaomi/redwood-kernel-6.18/build-info.txt)"
echo
echo "Now build with: $HERE/build.sh"
