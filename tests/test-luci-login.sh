#!/bin/sh
# Tests for the LuCI-is-serving helpers in tests/lib/assert.sh against a live LuCI.
#   LUCI_URL=http://127.0.0.1:18080/cgi-bin/luci/ sh tests/test-luci-login.sh
. "$(dirname "$0")/lib/assert.sh"
: "${LUCI_URL:?set LUCI_URL to a LuCI login URL}"
assert_eq yes "$(luci_serving "$LUCI_URL" && echo yes || echo no)"        "live LuCI recognised"
assert_eq no  "$(luci_serving "${LUCI_URL%/}-nope/" && echo yes || echo no)" "404 path not recognised"
assert_eq no  "$(luci_serving "http://127.0.0.1:1/" && echo yes || echo no)" "closed port not recognised"
assert_luci_login "$LUCI_URL" "assert_luci_login on live LuCI"
finish
