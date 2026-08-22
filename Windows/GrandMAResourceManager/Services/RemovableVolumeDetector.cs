using System.IO;
using GrandMAResourceManager.Models;

namespace GrandMAResourceManager.Services;

/// <summary>A drive found to contain a recognized console's marker folder.</summary>
public sealed record DetectedUsbSource(string DriveRoot, string DataRootPath, ConsoleFamily Family);

public static class RemovableVolumeDetector
{
    public static DetectedUsbSource? DetectConsoleFolder(string driveRoot)
    {
        foreach (var family in Enum.GetValues<ConsoleFamily>())
        {
            var candidate = Path.Combine(driveRoot, family.UsbRootFolderName());
            if (Directory.Exists(candidate))
                return new DetectedUsbSource(driveRoot, candidate, family);
        }
        return null;
    }

    public static List<DetectedUsbSource> DetectMountedConsoleVolumes()
    {
        var results = new List<DetectedUsbSource>();
        foreach (var drive in DriveInfo.GetDrives())
        {
            if (!drive.IsReady) continue;
            var detected = DetectConsoleFolder(drive.RootDirectory.FullName);
            if (detected is not null) results.Add(detected);
        }
        return results;
    }
}
