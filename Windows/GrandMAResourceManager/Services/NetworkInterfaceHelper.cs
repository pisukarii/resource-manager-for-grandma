using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace GrandMAResourceManager.Services;

/// <summary>
/// Determines whether a given host IP shares a subnet with one of this PC's
/// own active network interfaces — used to flag an SFTP console as being on
/// the "same MA Net" (i.e. reachable via a direct LAN hop through whatever
/// adapter is plugged into the Manet port) rather than assuming a fixed
/// MA-Net IP range, which varies by rig/model. Mirrors the macOS app's
/// <c>NetworkInterfaceHelper</c>.
/// </summary>
public static class NetworkInterfaceHelper
{
    public static bool IsHostOnLocalSubnet(string host)
    {
        if (!IPAddress.TryParse(host, out var hostAddress) || hostAddress.AddressFamily != AddressFamily.InterNetwork)
            return false;
        var hostBits = ToUInt32(hostAddress);

        foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (nic.OperationalStatus != OperationalStatus.Up) continue;
            if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;

            foreach (var unicast in nic.GetIPProperties().UnicastAddresses)
            {
                if (unicast.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                if (unicast.IPv4Mask is null) continue;

                var ifaceBits = ToUInt32(unicast.Address);
                var maskBits = ToUInt32(unicast.IPv4Mask);
                if (maskBits != 0 && (ifaceBits & maskBits) == (hostBits & maskBits))
                    return true;
            }
        }
        return false;
    }

    private static uint ToUInt32(IPAddress address)
    {
        var bytes = address.GetAddressBytes();
        return ((uint)bytes[0] << 24) | ((uint)bytes[1] << 16) | ((uint)bytes[2] << 8) | bytes[3];
    }
}
