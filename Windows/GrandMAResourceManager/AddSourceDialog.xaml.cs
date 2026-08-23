using System.IO;
using System.Windows;
using System.Windows.Controls;
using GrandMAResourceManager.Models;
using GrandMAResourceManager.Services;
using Microsoft.Win32;

namespace GrandMAResourceManager;

public partial class AddSourceDialog : Window
{
    public SourceConfig? CreatedConfig { get; private set; }

    private readonly SourceStore _store;

    private sealed record LocalItem(string Name, string FullPath, ConsoleFamily Family)
    {
        public string FamilyDisplay => Family.DisplayName();
        public bool IsLibrary => Name == "gma3_library";
        public string DisplayName => IsLibrary ? "共有ライブラリ (gma3_library)" : Name;
        public string Glyph => IsLibrary ? Glyphs.Component : Glyphs.Laptop;
    }

    private sealed record UsbItem(string DriveRoot, string DataRootPath, ConsoleFamily Family)
    {
        public string FamilyDisplay => Family.DisplayName();
    }

    public AddSourceDialog(SourceStore store)
    {
        InitializeComponent();
        _store = store;

        var localFolders = LocalInstallDetector.DetectVersionFolders()
            .Select(f => new LocalItem(f.Name, f.FullPath, f.Family))
            .ToList();
        LocalListBox.ItemsSource = localFolders;
        LocalEmptyText.Visibility = localFolders.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

        var usbVolumes = RemovableVolumeDetector.DetectMountedConsoleVolumes()
            .Select(v => new UsbItem(v.DriveRoot, v.DataRootPath, v.Family))
            .ToList();
        UsbListBox.ItemsSource = usbVolumes;
        UsbEmptyText.Visibility = usbVolumes.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

        // Set after InitializeComponent (not as an XAML IsChecked="True" literal) so the
        // Checked handler below can safely reach LocalPanel/UsbPanel, which are declared
        // later in the visual tree and wouldn't exist yet if this fired during XAML parsing.
        LocalKindToggle.IsChecked = true;
    }

    private void OnKindToggleChanged(object sender, RoutedEventArgs e)
    {
        LocalPanel.Visibility = LocalKindToggle.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        UsbPanel.Visibility = UsbKindToggle.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        SftpPanel.Visibility = SftpKindToggle.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnOpenSftpDialogClick(object sender, RoutedEventArgs e)
    {
        var dialog = new SftpConnectionDialog(existingConfig: null) { Owner = this };
        if (dialog.ShowDialog() == true && dialog.ResultConfig is { } config)
        {
            CreatedConfig = config;
            DialogResult = true;
            Close();
        }
    }

    private void OnLocalAddClick(object sender, RoutedEventArgs e)
    {
        var item = (LocalItem)((Button)sender).Tag;
        AddLocal(item.IsLibrary ? "共有ライブラリ" : $"onPC {item.Name}", item.FullPath, SourceKind.Local, item.Family);
    }

    private void OnLocalItemDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (LocalListBox.SelectedItem is LocalItem item)
            AddLocal(item.IsLibrary ? "共有ライブラリ" : $"onPC {item.Name}", item.FullPath, SourceKind.Local, item.Family);
    }

    private void OnUsbAddClick(object sender, RoutedEventArgs e)
    {
        var item = (UsbItem)((Button)sender).Tag;
        AddLocal(item.DriveRoot, item.DataRootPath, SourceKind.Usb, item.Family);
    }

    private void OnUsbItemDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (UsbListBox.SelectedItem is UsbItem item)
            AddLocal(item.DriveRoot, item.DataRootPath, SourceKind.Usb, item.Family);
    }

    private void OnPickLocalFolderClick(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFolderDialog
        {
            Title = "onPC バージョンフォルダを選択",
            InitialDirectory = Directory.Exists(LocalInstallDetector.Ma3Root) ? LocalInstallDetector.Ma3Root : null
        };
        if (dialog.ShowDialog(this) == true)
        {
            var family = LocalMa2Radio.IsChecked == true ? ConsoleFamily.Ma2 : ConsoleFamily.Ma3;
            AddLocal(System.IO.Path.GetFileName(dialog.FolderName), dialog.FolderName, SourceKind.Local, family);
        }
    }

    private void OnPickUsbFolderClick(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFolderDialog { Title = "USBメモリ上のデータフォルダを選択" };
        if (dialog.ShowDialog(this) == true)
        {
            var detected = RemovableVolumeDetector.DetectConsoleFolder(dialog.FolderName);
            if (detected is not null)
            {
                AddLocal(System.IO.Path.GetFileName(detected.DriveRoot.TrimEnd(System.IO.Path.DirectorySeparatorChar)),
                    detected.DataRootPath, SourceKind.Usb, detected.Family);
            }
            else
            {
                var family = UsbMa2Radio.IsChecked == true ? ConsoleFamily.Ma2 : ConsoleFamily.Ma3;
                AddLocal(System.IO.Path.GetFileName(dialog.FolderName.TrimEnd(System.IO.Path.DirectorySeparatorChar)),
                    dialog.FolderName, SourceKind.Usb, family);
            }
        }
    }

    private void AddLocal(string name, string path, SourceKind kind, ConsoleFamily family)
    {
        CreatedConfig = new SourceConfig { Name = name, Kind = kind, Path = path, Family = family };
        DialogResult = true;
        Close();
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
