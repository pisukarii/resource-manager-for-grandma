using System.Windows;
using System.Windows.Input;
using GrandMAResourceManager.Services;
using GrandMAResourceManager.ViewModels;

namespace GrandMAResourceManager;

public partial class QuickOpenWindow : Window
{
    public IndexedEntry? SelectedEntry { get; private set; }

    private readonly MainViewModel _mainVm;
    private readonly FileIndex _index = new();

    public QuickOpenWindow(MainViewModel mainVm)
    {
        InitializeComponent();
        _mainVm = mainVm;
        Loaded += OnLoadedAsync;
    }

    private async void OnLoadedAsync(object sender, RoutedEventArgs e)
    {
        SearchBox.Focus();
        StatusText.Text = "インデックスを作成中...";
        await _index.RefreshAsync(_mainVm.Store.Sources);
        StatusText.Text = $"最終更新: {DateTime.Now:HH:mm:ss}";
    }

    private void OnSearchTextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        var results = _index.Search(SearchBox.Text);
        ResultsListBox.ItemsSource = results;
        if (results.Count > 0) ResultsListBox.SelectedIndex = 0;
    }

    private void OnResultDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        Choose();
    }

    private void OnResultsKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.Enter) Choose();
    }

    private void Choose()
    {
        if (ResultsListBox.SelectedItem is IndexedEntry entry)
        {
            SelectedEntry = entry;
            DialogResult = true;
            Close();
        }
    }
}
