# Minimal assertion helpers for POSIX sh tests. Source this file, call assert_*, end with finish.
_pass=0
_fail=0

_ok()  { _pass=$((_pass + 1)); printf 'ok   - %s\n' "$1"; }
_bad() { _fail=$((_fail + 1)); printf 'FAIL - %s\n       %s\n' "$1" "$2"; }

# assert_eq <expected> <actual> <msg>
assert_eq() {
	if [ "$1" = "$2" ]; then _ok "$3"; else _bad "$3" "expected [$1] got [$2]"; fi
}

# assert_contains <haystack> <needle> <msg>
assert_contains() {
	case "$1" in
		*"$2"*) _ok "$3" ;;
		*) _bad "$3" "[$2] not found" ;;
	esac
}

# assert_http <expected_code> <url> <msg>
assert_http() {
	_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$2")
	assert_eq "$1" "$_code" "$3"
}

finish() {
	printf '%s passed, %s failed\n' "$_pass" "$_fail"
	[ "$_fail" -eq 0 ]
}

# luci_serving <url>: true when LuCI answers at <url> — either its login page
# (403 + "X-LuCI-Login-Required: yes", the normal not-logged-in reply) or a 200 page.
luci_serving() {
	_hdr=$(curl -s -D - -o /dev/null --max-time 10 "$1" | tr -d '\r')
	case "$_hdr" in
		"HTTP/"*" 200"*) return 0 ;;
	esac
	printf '%s\n' "$_hdr" | grep -qi '^X-LuCI-Login-Required: yes'
}

# assert_luci_login <url> <msg>
assert_luci_login() {
	if luci_serving "$1"; then _ok "$2"; else _bad "$2" "LuCI not serving at $1"; fi
}
