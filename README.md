# grandMA Resource Manager (macOS)

grandMA3 / grandMA2 のファイルに素早くアクセスするための Mac アプリです。ローカル onPC・USBメモリ・実機コンソール(SFTP)を横断して Shows / Macros / Presets などのフォルダに一発でジャンプし、ドラッグ&ドロップでインポート/エクスポートできます。

## ダウンロードしてすぐ使う

Xcode不要です。[Releases](../../releases) から最新の `GrandMAResourceManager.app.zip` をダウンロードして展開し、`/Applications` に入れて起動してください。

未署名アプリのため、初回起動時に「開発元が未確認のため開けません」という警告が出ます。**右クリック(またはControl+クリック)→「開く」**を選ぶと起動できます(2回目以降は警告なしで起動します)。

## 主な機能

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
