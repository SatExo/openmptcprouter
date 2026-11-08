#!/bin/sh
# Unit tests for feed/hyperg-base/files/etc/uci-defaults/99-hyperg-base against a temp UCI dir.
# Needs the `uci` CLI (run inside an OpenWrt VM or router). Run from repo root.
. "$(dirname "$0")/lib/assert.sh"
DEFAULTS=feed/hyperg-base/files/etc/uci-defaults/99-hyperg-base
t=$(mktemp -d)
fresh() {
	cat > "$t/uhttpd" <<'U'
config uhttpd 'main'
	option home '/www'
	option cgi_prefix '/cgi-bin'
	list ucode_prefix '/cgi-bin/luci=/usr/share/ucode/luci/uhttpd.uc'
U
	cat > "$t/system" <<'S'
config system
	option hostname 'OpenMPTCProuter'
S
	cat > "$t/firewall" <<'F'
config rule
	option name 'Allow-Ping'
	option src 'wan'
	option proto 'icmp'
	option target 'ACCEPT'
F
}
run() { UCI="uci -c $t" HYPERG_SYNC_WWW=true sh "$DEFAULTS" 2>&1; }
get() { uci -c "$t" -q get "$1"; }

fresh; run >/dev/null
assert_eq "/www-hyperg" "$(get uhttpd.main.home)"                          "web root switched"
assert_eq "/cgi-bin/hyperg=/usr/share/ucode/luci/uhttpd.uc" "$(get uhttpd.main.ucode_prefix)" "ucode handler moved to hyperg"
assert_eq "HyperG" "$(get system.@system[0].hostname)"                      "default hostname"

# test_defaults_idempotent_and_respect_operator
run >/dev/null
assert_eq "/cgi-bin/hyperg=/usr/share/ucode/luci/uhttpd.uc" "$(get uhttpd.main.ucode_prefix)" "second run: one handler"
uci -c "$t" set system.@system[0].hostname=Pearl; uci -c "$t" set uhttpd.main.home=/srv/web; uci -c "$t" commit
run >/dev/null
assert_eq "Pearl" "$(get system.@system[0].hostname)"                       "operator hostname kept"
assert_eq "/srv/web" "$(get uhttpd.main.home)"                              "operator web root kept"

# a rule that opens the web interface to WAN is reported, not changed
fresh
printf "config rule\n\toption name 'Web-WAN'\n\toption src 'wan'\n\toption dest_port '443'\n\toption target 'ACCEPT'\n" >> "$t/firewall"
out=$(run)
assert_contains "$out" "Web-WAN accepts web from wan"                      "web-from-wan rule reported"
assert_eq "ACCEPT" "$(get firewall.@rule[1].target)"                        "rule left unchanged"
rm -rf "$t"
finish
