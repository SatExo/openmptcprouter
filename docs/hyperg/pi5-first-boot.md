# HyperG on the Raspberry Pi 5 — first boot

## You need

- Raspberry Pi 5 with its official power supply, a microSD card (16 GB or more).
- The rpi5 image from the CI run (artifact `hyperg-<version>-rpi5`) or from the build VM
  (`~/hg/out/<version>/rpi5/`). Use the `*-squashfs-factory.img.gz` file.
- The managed switch, and a laptop.

## Steps

1. Write the image to the microSD card with Raspberry Pi Imager → *Choose OS* → **Use custom**
   (the `.img.gz` can be used as is). Do not let Imager apply its own OS customisation.
2. Connect the Pi's Ethernet port to an **untagged (LAN) port** of the switch, and the laptop to
   another untagged port. VLANs (Starlink) come later; for first boot no VLAN is needed.
3. Insert the card and power the Pi on. First boot takes 1–2 minutes.
4. The laptop gets an address in 192.168.100.0/24 by DHCP.
5. Open `http://192.168.100.1/` — it must land on `http://192.168.100.1/cgi-bin/hyperg/`.

## Check it (before setting a password)

From the laptop or the build VM on the same LAN, in the repository:

```bash
tests/smoke/check-router.sh 192.168.100.1 80 22
```

All lines must be `ok`. (The WAN test is skipped on the Pi; run it later from the WAN side.)

## Then

Set the root password in the web interface straight away. Never write it in this repository.
