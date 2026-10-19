import XCTest
@testable import BedrockConnectCore

final class BedrockQueryTests: XCTestCase {
    func testCleanMinecraftText() {
        let raw = "§e✦ §aThe Hive Bedrock §7[geo.hivebedrock.network:19132]"
        let cleaned = BedrockQuery.cleanMinecraftText(raw)
        XCTAssertEqual(cleaned, "✦ The Hive Bedrock [geo.hivebedrock.network:19132]")
    }

    func testServerBindingAndLANQuery() {
        let testPort: UInt16 = 19135
        let server = BedrockTransferServer(
            bindIp: "0.0.0.0",
            bindPort: testPort,
            targetHost: "127.0.0.1",
            targetPort: testPort,
            serverName: "LAN Test DirectConnect"
        )

        server.start()
        defer { server.stop() }

        // Allow socket to bind
        Thread.sleep(forTimeInterval: 0.1)

        // 1. Verify network interfaces discovery
        let interfaces = BedrockTransferServer.getLocalIPv4Interfaces()
        XCTAssertFalse(interfaces.isEmpty, "Should discover at least one active non-loopback IPv4 interface")

        guard let lanIp = BedrockTransferServer.getPrimaryLocalIP() else {
            XCTFail("Should find a primary local IP")
            return
        }

        // 2. Query via loopback
        let loopbackRes = BedrockQuery.pingSync(host: "127.0.0.1", port: testPort, timeout: 1.0)
        XCTAssertTrue(loopbackRes.online, "Should be reachable via 127.0.0.1")
        XCTAssertTrue(loopbackRes.serverName.contains("LAN Test DirectConnect"))

        // 3. Query via LAN IP (e.g. 192.168.x.x - proving external 0.0.0.0 binding)
        let lanRes = BedrockQuery.pingSync(host: lanIp, port: testPort, timeout: 1.0)
        XCTAssertTrue(lanRes.online, "Should be reachable via LAN IP \(lanIp) on port \(testPort)")
        XCTAssertTrue(lanRes.serverName.contains("LAN Test DirectConnect"))
    }
}
