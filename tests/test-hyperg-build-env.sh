#!/bin/sh
# Unit tests for scripts/hyperg-build.sh --print-env (pinned build inputs). Run from repo root.
. "$(dirname "$0")/lib/assert.sh"
env_out=$(scripts/hyperg-build.sh --print-env x86_64)
assert_contains "$env_out" "OMR_DIST=hyperg"        "dist"
assert_contains "$env_out" "OMR_TARGET=x86_64"      "target"
assert_contains "$env_out" "OMR_KERNEL=6.18"        "kernel"
assert_contains "$env_out" "OMR_FEED_SRC=v0.65"     "omr feed pinned to tag"
assert_contains "$env_out" "CUSTOM_FEED=feed"       "local feed"
assert_contains "$env_out" "OMR_PACKAGES=full"      "package set"
assert_contains "$env_out" "OMR_HOST=localhost"     "no ifconfig.co lookup"
assert_contains "$env_out" "OMR_RELEASE=$(cat VERSION)-omr0.65" "release string"
# no package feed pointing at foreign (incompatible) OpenWrt builds: .invalid never resolves
assert_contains "$env_out" "OMR_PACKAGES_URL=http://packages.hyperg.invalid" "apk feeds not foreign"
assert_contains "$env_out" "OMR_REPO=http://packages.hyperg.invalid/" "distfeed repo not localhost"
assert_contains "$(scripts/hyperg-build.sh --print-env rpi5)" "OMR_TARGET=rpi5" "rpi5"
err_file=$(mktemp)
scripts/hyperg-build.sh --print-env rpi4 2>"$err_file"; assert_eq 2 $? "bad target exit code"
assert_contains "$(cat "$err_file")" "unknown target: rpi4" "bad target message"
rm -f "$err_file"
finish
