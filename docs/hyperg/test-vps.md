# Test VPS on OpenMPTCProuter 0.65

The router and its VPS must run the **same OMR version**. HyperG 0.1.x is based on OMR 0.65,
so it needs a VPS with the OMR 0.65 server.

- The **Germany VPS** serves the one live ship: **do not touch it**.
- The old Brussels and Amsterdam VPSs and their install scripts are not used.

## Steps (owner)

1. Rent a small VPS: Debian 12 (or the version the OMR 0.65 server documentation lists),
   1 vCPU / 1 GB RAM is enough for testing, a public IPv4 address.
2. Install the OMR server with the install command given in the **official OpenMPTCProuter
   documentation for 0.65** (openmptcprouter.com → Install → VPS). Copy the command from the site
   at the time; do not reuse old scripts.
3. At the end the installer prints the server key and the ports. Keep them in your password
   manager.
4. Enter the VPS address and key **only** in the router: stock OMR wizard for now
   (HyperG's WAN-Bonding page from plan 3 on). They are never written in this repository or in
   any issue or commit message.

## Check

On the router (x86_64 VM or Pi 5): *Status → OpenMPTCProuter* shows the server connected and
the aggregated tunnel up.
