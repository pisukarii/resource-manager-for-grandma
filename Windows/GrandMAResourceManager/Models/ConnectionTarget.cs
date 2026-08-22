namespace GrandMAResourceManager.Models;

/// <summary>
/// Which kind of machine an SFTP Source connects to. The console and a
/// regular onPC install have entirely different login accounts and base
/// paths, so the connection form asks up front rather than letting the two
/// get mixed up. Mirrors the macOS app's <c>SFTPConnectionForm.ConnectionTarget</c>.
/// </summary>
public enum ConnectionTarget
{
    Console,
    OtherOnPC
}

public static class ConnectionTargetExtensions
{
    public static string DisplayName(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console => "実機コンソール",
        ConnectionTarget.OtherOnPC => "他のonPC (SSH)",
        _ => target.ToString()
    };

    public static string DefaultUsername(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console => "remote",
        ConnectionTarget.OtherOnPC => "",
        _ => ""
    };

    public static string DefaultName(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console => "コンソール",
        ConnectionTarget.OtherOnPC => "onPC (SSH)",
        _ => ""
    };

    public static string HostHint(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console => "ホスト (Manetアダプタの IPアドレス)",
        ConnectionTarget.OtherOnPC => "ホスト (そのPCの IPアドレス)",
        _ => "ホスト"
    };

    public static string UsernameHint(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console => "コンソールのSFTPアカウント (通常 remote)",
        ConnectionTarget.OtherOnPC => "そのPCのログインユーザー名",
        _ => ""
    };

    /// <summary>
    /// Default base path to pre-fill when switching to this target.
    /// <see cref="ConnectionTarget.Console"/> uses the console's internal
    /// storage path (confirmed 2026-08-19 against a real grandMA3 console's
    /// Linux filesystem). <see cref="ConnectionTarget.OtherOnPC"/> is left
    /// blank since it depends on that machine's own username/version.
    /// </summary>
    public static string DefaultBasePath(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console => "/MALighting/grandma3",
        ConnectionTarget.OtherOnPC => "",
        _ => ""
    };

    public static string BasePathPlaceholder(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console => "例: /MALighting/grandma3",
        ConnectionTarget.OtherOnPC => "例(Windows): C:/ProgramData/MALightingTechnology/gma3_2.4.2",
        _ => ""
    };

    public static string BasePathHelpText(this ConnectionTarget target) => target switch
    {
        ConnectionTarget.Console =>
            "実機コンソール(Linux)の内部ストレージ上のパスです。バージョンやモデルによって異なる場合は、ここを実際のパスに書き換えてから「接続をテスト」してください。",
        ConnectionTarget.OtherOnPC =>
            "そのPC上の onPC インストールフォルダを指定してください。\nWindows: C:/ProgramData/MALightingTechnology/gma3_x.y.z\nMac: /Users/ユーザー名/MALightingTechnology/gma3_x.y.z (バージョン番号は実際にインストールされているものに置き換えてください)",
        _ => ""
    };
}
