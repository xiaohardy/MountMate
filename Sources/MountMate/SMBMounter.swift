import Foundation
import Darwin
import NetFS
import MountMateCore

enum SMBMounter {
    static func connect(_ share: ManagedShare, password: String?, completion: @escaping (Int32) -> Void) {
        guard let address = SMBAddress(share.address) else {
            completion(EINVAL)
            return
        }
        let options = NSMutableDictionary()
        options["UIOption"] = "NoUI"
        if share.guestAccess { options["Guest"] = true }
        let gate = CompletionGate(completion)
        var requestID: AsyncRequestID?
        let status = NetFSMountURLAsync(
            address.url as CFURL,
            nil,
            share.guestAccess || share.username.isEmpty ? nil : share.username as CFString,
            share.guestAccess ? nil : password.map { $0 as CFString },
            options as CFMutableDictionary,
            nil,
            &requestID,
            DispatchQueue.global(qos: .utility)
        ) { result, _, _ in
            gate.finish(result)
        }
        if status != 0 {
            gate.finish(status)
            return
        }
        let pendingID = requestID
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 20) {
            if gate.finish(ETIMEDOUT), let pendingID { NetFSMountURLCancel(pendingID) }
        }
    }

    static func isAuthenticationError(_ status: Int32) -> Bool {
        [EACCES, EPERM, EAUTH, -5045, -5046, -5999, -5997].contains(status)
    }
}

private final class CompletionGate {
    private let lock = NSLock()
    private var completion: ((Int32) -> Void)?

    init(_ completion: @escaping (Int32) -> Void) { self.completion = completion }

    @discardableResult
    func finish(_ status: Int32) -> Bool {
        lock.lock()
        let callback = completion
        completion = nil
        lock.unlock()
        callback?(status)
        return callback != nil
    }
}
