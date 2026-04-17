import Foundation

@MainActor
final class TickScheduler {

    var onTick: (() -> Void)?
    var onPersistCycle: (() -> Void)?

    private var tickCount = 0

    func start() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.fire()
            }
        }
    }

    private func fire() {
        onTick?()
        tickCount += 1
        if tickCount >= AppConstants.persistIntervalTicks {
            tickCount = 0
            onPersistCycle?()
        }
    }
}
