namespace GrandMAResourceManager.Models;

public enum SourceKind
{
    Local,
    Usb
}

public static class SourceKindExtensions
{
    public static string DisplayName(this SourceKind kind) => kind switch
    {
        SourceKind.Local => "ローカル (onPC)",
        SourceKind.Usb => "USBメモリ",
        _ => kind.ToString()
    };

    public static string Glyph(this SourceKind kind) => kind switch
    {
        SourceKind.Local => Glyphs.Laptop,
        SourceKind.Usb => Glyphs.ExternalDrive,
        _ => Glyphs.Folder
    };
}
