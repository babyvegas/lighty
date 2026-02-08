import Foundation
import WatchConnectivity
internal import Combine

@MainActor
final class WatchConnectivityCoordinator: NSObject, ObservableObject {
    @Published private(set) var isSupported = WCSession.isSupported()
    @Published private(set) var isCompanionAppInstalled = false
    @Published private(set) var isReachable = false
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var lastEventDescription = "No messages yet"
    @Published private(set) var lastPongDescription = "No pong yet"
    @Published var lastSessionPayload: [String: Any]?
    @Published var didReceiveSessionFinished = false
    @Published var lastRestPayload: [String: Any]?

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

    func sendPingToPhone() {
        guard let session else {
            lastEventDescription = "WCSession not supported"
            return
        }

        guard session.isCompanionAppInstalled else {
            lastEventDescription = "Companion iPhone app is not installed/available"
            return
        }

        let payload: [String: Any] = [
            "type": "ping",
            "origin": "watch",
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                Task { @MainActor in
                    guard let self else { return }
                    let type = reply["type"] as? String ?? "unknown"
                    self.lastPongDescription = "Reply: \(type) at \(Self.timeLabel(Date()))"
                    self.lastEventDescription = "Ping delivered to iPhone"
                }
            }, errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Ping failed: \(error.localizedDescription)"
                }
            })
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "iPhone unreachable. Ping queued."
        }
    }

    func sendSetToggle(sessionId: String, exerciseId: String, setId: String, isCompleted: Bool) {
        guard let session else { return }

        let payload: [String: Any] = [
            "type": "set_toggled",
            "origin": "watch",
            "sessionId": sessionId,
            "exerciseId": exerciseId,
            "setId": setId,
            "isCompleted": isCompleted,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Set update failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Set update queued"
        }
    }

    func sendSetUpdate(sessionId: String, exerciseId: String, setId: String, weight: Double, reps: Int) {
        guard let session else { return }

        let payload: [String: Any] = [
            "type": "set_updated",
            "origin": "watch",
            "sessionId": sessionId,
            "exerciseId": exerciseId,
            "setId": setId,
            "weight": weight,
            "reps": reps,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Set value update failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Set value update queued"
        }
    }

    func sendSetAdded(sessionId: String, exerciseId: String, setId: String) {
        guard let session else { return }

        let payload: [String: Any] = [
            "type": "set_added",
            "origin": "watch",
            "sessionId": sessionId,
            "exerciseId": exerciseId,
            "setId": setId,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Set add failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Set add queued"
        }
    }

    func sendSetDeleted(sessionId: String, exerciseId: String, setId: String) {
        guard let session else { return }

        let payload: [String: Any] = [
            "type": "set_deleted",
            "origin": "watch",
            "sessionId": sessionId,
            "exerciseId": exerciseId,
            "setId": setId,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Set delete failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Set delete queued"
        }
    }

    func sendRestAdjustment(sessionId: String, exerciseId: String, remainingSeconds: Int, exerciseName: String) {
        guard let session else { return }

        let payload: [String: Any] = [
            "type": "rest_adjusted",
            "origin": "watch",
            "sessionId": sessionId,
            "exerciseId": exerciseId,
            "exerciseName": exerciseName,
            "remainingSeconds": remainingSeconds,
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastEventDescription = "Rest update failed: \(error.localizedDescription)"
                }
            }
        } else {
            session.transferUserInfo(payload)
            lastEventDescription = "Rest update queued"
        }
    }

    func sendSessionFinished(sessionId: String) {
        guard let session else { return }

        let payload: [String: Any] = [
            "type": "session_finished",
            "origin": "watch",
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

    private func refreshSessionState() {
        guard let session else { return }
        isCompanionAppInstalled = session.isCompanionAppInstalled
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

extension WatchConnectivityCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
            self.isReachable = session.isReachable
            self.cancelOutstandingTransfersIfNeeded(session)
            if let error {
                self.lastEventDescription = "Activation error: \(error.localizedDescription)"
            } else {
                self.lastEventDescription = "Session activated"
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
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
                    "origin": "watch",
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
            lastPongDescription = "Pong from iPhone at \(Self.timeLabel(Date()))"
        }

        if type == "session_snapshot" {
            lastSessionPayload = payload
            lastEventDescription = "Session updated from iPhone"
            return
        }

        if type == "rest_adjusted" {
            lastRestPayload = payload
            lastEventDescription = "Rest updated from iPhone"
            return
        }

        if type == "session_finished" {
            didReceiveSessionFinished = true
            lastEventDescription = "Session finished from iPhone"
            return
        }

        lastEventDescription = "Received \(type) from iPhone"
    }
}
