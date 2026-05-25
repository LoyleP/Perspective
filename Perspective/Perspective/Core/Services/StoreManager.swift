import StoreKit
import Foundation
import OSLog

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
            Log.store.info("Loaded \(self.products.count) products")
        } catch {
            Log.store.error("Failed to load products: \(error)")
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
                Log.store.info("Purchase successful: \(product.id)")

            case .userCancelled:
                Log.store.info("User cancelled purchase")

            case .pending:
                Log.store.info("Purchase pending approval")

            @unknown default:
                Log.store.warning("Unknown purchase result")
            }
        } catch {
            Log.store.error("Purchase failed: \(error)")
            self.error = .from(error)
            throw self.error ?? AppError.from(error)
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
            Log.store.info("Restore successful")
        } catch {
            Log.store.error("Restore failed: \(error)")
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
                Log.store.error("Failed to verify transaction: \(error)")
            }
        }

        purchasedSubscriptions = activeSubscriptions
        Log.store.debug("Active subscriptions: \(activeSubscriptions)")
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
                    Log.store.error("Transaction update failed: \(error)")
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
