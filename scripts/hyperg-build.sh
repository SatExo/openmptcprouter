#!/bin/sh
# Build a HyperG image with upstream OMR build.sh, every version input pinned here.
#   scripts/hyperg-build.sh <x86_64|rpi5> [make args...]
#   scripts/hyperg-build.sh --print-env <x86_64|rpi5>   (dry run: print pinned env, exit)
set -e

OMR_BASE_TAG=v0.65
OMR_BASE_VERSION=0.65
KERNEL=6.18
# No online package repository in phase 1: point apk at a name that can never resolve, so
# `apk add` fails fast instead of installing packages from a different OpenWrt build.
PACKAGES_URL=http://packages.hyperg.invalid
# OpenWrt's own tools/Makefile that feed/source/*/6.18/tools/Makefile was made from (checked after the build)
TOOLS_MAKEFILE_SHA256=8df45eda7e42012d71e75d30dd0049cb7c9cef7dc888e989d2ce87eccf0b30d8

ROOT=$(cd "$(dirname "$0")/.." && pwd)

print_only=no
if [ "$1" = "--print-env" ]; then
	print_only=yes
	shift
fi

target=$1
case "$target" in
	x86_64|rpi5) ;;
	*)
		echo "unknown target: $target" >&2
		exit 2
		;;
esac
shift

HYPERG_VERSION=$(cat "$ROOT/VERSION")

export OMR_DIST=hyperg
export OMR_TARGET="$target"
export OMR_KERNEL="$KERNEL"
export OMR_FEED_SRC="$OMR_BASE_TAG"
export CUSTOM_FEED=feed
export OMR_PACKAGES=full
export OMR_HOST=localhost
export OMR_RELEASE="${HYPERG_VERSION}-omr${OMR_BASE_VERSION}"
export OMR_PACKAGES_URL="$PACKAGES_URL"
export OMR_REPO="$PACKAGES_URL/release/$OMR_RELEASE-$OMR_KERNEL/$OMR_TARGET"

if [ "$print_only" = yes ]; then
	for v in CUSTOM_FEED OMR_DIST OMR_FEED_SRC OMR_HOST OMR_KERNEL OMR_PACKAGES OMR_PACKAGES_URL OMR_RELEASE OMR_REPO OMR_TARGET; do
		eval "echo $v=\$$v"
	done | sort
	exit 0
fi

cd "$ROOT"
./build.sh "$@"

feed_dir=feeds/openmptcprouter
if git -C "$feed_dir" tag --points-at HEAD | grep -qx "$OMR_BASE_TAG"; then
	echo "OMR feed at $OMR_BASE_TAG"
else
	echo "OMR feed NOT at $OMR_BASE_TAG: $(git -C "$feed_dir" rev-parse --short HEAD)" >&2
	exit 1
fi

# feed/source/<target>/<kernel>/tools/Makefile replaces OpenWrt's (adds dwarves -> cmake); it is a
# whole-file copy, so it is only valid for the upstream file it was made from.
src="$target/$KERNEL/source"
have=$(git -C "$src" show HEAD:tools/Makefile | sha256sum | cut -d' ' -f1)
if [ "$have" != "$TOOLS_MAKEFILE_SHA256" ]; then
	echo "OpenWrt tools/Makefile changed upstream ($have): refresh feed/source/*/$KERNEL/tools/Makefile" >&2
	exit 1
fi
if ! cmp -s "$CUSTOM_FEED/source/$target/$KERNEL/tools/Makefile" "$src/tools/Makefile"; then
	echo "tools/Makefile override not applied in $src" >&2
	exit 1
fi
echo "tools/Makefile override applied"

out="out/$HYPERG_VERSION/$target"
mkdir -p "$out"
find "$target/$KERNEL/source/bin/targets" -type f \
	\( -name '*.img.gz' -o -name '*.qcow2' -o -name 'sha256sums' \) -exec cp -f {} "$out/" \;
echo "images in $out"
