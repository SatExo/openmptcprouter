# Plan 1 — handoff to the build machine

Written 2026-11-08 on the office PC (Windows, no Linux build possible). Continue here, on the
build VM, with Claude Code.

- Design: `docs/hyperg/2026-11-07-hyperg-firmware-restart-design.md`
- Plan: `docs/hyperg/plans/2026-11-08-plan-1-build-pipeline.md`
- Progress ledger (rulings, what is verified, deferred minors): `docs/hyperg/plans/2026-11-08-plan-1-progress.md`

All code for Tasks 1–7 and the final-review fixes is committed on branch `hyperg`.
**Still to verify on the build VM, in this order:**

1. Task 2 Steps 5–6: `sudo scripts/setup-build-host.sh && scripts/check-build-host.sh` →
   `build host OK`; owner registers the runner (label `hyperg-build`) → Idle, survives reboot.
2. Unit tests on Linux: `sh tests/test-hyperg-build-env.sh` (13/13), `sh tests/test-sync-www.sh` (7/7).
3. Task 3 Steps 2–4: `scripts/hyperg-build.sh x86_64 -j$(nproc)`; check `.config` selects
   hyperg-full, openmptcprouter-full, snmpd, modemmanager, kmod-usb-serial-option; build rpi5.
4. Task 4 Steps 6–7 and Task 5 Steps 2–3: `tests/smoke/boot-x86_64.sh out/0.1.0/x86_64/*-squashfs-combined.img.gz`
   → all `check-router.sh` assertions pass; repeat with `HYPERG_NO_KVM=1`.
   Also run `tests/test-uci-defaults.sh` and `LUCI_URL=http://127.0.0.1:18080/cgi-bin/hyperg/ tests/test-luci-login.sh`
   inside/against the booted image (`--keep-running`).
5. Task 6 Steps 1, 3, 4: fake-key branch fails gitleaks; push to `hyperg` → green with
   artifacts; second run on warm cache green, feed at v0.65.
6. Task 7 Steps 2, 4: Pi 5 boot + `check-router.sh 192.168.100.1 80 22`; test VPS connected.

Open checks from the review (do at step 4): do OMR uci-defaults that run after
`99-hyperg-base` override hostname / uhttpd home / ucode_prefix or set WAN static; do OMR LuCI
apps hard-code `/cgi-bin/luci/` links (grep the OMR feed before plan 3); does anything in OMR
parse the release string `0.1.0-omr0.65-6.18`.

When everything above is green: final whole-branch check, then plan 2 (theme) is written.
