# Devices

[日本語](devices.ja.md) · [Guide index](README.md)

The same SD image selects the board at boot. RGB30 r1 and r2 use the same image.

| Device | What was checked |
| --- | --- |
| Anbernic RG353M | Boot, frontend, SD2, Wi-Fi, USB ADB, and representative emulator, audio and sleep tests |
| Anbernic RG353V | Boot, SD2, USB ADB, power-on with USB connected, and representative emulator, app, audio and sleep tests |
| Anbernic RG503 | Boot, 960×544 display, SD2, USB ADB with an alternate data cable, and representative emulator, app, audio and sleep tests |
| Powkiddy RGB30 r1 / r2 | Boot, automatic board revision selection, frontend, and ADB on both revisions. The broader SD2, emulator and audio tests used r2. |
| Powkiddy RK2023 | Boot, 640×480 display, SD2, USB ADB, representative emulator and app tests, sleep and USB DAC switching back to the speaker. Wi-Fi hardware was absent from the test unit's device inventory. |

The image includes board definitions for RG353P and RGB10 Max 3. Both still await a plumOS hardware boot test. RG353VS is also untested and has no dedicated device tree in the image. [Device evidence](../boot-and-device-support.md)
