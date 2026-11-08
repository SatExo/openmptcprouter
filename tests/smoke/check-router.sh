#!/bin/sh
# Assertions against a running HyperG router (QEMU VM or Pi 5). Fresh image: root, empty password.
#   tests/smoke/check-router.sh <host> <http_port> <ssh_port> [wan_http_port]
. "$(dirname "$0")/../lib/assert.sh"
H=$1; P=$2; SP=$3; WP=$4
if [ -z "$H" ] || [ -z "$P" ] || [ -z "$SP" ]; then
	echo "usage: check-router.sh <host> <http_port> <ssh_port> [wan_http_port]" >&2
	exit 2
fi
r() {
	sshpass -p '' ssh -p "$SP" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR -o ConnectTimeout=15 "root@$H" "$1"
}

assert_http 200 "http://$H:$P/cgi-bin/hyperg/"                 "hyperg path serves LuCI"
assert_http 404 "http://$H:$P/cgi-bin/luci/"                   "luci path gone"
assert_contains "$(curl -s --max-time 10 "http://$H:$P/")" "cgi-bin/hyperg/" "root redirects to hyperg"
# test_cgi_helpers_reachable: present = anything but 404
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$H:$P/cgi-bin/cgi-download")
assert_eq yes "$([ "$code" != 404 ] && echo yes || echo no)"   "cgi-download reachable ($code)"
assert_eq hyperg "$(r '. /etc/openwrt_release; echo $DISTRIB_ID')" "dist id"
assert_eq HyperG "$(r 'uci get system.@system[0].hostname')"      "hostname default"
assert_eq 0.1.0  "$(r 'uci get hyperg.main.version')"             "hyperg config"
assert_eq yes "$(r 'pidof snmpd >/dev/null && echo yes')"         "snmpd running"
assert_eq yes "$(r 'command -v ModemManager >/dev/null && echo yes')" "ModemManager installed"
assert_eq yes "$(r 'command -v wg >/dev/null && echo yes')"       "wireguard-tools installed"
if [ -n "$WP" ]; then
	assert_http 000 "http://$H:$WP/cgi-bin/hyperg/"             "web not reachable from WAN"
fi
# test_defaults_idempotent_and_respect_operator (on the real image copy in /rom)
r 'uci set system.@system[0].hostname=Pearl; uci commit system; sh /rom/etc/uci-defaults/99-hyperg-base'
assert_eq Pearl "$(r 'uci get system.@system[0].hostname')"       "operator hostname kept"
r 'uci set system.@system[0].hostname=HyperG; uci commit system'
finish
