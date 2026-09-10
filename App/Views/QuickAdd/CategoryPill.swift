import SwiftUI

struct CategoryPill: View {
    let category: ItemCategory
    let isSelected: Bool
    var onDelete: (() -> Void)? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.system(size: 14))
                Text(category.name)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .green : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green.opacity(0.2) : Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.green : Color(UIColor.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("刪除「\(category.name)」分類", systemImage: "trash")
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
