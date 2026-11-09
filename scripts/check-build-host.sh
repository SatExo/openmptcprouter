#!/bin/sh
# Check that this Linux machine can build HyperG images. Prints "build host OK" or MISSING lines.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MIN_DISK_GB=150
MIN_RAM_GB=8
TOOLS="git gcc g++ make python3 rsync unzip wget curl file gawk perl qemu-system-x86_64 gitleaks sshpass rst2man clang opt llc llvm-dis llvm-strip"

missing=0
miss() { echo "MISSING: $1"; missing=1; }

os_ok=no
if [ -r /etc/os-release ]; then
	. /etc/os-release
	major=${VERSION_ID%%.*}
	case "$ID" in
		ubuntu) [ "${major:-0}" -ge 22 ] 2>/dev/null && os_ok=yes ;;
		debian) [ "${major:-0}" -ge 12 ] 2>/dev/null && os_ok=yes ;;
	esac
fi
[ "$os_ok" = yes ] || miss "Ubuntu 22.04+ or Debian 12+"

case "$ROOT" in
	/mnt/*) miss "build dir on Linux filesystem (repo is under $ROOT)" ;;
esac

free_gb=$(df -Pk "$ROOT" 2>/dev/null | awk 'NR==2 { print int($4 / 1048576) }')
[ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || miss "${MIN_DISK_GB} GB free disk (have ${free_gb:-?} GB)"

ram_gb=$(awk '/^MemTotal:/ { print int(($2 + 524288) / 1048576) }' /proc/meminfo 2>/dev/null)
[ "${ram_gb:-0}" -ge "$MIN_RAM_GB" ] || echo "WARN: ${MIN_RAM_GB} GB RAM preferred (have ${ram_gb:-?} GB)"

for t in $TOOLS; do
	command -v "$t" >/dev/null 2>&1 || miss "$t"
done

if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then echo "INFO: kvm yes"; else echo "INFO: kvm no"; fi

if [ "$missing" -eq 0 ]; then
	echo "build host OK"
fi
exit "$missing"
