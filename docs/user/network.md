# Network and USB

[日本語](network.ja.md) · [Guide index](README.md)

On devices with detected Wi-Fi hardware, use `START` → `Network Settings` → `Connect Wi-Fi` to choose an SSID. Read the IP address under `INFORMATION` in the same menu, and enable the service you need under `NW Service`.

| Service | How to connect |
| --- | --- |
| SSH / SFTP | Device IP, port 22. The factory login is `root` / `plumos`. SFTP starts in the user area. |
| FTP | Device IP, port 21. Anonymous access to the user area. |
| Samba | Share `SDCARD`. Factory login `plumos` / `plumos`. The share starts in the user area. |
| USB ADB | Connect the handheld's data-capable port using a data cable and run `adb devices -l`. The ADB switch is under `NW Service`. A service change can require a restart. |

Factory credentials are shared across installations and USB ADB provides a root shell. Enable the services you use on a trusted network or computer.
