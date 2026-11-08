#!/bin/sh
# Fast loop: copy feed/hyperg-base/files into a running router/VM over SSH and apply them.
#   tests/dev-push.sh <ssh_port> [host]
SP=$1; H=${2:-127.0.0.1}
[ -n "$SP" ] || { echo "usage: dev-push.sh <ssh_port> [host]" >&2; exit 2; }
F=feed/hyperg-base/files
SSH="sshpass -p '' ssh -p $SP -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@$H"
tmp=$(mktemp -d)
mkdir -p "$tmp/usr/share/hyperg/www-static"
cp -R "$F/etc" "$F/usr" "$tmp/"
cp -R "$F/www-hyperg-static/." "$tmp/usr/share/hyperg/www-static/"
tar -cf - -C "$tmp" . | eval "$SSH 'tar -xf - -C /'"
rm -rf "$tmp"
eval "$SSH 'sh /etc/uci-defaults/99-hyperg-base && /etc/init.d/hyperg-www enable && /etc/init.d/hyperg-www restart && /etc/init.d/uhttpd restart'"
