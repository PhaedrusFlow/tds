@echo off
setlocal EnableDelayedExpansion

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >nul 2>&1
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >nul 2>&1

wsl --install --no-distribution 2>nul
wsl --update 2>nul
wsl --set-default-version 2

set ARCH_TMP_DIR=%USERPROFILE%DownloadsArchWSL
set ARCH_WSL_FILE=archlinux-latest.wsl
set ARCH_DISTRO_NAME=archlinux
set ARCH_INSTALL_DIR=%USERPROFILE%WSLArchLinux
set ARCH_USER=fieldtech

if not exist "%ARCH_TMP_DIR%" mkdir "%ARCH_TMP_DIR%"
if not exist "%ARCH_INSTALL_DIR%" mkdir "%ARCH_INSTALL_DIR%"

powershell -NoLogo -NoProfile -Command "Invoke-WebRequest -Uri 'https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.wsl' -OutFile '%ARCH_TMP_DIR%%ARCH_WSL_FILE%' -UseBasicParsing"
if errorlevel 1 goto :eof

wsl --import %ARCH_DISTRO_NAME% "%ARCH_INSTALL_DIR%" "%ARCH_TMP_DIR%%ARCH_WSL_FILE%" --version 2
if errorlevel 1 goto :eof

> "%USERPROFILE%.wslconfig" echo [wsl2]
>>"%USERPROFILE%.wslconfig" echo memory=8GB
>>"%USERPROFILE%.wslconfig" echo processors=4
>>"%USERPROFILE%.wslconfig" echo swap=4GB
>>"%USERPROFILE%.wslconfig" echo localhostForwarding=true
>>"%USERPROFILE%.wslconfig" echo pageReporting=false
>>"%USERPROFILE%.wslconfig" echo nestedVirtualization=true
>>"%USERPROFILE%.wslconfig" echo sparseVhd=true

wsl --shutdown

wsl -d %ARCH_DISTRO_NAME% -u root -- bash -lc "set -e; pacman-key --init; pacman-key --populate archlinux; sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf || true; pacman -Syu --noconfirm; pacman -S --noconfirm iperf3 wget ca-certificates sudo vim reflector; reflector --country United States --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true; pacman -Syyu --noconfirm; if ! pacman -Si speedtest-cli >/dev/null 2>&1; then pacman -S --noconfirm speedtest-cli || true; fi; if ! id %ARCH_USER% >/dev/null 2>&1; then useradd -m -G wheel -s /bin/bash %ARCH_USER%; echo '%ARCH_USER%:%ARCH_USER%' | chpasswd; fi; grep -q '^%%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers || echo '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers; cat >/etc/wsl.conf <<'EOF'
[network]
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true

[automount]
enabled = true
root = /mnt
options = metadata,uid=1000,gid=1000,umask=022,fmask=11
EOF"

wsl -d %ARCH_DISTRO_NAME% -u root -- bash -lc "command -v archlinux-config >/dev/null 2>&1 && archlinux-config --default-user %ARCH_USER% || true"

echo.
echo Installed Arch Linux on WSL2.
echo Start with: wsl -d %ARCH_DISTRO_NAME%
echo User: %ARCH_USER%
echo Password: %ARCH_USER%
echo Tools: iperf3, speedtest-cli
echo.
endlocal
exit /b 0
