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

assert_luci_login "http://$H:$P/cgi-bin/hyperg/"               "hyperg path serves LuCI"
assert_http 404 "http://$H:$P/cgi-bin/luci/"                   "luci path gone"
assert_contains "$(curl -s --max-time 10 "http://$H:$P/")" "cgi-bin/hyperg/" "root redirects to hyperg"
# test_cgi_helpers_reachable: present = anything but 404
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$H:$P/cgi-bin/cgi-download")
assert_eq yes "$([ "$code" != 404 ] && echo yes || echo no)"   "cgi-download reachable ($code)"
assert_eq hyperg "$(r '. /etc/openwrt_release; echo $DISTRIB_ID')" "dist id"
assert_eq HyperG "$(r 'uci get system.@system[0].hostname')"      "hostname default"
assert_eq 0.1.0  "$(r 'uci get hyperg.main.version')"             "hyperg config"
# snmpd starts last (S99) and can come up well after LuCI does; give it up to 120 s (no-KVM boots)
assert_eq yes "$(r 'i=0; while [ $i -lt 120 ]; do pidof snmpd >/dev/null && { echo yes; exit; }; sleep 2; i=$((i + 2)); done')" "snmpd running"
assert_eq yes "$(r 'command -v ModemManager >/dev/null && echo yes')" "ModemManager installed"
assert_eq yes "$(r 'command -v wg >/dev/null && echo yes')"       "wireguard-tools installed"
assert_eq none "$(r 'grep -rl downloads.openwrt.org /etc/apk 2>/dev/null || echo none')" "no foreign apk feeds"
if [ -n "$WP" ]; then
	# OMR ships wan1/wan2 as static macvlans on eth1 with no address (its wizard fills them in), so
	# put wan1 on DHCP to give it an address on the QEMU user network. The WAN hostfwd targets the
	# first lease, 10.0.2.15; with any other address "web not reachable from WAN" proves nothing.
	wan_ip=$(r 'uci set network.wan1.proto=dhcp; uci commit network; /etc/init.d/network reload
		i=0; while [ $i -lt 60 ]; do
			a=$(ifstatus wan1 | jsonfilter -e "@[\"ipv4-address\"][0].address")
			[ -n "$a" ] && { echo "$a"; exit; }
			sleep 2; i=$((i + 2))
		done')
	assert_eq 10.0.2.15 "$wan_ip" "WAN (wan1, DHCP) up for the WAN-side test"
	assert_eq wan "$(r 'fw4 -q network wan1')" "wan1 in firewall zone wan"
	assert_http 000 "http://$H:$WP/cgi-bin/hyperg/"             "web not reachable from WAN"
fi
# test_defaults_idempotent_and_respect_operator (on the real image copy in /rom; squashfs only)
assert_eq yes "$(r 'test -f /rom/etc/uci-defaults/99-hyperg-base && echo yes')" "squashfs image with /rom"
r 'uci set system.@system[0].hostname=Pearl; uci commit system'
assert_eq 0 "$(r 'sh /rom/etc/uci-defaults/99-hyperg-base >/dev/null 2>&1; echo $?')" "defaults re-run ok"
assert_eq Pearl "$(r 'uci get system.@system[0].hostname')"       "operator hostname kept"
r 'uci set system.@system[0].hostname=HyperG; uci commit system'
# luci path stays gone after a luci-base upgrade re-adds its handler (fixed on next boot/restart)
r "uci add_list uhttpd.main.ucode_prefix='/cgi-bin/luci=/usr/share/ucode/luci/uhttpd.uc'; uci commit uhttpd; /etc/init.d/hyperg-www restart; /etc/init.d/uhttpd restart; sleep 3"
assert_http 404 "http://$H:$P/cgi-bin/luci/"                   "luci path gone after re-add"
finish
