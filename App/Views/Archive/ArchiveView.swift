import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Query(sort: \ArchivedItem.archivedAt, order: .reverse) private var allArchivedItems: [ArchivedItem]
    
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: ArchiveReason = .consumed
    
    // Multi-select states
    @State private var selection = Set<ArchivedItem>()
    @State private var isEditing = false
    
    private var items: [ArchivedItem] {
        allArchivedItems.filter { $0.reasonRaw == selectedTab.rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // HEADER
            HStack {
                Text("歷史紀錄")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Button(action: {
                    withAnimation {
                        if isEditing {
                            // If they click "Done" but have selected items, ask if they want to delete? No, let's just exit edit mode.
                            isEditing = false
                            selection.removeAll()
                        } else {
                            isEditing = true
                        }
                    }
                }) {
                    Text(isEditing ? "完成" : "選擇")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(UIColor.separator), lineWidth: 1))
                }
            }
            .padding()
            
            Picker("分類", selection: $selectedTab) {
                Text("已吃完／用完").tag(ArchiveReason.consumed)
                Text("過期丟棄").tag(ArchiveReason.wasted)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedTab == .consumed {
                Text("已拯救未浪費：\(items.count) 件物品 🎉")
                    .foregroundColor(.green)
                    .font(.headline)
                    .padding()
            } else {
                Text("浪費紀錄：\(items.count) 件 — 下次注意採買量 ⚠️")
                    .foregroundColor(.red)
                    .font(.headline)
                    .padding()
            }
            
            if items.isEmpty {
                Spacer()
                Text("尚無紀錄")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List(selection: $selection) {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                HStack(spacing: 4) {
                                    Text(item.category.emoji)
                                        .font(.caption)
                                    Text(item.category.name)
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(DateHelpers.formatDateShort(item.archivedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(item)
                        .swipeActions {
                            Button(role: .destructive) {
                                modelContext.delete(item)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
                
                // MULTI-DELETE ACTION BAR
                if isEditing {
                    Button(action: {
                        for item in selection {
                            modelContext.delete(item)
                        }
                        selection.removeAll()
                        withAnimation { isEditing = false }
                    }) {
                        Text("刪除選取 (\(selection.count))")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selection.isEmpty ? Color.gray : Color.red)
                            .cornerRadius(12)
                    }
                    .padding()
                    .disabled(selection.isEmpty)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
