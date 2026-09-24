# MountMate

[简体中文说明](README.zh-CN.md)

MountMate is a macOS menu bar app that keeps selected SMB shares connected and safely cleans up temporary mounts. It shows a star for each mount in the menu bar; your fixed mounts take the first positions.

## Install

1. Download the Apple Silicon DMG from the [v0.3.2 preview release](https://github.com/xiaohardy/MountMate/releases/tag/v0.3.2).
2. Open the DMG and drag **MountMate.app** to **Applications**.
3. Open MountMate from Applications. Close its main window to keep it running from the menu bar.

### First launch on macOS

This preview build has a local ad hoc signature and **has not been notarized by Apple**. A downloaded copy may be blocked on first launch. Only continue if you obtained it from [this project's release](https://github.com/xiaohardy/MountMate/releases/tag/v0.3.2) and trust it.

1. Try opening the app once. If macOS blocks it, choose **Done** if available.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, and choose **Open Anyway**.
3. Confirm **Open** when macOS asks again. See [Apple's instructions](https://support.apple.com/en-us/102445).

If macOS says the app **is damaged** or **will damage your computer**, stop and [report the warning](https://github.com/xiaohardy/MountMate/issues). Do not disable macOS security checks for all apps.

MountMate targets macOS 14 or later on Apple Silicon. This preview was built and checked on macOS 27; earlier macOS versions and Intel Macs have not been tested.

## Use MountMate

- Add an SMB share with its `smb://server/share` address, or select an already mounted SMB share from **Overview → Add from Current Mounts**. USB disks, disk images, and other network protocols remain visible in the overview but cannot be imported as fixed mounts.
- Turn on **Keep Connected** for shares that should reconnect after a disconnect, wake, or network recovery. Disconnecting a fixed share inside the app pauses its automatic reconnection until you resume it.
- Review the cleanup categories and protected mounts before using **Clean Temporary Mounts**. Fixed shares that are kept connected are always protected from bulk cleanup. You can also enable one cleanup at a chosen local time each day; a missed cleanup is skipped after sleep.
- The twelve menu bar stars run clockwise from the top. A mounted, healthy volume lights its star; a disconnected or unhealthy one dims. Additional mounts beyond twelve do not add more stars.

MountMate requests a normal unmount and skips busy volumes. It does not force eject a disk, wake your Mac for cleanup, or resume a file transfer that failed during a network interruption. Automatic reconnection currently supports SMB only.

## Local data and credentials

Settings and the most recent 150 events are stored in `~/Library/Application Support/MountMate/settings.json`. This file can contain share names, SMB addresses, usernames, and mount identifiers, so remove those details before sharing it. Passwords are stored in the macOS Keychain, not in the settings file. Importing a mounted SMB share first tries credentials already available to macOS; if that fails, edit the fixed mount and add credentials in MountMate.

MountMate does not include analytics or a data upload service. It connects to the SMB servers you configure and uses macOS APIs to inspect and unmount local volumes. For automatic reconnection after login, enable **Launch MountMate at Login** in the Fixed Mounts tab.

## Build from source

Install Xcode and its Swift tools on an Apple Silicon Mac, then run:

```sh
swift test --scratch-path "${TMPDIR:-/tmp}/mountmate-test-build" --disable-sandbox
./scripts/package-dmg.sh
```

The packaging script creates an ad hoc signed preview DMG in `dist/` and verifies its signature, architecture, version, resources, and disk image checksum. It does not need an NAS connection to build. The app icon is drawn by `scripts/draw-icon.swift`; run `scripts/create-icon.sh` to regenerate it.

## Feedback and license

Please use [GitHub Issues](https://github.com/xiaohardy/MountMate/issues) for bugs and ideas. MountMate is released under the [MIT License](LICENSE).
