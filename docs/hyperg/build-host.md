# HyperG build host

HyperG images are built on the spare **Windows 11 Pro** PC (Core i7, 16 GB). The PC stays a
Windows PC; the build runs in a Linux virtual machine on it that starts by itself with Windows,
so nobody has to be logged in. Remote access over RDP is enough for every step below.

## 1. Check the PC (once)

1. Open Task Manager → Performance → CPU: **Virtualization: Enabled**. If it says Disabled,
   enable Intel VT-x in the BIOS/UEFI setup.
2. Free disk space on the drive that will hold the VM: at least **220 GB**.

## 2. Create the virtual machine (once)

1. *Turn Windows features on or off* → tick **Hyper-V** → reboot.
2. Download the Ubuntu 24.04 LTS **Server** ISO from ubuntu.com.
3. In an elevated PowerShell, from this repository's `scripts\windows` folder:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\new-build-vm.ps1 -IsoPath C:\path\to\ubuntu-24.04-live-server-amd64.iso
   ```

   Use `-VhdDir D:\HyperG\vm` to put the disk on another drive.
4. Start the VM in Hyper-V Manager, connect, install Ubuntu Server:
   - user name `hgbuild`, tick **Install OpenSSH server**;
   - storage: *Use an entire disk*, and **untick "Set up this disk as an LVM group"** (the LVM
     default gives Ubuntu only about half the disk, and the build needs 150 GB free). If it was
     left ticked, fix it after install with
     `sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv`;
   - after install, remove the ISO:
     `Get-VMDvdDrive -VMName hyperg-build | Set-VMDvdDrive -Path $null`.
5. Find the VM's address (`ip -4 addr` in the VM console) and from now on use
   `ssh hgbuild@<address>` from the Windows PC.

## 3. Prepare Linux (once)

Inside the VM, on its own disk (never under `/mnt`):

```bash
git clone https://github.com/SatExo/hg.git ~/hg
cd ~/hg && git checkout hyperg
sudo scripts/setup-build-host.sh
scripts/check-build-host.sh
```

`check-build-host.sh` must print `build host OK`. `INFO: kvm yes` means boot tests run at full
speed; `kvm no` still works, only slower.

## 4. Register the GitHub runner (once — owner)

The registration token is the owner's to enter; it is never stored in this repository.

1. GitHub → `SatExo/hg` → Settings → Actions → Runners → **New self-hosted runner** → Linux x64.
2. Run the commands GitHub shows, inside the VM, as `hgbuild`, in `~/actions-runner`.
   When asked for labels, add **`hyperg-build`**.
3. Install it as a service so it runs without a login:

   ```bash
   cd ~/actions-runner && sudo ./svc.sh install hgbuild && sudo ./svc.sh start
   ```

4. The runner shows **Idle** on the Runners page. Reboot Windows without logging in: it
   should be Idle again within 5 minutes.

## Returning the PC to spare duty

- Shut down the VM in Hyper-V Manager, then
  `Set-VM -Name hyperg-build -AutomaticStartAction Nothing`.
- The build cache stays inside the VM disk for next time. To use the PC for builds again,
  set `-AutomaticStartAction Start` and start the VM.

## Windows 11 Home (no Hyper-V)

Use WSL2 instead of steps 2–3's VM, with the same sizes:

1. `wsl --install -d Ubuntu-24.04`
2. `%UserProfile%\.wslconfig`:

   ```ini
   [wsl2]
   memory=10GB
   processors=6
   nestedVirtualization=true
   vmIdleTimeout=-1
   ```

3. In the distro, `/etc/wsl.conf`: `[boot]` `systemd=true`; then `wsl --shutdown`.
4. Task Scheduler → task "At startup", run whether user is logged on or not:
   `wsl.exe -d Ubuntu-24.04 --exec sleep infinity`.
5. Continue with step 3 above (clone into `~/hg`, not `/mnt/c`).
