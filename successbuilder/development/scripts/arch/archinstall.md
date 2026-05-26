# Archinstall Networking Guide

This guide walks a beginner through getting online in the Arch Linux live environment and then launching `archinstall`, with separate paths for Wi-Fi and Ethernet users.

## Before starting

1. Boot the Arch Linux installer USB and wait until the shell prompt appears.[cite:137]
2. Make sure the keyboard works and read the prompt carefully; most commands below are typed exactly as shown.[cite:137]
3. If you are using a wired Ethernet cable, you can usually skip `iwctl` entirely because wired networking is normally detected automatically in the live environment.

## Check whether internet already works

Run:

```bash
ping -c 3 archlinux.org
```

- If you get replies, your network is already working and you can move straight to
  `archinstall`.
- If it fails and you are on Ethernet, check that the cable is plugged in at both ends and then try the ping again.
- If it fails and you are on Wi-Fi, follow the `iwctl` steps below.

## Wi-Fi with iwctl

### Start iwctl

Type:

```bash
iwctl
```

You should now see a prompt that looks like this:

```text
[iwd]#
```

That means you are inside the Wi-Fi tool provided by `iwd`.

### Find the Wi-Fi device name

Type:

```bash
device list
```

Look for a device name such as `wlan0` or `wlp2s0`; that is the wireless device you will use in the next commands.

### Turn Wi-Fi on if needed

If the device shows as off or unpowered, turn it on with:

```bash
device YOUR_DEVICE set-property Powered on
```

Example:

```bash
device wlan0 set-property Powered on
```

This is only needed if the adapter is not already powered on.

### Scan for nearby networks

Type:

```bash
station YOUR_DEVICE scan
```

Example:

```bash
station wlan0 scan
```

This command may not print anything, which is normal.

### Show available network names

Type:

```bash
station YOUR_DEVICE get-networks
```

Example:

```bash
station wlan0 get-networks
```

This will list nearby Wi-Fi networks so you can identify your SSID, which is simply your Wi-Fi network name.

### Connect to your Wi-Fi

Type:

```bash
station YOUR_DEVICE connect "YOUR_WIFI_NAME"
```

Example:

```bash
station wlan0 connect "MyHomeWiFi"
```

- If the network uses a password, `iwctl` will prompt for it.
- If your Wi-Fi name contains spaces, keep the quotes around it.[cite:145]

### Confirm that you connected

Type:

```bash
station YOUR_DEVICE show
```

Then exit `iwctl`:

```bash
exit
```

Back at the main shell, test the connection:

```bash
ping -c 3 archlinux.org
```

If the ping replies, you are online and ready to run `archinstall`.

## Ethernet users

If you are using a wired connection:

1. Plug the Ethernet cable into the computer before or during boot.
2. Do **not** open `iwctl` unless you are troubleshooting Wi-Fi.
3. Test the connection with:

```bash
ping -c 3 archlinux.org
```

If you get replies, Ethernet is working and you can continue.

If you do not get replies:

- Reseat the cable on both ends.[cite:140]
- Try a different Ethernet port or cable if possible.[cite:140]
- Run `ip a` and look for a wired interface such as `enp...`; if it exists but has no address, the problem may be hardware, VM settings, or upstream network access rather than `archinstall` itself.

## Run archinstall

Once internet works, start the guided installer with:

```bash
archinstall
```

The installer will open its guided interface so you can choose language, disks, filesystem, bootloader, desktop profile if desired, users, and networking preferences for the installed system.[cite:141]

## Beginner checklist inside archinstall

Use this simple order:

1. Select your language and keyboard layout.
2. Choose the disks you want to install to.
3. Pick your filesystem and bootloader.
4. Set hostname, root password, and your normal user account.
5. Choose any profile or desktop environment you want.
6. Review the summary before confirming.
7. Start installation and wait for completion.[cite:141]

## After installation

When `archinstall` finishes:

1. Read any final messages on screen.[cite:141]
2. Reboot when prompted or type `reboot` after exiting.
3. Remove the USB installer when the system starts to reboot so it boots into the newly installed system.[cite:137]

## Common mistakes

- Typing `iwctl` commands with the wrong device name; always check `device list` first.
- Forgetting quotes around Wi-Fi names that contain spaces.[cite:145]
- Using `iwctl` for Ethernet; wired users usually just need to plug in the cable and test with `ping`.
- Proceeding to `archinstall` before verifying connectivity with `ping -c 3 archlinux.org`.
