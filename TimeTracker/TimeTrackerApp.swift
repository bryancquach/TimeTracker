import SwiftUI

@main
struct TimeTrackerApp: App {
    @State private var viewModel = TimerViewModel()

    init() {
        UserDefaults.standard.set(600, forKey: "NSInitialToolTipDelay")
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(viewModel: viewModel)
        } label: {
            Label(viewModel.totalFormattedHours, systemImage: "hourglass")
        }
        .menuBarExtraStyle(.window)
    }
}
