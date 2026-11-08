# HyperG firmware restart — design

Date: 2026-11-07 (updated 2026-11-08 with owner answers)
Status: for owner approval

## 1. Intent

HyperG is a multi-WAN bonding router for ships, built on OpenMPTCProuter (OMR). Several cellular
links (and now Starlink) are aggregated with Multipath TCP through a VPS, so the vessel gets one
fast, resilient connection.

In 2022–2023 the stock OMR web interface (LuCI) was redesigned into the "Hyper-G" interface. The
operator configures the routers **remotely**; the crew rarely touches them. The redesign made
configuration faster and is far better looking than stock OMR — it still is. But it was built by
overwriting LuCI's and OMR's own core files on an installed router, so it could not survive an
OMR upgrade. A 2024 attempt to port it to OMR 0.61 (and to do it "as a theme") stalled: stock
pages are badly structured (inconsistent, deeply nested markup), so CSS alone cannot produce the
layout — each page had to be reprogrammed.

This project restarts that work on the **current** OMR release, and turns HyperG into **our own
firmware build** so that, once the basics are in place, the router can keep being improved for its
specific purpose without re-porting by hand every upstream release.

**The design is the asset, not the old code.** The old code is reference material; the new code
is written cleanly against today's LuCI and OMR.

## 2. Current state (reference material)

All under `D:\SATMARIN\TECH DOCS\Hexoflux\`.

| What | Where | Notes |
|---|---|---|
| Visual reference of the finished v2 design | `HyperG-restart\reference-v2-screenshots\` (51 PNGs + `index.txt`) | Captured 2026-11-07 from a VM running the Pearl copy. **Contains real secrets — confidential.** |
| v2 interface as deployed (Apr 2023) | `openWRTDEV-pearl\` (`openWRTDEV\www`, `usr\...`) | Base: hyperg 1.1.alpha.12 = OMR ~0.59, OpenWrt/LuCI 21.02 |
| v2 sources / dev overlay | `openwrtDEV\usr`, `openwrtDEV\www`, `openwrtDEV\luci-theme-hyper`, `openwrtDEV\luci-app-hud`, `openwrtDEV\hyperg v3 interface files from Ambiorix` | rpcd backend `usr/libexec/rpcd/hyperg` (`hud_status`, `setMultipath`) |
| 2024 port attempt to OMR 0.61 | `openwrtDEV\v3.1 WIP`, stock baseline `openwrtDEV\ORIGINALS0.61` | Light restyle on Argon; menu moved to Network → Bonding |
| v3 configs (USB modems, Telenor) | `openwrtDEV\V3 config files` | ModemManager modems, openvpn, shadowsocks-rust |
| Gateway monitor (MikroTik era) | `gateway\` | Node.js app; out of scope (see §4) |
| Old fork of OMR build scripts | GitHub `SatExo/hg` (local clone `openwrtDEV\hg`) | We control this repo |
| Reference VM | QEMU, `http://127.0.0.1:18080/cgi-bin/hyperg/` | Copy of the alpha.12 image + Pearl UI files; software emulation (slow) |

Key facts about v2 that shape the rebuild:

- The look comes from three things: the `hyper` theme (black sidebar, orange header bar, "atom"
  spinner, dark cards), **modified core LuCI JS** (`form.js`, `ui.js`, `cbi.js`, `luci.js`,
  `network.js`) that turns checkboxes into LED-style toggle buttons and lays forms out as cards,
  and **reprogrammed pages** (WAN-Bonding wizard and others) built from card blocks.
- Custom pages: **WAN-Bonding** (tabs WAN-Bonding / Status / Advanced; gateway-server cards with
  Master/Disable LED toggles; Advanced Settings cards: IPv6, Proxy, VPN, Server, MPTCP over VPN,
  Country; LAN and WAN interface cards with LED toggles; add server / add interface), **HUD**
  and a custom **Dashboard**.
- Old code contains hard-coded credentials (MikroTik admin, Google Maps API key, VPS tokens, VPN
  keys, MSSQL login). None of it may be carried over.

## 3. Hardware and deployment

- **Primary: Raspberry Pi 5** (OMR target `rpi5`, platform `bcm27xx/bcm2712`).
  - Built-in Ethernet → small managed **2.5 Gbps switch**; LAN and Starlink separated by **VLANs**
    on that port.
  - **3 × 5G USB modems** (3–6 in future units), Quectel RM500-series, managed by
    **ModemManager**, each with its own power supply.
  - **Starlink** as an Ethernet WAN (via the switch/VLAN).
- **Secondary: x86-64** (OMR target `x86_64`), built from the same packages. *My call:* used for
  testing in a VM here; costs little extra.
- **New units only.** Routers already in service are **not** reflashed; legacy systems stay on
  plain OMR. No config migration from v2 is needed.
- 4G MikroTik-based units (RBM33G + Quectel modems): **out of scope**.
- **VPS:** a new **test VPS on OMR 0.65** is set up for this project. The one live ship uses the
  Germany VPS, which is not touched. Brussels/Amsterdam are not used.

## 4. Goals, non-goals, anti-goals

### Goals (phase 1 — "the basics are done")

1. **Own firmware image** for Raspberry Pi 5 (and x86-64) built from current OMR (**v0.65**, the
   latest stable tag at time of writing), built on our own Linux build machine, downloadable.
2. **Every page of the interface in the Hyper-G design — layout included, not just colours.**
   Every page OMR 0.65 ships in its menu gets the v2 treatment: sidebar, header bar, spinner, dark
   cards, LED-style toggles, and the card-based page layout seen in the screenshots. This means
   **a HyperG-built view for every page** (see §5, "Pages"), because stock page markup cannot be
   styled into that layout.
3. **WAN-Bonding page** rebuilt as in v2 (card layout, LED toggles, tabs), working against OMR
   0.65's configuration, so a router can be configured remotely with it end-to-end: gateway
   server(s), VPN/proxy choice, LAN, WANs including ModemManager 5G modems and an Ethernet/VLAN
   WAN for Starlink.
4. **HUD page** rebuilt. Owner gave free hand on content; the clock is optional. *My call* for
   the starting point (shown as a mockup for approval before building): one tile per WAN
   (modems + Starlink) with LED state (master/on/backup/off) and multipath toggle; modem tiles show
   operator, technology (5G SA/NSA/LTE), signal (RSRP/RSRQ/SINR) and band from ModemManager; per-WAN
   live throughput and latency to the VPS; bonded total throughput; VPS/tunnel status; hourly
   history from vnstat.
5. **Safe remote operation** (see §5, "Remote access").
6. Upgrading to a newer OMR release = change the pinned version, rebuild, re-check the pages that
   upstream changed — no copying files over an installed router.

### Non-goals (phase 1)

- MikroTik/4G support, the Node.js gateway app, MSSQL cell-tower lookup.
- Reflashing or migrating units already in service.
- HUD **map** (position + serving cells). *My call:* phase 2. Natural source is the RM500 modems'
  own GNSS; needs a map tile/API choice and a key stored in router config.
- Starlink dish telemetry (obstruction, outages via the dish's local API). *My call:* phase 2;
  phase 1 treats Starlink as a plain WAN.
- Recreating pages that existed in v2 but no longer exist in OMR 0.65.
- Public release / customer source distribution (GPL obligations to be handled when units ship).

### Next phase: maritime link management (owner direction, not built in phase 1)

Once the interface is done, work moves to link management for the maritime environment,
including but not limited to: **live link quality assessment and mitigation**, **easy local VLAN
assignment**, and **port/location-specific settings**. Phase 1 must not block this. *My calls* on
what that means for phase 1:

- The backend has **one link-metrics collector** (per WAN: latency, loss and jitter to the VPS,
  throughput, and modem signal/band/technology), sampling on a fixed interval and keeping a short
  rolling history on the router. The HUD reads from it, and later quality assessment and automatic
  mitigation build on the same data instead of a second mechanism.
- HyperG's own settings live in **our own UCI config** (`hyperg`), structured so named **profiles**
  (e.g. per port or region: preferred links, bands, master link, thresholds) can be added later
  without reworking what exists.
- The network and WAN-Bonding pages are built so that **assigning a local port/VLAN** to a role
  (LAN, Starlink, guest, crew…) is one card with a few fields, not several stock pages.
- Mitigation in later phases acts through OMR's own controls (multipath state, master link,
  tracker), so it stays compatible with stock OMR behaviour.

### Anti-goals (failure even if it "works")

- **Overwriting LuCI or OMR core files** (`form.js`, `ui.js`, upstream controllers/views) in the
  image. That is what made v2 un-upgradeable. Every reprogrammed page is **our own view** in our
  own package, with our own menu entry; the upstream menu entry is hidden. Upstream files are
  never patched in place.
- **Any secret in the repositories** (keys, passwords, tokens, API keys). Secrets live in router
  config (UCI) and are entered on the device.
- Losing the aesthetic: a stock-looking OMR with an orange accent is not the target. The
  screenshots are the bar.
- Breaking OMR functionality in the name of looks (bonding, failover, VPS management must keep
  working exactly as stock). Our views read and write the **same UCI options** upstream's pages
  do.
- A configuration change that locks the operator out of a ship with no automatic recovery.

## 5. How it gets made

### Repositories (GitHub, account `SatExo`, both private)

- **`SatExo/hg`** — the image builder. Brought up to date with `Ysurac/openmptcprouter` `develop`
  history, pinned to the **v0.65** tag. Builds with upstream's `build.sh`, pulling our feed via
  `CUSTOM_FEED_URL` / `CUSTOM_FEED_URL_BRANCH`, with `OMR_DIST` set for HyperG branding.
  Targets: `rpi5`, `x86_64`.
- **Our OpenWrt package feed**, kept in `SatExo/hg` under `feed/` (*my call, changed during
  planning:* upstream `build.sh` accepts a local feed folder via `CUSTOM_FEED`, so one private
  repo, one commit = one consistent image, and the build machine needs no second credential):
  - `luci-theme-hyper` — page frame (sidebar, header, spinner, branding), CSS, and the shared
    HyperG widget set (cards, LED toggles, tab bars) used by all our views. Default theme.
  - `luci-app-hyperg` — all HyperG views: WAN-Bonding, HUD, Dashboard, and the reprogrammed
    versions of every other page; menu.d entries; rpcd ACLs.
  - `hyperg-backend` (name is the builder's choice) — rpcd/ucode backend for HUD status, modem
    info (ModemManager), multipath toggling; uci-defaults for HyperG defaults.
  - Optional `source/<target>/<kernel>/` overrides, as `build.sh` supports, only if really needed.

### Pages

- First task of the page work: an **inventory** of every menu page in OMR 0.65 (with the packages
  we ship), mapped to its v2 screenshot where one exists. Pages with no v2 equivalent get the same
  card style, designed by the builder in the v2 spirit.
- Each page becomes a HyperG view built from the shared widget set, saving to the same UCI config
  as the upstream page it replaces.
- A **page register** in the feed records, for each HyperG view, which upstream view it replaces
  and the upstream version it was checked against. On an OMR upgrade, the build lists upstream
  views that changed since, so only those pages are re-checked.
- *My call:* order of the page work — WAN-Bonding, HUD and Dashboard first, then the pages the
  operator uses for remote configuration (Network, MPTCP, VPN, Status), then the rest (System,
  Services).

### Remote access

- Owner's answer: routers are reached **through the VPS tunnel** and, independently, through
  **per-link WireGuard VPNs** (on the 4G units each modem board had its own).
- *My call* for 5G USB modems (which cannot host a VPN themselves): the router keeps a separate
  **WireGuard management tunnel** that can run over any single WAN, independent of the bonding,
  so the operator can still get in if the bonded tunnel or VPS is down. Peer address and keys are
  entered on the device; none are in the repos.
- The web interface is served only at **`/cgi-bin/hyperg/`** (owner's choice, to limit visible
  OpenWrt exposure); `/cgi-bin/luci/` is disabled. Web access only from LAN and the management
  tunnel(s), not from WANs. *My call.*
- Every change that can cut connectivity (WAN toggles, multipath, network, firewall, VPN) uses
  LuCI's **apply with automatic rollback**: if the browser cannot confirm within the timeout,
  the router reverts. *My call.*

### Image contents

- Stock OMR 0.65 package set, plus ModemManager and the RM500 USB/QMI/MBIM drivers, plus
  **SNMP (snmpd) always included** (owner's choice).
- Other v2 extras (Mosquitto, quota, iperf, mail, ttyd, WoL, packet capture, unbound,
  https-dns-proxy, UPnP) only on request. *My call.*
- Starting network config (uci-defaults): LAN untagged on the built-in port, Starlink on a tagged
  VLAN (ID configurable), modems as WANs by ModemManager. The managed switch is configured by
  hand. *My call.*

### Build

- **Own Linux build machine** (owner's choice: a spare office PC — modest but free). *My call:*
  register it as a **GitHub Actions self-hosted runner** for `SatExo/hg`, so a push or a manual
  trigger builds both targets and the images are downloadable from the run, at no cost. First
  build will take hours on that hardware; later builds reuse the cache.
- The PC is the spare Windows 11 PC (Core i7, 16 GB), which must stay a Windows PC: builds run in
  a Linux VM on it (Hyper-V on Pro, WSL2 on Home), 6 vCPU, 10 GB RAM, 200 GB disk, starting
  automatically with Windows. Owner's choice; VM sizing is my call.
- Version string identifies HyperG version + OMR base version.

### Technology

- Current LuCI conventions: client-side JS views (`luci-static/resources/view/...`), `menu.d`
  JSON, `acl.d` JSON, rpcd/ucode backends. Lua only where OMR itself still requires it.
- Data sources: `uci`, `ubus` (network, ModemManager via `mmcli`/ubus), OMR's existing rpcd
  calls, vnstat for history.

## 6. Delivery order

1. Build machine + repos + CI producing a **stock OMR 0.65 image** for `rpi5` and `x86_64` with
   our (empty) feed wired in. Boot it in the VM and on the Pi 5. Test VPS on 0.65 set up.
2. **`luci-theme-hyper`** frame and shared widget set; page inventory and register.
3. **WAN-Bonding** page.
4. **HUD** (mockup approved first) and **Dashboard**.
5. Remaining pages in the order in §5 "Pages".
6. Bench test on the Pi 5: 3 × RM500 + Starlink against the test VPS, remote configuration
   end-to-end, including the management tunnel and rollback.

## 7. Verification

- Each build: image boots (x86-64 in QEMU here; Pi 5 on the bench), interface reachable at
  `/cgi-bin/hyperg/`, theme active, `/cgi-bin/luci/` not reachable.
- Visual: every page in the menu captured with the same screenshot script used for v2, side by
  side with `reference-v2-screenshots`, for owner review per page.
- Functional: each HyperG page, saved with no changes, leaves UCI identical; a change on our page
  produces the same UCI as the same change on the upstream page.
- Bench (Pi 5): 3 modems + Starlink come up as WANs, bonding to the test VPS works, toggles on
  WAN-Bonding/HUD change multipath state, a deliberately bad change rolls back, the management
  tunnel works with the VPS down, settings survive reboot and a sysupgrade to a newer HyperG build.
- Repo scan for secrets before every push.

## 8. Left to the builder

- Package names beyond the theme; internal file layout of the feed.
- How the shared widget set is built (within the anti-goal).
- Design of pages with no v2 screenshot, in the v2 style.
- CI details (caching, retention), versioning scheme.
- How much of the old `hyperg` rpcd logic is reused vs. rewritten.

## 9. Calls made by Claude (to be checked)

- x86-64 built alongside Pi 5, mainly for VM testing.
- HUD map and Starlink telemetry deferred to phase 2.
- HUD starting content (§4 goal 4), shown as a mockup before building.
- Page work order: WAN-Bonding, HUD, Dashboard → remote-config pages → the rest.
- Page register to make OMR upgrades manageable.
- WireGuard management tunnel over a single WAN for 5G units.
- Web interface reachable only from LAN and management tunnels; apply-with-rollback on risky
  changes.
- Extras beyond stock + ModemManager + SNMP only on request.
- Starting network: LAN untagged, Starlink tagged VLAN; switch configured by hand.
- Build PC used as a GitHub Actions self-hosted runner.
- One private repo `SatExo/hg` holding both the builder and our feed (`feed/`).
- `/cgi-bin/hyperg/` is achieved by giving uhttpd its own web root (`/www-hyperg`) that mirrors
  `/www` except LuCI's `/cgi-bin/luci` and `index.html`; no upstream file is deleted or edited.
- Base pinned to OMR v0.65 (latest stable), not the moving `develop` branch.
