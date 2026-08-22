using System.Management;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using GrandMAResourceManager.Models;

namespace GrandMAResourceManager.Services;

/// <summary>
/// Watches for drives containing a <c>grandMA3</c> or <c>gma2</c> folder and
/// surfaces the most recently connected one that isn't already a configured
/// Source, so the UI can offer a one-click "add as Source" banner. Uses WMI
/// (<c>Win32_VolumeChangeEvent</c>) since Windows has no direct equivalent
/// of macOS's NSWorkspace mount notifications.
/// </summary>
public sealed partial class RemovableVolumeWatcher : ObservableObject
{
    [ObservableProperty]
    private DetectedUsbSource? _pendingDetection;

    private readonly SourceStore _store;
    private readonly Dispatcher _dispatcher;
    private ManagementEventWatcher? _watcher;

    // EventType 2 = "Configuration changed" (covers new drive letter arrival).
    private const string Query =
        "SELECT * FROM Win32_VolumeChangeEvent WHERE EventType = 2 OR EventType = 3";

    public RemovableVolumeWatcher(SourceStore store)
    {
        _store = store;
        _dispatcher = Dispatcher.CurrentDispatcher;

        try
        {
            _watcher = new ManagementEventWatcher(new WqlEventQuery(Query));
            _watcher.EventArrived += OnEventArrived;
            _watcher.Start();
        }
        catch (ManagementException)
        {
            // WMI unavailable in this environment — the manual "USBメモリを
            // 手動で選択..." flow in AddSourceDialog still works.
        }

        foreach (var detected in RemovableVolumeDetector.DetectMountedConsoleVolumes())
        {
            Evaluate(detected);
        }
    }

    public void DismissPending() => PendingDetection = null;

    private void OnEventArrived(object sender, EventArrivedEventArgs e)
    {
        _dispatcher.Invoke(() =>
        {
            foreach (var detected in RemovableVolumeDetector.DetectMountedConsoleVolumes())
            {
                Evaluate(detected);
            }
        });
    }

    private void Evaluate(DetectedUsbSource detected)
    {
        var alreadyConfigured = _store.Configs.Any(c => c.Path == detected.DataRootPath);
        if (!alreadyConfigured) PendingDetection = detected;
    }
}
