using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace GrandMAResourceManager.Services;

/// <summary>
/// Stores SFTP passwords outside sources.json, each encrypted at rest via
/// Windows DPAPI (tied to the current user account, so another Windows user
/// on the same machine can't read them) and written to its own file keyed by
/// Source id. The Windows equivalent of the macOS app's
/// <c>KeychainCredentialStore</c>.
/// </summary>
public static class CredentialStore
{
    private static readonly string Directory_ = InitDirectory();

    private static string InitDirectory()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var dir = Path.Combine(appData, "GrandMAResourceManager", "credentials");
        Directory.CreateDirectory(dir);
        return dir;
    }

    private static string PathFor(Guid sourceId) => Path.Combine(Directory_, $"{sourceId}.bin");

    public static void SavePassword(string password, Guid sourceId)
    {
        var plainBytes = Encoding.UTF8.GetBytes(password);
        var encrypted = ProtectedData.Protect(plainBytes, optionalEntropy: null, DataProtectionScope.CurrentUser);
        File.WriteAllBytes(PathFor(sourceId), encrypted);
    }

    public static string? Password(Guid sourceId)
    {
        var path = PathFor(sourceId);
        if (!File.Exists(path)) return null;
        try
        {
            var encrypted = File.ReadAllBytes(path);
            var plainBytes = ProtectedData.Unprotect(encrypted, optionalEntropy: null, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(plainBytes);
        }
        catch (CryptographicException)
        {
            return null;
        }
    }

    public static void DeletePassword(Guid sourceId)
    {
        var path = PathFor(sourceId);
        if (File.Exists(path)) File.Delete(path);
    }
}
