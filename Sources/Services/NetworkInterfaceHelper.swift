import Foundation
import Darwin

/// Determines whether a given host IP shares a subnet with one of this
/// Mac's own active network interfaces — used to flag an SFTP console as
/// being on the "same MA Net" (i.e. reachable via a direct LAN hop through
/// whatever interface is plugged into the Manet adapter) rather than
/// assuming a fixed MA-Net IP range, which varies by rig/model.
enum NetworkInterfaceHelper {
    static func isHostOnLocalSubnet(_ host: String) -> Bool {
        guard let hostAddr = ipv4Address(from: host) else { return false }

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return false }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp, !isLoopback,
               let addrPtr = interface.ifa_addr, addrPtr.pointee.sa_family == UInt8(AF_INET),
               let netmaskPtr = interface.ifa_netmask {
                let ifaceAddr = sockaddrToUInt32(addrPtr)
                let netmask = sockaddrToUInt32(netmaskPtr)
                if netmask != 0, (ifaceAddr & netmask) == (hostAddr & netmask) {
                    return true
                }
            }
            ptr = interface.ifa_next
        }
        return false
    }

    private static func sockaddrToUInt32(_ sa: UnsafeMutablePointer<sockaddr>) -> UInt32 {
        var addrIn = sockaddr_in()
        memcpy(&addrIn, sa, MemoryLayout<sockaddr_in>.size)
        return addrIn.sin_addr.s_addr
    }

    private static func ipv4Address(from string: String) -> UInt32? {
        guard !string.isEmpty else { return nil }
        var addr = in_addr()
        guard string.withCString({ inet_pton(AF_INET, $0, &addr) }) == 1 else { return nil }
        return addr.s_addr
    }
}
