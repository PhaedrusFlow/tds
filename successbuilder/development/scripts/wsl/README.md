# Arch Linux on WSL2 Setup Guide

This guide explains how to run the Windows script that installs Arch Linux in WSL2 on Windows 11 and adds internet speed test tools such as `iperf3` and `speedtest-cli`.

## What this does

The script turns on Windows Subsystem for Linux (WSL), a way to run Linux on Windows. It sets WSL2 as the default version, downloads the Arch Linux WSL image, imports it as a WSL distribution, and installs the speed test tools inside Arch Linux.

<details>
<summary>▼ Before you start</summary>

- Use a Windows 11 computer with administrator access.[web:3]
- Make sure virtualization is enabled in the computer BIOS or UEFI if WSL installation fails.
- Save the script as a file ending in `.cmd`, such as `install-arch-wsl-speedtest.cmd`.
- Keep the computer connected to the internet during setup.

</details>

<details>
<summary>▼ Step 1: Save the script (Unnecessary if you use the wsl.cmd file in this folder)</summary>

1. Open **Notepad**.
2. Paste the script into the blank file.
3. Select **File** and then **Save As**.
4. In **File name**, enter `awsl.cmd`.
5. In **Save as type**, choose **All Files**.
6. Save it somewhere easy to find, such as the **Desktop**.

</details>

<details>
<summary>▼ Step 2: Run the script</summary>

1. Find the `.cmd` file you saved.
2. Right-click it.
3. Select **Run as administrator**.
4. Wait while Windows installs WSL, configures WSL2, downloads Arch Linux, and installs packages.
5. If Windows asks to restart, restart the computer and run the script again.

</details>

<details>
<summary>▼ Step 3: Open Arch Linux</summary>

After the script finishes, open **Command Prompt**, **PowerShell**, or **Windows Terminal** and enter:

```cmd
wsl -d archlinux
```

This starts the Arch Linux environment that was imported by the script.

</details>

<details>
<summary>▼ Step 4: Sign in</summary>

The script creates this user account unless it already exists:

- Username: `fieldtech`
- Password: `fieldtech`

After signing in, it is a good idea to change the password.

To change the password, enter:

```bash
passwd
```

</details>

<details>
<summary>▼ Step 5: Run a speed test</summary>

To run the installed speed test tools, use these commands inside Arch Linux:

```bash
speedtest-cli
```

```bash
iperf3 -c <server> -t 30 -P 4
```

`speedtest-cli` checks internet speed using a command line speed test tool, and `iperf3` tests throughput against an iperf server.

Example:

```bash
iperf3 -c 192.168.1.10 -t 30 -P 4
```

</details>

<details>
<summary>▼ What to expect</summary>

- The first run can take several minutes.
- WSL may need a restart before settings fully apply.[web:3]
- Arch Linux will open in a terminal window, not a desktop environment.[web:5]
- The script writes a `.wslconfig` file in the Windows user profile to tune WSL2 resource settings.[web:3]

</details>

<details>
<summary>▼ If something goes wrong</summary>

Try these steps:

1. Restart the computer.
2. Run the script again as administrator.
3. Open Command Prompt as administrator and run:

```cmd
wsl --status
```

4. If WSL is missing or broken, run:

```cmd
wsl --update
```

5. If installation still fails, check that virtualization is enabled in BIOS or UEFI and that Windows features for WSL and Virtual Machine Platform are available.

</details>

<details>
<summary>▼ Useful commands</summary>

Open Arch Linux:

```cmd
wsl -d archlinux
```

See installed WSL distributions:

```cmd
wsl -l -v
```

Shut down WSL:

```cmd
wsl --shutdown
```

Run a speed test:

```bash
speedtest-cli
```

Run an iperf test:

```bash
iperf3 -c <server> -t 30 -P 4
```

</details>
