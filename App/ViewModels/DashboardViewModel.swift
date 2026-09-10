//
//  DashboardViewModel.swift
//  ExpiryGuard
//

import Foundation
import SwiftData

@Observable
@MainActor
final class DashboardViewModel {
    var currentFilter: ExpiryStatus? = nil
    
    func toggleFilter(_ status: ExpiryStatus) {
        if currentFilter == status {
            currentFilter = nil
        } else {
            currentFilter = status
        }
    }
    
    func filteredItems(_ items: [TrackedItem]) -> [TrackedItem] {
        let sorted = items.sorted { $0.expiryDate < $1.expiryDate }
        if let currentFilter {
            return sorted.filter { $0.status == currentFilter }
        }
        return sorted
    }
    
    func countByStatus(_ items: [TrackedItem]) -> (expired: Int, urgent: Int, safe: Int) {
        var expired = 0
        var urgent = 0
        var safe = 0
        
        for item in items {
            switch item.status {
            case .expired:
                expired += 1
            case .urgent:
                urgent += 1
            case .safe:
                safe += 1
            }
        }
        
        return (expired, urgent, safe)
    }
}
