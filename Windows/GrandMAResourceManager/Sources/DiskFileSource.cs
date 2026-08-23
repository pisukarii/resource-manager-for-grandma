using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using GrandMAResourceManager.Models;
using Microsoft.VisualBasic.FileIO;

namespace GrandMAResourceManager.Sources;

/// <summary>
/// Backs a source that lives entirely on local disk: an onPC install
/// (rooted at the console's ProgramData folder, with version-scoped and
/// shared-library categories resolved via <paramref name="prefixResolver"/>)
/// or a mounted USB drive (rooted at the drive's marker folder, uniform for
/// every category). Mirrors the macOS app's <c>DiskFileSource.swift</c> —
/// one class backs both, the only difference is how the prefix resolves.
/// </summary>
public sealed partial class DiskFileSource : ObservableObject, IFileSource
{
    public Guid Id { get; }
    public SourceConfig Config { get; }

    [ObservableProperty]
    private SourceConnectionState _connectionState = SourceConnectionState.Disconnected;

    private readonly string _rootPath;
    private readonly Func<ConsoleCategory, RelativePath> _prefixResolver;

    public DiskFileSource(SourceConfig config, string rootPath, Func<ConsoleCategory, RelativePath> prefixResolver)
    {
        Id = config.Id;
        Config = config;
        _rootPath = rootPath;
        _prefixResolver = prefixResolver;
    }

    public bool SupportsDestructiveOperations => true;

    public Task ConnectAsync()
    {
        var exists = Directory.Exists(_rootPath);
        ConnectionState = exists ? SourceConnectionState.Connected : SourceConnectionState.Error($"フォルダが見つかりません: {_rootPath}");
        if (!exists) throw new FileSourceException($"フォルダが見つかりません: {_rootPath}");
        return Task.CompletedTask;
    }

    public RelativePath RootPrefix(ConsoleCategory category) => _prefixResolver(category);

    public Task<List<FileEntry>> ListAsync(RelativePath path)
    {
        var targetPath = ResolvePath(path);
        return Task.Run(() =>
        {
            var dir = new DirectoryInfo(targetPath);
            if (!dir.Exists) return new List<FileEntry>();

            var entries = dir.EnumerateFileSystemInfos()
                .Where(info => (info.Attributes & FileAttributes.Hidden) == 0)
                .Select(info => new FileEntry(
                    info.Name,
                    info.Attributes.HasFlag(FileAttributes.Directory),
                    info is FileInfo fi ? fi.Length : null,
                    info.LastWriteTime,
                    path.Appending(info.Name)))
                .OrderBy(e => e.IsDirectory ? 0 : 1)
                .ThenBy(e => e.Name, StringComparer.CurrentCultureIgnoreCase)
                .ToList();

            return entries;
        });
    }

    public Task<bool> ExistsAsync(RelativePath path)
    {
        var fullPath = ResolvePath(path);
        return Task.FromResult(File.Exists(fullPath) || Directory.Exists(fullPath));
    }

    public Task CopyInAsync(string localPath, RelativePath destination)
    {
        var destDir = ResolvePath(destination);
        var destPath = System.IO.Path.Combine(destDir, System.IO.Path.GetFileName(localPath));
        return Task.Run(() =>
        {
            Directory.CreateDirectory(destDir);
            if (Directory.Exists(localPath))
                CopyDirectory(localPath, destPath);
            else
                File.Copy(localPath, destPath, overwrite: true);
        });
    }

    public Task CopyOutAsync(RelativePath source, string localPath)
    {
        var sourcePath = ResolvePath(source);
        return Task.Run(() =>
        {
            if (Directory.Exists(sourcePath))
                CopyDirectory(sourcePath, localPath);
            else
                File.Copy(sourcePath, localPath, overwrite: true);
        });
    }

    public void Reveal(RelativePath path)
    {
        var fullPath = ResolvePath(path);
        System.Diagnostics.Process.Start("explorer.exe", $"/select,\"{fullPath}\"");
    }

    public string? LocalFilePath(RelativePath path) => ResolvePath(path);

    public Task RenameAsync(RelativePath path, string newName)
    {
        var sourcePath = ResolvePath(path);
        var destPath = System.IO.Path.Combine(System.IO.Path.GetDirectoryName(sourcePath)!, newName);
        return Task.Run(() =>
        {
            if (Directory.Exists(sourcePath))
                Directory.Move(sourcePath, destPath);
            else
                File.Move(sourcePath, destPath);
        });
    }

    /// <summary>Sends to the Recycle Bin rather than permanently deleting,
    /// so a confirmed delete is still recoverable if it was a mistake.</summary>
    public Task DeleteAsync(RelativePath path)
    {
        var fullPath = ResolvePath(path);
        return Task.Run(() =>
        {
            if (Directory.Exists(fullPath))
            {
                FileSystem.DeleteDirectory(fullPath, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
            }
            else
            {
                FileSystem.DeleteFile(fullPath, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
            }
        });
    }

    private string ResolvePath(RelativePath path) =>
        path.Components.Aggregate(_rootPath, System.IO.Path.Combine);

    private static void CopyDirectory(string sourceDir, string destDir)
    {
        Directory.CreateDirectory(destDir);
        foreach (var file in Directory.GetFiles(sourceDir))
        {
            File.Copy(file, System.IO.Path.Combine(destDir, System.IO.Path.GetFileName(file)), overwrite: true);
        }
        foreach (var subDir in Directory.GetDirectories(sourceDir))
        {
            CopyDirectory(subDir, System.IO.Path.Combine(destDir, System.IO.Path.GetFileName(subDir)));
        }
    }
}
