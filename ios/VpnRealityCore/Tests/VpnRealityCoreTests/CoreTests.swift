import XCTest
@testable import VpnRealityCore

final class CoreTests: XCTestCase {
    private let exampleURI = "vless://00000000-0000-4000-8000-000000000000@YOUR_SERVER_IP_OR_DOMAIN:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA&sid=abcd1234&spx=%2F#example-reality"

    func testImportsRepositoryExampleURI() throws {
        let profile = try ProfileImporter.parseVlessURI(exampleURI)
        XCTAssertEqual(profile.name, "example-reality")
        XCTAssertEqual(profile.address, "YOUR_SERVER_IP_OR_DOMAIN")
        XCTAssertEqual(profile.port, 443)
        XCTAssertEqual(profile.uuid, ProfileValidator.sampleUUID)
        XCTAssertEqual(profile.flow, "xtls-rprx-vision")
        XCTAssertEqual(profile.reality.publicKey, ProfileValidator.samplePublicKey)
        XCTAssertEqual(profile.reality.shortId, "abcd1234")
        XCTAssertEqual(profile.reality.serverNames, ["www.cloudflare.com"])
        XCTAssertEqual(profile.reality.fingerprint, "chrome")
        XCTAssertEqual(profile.reality.spiderX, "/")
        XCTAssertFalse(ProfileValidator.placeholderIssues(profile).isEmpty)
        XCTAssertTrue(ProfileValidator.structuralIssues(profile).isEmpty)
    }

    func testImportsDesktopJSONShape() throws {
        let json = """
        {
          "name": "example-reality",
          "address": "203.0.113.10",
          "port": 443,
          "uuid": "11111111-1111-4111-8111-111111111111",
          "flow": "xtls-rprx-vision",
          "encryption": "none",
          "network": "tcp",
          "security": "reality",
          "socks_port": 10808,
          "http_port": 10809,
          "notes": "",
          "reality": {
            "public_key": "sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA",
            "short_id": "abcd1234",
            "server_names": ["www.cloudflare.com", "www.microsoft.com"],
            "fingerprint": "chrome",
            "spider_x": "/",
            "dest": "www.cloudflare.com:443"
          }
        }
        """
        let profile = try ProfileImporter.importAny(json)
        XCTAssertEqual(profile.address, "203.0.113.10")
        XCTAssertEqual(profile.reality.serverNames, ["www.cloudflare.com", "www.microsoft.com"])
        XCTAssertEqual(profile.reality.dest, "www.cloudflare.com:443")
        XCTAssertEqual(profile.socksPort, 10808)
        XCTAssertEqual(profile.httpPort, 10809)
        XCTAssertTrue(ProfileValidator.structuralIssues(profile).isEmpty)
        XCTAssertEqual(
            ProfileValidator.connectIssues(profile).map(\.code),
            ["placeholder_key"]
        )
    }

    func testImportsXrayOutbound() throws {
        let json = """
        {
          "tag": "proxy",
          "protocol": "vless",
          "settings": {
            "vnext": [{
              "address": "203.0.113.10",
              "port": 8443,
              "users": [{
                "id": "11111111-1111-4111-8111-111111111111",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }]
            }]
          },
          "streamSettings": {
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
              "fingerprint": "chrome",
              "serverName": "www.cloudflare.com",
              "publicKey": "sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA",
              "shortId": "",
              "spiderX": "/"
            }
          }
        }
        """
        let profile = try ProfileImporter.importAny(json)
        XCTAssertEqual(profile.port, 8443)
        XCTAssertEqual(profile.reality.shortId, "")
        XCTAssertNil(profile.httpPort)
    }

    func testRejectsNonRealityAndNonTCP() {
        XCTAssertThrowsError(try ProfileImporter.parseVlessURI(
            "vless://11111111-1111-4111-8111-111111111111@203.0.113.10:443?security=tls&pbk=sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA"
        )) { error in
            XCTAssertEqual(error as? ProfileImportError, .unsupportedSecurity("tls"))
        }
        XCTAssertThrowsError(try ProfileImporter.parseVlessURI(
            "vless://11111111-1111-4111-8111-111111111111@203.0.113.10:443?security=reality&type=ws&pbk=sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA"
        )) { error in
            XCTAssertEqual(error as? ProfileImportError, .unsupportedTransport("ws"))
        }
        XCTAssertThrowsError(try ProfileImporter.parseVlessURI("vless://user@host:443"))
    }

    func testIPv6Host() throws {
        let profile = try ProfileImporter.parseVlessURI(
            "vless://11111111-1111-4111-8111-111111111111@[2001:db8::10]:443?security=reality&pbk=sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA&sid=ab&sni=www.cloudflare.com#v6"
        )
        XCTAssertEqual(profile.address, "2001:db8::10")
        XCTAssertEqual(EndpointAddress.kind(profile.address), .ipv6)
        XCTAssertEqual(profile.reality.shortId, "ab")
    }

    func testProxyConfigMatchesDesktopContract() throws {
        let profile = liveProfile()
        let object = try jsonObject(XrayConfigBuilder.proxyJSON(profile))
        let inbounds = object["inbounds"] as? [[String: Any]]
        XCTAssertEqual(inbounds?.count, 2)
        XCTAssertEqual(inbounds?.first?["protocol"] as? String, "socks")
        XCTAssertEqual(inbounds?.first?["port"] as? Int, 10808)
        XCTAssertEqual(inbounds?.first?["listen"] as? String, "127.0.0.1")
        XCTAssertEqual(inbounds?.last?["protocol"] as? String, "http")
        XCTAssertEqual(inbounds?.last?["port"] as? Int, 10809)
        XCTAssertNil(object["env"])
        assertRealityOutbound(object, profile: profile)
        let routing = object["routing"] as? [String: Any]
        let rules = routing?["rules"] as? [[String: Any]]
        XCTAssertEqual(rules?.first?["ip"] as? [String], ["geoip:private"])
        XCTAssertEqual(routing?["domainStrategy"] as? String, "AsIs")
        let log = object["log"] as? [String: Any]
        XCTAssertEqual(log?["loglevel"] as? String, "warning")
        XCTAssertNil(log?["access"])
        XCTAssertNil(log?["error"])
    }

    func testTunnelConfigUsesTunFDAndLiteralRoutes() throws {
        let profile = liveProfile()
        let text = try XrayConfigBuilder.tunnelJSON(profile: profile, tunFD: 17)
        XCTAssertFalse(text.contains("geoip:"))
        let object = try jsonObject(text)
        let env = object["env"] as? [String: String]
        XCTAssertEqual(env?["xray.tun.fd"], "17")
        let inbound = (object["inbounds"] as? [[String: Any]])?.first
        XCTAssertEqual(inbound?["protocol"] as? String, "tun")
        XCTAssertEqual(inbound?["port"] as? Int, 0)
        XCTAssertEqual(inbound?["tag"] as? String, "tun-in")
        let settings = inbound?["settings"] as? [String: Any]
        XCTAssertEqual(settings?["mtu"] as? Int, 1280)
        XCTAssertNil(settings?["autoSystemRoutingTable"])
        let rules = ((object["routing"] as? [String: Any])?["rules"] as? [[String: Any]])?.first
        XCTAssertEqual(rules?["ip"] as? [String], XrayConfigBuilder.directCIDRs)
        assertRealityOutbound(object, profile: profile)
    }

    func testInvokeEnvelopeAndParser() throws {
        let request = try LibXrayInvoke.runRequest(xrayJSON: "{\"outbounds\":[]}")
        let object = try jsonObject(request)
        XCTAssertEqual(object["apiVersion"] as? Int, 3)
        XCTAssertEqual(object["method"] as? String, "runXray")
        let payload = object["payload"] as? [String: Any]
        XCTAssertEqual(payload?["xrayJson"] as? String, "{\"outbounds\":[]}")

        let ok = try LibXrayInvoke.parse(#"{"success":true,"data":{"version":"26.11.9","running":true},"error":""}"#)
        XCTAssertTrue(ok.success)
        XCTAssertEqual(ok.version, "26.11.9")
        XCTAssertEqual(ok.running, true)

        let failed = try LibXrayInvoke.parse(#"{"success":false,"data":null,"error":"invalid password"}"#)
        XCTAssertFalse(failed.success)
        XCTAssertEqual(failed.error, "invalid password")
        XCTAssertEqual(try LibXrayInvoke.stopRequest().contains("\"method\":\"stopXray\""), true)
    }

    func testRedactionRemovesSecrets() {
        let profile = liveProfile()
        let leaked = "failed publicKey \(profile.reality.publicKey) uuid \(profile.uuid) at \(profile.address)"
        let redacted = SecretRedaction.redact(leaked, secrets: SecretRedaction.secrets(in: profile))
        XCTAssertFalse(redacted.contains(profile.reality.publicKey))
        XCTAssertFalse(redacted.contains(profile.uuid))
        XCTAssertFalse(redacted.contains(profile.address))
        XCTAssertEqual(SecretRedaction.preview(profile.reality.publicKey).contains(profile.reality.publicKey), false)
    }

    func testDescriptorChoicePrefersPacketFlowAndRefusesAmbiguousScan() {
        XCTAssertEqual(
            TunDescriptorChoice.choose(previous: [3], current: [3, 8, 9], packetFlowFD: 11),
            11
        )
        XCTAssertEqual(
            TunDescriptorChoice.choose(previous: [3], current: [3, 8], packetFlowFD: nil),
            8
        )
        XCTAssertNil(TunDescriptorChoice.choose(previous: [3], current: [3, 8, 9], packetFlowFD: nil))
        XCTAssertNil(TunDescriptorChoice.choose(previous: [], current: [0, 1, 2], packetFlowFD: 0))
        XCTAssertTrue(UtunInterfaceName.isUtun("utun3"))
        XCTAssertFalse(UtunInterfaceName.isUtun("en0"))
        XCTAssertFalse(UtunInterfaceName.isUtun("utun"))
    }

    func testAddressKinds() {
        XCTAssertEqual(EndpointAddress.kind("203.0.113.10"), .ipv4)
        XCTAssertEqual(EndpointAddress.kind("2001:db8::10"), .ipv6)
        XCTAssertEqual(EndpointAddress.kind("vpn.example.com"), .hostname)
        XCTAssertEqual(EndpointAddress.kind("01.2.3.4"), .hostname)
    }

    func testValidatorRejectsBadShortIDAndKey() {
        var profile = liveProfile()
        profile.reality.shortId = "abc"
        profile.reality.publicKey = "not-a-key"
        let codes = ProfileValidator.structuralIssues(profile).map(\.code)
        XCTAssertTrue(codes.contains("short_id"))
        XCTAssertTrue(codes.contains("public_key"))
    }

    private func liveProfile() -> VlessProfile {
        VlessProfile(
            name: "lab",
            address: "203.0.113.10",
            port: 443,
            uuid: "11111111-1111-4111-8111-111111111111",
            reality: RealitySettings(
                publicKey: ProfileValidator.samplePublicKey,
                shortId: "abcd1234",
                serverNames: ["www.cloudflare.com", "www.microsoft.com"],
                fingerprint: "chrome",
                spiderX: "/",
                dest: "www.cloudflare.com:443"
            )
        )
    }

    private func jsonObject(_ text: String) throws -> [String: Any] {
        let data = Data(text.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    private func assertRealityOutbound(_ object: [String: Any], profile: VlessProfile) {
        let outbound = (object["outbounds"] as? [[String: Any]])?.first
        XCTAssertEqual(outbound?["protocol"] as? String, "vless")
        let settings = outbound?["settings"] as? [String: Any]
        let vnext = (settings?["vnext"] as? [[String: Any]])?.first
        XCTAssertEqual(vnext?["address"] as? String, profile.address)
        XCTAssertEqual(vnext?["port"] as? Int, profile.port)
        let user = (vnext?["users"] as? [[String: Any]])?.first
        XCTAssertEqual(user?["id"] as? String, profile.uuid)
        XCTAssertEqual(user?["encryption"] as? String, "none")
        XCTAssertEqual(user?["flow"] as? String, "xtls-rprx-vision")
        let stream = outbound?["streamSettings"] as? [String: Any]
        XCTAssertEqual(stream?["network"] as? String, "tcp")
        XCTAssertEqual(stream?["security"] as? String, "reality")
        let reality = stream?["realitySettings"] as? [String: Any]
        XCTAssertEqual(reality?["show"] as? Bool, false)
        XCTAssertEqual(reality?["serverName"] as? String, "www.cloudflare.com")
        XCTAssertEqual(reality?["publicKey"] as? String, profile.reality.publicKey)
        XCTAssertEqual(reality?["shortId"] as? String, profile.reality.shortId)
        XCTAssertEqual(reality?["fingerprint"] as? String, "chrome")
        XCTAssertEqual(reality?["spiderX"] as? String, "/")
    }
}
