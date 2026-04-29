import Testing
import Foundation
@testable import TimeTracker

@Suite("TimeFormatting")
struct TimeFormattingTests {

    @Test("Zero seconds formats as 0.00h")
    func zeroSeconds() {
        #expect(TimeFormatting.formattedHours(from: 0) == "0.00h")
    }

    @Test("Sub-hour value formats correctly")
    func subHour() {
        #expect(TimeFormatting.formattedHours(from: 1800) == "0.50h")
    }

    @Test("Exactly one hour")
    func oneHour() {
        #expect(TimeFormatting.formattedHours(from: 3600) == "1.00h")
    }

    @Test("Multi-hour value formats correctly")
    func multiHour() {
        #expect(TimeFormatting.formattedHours(from: 9000) == "2.50h")
    }

    @Test("Large value formats correctly")
    func largeValue() {
        #expect(TimeFormatting.formattedHours(from: 360000) == "100.00h")
    }

    @Test("Fractional seconds round to two decimal places")
    func fractionalSeconds() {
        let result = TimeFormatting.formattedHours(from: 360)
        #expect(result == "0.10h")
    }
}
