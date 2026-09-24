import Foundation
import Darwin
import DiskArbitration
import MountMateCore

enum VolumeScanner {
    static func scan() -> [MountedVolume] {
        var mounts: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mounts, MNT_NOWAIT)
        guard count > 0, let mounts else { return [] }
        // hdiutil can take seconds on a busy Mac. There is no image to identify
        // when every visible mount is a network volume.
        let hasLocalVolume = (0..<Int(count)).contains { index in
            let item = mounts[index]
            return cString(item.f_mntonname).hasPrefix("/Volumes/") &&
                cString(item.f_mntfromname).hasPrefix("/dev/")
        }
        let imagePaths = hasLocalVolume ? mountedImages() : [:]
        let session = DASessionCreate(kCFAllocatorDefault)
        var result: [MountedVolume] = []

        for index in 0..<Int(count) {
            let item = mounts[index]
            let path = cString(item.f_mntonname)
            guard path.hasPrefix("/Volumes/"), path != "/Volumes/" else { continue }
            let source = cString(item.f_mntfromname)
            let fileSystem = cString(item.f_fstypename).lowercased()
            let name = URL(fileURLWithPath: path).lastPathComponent

            if ["smbfs", "nfs", "afpfs", "webdav"].contains(fileSystem) {
                let key = SMBAddress.key(forMountSource: source)
                result.append(MountedVolume(name: name, path: path, source: source,
                                            kind: .network, stableID: "network:\(key ?? source.lowercased())"))
                continue
            }

            if let imagePath = imagePaths[path] {
                result.append(MountedVolume(name: name, path: path, source: source,
                                            kind: .diskImage, stableID: "image:\(imagePath)"))
                continue
            }

            guard source.hasPrefix("/dev/"), let session,
                  let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, source),
                  let description = DADiskCopyDescription(disk) as NSDictionary? else { continue }

            let bus = (description[kDADiskDescriptionDeviceProtocolKey] as? String ?? "").lowercased()
            guard let kind = VolumeClassification.localKind(
                bus: bus,
                isInternal: description[kDADiskDescriptionDeviceInternalKey] as? Bool,
                isRemovable: description[kDADiskDescriptionMediaRemovableKey] as? Bool,
                isDiskImage: false
            ) else { continue }
            let uuid = (description[kDADiskDescriptionVolumeUUIDKey] as? UUID)?.uuidString
                ?? (description[kDADiskDescriptionMediaUUIDKey] as? UUID)?.uuidString
            let identity = uuid ?? "\(bus):\(name.lowercased())"
            result.append(MountedVolume(name: name, path: path, source: source,
                                        kind: kind, stableID: "local:\(identity)"))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func cString<T>(_ value: T) -> String {
        withUnsafePointer(to: value) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { String(cString: $0) }
        }
    }

    private static func mountedImages() -> [String: String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["info", "-plist"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        do { try process.run() } catch { return [:] }
        guard done.wait(timeout: .now() + 3) == .success else {
            process.terminate()
            return [:]
        }
        guard process.terminationStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(from: output.fileHandleForReading.readDataToEndOfFile(), options: [], format: nil) as? [String: Any],
              let images = plist["images"] as? [[String: Any]] else { return [:] }
        var paths: [String: String] = [:]
        for image in images {
            guard let imagePath = image["image-path"] as? String,
                  let entities = image["system-entities"] as? [[String: Any]] else { continue }
            for entity in entities {
                if let point = entity["mount-point"] as? String { paths[point] = imagePath }
            }
        }
        return paths
    }
}
