import Foundation
import WatchConnectivity
internal import Combine

@MainActor
final class PhoneWatchConnectivityCoordinator: NSObject, ObservableObject {
    @Published private(set) var isSupported = WCSession.isSupported()
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isReachable = false
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var lastEventDescription = "No messages yet"
    @Published private(set) var lastPongDescription = "No pong yet"

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        activateSessionIfNeeded()
    }

    func activateSessionIfNeeded() {
        guard let session else { return }
        session.delegate = self
        session.activate()
        refreshSessionState()
    }

    func sendPing() {
        guard let session else {
            lastEventDescription = "WCSession not supported on this device"
            return
        }

        guard session.isPaired else {
            lastEventDescription = "No paired watch simulator/device available"
            return
        }

        guard session.isWatchAppInstalled else {
            lastEventDescription = "Watch app is not installed on the paired watch"
            return
        }

        let payload: [String: Any] = [
            "type": "ping",
            "origin": "iphone",
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                Task { @MainActor in
                    guard let self else { return }
                    let type = reply["type"] as? String ?? "unknown"
                    self.lastPongDescription = "Reply: \(type) at \(Self.timeLabel(Date()))"
                    self.lastEventDescription = "Ping delivered to watch"
                }
            }, errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Ping failed: \(error.localizedDescription)"
                }
            })
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Watch unreachable. Ping queued."
        }
    }

    func sendSessionSnapshot(_ payload: [String: Any]) {
        guard let session else { return }
        guard session.isPaired, session.isWatchAppInstalled else {
            lastEventDescription = "Cannot push snapshot: watch pairing/app not ready"
            return
        }
        do {
            try session.updateApplicationContext(payload)
            lastEventDescription = "Snapshot sent to watch"
        } catch {
            lastEventDescription = "Snapshot failed: \(error.localizedDescription)"
        }
    }

    func sendSessionFinished(sessionId: String) {
        guard let session else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let payload: [String: Any] = [
            "type": "session_finished",
            "origin": "iphone",
            "sessionId": sessionId,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Finish send failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Finish queued"
        }
    }

    func sendSessionDiscarded(sessionId: String) {
        guard let session else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let payload: [String: Any] = [
            "type": "session_discarded",
            "origin": "iphone",
            "sessionId": sessionId,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Discard send failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Discard queued"
        }
    }

    func sendRestAdjustment(sessionId: String, exerciseId: String, remainingSeconds: Int, exerciseName: String) {
        guard let session else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let payload: [String: Any] = [
            "type": "rest_adjusted",
            "origin": "iphone",
            "sessionId": sessionId,
            "exerciseId": exerciseId,
            "exerciseName": exerciseName,
            "remainingSeconds": remainingSeconds,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Rest send failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Rest queued"
        }
    }

    private func refreshSessionState() {
        guard let session else { return }
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
        activationState = session.activationState
    }

    private func cancelOutstandingTransfersIfNeeded(_ session: WCSession) {
        // Prevent stale queued transfers from older simulator pairings.
        for transfer in session.outstandingUserInfoTransfers {
            transfer.cancel()
        }
    }

    private static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

extension PhoneWatchConnectivityCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            self.cancelOutstandingTransfersIfNeeded(session)
            if let error {
                self.lastEventDescription = "Activation error: \(error.localizedDescription)"
            } else {
                self.lastEventDescription = "Session activated"
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.lastEventDescription = "Session became inactive"
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            session.activate()
            self.lastEventDescription = "Session deactivated, reactivating"
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            self.activationState = session.activationState
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleIncoming(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.handleIncoming(message)
            if (message["type"] as? String) == "ping" {
                replyHandler([
                    "type": "pong",
                    "origin": "iphone",
                    "receivedAt": Date().timeIntervalSince1970
                ])
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleIncoming(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            self.handleIncoming(userInfo)
        }
    }

    @MainActor
    private func handleIncoming(_ payload: [String: Any]) {
        let type = payload["type"] as? String ?? "unknown"
        if type == "pong" {
            lastPongDescription = "Pong from watch at \(Self.timeLabel(Date()))"
        }

        if type == "session_snapshot", let summary = payload["summary"] as? String {
            lastEventDescription = "Snapshot from watch: \(summary)"
            return
        }

        if type == "set_updated" {
            NotificationCenter.default.post(
                name: .watchSetUpdated,
                object: nil,
                userInfo: payload
            )
            lastEventDescription = "Set value update from watch"
            return
        }

        if type == "set_toggled" {
            NotificationCenter.default.post(
                name: .watchSetToggled,
                object: nil,
                userInfo: payload
            )
            lastEventDescription = "Set update from watch"
            return
        }

        if type == "set_added" {
            NotificationCenter.default.post(
                name: .watchSetAdded,
                object: nil,
                userInfo: payload
            )
            lastEventDescription = "Set added from watch"
            return
        }

        if type == "set_deleted" {
            NotificationCenter.default.post(
                name: .watchSetDeleted,
                object: nil,
                userInfo: payload
            )
            lastEventDescription = "Set deleted from watch"
            return
        }

        if type == "rest_adjusted" {
            NotificationCenter.default.post(
                name: .watchRestAdjusted,
                object: nil,
                userInfo: payload
            )
            lastEventDescription = "Rest timer update from watch"
            return
        }

        if type == "session_finished" {
            NotificationCenter.default.post(
                name: .watchSessionFinished,
                object: nil,
                userInfo: payload
            )
            lastEventDescription = "Finish request from watch"
            return
        }

        if type == "session_discarded" {
            NotificationCenter.default.post(
                name: .watchSessionDiscarded,
                object: nil,
                userInfo: payload
            )
            lastEventDescription = "Discard request from watch"
            return
        }

        lastEventDescription = "Received \(type) from watch"
    }
}

extension Notification.Name {
    static let watchSetToggled = Notification.Name("lighty.watchSetToggled")
    static let watchSetUpdated = Notification.Name("lighty.watchSetUpdated")
    static let watchRestAdjusted = Notification.Name("lighty.watchRestAdjusted")
    static let watchSessionFinished = Notification.Name("lighty.watchSessionFinished")
    static let watchSetAdded = Notification.Name("lighty.watchSetAdded")
    static let watchSetDeleted = Notification.Name("lighty.watchSetDeleted")
    static let watchSessionDiscarded = Notification.Name("lighty.watchSessionDiscarded")
}
