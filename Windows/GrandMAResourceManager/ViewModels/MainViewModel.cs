using System.Collections.ObjectModel;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using GrandMAResourceManager.Models;
using GrandMAResourceManager.Services;
using GrandMAResourceManager.Sources;

namespace GrandMAResourceManager.ViewModels;

public partial class MainViewModel : ObservableObject
{
    public SourceStore Store { get; } = new();
    public RemovableVolumeWatcher UsbWatcher { get; }

    [ObservableProperty]
    private SourceConfig? _selectedSourceConfig;

    [ObservableProperty]
    private ConsoleCategory? _selectedCategory;

    [ObservableProperty]
    private RelativePath _currentPath = RelativePath.Root;

    [ObservableProperty]
    private string? _connectionError;

    [ObservableProperty]
    private string? _importError;

    [ObservableProperty]
    private bool _showAddSourceDialog;

    [ObservableProperty]
    private bool _isSelectionMode;

    [ObservableProperty]
    private string _searchText = "";

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private bool _isTransferring;

    [ObservableProperty]
    private string _transferLabel = "";

    public ObservableCollection<FileEntry> Entries { get; } = new();
    public ObservableCollection<FileEntry> FilteredEntries { get; } = new();
    public ObservableCollection<FileEntry> SelectedEntries { get; } = new();

    [ObservableProperty]
    private string? _selectedManufacturer;

    /// <summary>
    /// Many fixture library entries are named "&lt;Manufacturer&gt;@&lt;Model&gt;@&lt;date/release&gt;"
    /// (e.g. "Elation@Fuze_Wash_Z120@2023-15-05_First_Release"). When a
    /// folder's contents follow that convention, offer a manufacturer
    /// picker instead of making the user scroll/search through hundreds of
    /// entries — extracted straight from the "@"-delimited names, not tied
    /// to any specific category.
    /// </summary>
    public ObservableCollection<string> AvailableManufacturers { get; } = new();

    /// <summary>
    /// Some folders (e.g. MA3's "Resource") are just a flat wall of dozens
    /// of subfolders (lib_gels, lib_macros, lib_mvr, ...). Offer a "jump
    /// to..." menu once there are enough of them that scrolling/typing to
    /// find one stops being the fastest option — generic, not tied to any
    /// specific category.
    /// </summary>
    public ObservableCollection<FileEntry> JumpableSubfolders { get; } = new();

    public IFileSource? SelectedSource =>
        SelectedSourceConfig is null ? null : Store.SourceFor(SelectedSourceConfig.Id);

    public IReadOnlyList<ConsoleCategory> CurrentCategories =>
        SelectedSourceConfig?.VisibleCategories ?? Array.Empty<ConsoleCategory>();

    public string BreadcrumbText
    {
        get
        {
            if (SelectedSource is null || SelectedCategory is null) return "";
            var basePath = SelectedSource.CategoryPath(SelectedCategory);
            var suffix = CurrentPath.Components.Skip(basePath.Components.Count);
            var parts = new[] { SelectedCategory.DisplayName }.Concat(suffix);
            return string.Join(" / ", parts);
        }
    }

    public MainViewModel()
    {
        Store.Configs.CollectionChanged += (_, _) => OnPropertyChanged(nameof(HasNoSources));
        UsbWatcher = new RemovableVolumeWatcher(Store);
    }

    public void AddDetectedUsbSource(DetectedUsbSource detected)
    {
        var config = new SourceConfig
        {
            Name = new DirectoryInfo(detected.DriveRoot).Name is { Length: > 0 } name ? name : detected.DriveRoot,
            Kind = SourceKind.Usb,
            Path = detected.DataRootPath,
            Family = detected.Family
        };
        AddSource(config);
        UsbWatcher.DismissPending();
    }

    public bool HasNoSources => Store.Configs.Count == 0;

    partial void OnSelectedSourceConfigChanged(SourceConfig? value)
    {
        OnPropertyChanged(nameof(SelectedSource));
        OnPropertyChanged(nameof(CurrentCategories));
        SelectedCategory = null;
        SelectedEntries.Clear();
        IsSelectionMode = false;
        Entries.Clear();
        FilteredEntries.Clear();
        _ = ConnectAndNotifyAsync();
    }

    partial void OnSelectedCategoryChanged(ConsoleCategory? value)
    {
        OnPropertyChanged(nameof(BreadcrumbText));
        if (value is not null && SelectedSource is not null)
        {
            CurrentPath = SelectedSource.CategoryPath(value);
        }
    }

    partial void OnCurrentPathChanged(RelativePath value)
    {
        OnPropertyChanged(nameof(BreadcrumbText));
        SelectedEntries.Clear();
        IsSelectionMode = false;
        _ = ReloadAsync();
    }

    partial void OnSearchTextChanged(string value) => ApplyFilter();
    partial void OnSelectedManufacturerChanged(string? value) => ApplyFilter();

    private async Task ConnectAndNotifyAsync()
    {
        var source = SelectedSource;
        if (source is null) return;
        try
        {
            await source.ConnectAsync();
        }
        catch (Exception ex)
        {
            ConnectionError = ex.Message;
        }
    }

    private async Task ReloadAsync()
    {
        var source = SelectedSource;
        if (source is null) return;
        IsLoading = true;
        try
        {
            var results = await source.ListAsync(CurrentPath);
            Entries.Clear();
            foreach (var entry in results) Entries.Add(entry);
            RecomputeAvailableManufacturers();
            RecomputeJumpableSubfolders();
            ApplyFilter();
        }
        catch (Exception)
        {
            Entries.Clear();
            RecomputeAvailableManufacturers();
            RecomputeJumpableSubfolders();
            ApplyFilter();
        }
        finally
        {
            IsLoading = false;
        }
    }

    public const string AllManufacturersSentinel = "(すべてのメーカー)";

    private void RecomputeAvailableManufacturers()
    {
        SelectedManufacturer = null;
        AvailableManufacturers.Clear();
        var names = Entries
            .Select(e => e.Name.Contains('@') ? e.Name[..e.Name.IndexOf('@')] : null)
            .Where(n => n is not null)
            .Cast<string>()
            .ToList();
        if (names.Count < Entries.Count / 2 || names.Count == 0) return;
        AvailableManufacturers.Add(AllManufacturersSentinel);
        foreach (var name in names.Distinct().OrderBy(n => n, StringComparer.CurrentCultureIgnoreCase))
        {
            AvailableManufacturers.Add(name);
        }
        SelectedManufacturer = AllManufacturersSentinel;
    }

    private void RecomputeJumpableSubfolders()
    {
        JumpableSubfolders.Clear();
        var directories = Entries.Where(e => e.IsDirectory).ToList();
        if (directories.Count <= 8) return;
        foreach (var entry in directories.OrderBy(e => e.Name, StringComparer.CurrentCultureIgnoreCase))
        {
            JumpableSubfolders.Add(entry);
        }
    }

    public void JumpToSubfolder(FileEntry entry) => CurrentPath = entry.Path;

    private void ApplyFilter()
    {
        FilteredEntries.Clear();
        IEnumerable<FileEntry> source = Entries;
        if (SelectedManufacturer is not null && SelectedManufacturer != AllManufacturersSentinel)
        {
            source = source.Where(e => e.Name.StartsWith($"{SelectedManufacturer}@", StringComparison.CurrentCultureIgnoreCase));
        }
        var query = SearchText;
        if (!string.IsNullOrEmpty(query))
        {
            source = source.Where(e => e.Name.Contains(query, StringComparison.CurrentCultureIgnoreCase));
        }
        foreach (var entry in source) FilteredEntries.Add(entry);
    }

    [RelayCommand]
    private void GoToCategoryRoot()
    {
        if (SelectedCategory is not null && SelectedSource is not null)
            CurrentPath = SelectedSource.CategoryPath(SelectedCategory);
    }

    [RelayCommand]
    private void Refresh() => _ = ReloadAsync();

    [RelayCommand]
    private void OpenEntry(FileEntry entry)
    {
        if (entry.IsDirectory)
        {
            CurrentPath = entry.Path;
        }
        else
        {
            try { SelectedSource?.Reveal(entry.Path); } catch { /* best-effort */ }
        }
    }

    [RelayCommand]
    private void ToggleSelectionMode()
    {
        IsSelectionMode = !IsSelectionMode;
        if (!IsSelectionMode) SelectedEntries.Clear();
    }

    public async Task ImportFilesAsync(IEnumerable<string> localPaths, RelativePath? destination = null)
    {
        var source = SelectedSource;
        if (source is null) return;
        var dest = destination ?? CurrentPath;
        IsTransferring = true;
        try
        {
            foreach (var path in localPaths)
            {
                TransferLabel = $"{System.IO.Path.GetFileName(path)} を {source.Config.Name} へコピー中...";
                try
                {
                    await source.CopyInAsync(path, dest);
                }
                catch (Exception ex)
                {
                    ImportError = ex.Message;
                }
            }
        }
        finally
        {
            IsTransferring = false;
        }
        await ReloadAsync();
    }

    public async Task ImportToOtherSourceAsync(SourceConfig targetConfig, IEnumerable<string> localPaths)
    {
        if (SelectedCategory is null) return;
        var target = Store.SourceFor(targetConfig.Id);
        if (target is null) return;
        var dest = target.CategoryPath(SelectedCategory);
        IsTransferring = true;
        try
        {
            foreach (var path in localPaths)
            {
                TransferLabel = $"{System.IO.Path.GetFileName(path)} を {target.Config.Name} へコピー中...";
                try { await target.CopyInAsync(path, dest); }
                catch (Exception ex) { ImportError = ex.Message; }
            }
        }
        finally
        {
            IsTransferring = false;
        }
    }

    public async Task RenameAsync(FileEntry entry, string newBaseName)
    {
        var source = SelectedSource;
        if (source is null) return;
        var ext = entry.IsDirectory ? "" : Path.GetExtension(entry.Name);
        var newName = newBaseName + ext;
        if (newName == entry.Name) return;
        await source.RenameAsync(entry.Path, newName);
        await ReloadAsync();
    }

    public async Task DeleteAsync(IEnumerable<FileEntry> targets)
    {
        var source = SelectedSource;
        if (source is null) return;
        foreach (var entry in targets)
        {
            await source.DeleteAsync(entry.Path);
        }
        SelectedEntries.Clear();
        await ReloadAsync();
    }

    public void AddSource(SourceConfig config)
    {
        Store.AddSource(config);
        OnPropertyChanged(nameof(HasNoSources));
        SelectedSourceConfig ??= config;
    }

    public void RemoveSource(SourceConfig config)
    {
        Store.RemoveSource(config.Id);
        OnPropertyChanged(nameof(HasNoSources));
        if (SelectedSourceConfig?.Id == config.Id) SelectedSourceConfig = Store.Configs.FirstOrDefault();
    }
}
