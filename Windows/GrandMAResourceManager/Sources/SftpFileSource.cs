using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using GrandMAResourceManager.Models;
using GrandMAResourceManager.Services;
using Renci.SshNet;
using Renci.SshNet.Sftp;

namespace GrandMAResourceManager.Sources;

/// <summary>
/// Backs a source that connects to a real grandMA3 console (or another
/// machine's onPC install reached over plain SSH) via SFTP. Mirrors the
/// macOS app's <c>ConsoleSFTPSource.swift</c>.
///
/// Deliberately implements copy-in / copy-out / list / reveal(unsupported)
/// only — no delete or rename — since careless file operations on a
/// console's filesystem can leave it needing a reinstall.
/// </summary>
public sealed partial class SftpFileSource : ObservableObject, IFileSource
{
    public Guid Id { get; }
    public SourceConfig Config { get; }

    [ObservableProperty]
    private SourceConnectionState _connectionState = SourceConnectionState.Disconnected;

    private SftpClient? _client;

    public SftpFileSource(SourceConfig config)
    {
        Id = config.Id;
        Config = config;
    }

    public bool SupportsDestructiveOperations => false;

    partial void OnConnectionStateChanged(SourceConnectionState value)
    {
        Config.SftpConnected = value.Kind switch
        {
            SourceConnectionKind.Connected => true,
            SourceConnectionKind.Error => false,
            SourceConnectionKind.Disconnected => false,
            _ => null
        };
    }

    public async Task ConnectAsync()
    {
        var host = Config.Host;
        if (string.IsNullOrEmpty(host))
        {
            ConnectionState = SourceConnectionState.Error("ホストが設定されていません。");
            throw new FileSourceException("ホストが設定されていません。");
        }
        var username = Config.Username ?? "";
        var password = CredentialStore.Password(Config.Id) ?? "";
        var port = Config.Port ?? 22;

        ConnectionState = SourceConnectionState.Connecting;
        try
        {
            _client?.Dispose();
            var client = new SftpClient(host, port, username, password);
            await client.ConnectAsync(CancellationToken.None);
            _client = client;
            ConnectionState = SourceConnectionState.Connected;
        }
        catch (Exception ex)
        {
            ConnectionState = SourceConnectionState.Error(ex.Message);
            throw new FileSourceException(ex.Message);
        }
    }

    public RelativePath RootPrefix(ConsoleCategory category) => RelativePath.Root;

    public async Task<List<FileEntry>> ListAsync(RelativePath path)
    {
        var client = ActiveClient();
        var remotePath = RemotePath(path);
        var files = await ListDirectoryEntriesAsync(client, remotePath);
        return files
            .Where(f => f.Name != "." && f.Name != "..")
            .Select(f => new FileEntry(f.Name, f.IsDirectory, f.IsDirectory ? null : f.Length, f.LastWriteTime, path.Appending(f.Name)))
            .OrderBy(e => e.IsDirectory ? 0 : 1)
            .ThenBy(e => e.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    public Task<bool> ExistsAsync(RelativePath path)
    {
        var client = ActiveClient();
        return Task.Run(() => client.Exists(RemotePath(path)));
    }

    public async Task CopyInAsync(string localPath, RelativePath destination)
    {
        var client = ActiveClient();
        var remotePath = RemotePath(destination.Appending(System.IO.Path.GetFileName(localPath)));
        using var stream = File.OpenRead(localPath);
        await client.UploadFileAsync(stream, remotePath, CancellationToken.None);
    }

    public async Task CopyOutAsync(RelativePath source, string localPath)
    {
        var client = ActiveClient();
        var remotePath = RemotePath(source);
        using var stream = File.Create(localPath);
        await client.DownloadFileAsync(remotePath, stream, CancellationToken.None);
    }

    public void Reveal(RelativePath path) =>
        throw new FileSourceException("SFTP接続ではエクスプローラーでの表示はサポートされていません。");

    public string? LocalFilePath(RelativePath path) => null;

    public Task RenameAsync(RelativePath path, string newName) =>
        throw new FileSourceException("SFTP接続では名前の変更はサポートされていません。");

    public Task DeleteAsync(RelativePath path) =>
        throw new FileSourceException("SFTP接続では削除はサポートされていません。");

    /// <summary>
    /// Best-effort discovery of onPC install folders on a machine reached
    /// over plain SSH (not the console) — there's no protocol-level way to
    /// ask "where is grandMA3 installed", so this just probes the handful of
    /// locations onPC is documented to use on Windows/Mac/Linux. Requires
    /// <see cref="ConnectAsync"/> to have already succeeded.
    /// </summary>
    public async Task<List<string>> DiscoverOnPCVersionFoldersAsync(string usernameHint)
    {
        if (_client is not { IsConnected: true } client) return new List<string>();

        var candidateRoots = new List<string>
        {
            "/ProgramData/MALightingTechnology",
            "/C:/ProgramData/MALightingTechnology",
            "C:/ProgramData/MALightingTechnology",
        };
        if (!string.IsNullOrEmpty(usernameHint))
        {
            candidateRoots.InsertRange(0, new[]
            {
                $"/Users/{usernameHint}/MALightingTechnology",
                $"/home/{usernameHint}/MALightingTechnology",
            });
        }

        var results = new List<string>();
        foreach (var root in candidateRoots)
        {
            List<ISftpFile> entries;
            try
            {
                entries = await ListDirectoryEntriesAsync(client, root);
            }
            catch
            {
                continue;
            }
            results.AddRange(entries
                .Where(f => f.IsDirectory && f.Name.StartsWith("gma3_"))
                .Select(f => $"{root}/{f.Name}"));
        }
        return results;
    }

    private SftpClient ActiveClient() =>
        _client ?? throw new FileSourceException("接続されていません。");

    private static async Task<List<ISftpFile>> ListDirectoryEntriesAsync(SftpClient client, string path)
    {
        var entries = new List<ISftpFile>();
        await foreach (var entry in client.ListDirectoryAsync(path, CancellationToken.None))
        {
            entries.Add(entry);
        }
        return entries;
    }

    private string RemotePath(RelativePath path)
    {
        var baseComponents = (Config.BasePathOverride ?? "")
            .Split('/', StringSplitOptions.RemoveEmptyEntries);
        var allComponents = baseComponents.Concat(path.Components);
        return "/" + string.Join("/", allComponents);
    }
}
