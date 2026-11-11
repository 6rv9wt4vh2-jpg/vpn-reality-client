import Foundation
import VpnRealityCore

/// Local helper: print Xray JSON for a profile file.
/// Output contains the profile secrets. Use it only on a machine you control,
/// and do not paste the output into logs, commits, or tickets.

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let mode = arguments.first, mode == "proxy" || mode == "tunnel" else {
    fail("usage: vpnreality-config proxy|tunnel [--tun-fd N] <profile.json>")
}

var index = 1
var tunFD: Int32 = 0
if arguments.count > index, arguments[index] == "--tun-fd" {
    guard arguments.count > index + 1, let value = Int32(arguments[index + 1]), value > 2 else {
        fail("tun fd must be an integer greater than 2")
    }
    tunFD = value
    index += 2
}
guard arguments.count > index else {
    fail("usage: vpnreality-config proxy|tunnel [--tun-fd N] <profile.json>")
}
if mode == "tunnel", tunFD <= 2 {
    fail("tunnel mode requires --tun-fd N")
}

let url = URL(fileURLWithPath: arguments[index])
do {
    let text = try String(contentsOf: url, encoding: .utf8)
    let profile = try ProfileImporter.importAny(text)
    let json: String
    if mode == "proxy" {
        json = try XrayConfigBuilder.proxyJSON(profile)
    } else {
        json = try XrayConfigBuilder.tunnelJSON(profile: profile, tunFD: tunFD)
    }
    FileHandle.standardOutput.write(Data(json.utf8))
} catch {
    fail(error.localizedDescription)
}
