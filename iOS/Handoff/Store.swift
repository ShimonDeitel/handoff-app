import Foundation
import StoreKit

/// StoreKit 2 — auto-renewable subscription (`com.shimondeitel.handoff.pro.monthly`), billed
/// once per family/circle rather than per sibling. Pro is never persisted as truth: it is
/// derived live from `Transaction.currentEntitlements`, granted only on a `.verified`
/// transaction with no revocation and no expiration in the past.
@MainActor
final class Store: ObservableObject {
    static let productID = "com.shimondeitel.handoff.pro.monthly"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var purchaseInFlight = false

    private var updatesTask: Task<Void, Never>?

    private var debugForcePro: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["HANDOFF_FORCE_PRO"] == "1"
        #else
        return false
        #endif
    }

    init() {
        updatesTask = listenForTransactions()
        Task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["HANDOFF_NO_SK"] != "1" { await loadProduct() }
            #else
            await loadProduct()
            #endif
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    var displayPrice: String { product?.displayPrice ?? "$7.99" }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Store.productID])
            self.product = products.first
        } catch {
            self.product = nil
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Store.productID else { continue }
            if transaction.revocationDate != nil { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            entitled = true
        }
        isPro = entitled || debugForcePro
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }
}
