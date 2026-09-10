//
//  ItemCardView.swift
//  ExpiryGuard
//

import SwiftUI

struct ItemCardView: View {
    let item: TrackedItem
    let onEdit: () -> Void
    let onConsume: () -> Void
    var onArchiveWasted: (() -> Void)? = nil
    var onArchiveConsumed: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // LEFT & CENTER: Tappable to edit reminder
            HStack(spacing: 12) {
                // LEFT
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(item.category.emoji)
                            .font(.system(size: 12))
                        Text(item.category.name)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // CENTER
                Text(DateHelpers.formatDate(item.expiryDate))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                
                // STATUS BADGE
                Text(item.statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(item.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.status.backgroundColor)
                    .clipShape(Capsule())
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
            }
            
            // RIGHT: Action button (Checkmark for consumed, Trash for expired)
            Button(action: onConsume) {
                Image(systemName: item.status == .expired ? "trash" : "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(item.status == .expired ? .red : .green)
                    .frame(width: 34, height: 34)
                    .background(item.status == .expired ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(item.status == .expired ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.separator), lineWidth: 1)
        )
        .contextMenu {
            Button {
                if let onArchiveConsumed {
                    onArchiveConsumed()
                } else {
                    onConsume()
                }
            } label: {
                Label("已吃完／用完", systemImage: "checkmark.circle")
            }
            
            Button(role: .destructive) {
                if let onArchiveWasted {
                    onArchiveWasted()
                } else {
                    onConsume()
                }
            } label: {
                Label("過期丟棄", systemImage: "trash")
            }
            
            Divider()
            
            Button {
                onEdit()
            } label: {
                Label("設定提醒", systemImage: "bell")
            }
        }
    }
}
