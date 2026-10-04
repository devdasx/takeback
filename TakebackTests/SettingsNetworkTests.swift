import XCTest
@testable import Takeback

final class SettingsNetworkTests: XCTestCase {
    func testBundledServersHaveMuunProvenanceUniqueHostsAndTLS() throws {
        let seed = ElectrumSeed.bundled
        XCTAssertEqual(seed.commit.count, 40)
        XCTAssertEqual(Set(ElectrumServer.defaults.map(\.host)).count, ElectrumServer.defaults.count)
        XCTAssertTrue(ElectrumServer.defaults.allSatisfy { !$0.useTCP && $0.port > 0 })
        XCTAssertTrue(ElectrumServer.defaults.contains { $0.host == "electrum.blockstream.info" })
        XCTAssertTrue(ElectrumServer.defaults.contains { $0.host == "fulcrum.sethforprivacy.com" })
    }
}
