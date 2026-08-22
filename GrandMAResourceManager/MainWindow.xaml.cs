using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using GrandMAResourceManager.Models;
using GrandMAResourceManager.ViewModels;

namespace GrandMAResourceManager;

public partial class MainWindow : Window
{
    private MainViewModel Vm => (MainViewModel)DataContext;

    private System.Windows.Point _dragStartPoint;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainViewModel();
    }

    // MARK: Add / remove Source

    private void OnAddSourceClick(object sender, RoutedEventArgs e)
    {
        var dialog = new AddSourceDialog(Vm.Store) { Owner = this };
        if (dialog.ShowDialog() == true && dialog.CreatedConfig is { } config)
        {
            Vm.AddSource(config);
        }
    }

    private void OnRenameSourceClick(object sender, RoutedEventArgs e)
    {
        var menuItem = (MenuItem)sender;
        var contextMenu = (ContextMenu)menuItem.Parent;
        var listBoxItem = (ListBoxItem)contextMenu.PlacementTarget;
        var config = (SourceConfig)listBoxItem.DataContext;
        var newName = Microsoft.VisualBasic.Interaction.InputBox("新しい名前を入力してください。", "名前を変更", config.Name);
        if (string.IsNullOrWhiteSpace(newName)) return;
        Vm.Store.RenameSource(config.Id, newName);
    }

    private void OnRemoveSourceClick(object sender, RoutedEventArgs e)
    {
        var menuItem = (MenuItem)sender;
        var contextMenu = (ContextMenu)menuItem.Parent;
        var listBoxItem = (ListBoxItem)contextMenu.PlacementTarget;
        var config = (SourceConfig)listBoxItem.DataContext;
        Vm.RemoveSource(config);
    }

    // MARK: USB detection banner

    private void OnAddDetectedUsbClick(object sender, RoutedEventArgs e)
    {
        if (Vm.UsbWatcher.PendingDetection is { } detected)
            Vm.AddDetectedUsbSource(detected);
    }

    private void OnDismissUsbBannerClick(object sender, RoutedEventArgs e) => Vm.UsbWatcher.DismissPending();

    // MARK: Quick Open (wired up once QuickOpenWindow exists)

    private void OnQuickOpenClick(object sender, RoutedEventArgs e)
    {
        var window = new QuickOpenWindow(Vm) { Owner = this };
        if (window.ShowDialog() == true && window.SelectedEntry is { } jump)
        {
            Vm.SelectedSourceConfig = jump.Source;
            Vm.SelectedCategory = jump.Category;
            if (jump.Entry.IsDirectory)
                Vm.CurrentPath = jump.Entry.Path;
        }
    }

    // MARK: Drop onto a Source row in the sidebar (cross-source import)

    private void OnSourceRowDragOver(object sender, System.Windows.DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) && Vm.SelectedCategory is not null
            ? DragDropEffects.Copy
            : DragDropEffects.None;
        e.Handled = true;
    }

    private async void OnSourceRowDrop(object sender, System.Windows.DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
        var listBoxItem = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        if (listBoxItem?.DataContext is not SourceConfig targetConfig) return;
        var paths = (string[])e.Data.GetData(DataFormats.FileDrop);
        await Vm.ImportToOtherSourceAsync(targetConfig, paths);
    }

    // MARK: Drop into the file list (import into current folder)

    private void OnFileListDragOver(object sender, System.Windows.DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    private async void OnFileListDrop(object sender, System.Windows.DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
        var paths = (string[])e.Data.GetData(DataFormats.FileDrop);
        await Vm.ImportFilesAsync(paths);
    }

    // MARK: Drag a row out to Explorer/other apps

    private void OnFileListPreviewMouseDown(object sender, MouseButtonEventArgs e)
    {
        _dragStartPoint = e.GetPosition(null);
    }

    private void OnFileListMouseMove(object sender, System.Windows.Input.MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed) return;
        var current = e.GetPosition(null);
        if (Math.Abs(current.X - _dragStartPoint.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(current.Y - _dragStartPoint.Y) < SystemParameters.MinimumVerticalDragDistance)
        {
            return;
        }

        var listViewItem = FindAncestor<ListViewItem>(e.OriginalSource as DependencyObject);
        if (listViewItem?.DataContext is not FileEntry entry) return;

        var localPath = Vm.SelectedSource?.LocalFilePath(entry.Path);
        if (localPath is null) return; // no on-disk backing (not expected for this app, but be safe)

        var data = new DataObject(DataFormats.FileDrop, new[] { localPath });
        DragDrop.DoDragDrop(FileListView, data, DragDropEffects.Copy);
    }

    // MARK: Selection sync

    private void OnFileListSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        Vm.SelectedEntries.Clear();
        foreach (var item in FileListView.SelectedItems)
        {
            if (item is FileEntry entry) Vm.SelectedEntries.Add(entry);
        }
    }

    private void OnFileListDoubleClick(object sender, MouseButtonEventArgs e)
    {
        var listViewItem = FindAncestor<ListViewItem>(e.OriginalSource as DependencyObject);
        if (listViewItem?.DataContext is FileEntry entry)
        {
            Vm.OpenEntryCommand.Execute(entry);
        }
    }

    private void OnSelectAllClick(object sender, RoutedEventArgs e) => FileListView.SelectAll();

    private bool _isResettingJumpCombo;

    private void OnJumpSubfolderSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isResettingJumpCombo) return;
        if (JumpSubfolderComboBox.SelectedItem is FileEntry entry)
        {
            Vm.JumpToSubfolder(entry);
        }
        // Reset so it behaves like a one-shot "jump to..." menu rather than
        // a persistent filter (unlike the manufacturer picker).
        _isResettingJumpCombo = true;
        JumpSubfolderComboBox.SelectedItem = null;
        _isResettingJumpCombo = false;
    }

    // MARK: Context menu actions

    private void OnOpenMenuClick(object sender, RoutedEventArgs e)
    {
        if (EntryFromMenuItem(sender) is { } entry) Vm.OpenEntryCommand.Execute(entry);
    }

    private void OnRevealMenuClick(object sender, RoutedEventArgs e)
    {
        if (EntryFromMenuItem(sender) is { } entry)
        {
            try { Vm.SelectedSource?.Reveal(entry.Path); } catch { /* best-effort */ }
        }
    }

    private async void OnRenameMenuClick(object sender, RoutedEventArgs e)
    {
        if (EntryFromMenuItem(sender) is not { } entry) return;
        var currentBaseName = entry.IsDirectory ? entry.Name : System.IO.Path.GetFileNameWithoutExtension(entry.Name);
        var newBaseName = Microsoft.VisualBasic.Interaction.InputBox(
            "新しい名前を入力してください。", "名前を変更", currentBaseName);
        if (string.IsNullOrWhiteSpace(newBaseName)) return;
        try
        {
            await Vm.RenameAsync(entry, newBaseName);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "リネームエラー", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private async void OnDeleteMenuClick(object sender, RoutedEventArgs e)
    {
        if (EntryFromMenuItem(sender) is not { } entry) return;
        await ConfirmAndDeleteAsync(new[] { entry }, $"「{entry.Name}」を本当に削除しますか？");
    }

    private async void OnBulkDeleteClick(object sender, RoutedEventArgs e)
    {
        var targets = Vm.SelectedEntries.ToList();
        if (targets.Count == 0) return;
        await ConfirmAndDeleteAsync(targets, $"選択した{targets.Count}件を本当に削除しますか？");
    }

    private async Task ConfirmAndDeleteAsync(IReadOnlyList<FileEntry> targets, string message)
    {
        var result = MessageBox.Show(
            this,
            message + "\nこの操作は取り消せません(ごみ箱には入ります)。",
            "削除の確認",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning,
            MessageBoxResult.No);
        if (result != MessageBoxResult.Yes) return;
        try
        {
            await Vm.DeleteAsync(targets);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "削除エラー", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private static FileEntry? EntryFromMenuItem(object sender)
    {
        var menuItem = (MenuItem)sender;
        var contextMenu = (ContextMenu)menuItem.Parent;
        return (contextMenu.PlacementTarget as ListViewItem)?.DataContext as FileEntry;
    }

    private static T? FindAncestor<T>(DependencyObject? current) where T : DependencyObject
    {
        while (current is not null)
        {
            if (current is T match) return match;
            current = VisualTreeHelper.GetParent(current);
        }
        return null;
    }
}
