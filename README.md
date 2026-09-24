# MountMate

[简体中文说明](README.zh-CN.md) · [Release checklist](RELEASING.md)

MountMate is a macOS menu bar app that keeps selected SMB shares connected and safely cleans up temporary mounts. This is an **Apple Silicon preview**.

## Install or update

1. Download the DMG from the [v0.3.3 preview release](https://github.com/xiaohardy/MountMate/releases/tag/v0.3.3).
2. Open it and drag **MountMate.app** to **Applications**.
3. Start MountMate from Applications. Closing its window leaves the menu bar app running; choose **Quit MountMate** from the menu bar to exit.

If you use v0.3.2, turn off **Launch MountMate at login** in its **Pinned mounts** tab, then quit it from the menu bar before replacing the app. The v0.3.3 app has a new public bundle identifier. Your settings file remains in the same location, but macOS may ask again for network permissions and a saved SMB password. Check your pinned mounts, re-enter any password requested in the share editor, and then re-enable launch at login. If an old login item remains in **System Settings → General → Login Items**, remove that old item.

### First launch on macOS

This preview has an ad hoc signature and **has not been notarized by Apple**. A downloaded copy may be blocked on first launch. Continue only if you obtained it from [this project's release](https://github.com/xiaohardy/MountMate/releases/tag/v0.3.3) and trust it.

1. Try opening the app once. If macOS blocks it, choose **Done** if available.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, and choose **Open Anyway**.
3. Confirm **Open** when macOS asks again. See [Apple's instructions](https://support.apple.com/en-us/102445).

If macOS says the app **is damaged** or **will damage your computer**, stop and [report the warning](https://github.com/xiaohardy/MountMate/issues). Do not disable macOS security checks for all apps.

MountMate targets macOS 14 or later on Apple Silicon. This preview was built and checked on macOS 27; earlier macOS versions, Intel Macs, and first launch on a clean Mac have not been tested.

## Use MountMate

- **Pinned mounts:** Add an SMB share using an address such as smb://server/share, without a password in the address. You can also choose **Overview → Add from current mounts** to import an already mounted SMB share. If its mount source includes a username, the importer brings it over. Imported shares first try SMB credentials already available to macOS; if reconnection needs a password, edit the share and save it in MountMate's Keychain item.
- **Reconnect:** Turn on **Keep connected** for a pinned share. MountMate checks it at launch, after wake or network recovery, and during periodic checks. Disconnecting it inside the app pauses automatic reconnection until you resume it. A mount that still exists but fails an access check is marked unhealthy; MountMate does not forcibly unmount and remount it.
- **Current mounts:** The overview scans supported mounts under /Volumes: SMB, NFS, AFP, WebDAV, disk images, and recognizable external disks. Only SMB shares can become pinned mounts.
- **Cleanup:** In **Cleanup rules**, choose the categories eligible for both **Clean up temporary mounts** and daily cleanup. By default, only disk images and USB volumes clearly marked removable are selected; other external disks and network shares are excluded. The shield button protects a mount from both cleanup actions. **Unmount** is a separate manual action and can still be requested for a protected mount. A kept-connected SMB share is always protected from bulk cleanup.
- **Daily time:** Daily cleanup is off by default; its initial time is 03:00 in the Mac's local time. It runs once during the five minutes after that time only while the app is awake and already running. A time missed during sleep or while the app is closed is not made up later.
- **Stars and languages:** The menu bar has up to twelve clockwise star positions, starting at the top. Pinned mounts reserve the first positions. A pinned SMB star dims if its mount disconnects or its access check fails; an ordinary mount's star reflects whether the scanner sees it. More than twelve mounts do not create extra stars. Choose the interface language at the top of **Overview**; eight languages are available.

MountMate requests a normal unmount. If macOS rejects it because a volume is busy or for another reason, the volume stays mounted and the error appears in **Activity log**. MountMate does not force eject a disk, wake the Mac for cleanup, or resume a file transfer that failed during a network interruption. Automatic reconnection supports SMB only.

## Settings, privacy, and recovery

Settings and the most recent 150 events are stored in **~/Library/Application Support/MountMate/settings.json** with user-only file permissions. This file can contain share names, SMB addresses, usernames, and mount identifiers; remove those details before sharing it. Passwords are stored in the macOS Keychain. MountMate has no analytics or data upload service. It connects to SMB servers you configure and uses macOS APIs to inspect and unmount volumes.

If MountMate says settings cannot be read or saved, it leaves the existing settings file intact and pauses changes and cleanup. Quit MountMate, make a backup copy of the file above, then restore a known-good copy or move the unreadable file aside if you intend to start with empty settings. Fix a full disk or file-permission problem before restarting. You may need to add your pinned mounts again after starting with empty settings. Do not post the original settings file publicly.

For reconnection after login, enable **Launch MountMate at login** in **Pinned mounts**. The app must be running for automatic reconnection and daily cleanup.

## Build from source

Install Xcode and its Swift tools on an Apple Silicon Mac, then run:

~~~sh
swift test --scratch-path /tmp/mountmate-test-build --disable-sandbox
./scripts/package-dmg.sh
~~~

The script creates an ad hoc signed preview DMG in dist/ and checks its signature, architecture, version, icon, eight interface languages, localized permission text, and disk image checksum. It does not need a NAS connection to build. Run scripts/create-icon.sh to regenerate the app icon.

Please use [GitHub Issues](https://github.com/xiaohardy/MountMate/issues) for bugs and ideas. MountMate is released under the [MIT License](LICENSE).
