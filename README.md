# Resource Manager for grandMA

grandMA3 / grandMA2 のファイルに素早くアクセスするための Mac / Windows アプリです。ローカル onPC・USBメモリ・(macOS版のみ)実機コンソール(SFTP)を横断して Shows / Macros / Presets などのフォルダに一発でジャンプし、ドラッグ&ドロップでインポート/エクスポートできます。

**grandMA3 / grandMA2 のデータが入ったUSBメモリを挿すだけで自動検出**され、「Sourceとして追加しますか？」と聞かれるので、毎回手動でボリュームを探す必要がありません。

> **Note:** 実機コンソールへのSFTP接続機能(macOS版のみ)は実装済みですが、実機での動作検証がまだできていません。確認でき次第このREADMEで報告します。ローカル onPC / USBメモリでの利用はどちらのプラットフォームでも動作確認済みです。

## 主な機能

- **grandMA3 / grandMA2 のUSBメモリを挿すだけで自動検出**、ワンクリックでSourceとして追加
- ローカル onPC(macOS: `~/MALightingTechnology`、Windows: `C:\ProgramData\MALightingTechnology` など)、USBメモリを横断してファイル管理
- Shows / Macros / Sequences / Presets など grandMA3 のフォルダ構成をワンクリックでナビゲート
- ドラッグ&ドロップでのインポート/エクスポート
- ファイルのリネーム・削除(確認ダイアログ、ゴミ箱/リサイクル箱送り)
- クイックオープン検索(全Source横断)
- フィクスチャライブラリのメーカー名でのフィルタ

## macOS / Windows 対応表

| 機能 | macOS | Windows |
|---|:---:|:---:|
| ローカル onPC (grandMA3) | ✅ | ✅ |
| ローカル onPC (grandMA2) | ❌ | ✅ |
| USBメモリ (grandMA3 / grandMA2 自動検出) | ✅ | ✅ |
| 実機コンソール接続 (SFTP) | ✅ ※未検証 | ❌ |
| 他のMac/PC(onPC)へのSSH接続 | ✅ | ❌ |
| ドラッグ&ドロップ インポート/エクスポート | ✅ | ✅ |
| 別Source間のドラッグ移動 | ✅ (SFTP含む) | ✅ (ローカル/USB間) |
| リネーム・削除 | ✅ | ✅ |
| 複数選択・一括削除 | ✅ (選択モード切替) | ✅ (Ctrl/Shift+クリック) |
| クイックオープン検索 | ✅ (⌘K) | ✅ (Ctrl+K) |
| メーカー名フィルタ | ✅ | ✅ |
| フォルダ種別アイコン(lib_*等) | ✅ | 未対応 |
| MA Net(同一サブネット)判定表示 | ✅ | - (SFTP非対応のため) |

※ 実機コンソールへのSFTP接続はmacOS版のみ実装済みですが、実機での動作検証がまだできていません(上記Note参照)。ローカル onPC / USBメモリの利用はどちらのプラットフォームでも動作確認済みです。

## ダウンロードしてすぐ使う

インストーラ不要、Xcode/Visual Studio不要です。[Releases](../../releases) から自分のOS用のファイルをダウンロードしてください。

### macOS

1. `GrandMAResourceManager-macOS.zip` をダウンロードして展開
2. `Resource Manager for grandMA.app` を `/Applications` に入れて起動

未署名アプリのため、初回起動時にmacOSの警告でブロックされます。

1. まず `Resource Manager for grandMA.app` を**右クリック(またはControl+クリック)→「開く」**を試す
2. 「開く」ボタンが出るダイアログならそのまま「開く」で起動完了
3. それでも「破損している」「開けません」としか出ず「開く」の選択肢が無い場合は、**「システム設定」→「プライバシーとセキュリティ」**を開き、一番下までスクロールすると「"Resource Manager for grandMA" はブロックされました」といった表示があるので、その横の**「このまま開く」**をクリック → パスワードやTouch IDで確認
4. 再度アプリを起動すると、今度は普通に開けます

一度許可すれば、2回目以降は警告なしで起動します。

対応OS: macOS 14 (Sonoma) 以降。

### Windows

1. `GrandMAResourceManager-win-x64.zip`(または `.exe`)をダウンロード
2. 展開して `GrandMAResourceManager.exe` をダブルクリック(.NETランタイムのインストール不要、単体で動作します)

未署名アプリのため、初回起動時にWindows SmartScreenの警告が出ます。「詳細情報」→「実行」を選べば起動できます。

対応OS: Windows 10/11 (64-bit)。

## ソースからビルドする

### macOS

```bash
brew install xcodegen
cd "resource-manager-for-grandma"   # このリポジトリのルート
xcodegen generate
./install.sh
```

`install.sh` が Release ビルドを `/Applications` にインストールします。

### Windows

```powershell
cd Windows
.\install.ps1
```

`.NET 8 SDK` が必要です(`dotnet` コマンドが使えること)。`install.ps1` が自己完結型の単体 `.exe` を `Windows\publish\` に生成します。

## ライセンス

閲覧・ダウンロードして使うのは自由ですが、改変や再配布は許可していません。詳細は [LICENSE.md](LICENSE.md) を参照してください。
