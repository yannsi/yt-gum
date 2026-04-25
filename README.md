# yt-gum

YouTube TUI powered by [gum](https://github.com/charmbracelet/gum) & [yt-dlp](https://github.com/yt-dlp/yt-dlp)

## 機能

- キーワード検索・URL直接入力
- ストリーミング再生（mpv）
- 動画保存（1080p / 720p / 最高品質）
- 音声保存（MP3 / M4A / WAV / FLAC）
- 字幕ファイル保存（日本語・英語）
- 保存先フォルダの変更

## 依存関係

- [gum](https://github.com/charmbracelet/gum)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [mpv](https://mpv.io/)
- [ffmpeg](https://ffmpeg.org/)

## インストール

```bash
git clone https://github.com/yannsi/yt-gum.git
cd yt-gum
makepkg -si
```

## 起動

```bash
yt-gum
```

ターミナルエミュレータから起動してください。

## mpv 操作キー

|キー     |動作       |
|-------|---------|
|`q`    |終了       |
|`Space`|一時停止     |
|`← →`  |10秒スキップ  |
|`j / J`|字幕トラック切替 |
|`v`    |字幕 表示/非表示|