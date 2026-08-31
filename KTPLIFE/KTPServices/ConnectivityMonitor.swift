import Foundation
import Network
import Combine

extension Notification.Name {
    static let connectivityRestored = Notification.Name("KTPLIFE.connectivityRestored")
}

final class ConnectivityMonitor: ObservableObject {
    static let shared = ConnectivityMonitor()

    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "KTPLIFE.ConnectivityMonitor")
    private var hasReceivedInitialPath = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                let restored = self.hasReceivedInitialPath && !self.isConnected && isConnected
                self.hasReceivedInitialPath = true
                self.isConnected = isConnected
                if restored {
                    NotificationCenter.default.post(name: .connectivityRestored, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
