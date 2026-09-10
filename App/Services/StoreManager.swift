import Foundation
import StoreKit

/// StoreKit 2 內購管理 — 管理 Pro 終身買斷
@Observable
@MainActor
final class StoreManager {
    
    // MARK: - Constants
    
    static let shared = StoreManager()
    static let lifetimeProductID = "com.expiryguard.pro.lifetime"
    static let freeItemLimit = 5
    
    // MARK: - Published State
    
    private(set) var products: [Product] = []
    private(set) var hasUnlockedPro: Bool = ProcessInfo.processInfo.arguments.contains("-screenshot-pro")
    private(set) var isPurchasing: Bool = false
    
    // MARK: - Private
    
    private var transactionListenerTask: Task<Void, Never>?
    
    init() {
        transactionListenerTask = listenForTransactions()
        Task {
            await fetchProducts()
            await updateEntitlements()
        }
    }
    
    
    // MARK: - Public Methods
    
    /// 從 App Store 載入產品資訊
    func fetchProducts() async {
        do {
            products = try await Product.products(for: [Self.lifetimeProductID])
        } catch {
            print("[StoreManager] 載入產品失敗: \(error)")
        }
    }
    
    /// 執行終身買斷購買（透過 Apple StoreKit 2 真實扣款）
    func purchaseLifetimeUnlock() async throws -> Bool {
        // 若尚未載入產品，先嘗試重新載入
        if products.isEmpty {
            await fetchProducts()
        }
        
        guard let product = products.first(where: { $0.id == Self.lifetimeProductID }) else {
            throw StoreError.productNotFound
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateEntitlements()
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// 恢復購買（App Store 審核必備）
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateEntitlements()
    }
    
    /// 檢查是否可以新增物品（免費額度 or Pro）
    func canAddItem(currentCount: Int) -> Bool {
        hasUnlockedPro || currentCount < Self.freeItemLimit
    }
    
    // MARK: - Private Methods
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
    
    private func updateEntitlements() async {
        if ProcessInfo.processInfo.arguments.contains("-screenshot-pro") {
            self.hasUnlockedPro = true
            return
        }
        var isProActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.lifetimeProductID
                    && transaction.revocationDate == nil {
                    isProActive = true
                }
            }
        }
        self.hasUnlockedPro = isProActive
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updateEntitlements()
                    await transaction.finish()
                }
            }
        }
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .productNotFound: return "找不到產品資訊"
        }
    }
}
