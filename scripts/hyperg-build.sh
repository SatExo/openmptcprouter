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

out="out/$HYPERG_VERSION/$target"
mkdir -p "$out"
find "$target/$KERNEL/source/bin/targets" -type f \
	\( -name '*.img.gz' -o -name '*.qcow2' -o -name 'sha256sums' \) -exec cp -f {} "$out/" \;
echo "images in $out"
