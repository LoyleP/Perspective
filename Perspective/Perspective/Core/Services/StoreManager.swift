import StoreKit
import Foundation

@MainActor
@Observable
final class StoreManager {
    // MARK: - Product IDs
    private enum ProductID {
        static let monthlySubscription = "perspective.premium.monthly"
        static let annualSubscription = "perspective.premium.annual"
    }

    // MARK: - Published State
    private(set) var products: [Product] = []
    private(set) var purchasedSubscriptions: Set<String> = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    var isPremium: Bool {
        !purchasedSubscriptions.isEmpty
    }

    // MARK: - Transaction Updates
    nonisolated(unsafe) private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            let productIDs = [
                ProductID.monthlySubscription,
                ProductID.annualSubscription
            ]

            products = try await Product.products(for: productIDs)
            print("✅ Loaded \(products.count) products")
        } catch {
            print("❌ Failed to load products: \(error)")
            self.error = .from(error)
        }

        isLoading = false
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async throws {
        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                print("✅ Purchase successful: \(product.id)")

            case .userCancelled:
                print("ℹ️ User cancelled purchase")

            case .pending:
                print("⏳ Purchase pending approval")

            @unknown default:
                print("⚠️ Unknown purchase result")
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            self.error = .from(error)
            throw self.error ?? AppError.unknown(error)
        }

        isLoading = false
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        error = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("✅ Restore successful")
        } catch {
            print("❌ Restore failed: \(error)")
            self.error = .from(error)
        }

        isLoading = false
    }

    // MARK: - Update Subscription Status
    private func updateSubscriptionStatus() async {
        var activeSubscriptions: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)

                if transaction.productType == .autoRenewable {
                    activeSubscriptions.insert(transaction.productID)
                }
            } catch {
                print("❌ Failed to verify transaction: \(error)")
            }
        }

        purchasedSubscriptions = activeSubscriptions
        print("ℹ️ Active subscriptions: \(activeSubscriptions)")
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                    await self?.updateSubscriptionStatus()
                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Product Helpers
    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthlySubscription }
    }

    var annualProduct: Product? {
        products.first { $0.id == ProductID.annualSubscription }
    }
}

// MARK: - Store Error
enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "La vérification de l'achat a échoué."
        }
    }
}
