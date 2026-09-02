import StoreKit
@testable import FreeDay
import Testing

struct StoreKitProductLoadTests {
    @Test("Product.products does not throw for the FreeDay IDs")
    func productLoadDoesNotThrow() async throws {
        let products = try await Product.products(for: SubscriptionProductID.allIDs)
        let loaded = Set(products.map(\.id))
        #expect(loaded.isSubset(of: Set(SubscriptionProductID.allIDs)))
    }
}
