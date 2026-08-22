using System.Collections.ObjectModel;
using System.IO;
using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using GrandMAResourceManager.Sources;

namespace GrandMAResourceManager.Models;

public sealed partial class SourceStore : ObservableObject
{
    public ObservableCollection<SourceConfig> Configs { get; } = new();

    private readonly Dictionary<Guid, IFileSource> _liveSources = new();
    private readonly string _storagePath;

    public SourceStore()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var dir = System.IO.Path.Combine(appData, "GrandMAResourceManager");
        Directory.CreateDirectory(dir);
        _storagePath = System.IO.Path.Combine(dir, "sources.json");
        Load();
    }

    public IEnumerable<IFileSource> Sources =>
        Configs.Select(c => _liveSources.TryGetValue(c.Id, out var s) ? s : null).Where(s => s is not null)!;

    public IFileSource? SourceFor(Guid id) => _liveSources.TryGetValue(id, out var s) ? s : null;

    public void AddSource(SourceConfig config)
    {
        Configs.Add(config);
        Instantiate(config);
        Save();
    }

    public void RenameSource(Guid id, string newName)
    {
        if (string.IsNullOrWhiteSpace(newName)) return;
        var config = Configs.FirstOrDefault(c => c.Id == id);
        if (config is null) return;
        config.Name = newName; // SourceConfig is a shared reference (both Configs and the live IFileSource.Config), and an ObservableObject, so this alone updates the UI.
        Save();
    }

    public void RemoveSource(Guid id)
    {
        var config = Configs.FirstOrDefault(c => c.Id == id);
        if (config is not null) Configs.Remove(config);
        _liveSources.Remove(id);
        Save();
    }

    private void Instantiate(SourceConfig config)
    {
        if (config.Path is null) return;

        switch (config.Kind)
        {
            case SourceKind.Local:
                // gma3: root = MALightingTechnology (parent of the version
                // folder), shows/backups get the version-folder prefix.
                // gma2: root = the version folder itself, and EVERY
                // category is version-scoped (no shared library concept).
                if (config.ResolvedFamily == ConsoleFamily.Ma3)
                {
                    var versionDir = new DirectoryInfo(config.Path);
                    var malightingRoot = versionDir.Parent!.FullName;
                    var versionName = versionDir.Name;
                    _liveSources[config.Id] = new DiskFileSource(config, malightingRoot,
                        category => category.RootKind == ConsoleCategoryRootKind.VersionScoped
                            ? new RelativePath(versionName)
                            : RelativePath.Root);
                }
                else
                {
                    _liveSources[config.Id] = new DiskFileSource(config, config.Path,
                        _ => RelativePath.Root);
                }
                break;

            case SourceKind.Usb:
                // config.Path already points at <drive>\grandMA3 or
                // <drive>\gma2; every category sits directly under it.
                _liveSources[config.Id] = new DiskFileSource(config, config.Path, _ => RelativePath.Root);
                break;
        }
    }

    private void Load()
    {
        if (!File.Exists(_storagePath)) return;
        try
        {
            var json = File.ReadAllText(_storagePath);
            var configs = JsonSerializer.Deserialize<List<SourceConfig>>(json);
            if (configs is null) return;
            foreach (var config in configs)
            {
                Configs.Add(config);
                Instantiate(config);
            }
        }
        catch (JsonException)
        {
            // Corrupt/legacy sources.json — start fresh rather than crash.
        }
    }

    private void Save()
    {
        var json = JsonSerializer.Serialize(Configs.ToList(), new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_storagePath, json);
    }
}
