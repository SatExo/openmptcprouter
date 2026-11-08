#!/bin/sh
# Unit tests for feed/hyperg-base/files/usr/libexec/hyperg/sync-www, temp dirs only. Run from repo root.
. "$(dirname "$0")/lib/assert.sh"
t=$(mktemp -d); src=$t/www; st=$t/static; dst=$t/out
mkdir -p "$src/cgi-bin" "$src/luci-static" "$st/cgi-bin"
touch "$src/index.html" "$src/cgi-bin/luci" "$src/cgi-bin/cgi-upload" "$src/cgi-bin/cgi-backup"
echo hg > "$st/cgi-bin/hyperg"; echo redirect > "$st/index.html"
SYNC=${SYNC:-feed/hyperg-base/files/usr/libexec/hyperg/sync-www}
sh "$SYNC" "$src" "$st" "$dst"
assert_eq "$src/luci-static" "$(readlink "$dst/luci-static")"              "luci-static mirrored"
assert_eq "$src/cgi-bin/cgi-upload" "$(readlink "$dst/cgi-bin/cgi-upload")" "cgi helper mirrored"
assert_eq "no" "$([ -e "$dst/cgi-bin/luci" ] && echo yes || echo no)"       "luci cgi absent"
assert_eq "hg" "$(cat "$dst/cgi-bin/hyperg")"                              "hyperg cgi present"
assert_eq "redirect" "$(cat "$dst/index.html")"                            "own index.html"
# test_www_mirror_picks_up_new_entries
mkdir "$src/newapp"; sh "$SYNC" "$src" "$st" "$dst"
assert_eq "$src/newapp" "$(readlink "$dst/newapp")"                        "new entry picked up"
# stale links removed
rmdir "$src/newapp"; sh "$SYNC" "$src" "$st" "$dst"
assert_eq "no" "$([ -L "$dst/newapp" ] && echo yes || echo no)"            "stale link removed"
rm -rf "$t"
finish
