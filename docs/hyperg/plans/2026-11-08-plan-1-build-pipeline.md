# HyperG Plan 1 — Build Pipeline and Base Image — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A push to `SatExo/hg` builds a bootable HyperG image (OMR v0.65 base) for `x86_64` and `rpi5` on a Linux VM hosted on the spare Windows 11 PC, smoke-tests the x86_64 image in QEMU, and the image serves the web interface only at `/cgi-bin/hyperg/` with SNMP and ModemManager included.

**Architecture:** `SatExo/hg` gets a fresh `hyperg` branch cut from upstream `Ysurac/openmptcprouter` tag `v0.65`. Our OpenWrt feed lives in `feed/` of the same repo and is handed to upstream's unmodified `build.sh` through `CUSTOM_FEED=feed` with `OMR_DIST=hyperg`; `build.sh` then selects our meta package `hyperg-full` (`CONFIG_PACKAGE_${OMR_DIST}-${OMR_PACKAGES}=y`), which depends on `openmptcprouter-full` plus our additions. A wrapper script pins every version input. GitHub Actions runs on a self-hosted runner inside the build VM.

**Tech Stack:** OpenWrt build system (OMR `build.sh`, kernel 6.18, apk package manager), POSIX shell, ucode (LuCI CGI), uhttpd, GitHub Actions (self-hosted runner), Hyper-V, QEMU, gitleaks.

**Spec:** `D:\SATMARIN\TECH DOCS\Hexoflux\HyperG-restart\docs\2026-11-07-hyperg-firmware-restart-design.md`

## Plan series (roadmap)

This is plan 1 of 6. Each later plan is written when the previous one is done, against the code that then exists.

1. **Build pipeline and base image** (this plan).
2. Theme frame and shared widget set (`luci-theme-hyper`), page inventory and page register.
3. WAN-Bonding page.
4. Link-metrics collector + HUD (mockup approved first) + Dashboard.
5. Remaining pages (remote-config pages first, then System/Services); WireGuard management tunnel; apply-with-rollback audit.
6. Pi 5 bench acceptance: 3 × RM500 + Starlink against the test VPS.

## Global Constraints

- Base: upstream `Ysurac/openmptcprouter` tag **`v0.65`**; OMR feed pinned with `OMR_FEED_SRC=v0.65` (upstream's default is the moving `develop`).
- Kernel: `OMR_KERNEL=6.18` (upstream default for v0.65).
- Targets: `rpi5` and `x86_64` only.
- `OMR_DIST=hyperg`; HyperG version from the repo file `VERSION` (initial value `0.1.0`); `OMR_RELEASE=<VERSION>-omr0.65`.
- Never ship a package with the same name as an upstream package: `build.sh` installs our feed with `feeds install -f` (force), so a name clash silently replaces upstream.
- Never edit or delete a file owned by an upstream package, in the build tree or at runtime.
- No secret in the repository. Tokens, keys and passwords are entered by the owner on the device or runner, never committed. Claude does not type tokens into anything; the owner does those steps.
- Web interface at `/cgi-bin/hyperg/` only; `/cgi-bin/luci/` returns 404. Not reachable from WAN.
- Image includes `snmpd` + `luci-app-snmpd`, ModemManager (`modemmanager`, `luci-proto-modemmanager`) and RM500 drivers (`kmod-usb-serial-option`, `kmod-usb-net-qmi-wwan`, `kmod-usb-net-cdc-mbim`).
- HyperG's own settings live in UCI config `/etc/config/hyperg`.
- Build host: the spare Windows 11 PC (Core i7, 16 GB) stays a Windows PC. Builds run in a **Hyper-V VM** (Ubuntu 24.04 Server, 6 vCPU, 8 GB RAM, 200 GB dynamically expanding disk, nested virtualization on, starts automatically with Windows). If the PC has Windows 11 Home (no Hyper-V), the fallback is WSL2 with the same sizes (Task 2 covers both).
- Build files stay on the VM's own Linux disk, never on a Windows drive (`/mnt/c`): building there is many times slower and breaks on case-insensitive paths.

## Review Focus

1. **Sysupgrade with "keep settings" re-runs uci-defaults** — an operator who renamed the router or changed uhttpd must keep their values. Test: `test_defaults_idempotent_and_respect_operator` (Task 4).
2. **LuCI helper CGIs** (`cgi-upload`, `cgi-download`, `cgi-backup`, `cgi-exec`, used by Backup/Flash Firmware and file uploads) must keep working under the new web root. Test: `test_cgi_helpers_reachable` (Task 4).
3. **Packages installed later** (via apk) that add files under `/www` must appear in the HyperG web root after a restart. Test: `test_www_mirror_picks_up_new_entries` (Task 4).
4. **A second build on the same VM** (warm cache, existing `feeds/` and target dirs) must succeed and not pick up stale feed versions. Test: CI run twice, Task 6 Step 4.
5. **No KVM inside the build VM** (nested virtualization off or unsupported) — the smoke test must fall back to software emulation with a longer timeout rather than fail. Test: `boot-x86_64.sh` honours `HYPERG_NO_KVM=1` (Task 5).

---

## File Structure (all in `SatExo/hg`, branch `hyperg`)

| Path | Responsibility |
|---|---|
| `VERSION` | HyperG version string, one line |
| `scripts/hyperg-build.sh` | Pins all build inputs, calls upstream `build.sh`; `--print-env` dry run |
| `scripts/check-build-host.sh` | Verifies the build VM meets prerequisites |
| `scripts/setup-build-host.sh` | Installs build prerequisites on Ubuntu/Debian |
| `scripts/windows/new-build-vm.ps1` | Creates the Hyper-V build VM on the Windows PC (owner runs it) |
| `feed/hyperg-full/Makefile` | Meta package: `openmptcprouter-full` + HyperG additions |
| `feed/hyperg-base/Makefile` | Base package: web root, defaults, `hyperg` config |
| `feed/hyperg-base/files/etc/config/hyperg` | HyperG UCI config skeleton |
| `feed/hyperg-base/files/etc/uci-defaults/99-hyperg-base` | First-boot defaults (idempotent) |
| `feed/hyperg-base/files/etc/init.d/hyperg-www` | Rebuilds `/www-hyperg` mirror before uhttpd starts |
| `feed/hyperg-base/files/usr/libexec/hyperg/sync-www` | The mirror logic (called by init script) |
| `feed/hyperg-base/files/www-hyperg-static/cgi-bin/hyperg` | LuCI CGI entry (ucode), HyperG path |
| `feed/hyperg-base/files/www-hyperg-static/index.html` | Redirect to `cgi-bin/hyperg/` |
| `tests/lib/assert.sh` | Minimal shell assertion helpers |
| `tests/test-hyperg-build-env.sh` | Unit tests for the wrapper's pinned env |
| `tests/test-sync-www.sh` | Unit tests for `sync-www` against a temp dir |
| `tests/smoke/check-router.sh` | Assertions against a running router (VM or Pi) |
| `tests/smoke/boot-x86_64.sh` | Boots an x86_64 image in QEMU, runs `check-router.sh` |
| `tests/dev-push.sh` | Copies `feed/hyperg-base/files` into a running VM for a fast loop |
| `.github/workflows/build.yml` | CI: secret scan, unit tests, build both targets, smoke test |
| `.gitignore` | Ignores build dirs (`x86_64/`, `rpi5/`, `feeds/`, `out/`) |
| `docs/hyperg/build-host.md` | Owner steps: Windows PC, build VM, runner registration |
| `docs/hyperg/test-vps.md` | Owner steps: test VPS on OMR 0.65 |
| `docs/hyperg/pi5-first-boot.md` | Flashing and first boot of the Pi 5 |

---

### Task 1: Fresh `hyperg` branch on upstream v0.65, wrapper script with pinned inputs

**Files:**
- Create: `VERSION`, `scripts/hyperg-build.sh`, `tests/lib/assert.sh`, `tests/test-hyperg-build-env.sh`, `.gitignore`

**Interfaces:**
- Produces: `scripts/hyperg-build.sh <target> [make args…]` where `<target>` ∈ `x86_64|rpi5`; `scripts/hyperg-build.sh --print-env <target>` prints `KEY=VALUE` lines (sorted) and exits 0; exits 2 with `unknown target: <t>` on stderr for any other target.
- Produces: `tests/lib/assert.sh` with `assert_eq <expected> <actual> <msg>`, `assert_contains <haystack> <needle> <msg>`, `assert_http <expected_code> <url> <msg>`, and `finish` (prints `N passed, M failed`, exits 1 if any failed).

- [ ] **Step 1: Preserve old history and cut the branch** (in a local clone of `SatExo/hg`)

```bash
git fetch origin
git branch legacy-2023 origin/master && git push origin legacy-2023
git remote add upstream https://github.com/Ysurac/openmptcprouter.git
git fetch upstream --tags
git checkout -b hyperg v0.65
```

Expected: `git describe --tags` prints `v0.65`.

- [ ] **Step 2: Write the failing test `tests/test-hyperg-build-env.sh`**

```sh
#!/bin/sh
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
assert_contains "$(scripts/hyperg-build.sh --print-env rpi5)" "OMR_TARGET=rpi5" "rpi5"
scripts/hyperg-build.sh --print-env rpi4 2>/tmp/err; assert_eq 2 $? "bad target exit code"
assert_contains "$(cat /tmp/err)" "unknown target: rpi4" "bad target message"
finish
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `sh tests/test-hyperg-build-env.sh`
Expected: FAIL (`scripts/hyperg-build.sh: not found`).

- [ ] **Step 4: Implement `tests/lib/assert.sh`, `VERSION` (`0.1.0`), `.gitignore` (`/x86_64/`, `/rpi5/`, `/feeds/`, `/out/`) and `scripts/hyperg-build.sh`**

The wrapper `export`s the variables tested above, `cd`s to the repo root, and for a real build runs `./build.sh "$@"` (upstream script, untouched), then copies `"$OMR_TARGET"/6.18/source/bin/targets/**` images into `out/<VERSION>/<target>/`. `assert_http` uses `curl -s -o /dev/null -w '%{http_code}' --max-time 10`.

- [ ] **Step 5: Run the test**

Run: `sh tests/test-hyperg-build-env.sh`
Expected: `11 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add VERSION scripts/hyperg-build.sh tests/ .gitignore
git commit -m "build: hyperg branch on OMR v0.65 with pinned build wrapper"
```

---

### Task 2: Build VM on the spare Windows 11 PC, and runner registration

**Files:**
- Create: `scripts/windows/new-build-vm.ps1`, `scripts/setup-build-host.sh`, `scripts/check-build-host.sh`, `docs/hyperg/build-host.md`

**Interfaces:**
- Produces: `scripts/windows/new-build-vm.ps1 -IsoPath <ubuntu-24.04-server.iso> [-VhdDir <dir>]` (run by the owner in an elevated PowerShell on the Windows PC). It creates VM `hyperg-build`: Generation 2, Secure Boot template `MicrosoftUEFICertificateAuthority`, 6 vCPU, 8 GB static RAM, 200 GB dynamic VHDX in `-VhdDir` (default `C:\HyperG\vm`), attached to the `Default Switch`, `Set-VMProcessor -ExposeVirtualizationExtensions $true` (nested virtualization, gives the VM `/dev/kvm`), `AutomaticStartAction Start`, `AutomaticStopAction ShutDown`. It refuses with a clear message if Hyper-V is not enabled, or if the VHD drive has under 220 GB free.
- Produces: `scripts/check-build-host.sh` — exits 0 and prints `build host OK` when all checks pass; otherwise prints one `MISSING: <item>` line per failure and exits 1. Checks: OS is Ubuntu 22.04+/Debian 12+; repo is **not** under `/mnt/` (`MISSING: build dir on Linux filesystem`); ≥150 GB free on the repo's filesystem; ≥8 GB RAM (`WARN:` only); commands present: `git gcc g++ make python3 rsync unzip wget curl file gawk perl qemu-system-x86_64 gitleaks sshpass`; prints `INFO: kvm yes|no`.

- [ ] **Step 1: Write `scripts/check-build-host.sh`; run it in a fresh Ubuntu VM or container**

Expected: exits 1 with `MISSING:` lines for the uninstalled tools.

- [ ] **Step 2: Write `scripts/setup-build-host.sh`**

Installs via `apt-get` the OpenWrt build prerequisites (`build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev python3-setuptools python3-dev rsync swig unzip zlib1g-dev file wget curl qemu-system-x86 qemu-utils sshpass`) and gitleaks from its GitHub release tarball, pinned by version and verified against the SHA-256 published with it.

- [ ] **Step 3: Write `scripts/windows/new-build-vm.ps1`**

Check it with `Invoke-ScriptAnalyzer` (PSScriptAnalyzer). Expected: no errors.

- [ ] **Step 4: Write `docs/hyperg/build-host.md`** — the owner's steps, in order:
  1. On the Windows 11 PC check the edition: `winver`. **Pro/Enterprise → Hyper-V path. Home → WSL2 path.**
  2. Hyper-V path:
     - Enable Hyper-V (*Turn Windows features on or off → Hyper-V*) and reboot.
     - Download the Ubuntu 24.04 Server ISO and run `new-build-vm.ps1`.
     - Install Ubuntu with an OpenSSH server and user `hgbuild`.
     - The VM starts on its own whenever Windows boots; no one needs to log in.
  3. WSL2 path:
     - Run `wsl --install -d Ubuntu-24.04`.
     - In `%UserProfile%\.wslconfig` set `[wsl2] memory=8GB processors=6 nestedVirtualization=true vmIdleTimeout=-1`.
     - In the distro's `/etc/wsl.conf` set `[boot] systemd=true`.
     - Add a Windows Task Scheduler task "at startup" running `wsl -d Ubuntu-24.04 --exec sleep infinity`, so WSL keeps running without a login.
  4. Inside Linux:
     - Clone the repo into `~/hg`. It must live on the Linux disk, never under `/mnt/c`.
     - Run `sudo scripts/setup-build-host.sh`, then `scripts/check-build-host.sh`.
  5. Register the runner. The owner does this, because the registration token is theirs to enter:
     - In GitHub go to *Settings → Actions → Runners → New self-hosted runner* and run the commands it shows inside the VM, with label `hyperg-build`.
     - Install the runner as a service: `sudo ./svc.sh install hgbuild && sudo ./svc.sh start`.
  6. Returning the PC to spare duty:
     - Hyper-V: shut down the VM and set `AutomaticStartAction Nothing`.
     - WSL2: disable the scheduled task.
     - The build cache stays in the VHDX for when the PC is used for builds again.

- [ ] **Step 5: Owner follows the doc; verify inside the VM**

Run: `scripts/check-build-host.sh`
Expected: `build host OK` and `INFO: kvm yes` (if `kvm no`, the smoke test still works via Task 5's fallback, only slower).

- [ ] **Step 6: Verify the runner**

Expected: runner `hyperg-build` shows **Idle** on the repo's Runners page; after rebooting the Windows PC without logging in it returns to **Idle** within 5 minutes.

- [ ] **Step 7: Commit**

```bash
git add scripts/windows/new-build-vm.ps1 scripts/setup-build-host.sh scripts/check-build-host.sh docs/hyperg/build-host.md
git commit -m "build: Hyper-V/WSL2 build host setup, check script and runner instructions"
```

---

### Task 3: Meta package `hyperg-full` and the first stock-equivalent image

**Files:**
- Create: `feed/hyperg-full/Makefile`

**Interfaces:**
- Consumes: `scripts/hyperg-build.sh` (Task 1).
- Produces: package `hyperg-full` (section `HyperG`, category `HyperG`, no files), whose `DEPENDS` are exactly: `+openmptcprouter-full +snmpd +luci-app-snmpd +modemmanager +luci-proto-modemmanager +kmod-usb-serial-option +kmod-usb-net-qmi-wwan +kmod-usb-net-cdc-mbim +wireguard-tools +hyperg-base`. (`hyperg-base` is added in Task 4; until then leave it out and add it in Task 4 Step 5.)
- Produces: image files under `out/0.1.0/x86_64/` and `out/0.1.0/rpi5/`.

- [ ] **Step 1: Write `feed/hyperg-full/Makefile`** modelled on upstream `openmptcprouter-full/Makefile` (meta package, empty `Build/Compile` and `install`), with the DEPENDS above minus `hyperg-base`.

- [ ] **Step 2: First full build of x86_64 in the build VM**

Run: `scripts/hyperg-build.sh x86_64 -j$(nproc) 2>&1 | tee out/build-x86_64.log`
Expected: exit 0; `out/0.1.0/x86_64/` contains `*-squashfs-combined*.img.gz`. (First build: several hours.)

- [ ] **Step 3: Confirm the package selection**

Run: `grep -E '^CONFIG_PACKAGE_(hyperg-full|openmptcprouter-full|snmpd|modemmanager|kmod-usb-serial-option)=y' x86_64/6.18/source/.config | wc -l`
Expected: `5`.

- [ ] **Step 4: Build rpi5**

Run: `scripts/hyperg-build.sh rpi5 -j$(nproc) 2>&1 | tee out/build-rpi5.log`
Expected: exit 0; `out/0.1.0/rpi5/` contains a `*bcm2712*` image.

- [ ] **Step 5: Commit**

```bash
git add feed/hyperg-full/Makefile
git commit -m "feat(feed): hyperg-full meta package (OMR full + SNMP + ModemManager + RM500 drivers)"
```

---

### Task 4: `hyperg-base` — own web root at `/cgi-bin/hyperg/`, defaults, `hyperg` config

**Files:**
- Create: everything under `feed/hyperg-base/`, `tests/test-sync-www.sh`, `tests/dev-push.sh`, `tests/smoke/check-router.sh`
- Modify: `feed/hyperg-full/Makefile` (add `+hyperg-base`)

**Interfaces:**
- Produces: `/usr/libexec/hyperg/sync-www <src_www> <static_dir> <dst_root>` — makes `<dst_root>` contain: a symlink for every top-level entry of `<src_www>` except `cgi-bin` and `index.html`; a real directory `cgi-bin/` containing a symlink for every entry of `<src_www>/cgi-bin` except `luci`; then copies `<static_dir>/*` over it (our `cgi-bin/hyperg` and `index.html`). Removes stale symlinks it created earlier. Exit 0. Called on device as `sync-www /www /usr/share/hyperg/www-static /www-hyperg`.
- Produces: init script `hyperg-www` with `START=49` (uhttpd is 50) calling `sync-www`.
- Produces: `/etc/config/hyperg`:

```
config hyperg 'main'
	option version '0.1.0'
```

  (Later plans add sections such as `profile` here; nothing else in this plan.)
- Produces: `/etc/uci-defaults/99-hyperg-base`, idempotent:
  - sets `uhttpd.main.home='/www-hyperg'` **only if** it is still `/www`;
  - sets `system.@system[0].hostname='HyperG'` **only if** it is still `OpenMPTCProuter` or `OpenWrt`;
  - checks that `firewall` has no rule accepting tcp 80/443 from zone `wan` (it checks and adds nothing; OMR's `wan` input policy is REJECT);
  - runs `sync-www` once; exits 0 so it is deleted after first run.
- Produces: `tests/smoke/check-router.sh <host> <http_port> <ssh_port> [wan_http_port]` — runs the assertions below against a live router over HTTP and SSH (`root`, empty password on a fresh image, via `sshpass -p ''`); `finish` exit code.
- Produces: `tests/dev-push.sh <ssh_port>` — copies `feed/hyperg-base/files/*` into a running VM at `127.0.0.1:<ssh_port>` (paths as installed), runs `/etc/uci-defaults/99-hyperg-base` and `/etc/init.d/hyperg-www restart; /etc/init.d/uhttpd restart`.

- [ ] **Step 1: Write the failing unit test `tests/test-sync-www.sh`** (runs on any Linux host, temp dirs only)

```sh
#!/bin/sh
. "$(dirname "$0")/lib/assert.sh"
t=$(mktemp -d); src=$t/www; st=$t/static; dst=$t/out
mkdir -p $src/cgi-bin $src/luci-static $st/cgi-bin
touch $src/index.html $src/cgi-bin/luci $src/cgi-bin/cgi-upload $src/cgi-bin/cgi-backup
echo hg > $st/cgi-bin/hyperg; echo redirect > $st/index.html
SYNC=feed/hyperg-base/files/usr/libexec/hyperg/sync-www
sh $SYNC $src $st $dst
assert_eq "$src/luci-static" "$(readlink $dst/luci-static)"            "luci-static mirrored"
assert_eq "$src/cgi-bin/cgi-upload" "$(readlink $dst/cgi-bin/cgi-upload)" "cgi helper mirrored"
assert_eq "no" "$([ -e $dst/cgi-bin/luci ] && echo yes || echo no)"     "luci cgi absent"
assert_eq "hg" "$(cat $dst/cgi-bin/hyperg)"                            "hyperg cgi present"
assert_eq "redirect" "$(cat $dst/index.html)"                          "own index.html"
# test_www_mirror_picks_up_new_entries
mkdir $src/newapp; sh $SYNC $src $st $dst
assert_eq "$src/newapp" "$(readlink $dst/newapp)"                      "new entry picked up"
# stale links removed
rmdir $src/newapp; sh $SYNC $src $st $dst
assert_eq "no" "$([ -L $dst/newapp ] && echo yes || echo no)"          "stale link removed"
finish
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `sh tests/test-sync-www.sh`
Expected: FAIL (sync-www missing).

- [ ] **Step 3: Implement `sync-www`** (POSIX sh, no bashisms — runs under busybox ash). Run `sh tests/test-sync-www.sh` → `7 passed, 0 failed`.

- [ ] **Step 4: Write `tests/smoke/check-router.sh`** with these assertions (they will fail against the Task 3 image, which has no `hyperg-base`):

```sh
assert_http 200 "http://$H:$P/cgi-bin/hyperg/"            "hyperg path serves LuCI"
assert_http 404 "http://$H:$P/cgi-bin/luci/"              "luci path gone"
assert_contains "$(curl -s http://$H:$P/)" "cgi-bin/hyperg/" "root redirects to hyperg"
# test_cgi_helpers_reachable: helper exists (405/403/400 = present; 404 = missing)
code=$(curl -s -o /dev/null -w '%{http_code}' http://$H:$P/cgi-bin/cgi-download)
assert_eq yes "$([ "$code" != 404 ] && echo yes || echo no)"  "cgi-download reachable"
assert_eq hyperg "$(r '. /etc/openwrt_release; echo $DISTRIB_ID')" "dist id"
assert_eq HyperG "$(r 'uci get system.@system[0].hostname')"     "hostname default"
assert_eq 0.1.0  "$(r 'uci get hyperg.main.version')"            "hyperg config"
assert_eq yes "$(r 'pidof snmpd >/dev/null && echo yes')"        "snmpd running"
assert_eq yes "$(r 'command -v ModemManager >/dev/null && echo yes')" "ModemManager installed"
assert_eq yes "$(r 'command -v wg >/dev/null && echo yes')"     "wireguard-tools installed"
[ -n "$WP" ] && assert_http 000 "http://$H:$WP/cgi-bin/hyperg/" "web not reachable from WAN"
# test_defaults_idempotent_and_respect_operator
r 'uci set system.@system[0].hostname=Pearl; uci commit system; sh /rom/etc/uci-defaults/99-hyperg-base'
assert_eq Pearl "$(r 'uci get system.@system[0].hostname')"      "operator hostname kept"
r 'uci set system.@system[0].hostname=HyperG; uci commit system'
```

  where `r` runs a command over SSH. (`/rom/etc/uci-defaults/99-hyperg-base` is the pristine copy in the read-only image.)

- [ ] **Step 5: Implement the rest of `hyperg-base`**:
  - `Makefile`: installs `files/` to the paths in the table, and `www-hyperg-static/` to `/usr/share/hyperg/www-static/`; `DEPENDS:=+luci-base +uhttpd`.
  - `cgi-bin/hyperg`: identical in content to LuCI's `htdocs/cgi-bin/luci` at the pinned LuCI commit. The dispatcher derives URLs from `SCRIPT_NAME`, so only the file name changes.
  - `index.html`: a meta refresh to `cgi-bin/hyperg/`.
  - `/etc/config/hyperg`, `99-hyperg-base` and `init.d/hyperg-www`.
  - Add `+hyperg-base` to `hyperg-full`.

- [ ] **Step 6: Fast loop against the Task 3 image in QEMU**

Run:
1. `tests/smoke/boot-x86_64.sh out/0.1.0/x86_64/*combined*.img.gz --keep-running`. Task 5 provides this script; until then, boot by hand with the QEMU settings listed in Task 5.
2. `tests/dev-push.sh 12222`
3. `tests/smoke/check-router.sh 127.0.0.1 18080 12222 18081`

Expected: all pass except `dist id`, which needs a rebuild.

- [ ] **Step 7: Rebuild x86_64 and run the full check**

Run: `scripts/hyperg-build.sh x86_64 -j$(nproc)` then `tests/smoke/boot-x86_64.sh out/0.1.0/x86_64/*combined*.img.gz`
Expected: `check-router.sh` all passed.

- [ ] **Step 8: Commit**

```bash
git add feed/hyperg-base feed/hyperg-full/Makefile tests/
git commit -m "feat(feed): hyperg-base with /cgi-bin/hyperg web root, defaults and hyperg config"
```

---

### Task 5: QEMU smoke-test runner

**Files:**
- Create: `tests/smoke/boot-x86_64.sh`

**Interfaces:**
- Consumes: `tests/smoke/check-router.sh` (Task 4).
- Produces: `tests/smoke/boot-x86_64.sh <image.img.gz> [--keep-running]`. It:
  - decompresses the image to a temp qcow2 overlay, so the image itself is never modified;
  - boots with 2 NICs:
    - LAN: `e1000`, user-net `net=192.168.100.0/24`, hostfwd `127.0.0.1:18080→192.168.100.1:80` and `127.0.0.1:12222→192.168.100.1:22`;
    - WAN: `e1000`, user-net, hostfwd `127.0.0.1:18081→:80`;
  - uses `-accel kvm` if `/dev/kvm` is usable and `HYPERG_NO_KVM` is unset, otherwise `-accel tcg`;
  - waits for HTTP 200 on `:18080/cgi-bin/hyperg/`, with a timeout of 180 s under KVM and 900 s under TCG;
  - runs `check-router.sh 127.0.0.1 18080 12222 18081`;
  - kills QEMU unless `--keep-running` is given.

  It exits with the check's exit code, or 3 with `boot timeout` if HTTP never answers.

- [ ] **Step 1: Run it against a missing file to see it fail cleanly**

Run: `tests/smoke/boot-x86_64.sh /nonexistent.img.gz; echo $?`
Expected: `image not found: /nonexistent.img.gz`, `2`.

- [ ] **Step 2: Implement it; run against the Task 4 image**

Run: `tests/smoke/boot-x86_64.sh out/0.1.0/x86_64/*combined*.img.gz`
Expected: check output ends `N passed, 0 failed`; exit 0.

- [ ] **Step 3: Software-emulation fallback**

Run: `HYPERG_NO_KVM=1 tests/smoke/boot-x86_64.sh out/0.1.0/x86_64/*combined*.img.gz`
Expected: log shows `accel: tcg`; same pass result (slower).

- [ ] **Step 4: Commit**

```bash
git add tests/smoke/boot-x86_64.sh
git commit -m "test: QEMU boot smoke test for x86_64 images"
```

---

### Task 6: CI workflow with secret scan

**Files:**
- Create: `.github/workflows/build.yml`, `.gitleaks.toml`

**Interfaces:**
- Consumes: `scripts/hyperg-build.sh`, `tests/*.sh`, `tests/smoke/boot-x86_64.sh`.
- Produces: workflow `build`.
  - Triggers: push to `hyperg`, and `workflow_dispatch`.
  - One job: `runs-on: [self-hosted, hyperg-build]`, `timeout-minutes: 720`, `concurrency: hyperg-build` (one build at a time).
  - Steps, in order:
    1. Checkout with `clean: false`, which keeps the warm `x86_64/`, `rpi5/` and `feeds/` caches (all git-ignored).
    2. `gitleaks detect --source . --no-banner --redact`; any finding fails the job.
    3. `sh tests/test-hyperg-build-env.sh`
    4. `sh tests/test-sync-www.sh`
    5. Build `x86_64`.
    6. Smoke test.
    7. Build `rpi5`.
    8. Upload `out/<VERSION>/x86_64/*combined*.img.gz` and `out/<VERSION>/rpi5/*.img.gz` as artifacts with `retention-days: 3`. Artifact storage for a private repo on GitHub Free is 500 MB, so all images also stay in the build VM under `out/`.

- [ ] **Step 1: Prove the secret scan bites** — on a scratch branch commit a file containing a fake key in the gitleaks `generic-api-key` shape, push, run the workflow.
Expected: job fails at the gitleaks step. Delete the scratch branch.

- [ ] **Step 2: Write `build.yml` and `.gitleaks.toml`** — use the default rules. Allowlist only upstream-owned paths that contain encrypted blobs (e.g. `deploy_rsa.enc`), and only if gitleaks flags them, each with a comment saying why.

- [ ] **Step 3: Push to `hyperg`**

Expected: workflow green; two artifacts listed on the run.

- [ ] **Step 4: Second run on warm cache (Review Focus 4)**

Run: *Actions → build → Run workflow* on `hyperg`.
Expected: green; build log shows the OMR feed checked out at `v0.65` (`git -C feeds/openmptcprouter describe --tags` → `v0.65`, printed by the wrapper before building).

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/build.yml .gitleaks.toml
git commit -m "ci: self-hosted build of x86_64 and rpi5 with secret scan and smoke test"
```

---

### Task 7: Pi 5 first boot and test VPS

**Files:**
- Create: `docs/hyperg/pi5-first-boot.md`, `docs/hyperg/test-vps.md`

**Interfaces:**
- Consumes: rpi5 image (Task 6 artifact), `tests/smoke/check-router.sh`.

- [ ] **Step 1: Write `docs/hyperg/pi5-first-boot.md`**, covering in order:
  1. Write the image to a microSD card (Raspberry Pi Imager → "Use custom").
  2. Connect the Pi's Ethernet, and a laptop, to untagged ports on the switch.
  3. Power on; the laptop gets an address from 192.168.100.0/24 by DHCP.
  4. Open `http://192.168.100.1/`; it should land on `/cgi-bin/hyperg/`.
  5. Set the root password in the interface.

- [ ] **Step 2: Owner boots the Pi 5; run the checks from a laptop on the same LAN, before setting a password**

Run: `tests/smoke/check-router.sh 192.168.100.1 80 22`
Expected: all passed.

- [ ] **Step 3: Write `docs/hyperg/test-vps.md`**, covering:
  - The owner provisions a small Debian VPS.
  - Install the OMR 0.65 server with the install command from the official OMR documentation for 0.65. Copy the exact command from openmptcprouter.com at the time; do not use the old Brussels/Amsterdam scripts.
  - Record the VPS IP and key **only** in the router's WAN-Bonding/OMR settings, never in the repo.
  - Leave the Germany VPS (live ship) untouched.

- [ ] **Step 4: Owner sets up the test VPS and connects the x86_64 VM or Pi 5 to it using stock OMR settings**

Expected: OMR status shows the VPS connected and the aggregate tunnel up.

- [ ] **Step 5: Commit**

```bash
git add docs/hyperg/
git commit -m "docs: Pi 5 first boot and test VPS setup"
```

---

## Done when

- A push to `hyperg` produces green CI with x86_64 and rpi5 images.
- The x86_64 image passes `check-router.sh` in QEMU; the Pi 5 passes it on the bench.
- The web interface answers only at `/cgi-bin/hyperg/`; SNMP and ModemManager are present; settings the operator changed survive re-running the defaults.
- A test VPS on OMR 0.65 is reachable from a HyperG router.
