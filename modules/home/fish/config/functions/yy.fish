function yy --description "Run yazi and cd to the directory it returns"
	# macOS: switch input source to ABC via Hammerspoon
	if is_mac; and command -q hs
		command hs -c 'hs.keycodes.currentSourceID("com.apple.keylayout.ABC")' >/dev/null 2>&1
	end

	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		cd -- "$cwd"
	end
	command rm -f -- "$tmp"
end

