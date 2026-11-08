# SDD ledger — plan: D:\SATMARIN\TECH DOCS\Hexoflux\HyperG-restart\docs\plans\2026-11-08-plan-1-build-pipeline.md
Spec: D:\SATMARIN\TECH DOCS\Hexoflux\HyperG-restart\docs\2026-11-07-hyperg-firmware-restart-design.md
Repo: D:\SATMARIN\TECH DOCS\Hexoflux\HyperG-restart\hg (clone of SatExo/hg), branch hyperg cut at v0.65 = 43522538
Pre-flight:
- T1 produces hyperg-build.sh/assert.sh -> T3,T4,T5,T6 consume: names consistent.
- T4 Step 6 consumes boot-x86_64.sh from T5 (forward ref, plan says boot by hand until T5): ok.
- T6 consumes test-hyperg-build-env.sh + test-sync-www.sh: consistent.
Ruling: legacy branch cut from origin/develop, not origin/master — SatExo/hg has only `develop` — cost if wrong: none (branch name only).
Ruling: tag v0.65 shares its commit with v0.66-snapshot, so `git describe` prints v0.66-snapshot; version checks use `git tag --points-at HEAD | grep -qx v0.65` — cost if wrong: a misleading log line.
Ruling: no push to SatExo/hg until the owner confirms (shared repo, outward-facing) — local commits only — cost if wrong: delay.
Ruling: executor is a Windows PC (no Linux, no KVM). Shell unit tests run in Git Bash; symlink-dependent tests (test-sync-www) run in busybox ash inside the reference QEMU VM; builds, smoke boots and CI steps wait for the build VM — cost if wrong: those Expected lines stay unverified until the build VM exists.
Ruling: repo-local git identity user.name=SatExo, user.email=owner's account email — no global identity configured — cost if wrong: amend author.
Task 1: complete (commits 4352253..31092e8, tests: sh tests/test-hyperg-build-env.sh → 11 passed, 0 failed)
Task 1: Ruling: did not add /feeds/ to .gitignore — upstream .gitignore already ignores `feeds` — cost if wrong: none.
Task 1: Ruling: assert.sh (test helper) written before the failing test so RED fails on the missing wrapper, not on a missing helper — cost if wrong: none.
Task 2: Ruling: PSScriptAnalyzer not installed here; new-build-vm.ps1 verified with the PowerShell parser only — cost if wrong: a lint warning (Write-Host) on the build PC.
Task 2: Ruling: gitleaks pinned to 8.21.2 and verified at install time against the release's own checksums file (GitHub release downloads time out from this PC, so the hash is not hard-coded) — cost if wrong: setup fails loudly on the build VM.
Task 2: partial — Steps 1-4 and 7 done (check script ran: exit 1 with MISSING lines as expected on this non-Linux PC). Steps 5-6 (setup + check on the VM, runner Idle) wait for the owner to create the build VM.
Task 3: partial — Step 1 and 5 done (Makefile committed). Steps 2-4 (x86_64/rpi5 builds, .config grep → 5) wait for the build VM.
Task 4: Ruling: LuCI also serves /cgi-bin/luci through uhttpd's in-process ucode handler (`uhttpd.main.ucode_prefix='/cgi-bin/luci=/usr/share/ucode/luci/uhttpd.uc'`), which ignores the web root. 99-hyperg-base therefore also moves that entry to /cgi-bin/hyperg (only if the stock luci entry is present). Our cgi-bin/hyperg file stays as fallback when the ucode handler is absent — cost if wrong: /cgi-bin/luci still answers; check-router's "luci path gone" catches it. Known limit: an `apk` upgrade of luci-base re-adds the luci entry via its postinst.
Task 4: Ruling: added tests/test-uci-defaults.sh (8 tests, temp UCI dir via UCI="uci -c dir", HYPERG_SYNC_WWW seam) — the plan only tested the defaults on a booted image; this pins idempotency, the ucode move and the WAN-rule report without a build — cost if wrong: none.
Task 4: Ruling: the firewall check reports to stderr + syslog (tag hyperg) and changes nothing, as the plan says — cost if wrong: an unsafe rule an operator added stays, but is visible in the log.
Task 4: verified here — test-sync-www.sh RED (2 passed/5 failed) → GREEN 7/7 and test-uci-defaults.sh RED (3/5 failed) → GREEN 8/8, both in busybox ash inside the reference QEMU VM (OpenWrt 21.02 userland). Steps 6-7 (dev-push + check-router against a built image, rebuild) wait for the build VM.
Task 5: Ruling: disk attached as IDE (not virtio) — the reference OMR x86 image booted that way here; virtio-blk support in the image is unverified — cost if wrong: slightly slower disk in the test VM.
Task 5: partial — Step 1 verified (missing image → "image not found", exit 2). Steps 2-3 (boot a built image with KVM and with HYPERG_NO_KVM=1) wait for the build VM.
Task 6: Ruling: gitleaks scans only HyperG commits (`--log-opts=v0.65..HEAD`), not upstream's whole history — upstream history is not ours to fix and would make the gate fail on things we can't change — cost if wrong: a secret introduced upstream after v0.65 is only caught when we rebase onto it (it would then be in our range).
Task 6: Ruling: CI unit tests run test-hyperg-build-env + test-sync-www only; test-uci-defaults needs the OpenWrt `uci` CLI, which Ubuntu lacks, so it runs in an OpenWrt VM (as done in Task 4) — cost if wrong: defaults regressions found at smoke-test time instead of unit-test time (check-router covers hostname + idempotency).
Task 6: partial — workflow + config committed, YAML validated. Step 1 (fake key fails the job), Step 3 (green run, 2 artifacts) and Step 4 (warm second run, feed at v0.65) need the push to SatExo/hg and the runner. gitleaks could not be installed here (winget: no internet to its source).
Task 7: partial — Steps 1, 3, 5 done (docs committed). Steps 2 and 4 (Pi 5 boot + check-router, test VPS connected) are owner bench steps after the first rpi5 image exists.
Final review: fresh reviewer (opus). Verdict: ready with fixes. 1 Critical, 6 Important, 14 Minor.
Final: fixed C1 smoke test expected 200, LuCI answers 403 + X-LuCI-Login-Required — confirmed against reference VM; test-luci-login.sh RED (function missing) → GREEN 4/4; boot wait + check-router use luci_serving/assert_luci_login.
Final: fixed I4 /cgi-bin/luci could return after luci-base upgrade — apply-web-path called from uci-defaults and init start; test-uci-defaults "re-added luci handler moved at boot" RED → GREEN, suite 10/10; on-image check added to check-router.
Final: fixed I3 image had foreign/localhost apk feeds — OMR_PACKAGES_URL/OMR_REPO = http://packages.hyperg.invalid; test-hyperg-build-env RED (2 failed) → GREEN 13/13; check-router asserts no downloads.openwrt.org.
Final: fixed I1 wrong image booted / vacuous /rom test — CI pins *-squashfs-combined.img.gz; boot script rejects >1 image (verified exit 2); check-router asserts /rom present and defaults exit 0. On-image RED not possible here (no image).
Final: fixed I2 WAN test could pass with WAN down — asserts WAN has 10.0.2.x first. Not runnable here (no image).
Final: fixed I5 Ubuntu LVM default leaves ~100 GB — doc says untick LVM or lvextend. Doc only.
Final: fixed I6 artifact quota — uploads only squashfs combined (x86) and squashfs factory+sysupgrade (rpi5). Config only.
Final: minor fixed incidentally: M11 Pi doc names the squashfs factory image (one-line doc change made with I1).
Final: minor (deferred): M1 defaults can't tell a deliberate stock value from stock (add defaults_applied marker).
Final: minor (deferred): M2 version string in a conffile and in four places.
Final: minor (deferred): M3 only cgi-download probed; probe cgi-upload/backup/exec too.
Final: minor (deferred): M4 feed tag checked only after the long build (use ONLY_GET_REPO first).
Final: minor (deferred): M5 out/<ver>/<target> not cleared before copying.
Final: minor (deferred): M6 boot wait budget ~2x and no INT/TERM trap.
Final: minor (deferred): M7 CI shows only last 200 log lines; upload build log on failure.
Final: minor (deferred): M8 720 min may be short for a cold two-target build; add permissions: contents: read + persist-credentials: false.
Final: minor (deferred): M9 add build user to kvm group in setup.
Final: minor (deferred): M10 doc: private-repo clone credentials; use hyperg-build.mshome.net.
Final: minor (deferred): M12 WAN firewall report only matches literal 80/443.
Final: minor (deferred): M13 snmpd ships with "public" community on LAN.
Final: minor (deferred): M14 removing hyperg-base leaves uhttpd pointing at /www-hyperg.
Final: Ruling: reviewer's declined-to-judge items (OMR uci-defaults after 99-, hard-coded /cgi-bin/luci links in OMR apps, release-string parsing) stand as open checks for the first smoke run and before plan 3 — cost if wrong: broken links found later.
Final: Ruling: repo visibility — if SatExo/hg is public (a fork of a public repo cannot be private), a self-hosted runner is exposed to fork PRs; must be confirmed by the owner before registering the runner — cost if wrong: Critical.
Follow-through: push tag v0.65 to origin with the branches (gitleaks range needs it).
Build PC (2026-11-08, LEN-W11-SPA): Task 2 Step 1 verified — Windows 11 Pro, i7-14700T, VT-x on (VBS hypervisor running), C: 407 GB free (>= 220 GB), Hyper-V enabled by the owner + reboot. Ubuntu 24.04.5 live-server ISO downloaded from releases.ubuntu.com, SHA256 97f3d7ff…cafae0fd8 matches SHA256SUMS (signature of SHA256SUMS not checked). new-build-vm.ps1 created hyperg-build (6 vCPU, nested virt True, autostart Start, checkpoints Disabled, ISO attached, Dynamic 200 GiB VHDX).
Ruling: VM RAM 10 GB → 8 GB static — on the 16 GB PC only 9.8 GB was free and the 10 GB VM failed to start (0x8007000E); dynamic memory not used because nested virtualization needs static memory. Script, build-host.md (WSL memory=8GB), plan and design updated; existing VM to be changed by the owner with Set-VMMemory -VMName hyperg-build -StartupBytes 8GB (pending) — cost if wrong: slower C++ link steps; lower -j if the guest swaps.
