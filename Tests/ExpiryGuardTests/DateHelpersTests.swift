//
//  DateHelpersTests.swift
//  ExpiryGuardTests
//
//  Created for ExpiryGuard on 2026/09/02.
//

import Testing
import Foundation
@testable import ExpiryGuard

@Suite("DateHelpers Tests")
struct DateHelpersTests {
    
    // MARK: - daysUntil
    
    @Test("daysUntil returns negative for past dates")
    func daysUntilPastDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let result = DateHelpers.daysUntil(yesterday)
        #expect(result == -1)
    }
    
    @Test("daysUntil returns 0 for today")
    func daysUntilToday() {
        let result = DateHelpers.daysUntil(.now)
        #expect(result == 0)
    }
    
    @Test("daysUntil returns positive for future dates")
    func daysUntilFutureDate() {
        let inFiveDays = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        let result = DateHelpers.daysUntil(inFiveDays)
        #expect(result == 5)
    }
    
    // MARK: - expiryStatus
    
    @Test("expired status for past dates")
    func expiredStatus() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        #expect(DateHelpers.expiryStatus(for: yesterday) == .expired)
    }
    
    @Test("urgent status for dates within 3 days")
    func urgentStatus() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        #expect(DateHelpers.expiryStatus(for: tomorrow) == .urgent)
        
        let in3Days = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        #expect(DateHelpers.expiryStatus(for: in3Days) == .urgent)
    }
    
    @Test("safe status for dates more than 3 days away")
    func safeStatus() {
        let in4Days = Calendar.current.date(byAdding: .day, value: 4, to: .now)!
        #expect(DateHelpers.expiryStatus(for: in4Days) == .safe)
    }
    
    @Test("today is urgent")
    func todayIsUrgent() {
        #expect(DateHelpers.expiryStatus(for: .now) == .urgent)
    }
    
    // MARK: - statusLabel
    
    @Test("status label for expired")
    func expiredLabel() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        #expect(DateHelpers.statusLabel(for: twoDaysAgo) == "過期 2 天")
    }
    
    @Test("status label for today")
    func todayLabel() {
        #expect(DateHelpers.statusLabel(for: .now) == "今天到期")
    }
    
    @Test("status label for future")
    func futureLabel() {
        let in5Days = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        #expect(DateHelpers.statusLabel(for: in5Days) == "剩 5 天")
    }
    
    // MARK: - addDays / addMonths
    
    @Test("addDays adds correct number of days")
    func addDaysTest() {
        let today = Date.now
        let result = DateHelpers.addDays(7, to: today)
        let diff = Calendar.current.dateComponents([.day], from: today, to: result).day!
        #expect(diff == 7)
    }
    
    @Test("addMonths adds correct number of months")
    func addMonthsTest() {
        let today = Date.now
        let result = DateHelpers.addMonths(1, to: today)
        let diff = Calendar.current.dateComponents([.month], from: today, to: result).month!
        #expect(diff == 1)
    }
}
