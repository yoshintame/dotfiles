function yt-transcript --description 'Fetch and clean a YouTube video transcript'
    set -l script "$HOME/.claude/skills/youtube-summary/scripts/yt-transcript"
    if not test -f "$script"
        echo "yt-transcript: script not found at $script" >&2
        echo "yt-transcript: run your dotfiles deploy to link it" >&2
        return 1
    end
    if not type -q yt-dlp
        echo "yt-transcript: yt-dlp is required but not installed" >&2
        return 1
    end
    python3 "$script" $argv
end
