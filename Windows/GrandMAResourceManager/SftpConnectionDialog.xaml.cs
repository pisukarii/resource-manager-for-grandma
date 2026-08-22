using System.Windows;
using System.Windows.Media;
using GrandMAResourceManager.Models;
using GrandMAResourceManager.Services;
using GrandMAResourceManager.Sources;

namespace GrandMAResourceManager;

/// <summary>
/// Add or edit an SFTP Source's connection settings. Mirrors the macOS
/// app's <c>SFTPConnectionForm</c>: passing <paramref name="existingConfig"/>
/// pre-fills the current values and switches the primary button to "保存"
/// (save) instead of "追加" (add) — the caller decides whether that means
/// <see cref="Models.SourceStore.AddSource"/> or
/// <see cref="Models.SourceStore.UpdateSource"/> based on which flow opened
/// this dialog.
/// </summary>
public partial class SftpConnectionDialog : Window
{
    /// <summary>The config to add/update, set once the user submits successfully.</summary>
    public SourceConfig? ResultConfig { get; private set; }

    private readonly SourceConfig? _existingConfig;
    private readonly Guid _id;

    public SftpConnectionDialog(SourceConfig? existingConfig)
    {
        InitializeComponent();
        _existingConfig = existingConfig;
        _id = existingConfig?.Id ?? Guid.NewGuid();

        if (existingConfig is not null)
        {
            Title = "SFTP接続設定を編集";
            SubmitButton.Content = "保存";
            NameBox.Text = existingConfig.Name;
            HostBox.Text = existingConfig.Host ?? "";
            PortBox.Text = (existingConfig.Port ?? 22).ToString();
            UsernameBox.Text = existingConfig.Username ?? "";
            PasswordBox.Password = CredentialStore.Password(existingConfig.Id) ?? "";
            BasePathBox.Text = existingConfig.BasePathOverride ?? "";
        }

        // Set after InitializeComponent (not as an XAML IsChecked="True" literal) so the
        // Checked handler below can safely reach NameBox/HostBox/etc., which are declared
        // later in the visual tree and wouldn't exist yet if this fired during XAML parsing.
        var target = existingConfig?.ConnectionTarget ?? ConnectionTarget.Console;
        if (target == ConnectionTarget.OtherOnPC) OtherOnPcTargetToggle.IsChecked = true;
        else ConsoleTargetToggle.IsChecked = true;
    }

    private void OnTargetToggleChanged(object sender, RoutedEventArgs e)
    {
        var target = ConsoleTargetToggle.IsChecked == true ? ConnectionTarget.Console : ConnectionTarget.OtherOnPC;
        HostHintText.Text = target.HostHint();
        UsernameHintText.Text = target.UsernameHint();
        SetupHelpButton.Visibility = target == ConnectionTarget.OtherOnPC ? Visibility.Visible : Visibility.Collapsed;
        DiscoveryPanel.Visibility = target == ConnectionTarget.OtherOnPC ? Visibility.Visible : Visibility.Collapsed;
        if (BasePathHelpText.Visibility == Visibility.Visible) BasePathHelpText.Text = target.BasePathHelpText();

        // このPC/コンソールのログイン情報が混ざらないよう、切り替えたら想定される既定値に揃える。
        // 編集時は既存の入力値を誤って消さないようスキップ。
        if (_existingConfig is not null) return;
        UsernameBox.Text = target.DefaultUsername();
        NameBox.Text = target.DefaultName();
        BasePathBox.Text = target.DefaultBasePath();
    }

    private void OnShowSetupInstructionsClick(object sender, RoutedEventArgs e)
    {
        MessageBox.Show(this,
            "SSH/SFTPを有効化する方法:\n\n" +
            "■ Windows (このPC自身をonPCとして接続先にする場合)\n" +
            "1. 「設定」→「アプリ」→「オプション機能」→「機能の追加」\n" +
            "2. 「OpenSSH サーバー」を検索してインストール\n" +
            "3. 「サービス」アプリで「OpenSSH SSH Server」を開始、スタートアップの種類を「自動」に設定\n" +
            "4. Windowsのログインユーザー名・パスワードでこの画面から接続できます\n\n" +
            "■ Mac (そのMacをonPCとして接続先にする場合)\n" +
            "1. 「システム設定」→「一般」→「共有」→「リモートログイン」をオン\n" +
            "2. アクセスを許可するユーザーを確認\n" +
            "3. そのMacのログインユーザー名・パスワードでこの画面から接続できます",
            "初回設定方法", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void OnToggleBasePathHelpClick(object sender, RoutedEventArgs e)
    {
        if (BasePathHelpText.Visibility == Visibility.Visible)
        {
            BasePathHelpText.Visibility = Visibility.Collapsed;
            return;
        }
        var target = ConsoleTargetToggle.IsChecked == true ? ConnectionTarget.Console : ConnectionTarget.OtherOnPC;
        BasePathHelpText.Text = target.BasePathHelpText();
        BasePathHelpText.Visibility = Visibility.Visible;
    }

    private async void OnTestConnectionClick(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(HostBox.Text)) return;
        TestButton.IsEnabled = false;
        var originalContent = TestButton.Content;
        TestButton.Content = "接続確認中...";
        ResultBanner.Visibility = Visibility.Collapsed;

        var config = BuildConfig();
        CredentialStore.SavePassword(PasswordBox.Password, config.Id);
        var probe = new SftpFileSource(config);
        try
        {
            await probe.ConnectAsync();
            ShowResult(success: true, "接続に成功しました");
        }
        catch (Exception ex)
        {
            ShowResult(success: false, ex.Message);
        }
        finally
        {
            TestButton.Content = originalContent;
            TestButton.IsEnabled = true;
        }
    }

    private async void OnDiscoverClick(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(HostBox.Text) || string.IsNullOrWhiteSpace(UsernameBox.Text) || string.IsNullOrWhiteSpace(PasswordBox.Password))
            return;

        DiscoverButton.IsEnabled = false;
        DiscoveryResultsList.Visibility = Visibility.Collapsed;
        DiscoveryStatusText.Visibility = Visibility.Visible;
        DiscoveryStatusText.Text = "検索中...";

        var config = BuildConfig();
        CredentialStore.SavePassword(PasswordBox.Password, config.Id);
        var probe = new SftpFileSource(config);
        List<string> results;
        try
        {
            await probe.ConnectAsync();
            results = await probe.DiscoverOnPCVersionFoldersAsync(UsernameBox.Text.Trim());
        }
        catch
        {
            results = new List<string>();
        }

        DiscoverButton.IsEnabled = true;
        if (results.Count == 0)
        {
            DiscoveryStatusText.Text = "見つかりませんでした。手動で入力してください。";
        }
        else
        {
            DiscoveryStatusText.Visibility = Visibility.Collapsed;
            DiscoveryResultsList.ItemsSource = results;
            DiscoveryResultsList.Visibility = Visibility.Visible;
        }
    }

    private void OnDiscoveredPathClick(object sender, RoutedEventArgs e)
    {
        if (((FrameworkElement)sender).Tag is string path)
        {
            BasePathBox.Text = path;
            DiscoveryResultsList.Visibility = Visibility.Collapsed;
        }
    }

    private void OnSubmitClick(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(HostBox.Text)) return;
        var config = BuildConfig();
        CredentialStore.SavePassword(PasswordBox.Password, config.Id);
        ResultConfig = config;
        DialogResult = true;
        Close();
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        // Discard scratch credentials written during Test/Discover for an
        // aborted *new* connection — nothing else references this id.
        if (_existingConfig is null) CredentialStore.DeletePassword(_id);
        DialogResult = false;
        Close();
    }

    private SourceConfig BuildConfig()
    {
        var target = ConsoleTargetToggle.IsChecked == true ? ConnectionTarget.Console : ConnectionTarget.OtherOnPC;
        var port = int.TryParse(PortBox.Text, out var parsedPort) ? parsedPort : 22;
        var host = HostBox.Text.Trim();
        return new SourceConfig
        {
            Id = _id,
            Name = string.IsNullOrWhiteSpace(NameBox.Text) ? host : NameBox.Text.Trim(),
            Kind = SourceKind.Sftp,
            Host = host,
            Port = port,
            Username = UsernameBox.Text.Trim(),
            ConnectionTarget = target,
            BasePathOverride = string.IsNullOrWhiteSpace(BasePathBox.Text) ? null : BasePathBox.Text.Trim(),
            Family = ConsoleFamily.Ma3
        };
    }

    private void ShowResult(bool success, string message)
    {
        ResultBanner.Visibility = Visibility.Visible;
        ResultBanner.Background = new SolidColorBrush(success
            ? Color.FromArgb(0x30, 0x34, 0xC7, 0x59)
            : Color.FromArgb(0x30, 0xFF, 0x6B, 0x6B));
        ResultText.Foreground = new SolidColorBrush(success
            ? Color.FromRgb(0x34, 0xC7, 0x59)
            : Color.FromRgb(0xFF, 0x6B, 0x6B));
        ResultText.Text = success ? message : $"接続に失敗しました: {message}";
    }
}
