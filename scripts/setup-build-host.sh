#!/bin/sh
# Install everything needed to build HyperG images on Ubuntu 22.04+/Debian 12+. Run with sudo.
set -e

GITLEAKS_VERSION=8.21.2

if [ "$(id -u)" -ne 0 ]; then
	echo "run with sudo" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
	build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git \
	libncurses-dev libssl-dev python3-setuptools python3-dev rsync swig unzip zlib1g-dev \
	file wget curl qemu-system-x86 qemu-utils sshpass \
	python3-docutils llvm

if ! command -v gitleaks >/dev/null 2>&1 || ! gitleaks version 2>/dev/null | grep -q "$GITLEAKS_VERSION"; then
	tmp=$(mktemp -d)
	base="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"
	tarball="gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
	curl -fsSL -o "$tmp/$tarball" "$base/$tarball"
	curl -fsSL -o "$tmp/checksums.txt" "$base/gitleaks_${GITLEAKS_VERSION}_checksums.txt"
	(cd "$tmp" && grep " $tarball\$" checksums.txt | sha256sum -c -)
	tar -xzf "$tmp/$tarball" -C "$tmp" gitleaks
	install -m 0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
	rm -rf "$tmp"
fi

echo "setup done; now run scripts/check-build-host.sh"
