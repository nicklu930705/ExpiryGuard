import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String? = nil
    
    private var priceLabel: String {
        if let product = StoreManager.shared.products.first {
            return "\(product.displayPrice) 終身買斷"
        }
        return "NT$ 150 終身買斷"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
            }
            
            if StoreManager.shared.hasUnlockedPro {
                Text("尊榮 Pro 守護者")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.green)
                
                Text("您已經解鎖了所有進階功能，感謝支持！")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 16) {
                    benefitRow(text: "解鎖無限追蹤數量")
                    benefitRow(text: "桌面即時小工具")
                    benefitRow(text: "拍照自動辨識效期")
                }
                .padding(.vertical, 20)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("開始使用")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
            } else {
                Text("升級 Pro 無限守護")
                    .font(.system(size: 21, weight: .bold))
                
                Text("免費額度已用完，升級解鎖完整功能")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 16) {
                    benefitRow(text: "解鎖無限追蹤數量")
                    benefitRow(text: "桌面即時小工具")
                    benefitRow(text: "拍照自動辨識效期")
                }
                .padding(.vertical, 20)
                
                Button(action: {
                    Task {
                        do {
                            let success = try await StoreManager.shared.purchaseLifetimeUnlock()
                            if success {
                                dismiss()
                            }
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    HStack {
                        if StoreManager.shared.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(priceLabel)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .disabled(StoreManager.shared.isPurchasing)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    Task {
                        do {
                            try await StoreManager.shared.restorePurchases()
                            if StoreManager.shared.hasUnlockedPro {
                                dismiss()
                            }
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("恢復購買")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
                
                Spacer()
                
                Text("一次性付費 · 永久使用")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
        }
    }
    
    private func benefitRow(text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
                .fontWeight(.bold)
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
