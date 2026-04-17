import Foundation

struct AppDataBundle: Codable {
    let labels: [TimerLabel]
    let independentLabels: [IndependentTimerLabel]
    let session: TimerSession?
    let logs: [SessionLog]
}
