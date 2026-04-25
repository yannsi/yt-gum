#!/bin/bash

# --- 設定 ---
DEFAULT_DIR="${HOME}/Downloads"

# --- デザイン設定 ---
C_MAIN="212"
C_SUB="45"
C_TEXT="255"
C_GRAY="245"
C_ERR="196"
C_OK="82"
BORDER="rounded"

# バナーの描画幅: 内幅54 + パディング4 + ボーダー2 = 60
CONTENT_W=60
LEFT=0
INDENT=""

# --- レイアウト計算 (画面リサイズ対応) ---
update_layout() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    LEFT=$(( (cols - CONTENT_W) / 2 ))
    (( LEFT < 0 )) && LEFT=0
    INDENT=$(printf '%*s' "$LEFT" '')
}

# --- gum ヘルパー ---

# 左マージン付き gum style
gstyle() {
    gum style --margin "0 0 0 $LEFT" "$@"
}

# 左マージン付き gum choose (カーソルのインデントで全アイテムを右にずらす)
gchoose() {
    gum choose --cursor "${INDENT}>> " --cursor.foreground "$C_MAIN" "$@"
}

# --- 関数定義 ---

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        if command -v gum &> /dev/null; then
            gum style --foreground "$C_ERR" --border double --border-foreground "$C_ERR" --padding "0 2" \
                "エラー: 必須ツール '$1' がインストールされていません。"
        else
            printf '\033[31mエラー: 必須ツール '"'"'%s'"'"' がインストールされていません。\033[0m\n' "$1" >&2
        fi
        exit 1
    fi
}

# 依存チェックを tput smcup より前に実行
check_dependency gum
check_dependency yt-dlp
check_dependency mpv
check_dependency ffmpeg

TMP_RESULTS=$(mktemp)
TMP_LIST=$(mktemp)

cleanup() {
    tput rmcup
    tput cnorm
    rm -f "$TMP_RESULTS" "$TMP_LIST"
}
trap cleanup EXIT
tput smcup

show_banner() {
    update_layout
    clear
    gum style \
        --foreground "$C_MAIN" --border-foreground "$C_SUB" --border double \
        --align center --width 54 --margin "1 0 1 $LEFT" --padding "1 2" \
        "YOUTUBE TUI" \
        "" \
        "Powered by gum & yt-dlp"
}

select_directory() {
    local current_dir="$1"
    local temp_dir="$current_dir"
    [ ! -d "$temp_dir" ] && temp_dir="$HOME"

    while true; do
        show_banner >&2
        gstyle --foreground "$C_SUB" "保存先フォルダを選択してください:" >&2
        gstyle --foreground "$C_MAIN" --bold --border "$BORDER" --border-foreground "$C_GRAY" \
            --padding "0 2" " $temp_dir " >&2
        echo "" >&2

        local folders
        folders=$(ls -F "$temp_dir" 2>/dev/null | grep '/$' | sed 's/\/$//')

        local CHOICE
        CHOICE=$(printf '%s\n' "戻る（変更しない）" "このフォルダを選択" "上の階層へ" $folders \
            | gchoose --height 15 --header "${INDENT}ディレクトリ選択")

        case "$CHOICE" in
            "戻る（変更しない）") echo "$current_dir"; return ;;
            "このフォルダを選択") echo "$temp_dir";    return ;;
            "上の階層へ")         temp_dir=$(realpath "$temp_dir/..") ;;
            "")                   echo "$current_dir"; return ;;
            *)                    temp_dir=$(realpath "$temp_dir/$CHOICE") ;;
        esac
    done
}

run_download() {
    local url="$1"
    local mode="$2"
    local output_dir="$3"

    if [ "$mode" = "video" ]; then
        QUALITY=$(gchoose "戻る" "高画質 1080p (MP4)" "標準 720p (MP4)" "最高品質（自動）")
        if [ "$QUALITY" = "戻る" ]; then return 0; fi

        SUBTITLE=$(gchoose --header "${INDENT}字幕オプション" \
            "戻る" \
            "動画のみ保存" \
            "動画と字幕ファイルを保存（日本語・英語）")
        if [ "$SUBTITLE" = "戻る" ]; then return 0; fi

        local sub_opts=()
        case "$SUBTITLE" in
            "動画と字幕ファイルを保存（日本語・英語）")
                sub_opts=(--write-auto-sub --sub-langs "ja,en" --convert-subs srt
                          --retries 10 --sleep-interval 3 --max-sleep-interval 8
                          --ignore-errors) ;;
        esac

        gstyle --foreground "$C_MAIN" "ダウンロード中..."
        case "$QUALITY" in
            "高画質 1080p (MP4)")
                yt-dlp -P "$output_dir" -S "res:1080,vcodec:h264,acodec:aac" \
                    --merge-output-format mp4 --add-metadata "${sub_opts[@]}" \
                    -o "%(title)s.%(ext)s" "$url" ;;
            "標準 720p (MP4)")
                yt-dlp -P "$output_dir" -S "res:720,vcodec:h264,acodec:aac" \
                    --merge-output-format mp4 --add-metadata "${sub_opts[@]}" \
                    -o "%(title)s.%(ext)s" "$url" ;;
            "最高品質（自動）")
                yt-dlp -P "$output_dir" --add-metadata "${sub_opts[@]}" \
                    -o "%(title)s.%(ext)s" "$url" ;;
        esac
    else
        AUDIO_FMT=$(gchoose "戻る" "MP3（汎用）" "M4A / AAC" "WAV（無圧縮）" "FLAC（ロスレス）" "最高品質（自動）")
        if [ "$AUDIO_FMT" = "戻る" ]; then return 0; fi

        case "$AUDIO_FMT" in
            "MP3（汎用）")      FMT="mp3"  ;;
            "M4A / AAC")        FMT="m4a"  ;;
            "WAV（無圧縮）")    FMT="wav"  ;;
            "FLAC（ロスレス）") FMT="flac" ;;
            "最高品質（自動）") FMT="best" ;;
        esac

        gstyle --foreground "$C_MAIN" "音声を抽出中 ($FMT)..."
        yt-dlp -P "$output_dir" -x --audio-format "$FMT" --audio-quality 0 \
            --add-metadata -o "%(title)s.%(ext)s" "$url"
    fi

    local status
    status=$?
    if [ $status -eq 0 ]; then
        gstyle --foreground "$C_OK" --bold "完了！"
        sleep 1
    else
        gstyle --foreground "$C_ERR" --bold "ダウンロード失敗！ (終了コード: $status)"
        gum input --prompt "${INDENT}> " --placeholder "（Enterキーで続行）" > /dev/null 2>&1 || true
    fi
}

show_action_menu() {
    local url="$1"
    local target_dir="$2"
    local title="$3"

    while true; do
        show_banner
        gstyle --foreground "$C_TEXT" --bold "選択中:"
        gstyle --foreground "$C_MAIN" "$title"
        echo ""

        gstyle --foreground "$C_SUB" "操作を選択してください:"
        ACTION=$(gchoose --height 10 \
            "ストリーミング再生" \
            "動画を保存" \
            "音声を保存" \
            "戻る")

        if [ -z "$ACTION" ] || [ "$ACTION" = "戻る" ]; then
            return 0
        fi

        case "$ACTION" in
            "ストリーミング再生")
                gstyle --foreground "$C_SUB" --border "$BORDER" --border-foreground "$C_GRAY" --padding "0 2" \
                    "操作キー" \
                    "  q       終了" \
                    "  Space   一時停止" \
                    "  ← →    10秒スキップ" \
                    "  j / J   字幕トラック切替" \
                    "  v       字幕 表示/非表示"
                echo ""
                gstyle --foreground "$C_MAIN" "ストリーミング中... (Q で終了)"
                mpv --really-quiet --geometry=50% --force-window \
                    --script-opts="ytdl_hook-ytdl_path=$(which yt-dlp)" \
                    --ytdl-raw-options=force-ipv4= "$url" > /dev/null 2>&1
                ;;
            "動画を保存")           run_download "$url" "video" "$target_dir" ;;
            "音声を保存")           run_download "$url" "audio" "$target_dir" ;;
        esac
    done
}

# --- メイン処理 ---

update_layout
TARGET_DIR="$DEFAULT_DIR"
[ ! -d "$TARGET_DIR" ] && TARGET_DIR="$HOME"

while true; do
    show_banner
    gstyle --foreground "$C_SUB" "メニュー"
    gstyle --foreground "$C_GRAY" "保存先: $(basename "$TARGET_DIR")"

    MODE=$(gchoose \
        "キーワード検索" \
        "URLを直接入力" \
        "保存先を変更" \
        "終了")

    if [ -z "$MODE" ] || [ "$MODE" = "終了" ]; then
        exit 0
    fi

    case "$MODE" in
        "保存先を変更")
            TARGET_DIR=$(select_directory "$TARGET_DIR")
            ;;
        "URLを直接入力")
            gstyle --foreground "$C_SUB" "YouTubeのURLを入力してください:"
            URL=$(gum input --prompt "${INDENT}> " \
                --placeholder "https://youtube.com/watch?v=..." \
                --width 55 --cursor.foreground "$C_MAIN")
            if [ -n "$URL" ]; then
                show_action_menu "$URL" "$TARGET_DIR" "URL入力動画"
            fi
            ;;
        "キーワード検索")
            gstyle --foreground "$C_SUB" "検索キーワードを入力してください:"
            QUERY=$(gum input --prompt "${INDENT}> " \
                --placeholder "例: 音楽, ゲーム実況..." \
                --width 55 --cursor.foreground "$C_MAIN")
            [ -z "$QUERY" ] && continue

            # $QUERY を位置引数で渡しコマンドインジェクションを防止
            gum spin --spinner dot --spinner.foreground "$C_MAIN" \
                --title "  YouTubeを検索中..." -- \
                bash -c 'yt-dlp --no-colors --flat-playlist --print "%(title)s | id:%(id)s" "ytsearch15:$1" > "$2"' \
                -- "$QUERY" "$TMP_RESULTS"

            if [ ! -s "$TMP_RESULTS" ]; then
                gstyle --foreground "$C_ERR" "検索結果が見つかりませんでした。"
                sleep 1; continue
            fi

            while true; do
                show_banner
                gstyle --foreground "$C_SUB" "動画を選択してください:"

                { echo "戻る（再検索）"; cat "$TMP_RESULTS"; } > "$TMP_LIST"

                SELECTED_LINE=$(gchoose --height 15 < "$TMP_LIST")

                if [ -z "$SELECTED_LINE" ] || [ "$SELECTED_LINE" = "戻る（再検索）" ]; then
                    break
                fi

                VIDEO_TITLE=$(echo "$SELECTED_LINE" | awk -F '| id:' '{print $1}' | xargs)
                VIDEO_ID=$(echo "$SELECTED_LINE" | awk -F '| id:' '{print $2}' | xargs)
                URL="https://www.youtube.com/watch?v=$VIDEO_ID"

                show_action_menu "$URL" "$TARGET_DIR" "$VIDEO_TITLE"
            done
            ;;
    esac
done
