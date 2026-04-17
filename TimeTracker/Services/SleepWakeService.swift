import Foundation
import AppKit

/// Observes system sleep/wake and screen sleep/wake notifications,
/// consolidating them into a single onSleep / onWake callback pair.
final class SleepWakeService: @unchecked Sendable {

    private var observers: [NSObjectProtocol] = []
    private var isSleeping = false

    init(onSleep: @escaping @Sendable () -> Void,
         onWake: @escaping @Sendable () -> Void) {

        let center = NSWorkspace.shared.notificationCenter

        observers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self, !self.isSleeping else { return }
                self.isSleeping = true
                onSleep()
            }
        )

        observers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.isSleeping else { return }
                self.isSleeping = false
                onWake()
            }
        )
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for obs in observers { center.removeObserver(obs) }
    }
}
