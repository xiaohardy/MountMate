# MountMate release checklist

This checklist adapts the project's macOS preview release SOP. Record the evidence for each release in its GitHub Release notes. Automated tests and a verified disk image do not replace a real installation test.

## Before building

- Confirm the user-visible behavior, version and build number, Apple Silicon target, minimum macOS target, app identifier, and known limits.
- Run the automated tests. Review the failure paths for unreadable settings, save errors, missing credentials, busy volumes, sleep, and missed daily cleanup.
- Check that all eight interface catalogs have the same keys and placeholders. Check each localized InfoPlist.strings file and its text in the built app.
- Review every file intended for GitHub. Exclude settings, logs, passwords, signing keys, private server names, real user data, and unrelated Git history. Check screenshots and icon metadata, Info.plist, Git author email, and account profile as well as source text.

## Build and inspect the installer

- Build in a clean temporary directory. Run scripts/package-dmg.sh and keep the resulting DMG and SHA-256.
- Verify the signed app after staging and again after read-only mounting of the DMG. Check strict code signature, arm64 executable, version/build, `LSUIElement=true`, icon, eight interface languages, eight localized permission texts, image checksum, and a two-item DMG root containing only MountMate.app and the Applications shortcut.
- Scan the final executable and bundled resources for personal build paths and private data. A source-only scan is insufficient.
- On a Mac used for testing, quit the old app before replacing it. Open the downloaded app and check that only the menu bar icon appears at launch, the Dock icon stays hidden, and **Open MountMate** still opens its window. Exercise adding or importing an SMB share, protection, normal unmount behavior, and a safe noncritical reconnection path. Record separately anything that was not tested, including other macOS versions, clean-Mac first launch, sleep, or real NAS recovery.
- An ad hoc signature is not Apple notarization. Keep preview releases marked as previews, describe the macOS first-launch steps using Apple's guidance, and never recommend disabling system-wide security checks.

## Publish and verify

- Check the remote main branch and existing tags before pushing. Create a new tag for a changed app or DMG; do not silently replace a published version.
- Publish the release with its DMG as a Release asset. Confirm the repository is public, the tag and asset match the version, and the release is neither a draft nor mislabeled as stable.
- Link versioned installation instructions from the Release notes. Update both English and Chinese READMEs and keep the release limitations and checksum consistent.
- Download the public DMG without repository credentials and compare its SHA-256 with the verified local artifact. Verify the downloaded image and inspect the mounted app again.
- If an older asset exposed private information, withdraw that asset, leave a clear notice on the old Release, and publish a corrected new version. A later commit cannot remove information from an already downloaded file.

MountMate's public preview builds use ad hoc signing and have not been notarized. Real SMB, permissions, sleep, and clean-Mac checks must be reported as tested or untested for each release.
