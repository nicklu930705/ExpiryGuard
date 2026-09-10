//
//  RadarDashboardView.swift
//  ExpiryGuard
//

import SwiftUI
import SwiftData

struct RadarDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedItem.expiryDate, order: .forward) private var items: [TrackedItem]
    
    @State private var viewModel = DashboardViewModel()
    @State private var showPaywall = false
    @State private var selectedItemForEdit: TrackedItem? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // TOP BAR
                    HStack {
                        Text("我的儲物箱")
                            .font(.system(size: 22, weight: .bold))
                        
                        Spacer()
                        
                        // Quota badge
                        Group {
                            if StoreManager.shared.hasUnlockedPro {
                                Button(action: { showPaywall = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 11))
                                        Text("Pro 無限版")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(LinearGradient(colors: [Color.green.opacity(0.85), Color.green], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(Capsule())
                                }
                            } else {
                                Button(action: { showPaywall = true }) {
                                    Text("\(items.count) / \(StoreManager.freeItemLimit) 免費額度 🚀升級")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(UIColor.separator), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // STATUS CARDS ROW
                    let counts = viewModel.countByStatus(items)
                    HStack(spacing: 12) {
                        StatusCardView(
                            title: "已過期",
                            count: counts.expired,
                            color: .red,
                            isSelected: viewModel.currentFilter == .expired
                        ) {
                            withAnimation {
                                viewModel.toggleFilter(.expired)
                            }
                        }
                        
                        StatusCardView(
                            title: "即將到期",
                            count: counts.urgent,
                            color: .orange,
                            isSelected: viewModel.currentFilter == .urgent
                        ) {
                            withAnimation {
                                viewModel.toggleFilter(.urgent)
                            }
                        }
                        
                        StatusCardView(
                            title: "安全",
                            count: counts.safe,
                            color: .green,
                            isSelected: viewModel.currentFilter == .safe
                        ) {
                            withAnimation {
                                viewModel.toggleFilter(.safe)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // SCROLLABLE ITEM LIST
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            let filtered = viewModel.filteredItems(items)
                            
                            if filtered.isEmpty {
                                Text("目前沒有追蹤的物品")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                            } else {
                                ForEach(filtered) { item in
                                    ItemCardView(
                                        item: item,
                                        onEdit: {
                                            selectedItemForEdit = item
                                        },
                                        onConsume: {
                                            consume(item)
                                        },
                                        onArchiveWasted: {
                                            consume(item, reason: .wasted)
                                        },
                                        onArchiveConsumed: {
                                            consume(item, reason: .consumed)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(item: $selectedItemForEdit) { item in
            EditReminderSheet(item: item)
        }
    }
    
    private func consume(_ item: TrackedItem, reason: ArchiveReason? = nil) {
        let finalReason = reason ?? (item.status == .expired ? .wasted : .consumed)
        
        let archived = ArchivedItem(from: item, reason: finalReason)
        modelContext.insert(archived)
        
        NotificationService.shared.cancelReminder(for: item.id)
        
        modelContext.delete(item)
        do {
            try modelContext.save()
            print("[Dashboard] Successfully archived '\(item.name)' as \(finalReason.rawValue)")
        } catch {
            print("[Dashboard] Failed to save archive: \(error)")
        }
    }
}
