# grandMA Resource Manager (macOS)

grandMA3 / grandMA2 のファイルに素早くアクセスするための Mac アプリです。ローカル onPC・USBメモリ・実機コンソール(SFTP)を横断して Shows / Macros / Presets などのフォルダに一発でジャンプし、ドラッグ&ドロップでインポート/エクスポートできます。

**grandMA3 / grandMA2 のデータが入ったUSBメモリを挿すだけで自動検出**され、「Sourceとして追加しますか？」とバナーで聞かれるので、毎回手動でボリュームを探す必要がありません。

## ダウンロードしてすぐ使う

Xcode不要です。[Releases](../../releases) から最新の `GrandMAResourceManager-macOS.zip` をダウンロードして展開し、`grandMA Resource Manager.app` を `/Applications` に入れて起動してください。

未署名アプリのため、初回起動時にmacOSの警告でブロックされます。以下の手順で開いてください。

1. まず `grandMA Resource Manager.app` を**右クリック(またはControl+クリック)→「開く」**を試す
2. 「開く」ボタンが出るダイアログならそのまま「開く」で起動完了
3. それでも「破損している」「開けません」としか出ず「開く」の選択肢が無い場合は、**「システム設定」→「プライバシーとセキュリティ」**を開き、一番下までスクロールすると「"grandMA Resource Manager" はブロックされました」といった表示があるので、その横の**「このまま開く」**をクリック → パスワードやTouch IDで確認
4. 再度アプリを起動すると、今度は普通に開けます

一度許可すれば、2回目以降は警告なしで起動します。

## 主な機能

- **grandMA3 / grandMA2 のUSBメモリを挿すだけで自動検出**、ワンクリックでSourceとして追加
- ローカル onPC(`~/MALightingTechnology`)、USBメモリ、実機コンソール(SFTP)の3系統を横断してファイル管理
- Shows / Macros / Sequences / Presets など grandMA3 のフォルダ構成をワンクリックでナビゲート
- grandMA2 (USB) にも対応
- ドラッグ&ドロップでのインポート/エクスポート(Source間・SFTP経由も含む)
- ファイルのリネーム・削除(確認ダイアログ、ゴミ箱送り)
- ⌘K のクイックオープン検索(全Source横断)
- フィクスチャライブラリのメーカー名でのフィルタ

## ソースからビルドする

```bash
brew install xcodegen
xcodegen generate
./install.sh
```

`install.sh` が Release ビルドを `/Applications` にインストールします。

## 動作要件

- macOS 14 (Sonoma) 以降

## ライセンス

閲覧・ダウンロードして使うのは自由ですが、改変や再配布は許可していません。詳細は [LICENSE.md](LICENSE.md) を参照してください。
