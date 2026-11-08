#!/bin/sh
# Boot an x86_64 HyperG image in QEMU (never modifying it) and run check-router.sh against it.
#   tests/smoke/boot-x86_64.sh <image.img.gz> [--keep-running]
# HYPERG_NO_KVM=1 forces software emulation.
IMG=$1
KEEP=$2
HERE=$(cd "$(dirname "$0")" && pwd)
LAN_HTTP=18080
LAN_SSH=12222
WAN_HTTP=18081
TIMEOUT_KVM=180
TIMEOUT_TCG=900

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
	echo "image not found: $IMG" >&2
	exit 2
fi

work=$(mktemp -d)
gunzip -c "$IMG" > "$work/base.img" 2>/dev/null || [ -s "$work/base.img" ] || {
	echo "cannot decompress $IMG" >&2
	exit 2
}
qemu-img create -q -f qcow2 -F raw -b "$work/base.img" "$work/disk.qcow2"

if [ -z "$HYPERG_NO_KVM" ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
	accel=kvm; timeout=$TIMEOUT_KVM
else
	accel=tcg; timeout=$TIMEOUT_TCG
fi
echo "accel: $accel"

qemu-system-x86_64 -name hyperg-smoke -m 1024 -smp 2 -accel "$accel" \
	-drive "file=$work/disk.qcow2,format=qcow2,if=ide" \
	-netdev "user,id=lan,net=192.168.100.0/24,host=192.168.100.2,dhcpstart=192.168.100.50,hostfwd=tcp:127.0.0.1:$LAN_HTTP-192.168.100.1:80,hostfwd=tcp:127.0.0.1:$LAN_SSH-192.168.100.1:22" \
	-device e1000,netdev=lan \
	-netdev "user,id=wan,hostfwd=tcp:127.0.0.1:$WAN_HTTP-:80" \
	-device e1000,netdev=wan \
	-display none -serial "file:$work/console.log" &
qemu_pid=$!

cleanup() {
	if [ "$KEEP" != "--keep-running" ]; then
		kill "$qemu_pid" 2>/dev/null
		wait "$qemu_pid" 2>/dev/null
		rm -rf "$work"
	else
		echo "QEMU left running (pid $qemu_pid); console log: $work/console.log"
	fi
}

waited=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$LAN_HTTP/cgi-bin/hyperg/")" = 200 ]; do
	if [ "$waited" -ge "$timeout" ] || ! kill -0 "$qemu_pid" 2>/dev/null; then
		echo "boot timeout after ${waited}s; last console lines:" >&2
		tail -20 "$work/console.log" >&2
		KEEP=
		cleanup
		exit 3
	fi
	sleep 5
	waited=$((waited + 5))
done
echo "web interface up after ${waited}s"

sh "$HERE/check-router.sh" 127.0.0.1 "$LAN_HTTP" "$LAN_SSH" "$WAN_HTTP"
rc=$?
cleanup
exit "$rc"
