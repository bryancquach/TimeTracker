import Testing
import Foundation
@testable import TimeTracker

@Suite("TimeFormatting")
struct TimeFormattingTests {

    @Test("Zero seconds formats as 0h 00m")
    func zeroSeconds() {
        #expect(TimeFormatting.formattedHours(from: 0) == "0h 00m")
    }

    @Test("Sub-hour value formats correctly")
    func subHour() {
        #expect(TimeFormatting.formattedHours(from: 1800) == "0h 30m")
    }

    @Test("Exactly one hour")
    func oneHour() {
        #expect(TimeFormatting.formattedHours(from: 3600) == "1h 00m")
    }

    @Test("Multi-hour value formats correctly")
    func multiHour() {
        #expect(TimeFormatting.formattedHours(from: 9000) == "2h 30m")
    }

    @Test("Large value formats correctly")
    func largeValue() {
        #expect(TimeFormatting.formattedHours(from: 360000) == "100h 00m")
    }

    @Test("Partial minutes are truncated")
    func truncatesPartialMinutes() {
        #expect(TimeFormatting.formattedHours(from: 59) == "0h 00m")
        #expect(TimeFormatting.formattedHours(from: 3599) == "0h 59m")
    }

    @Test("Increment-sized values land on exact minutes")
    func incrementValues() {
        #expect(TimeFormatting.formattedHours(from: 0.1 * 3600) == "0h 06m")
        #expect(TimeFormatting.formattedHours(from: 0.05 * 3600) == "0h 03m")
    }
}
