if not status --is-interactive
    exit
end

# brew
abbr br "brew"
abbr bri "brew install"
abbr bric "brew install --cask"
abbr brd "brew uninstall"
abbr brl "brew list"
abbr bru "brew upgrade"
abbr brud "brew update"
abbr brs "brew search"
abbr brsc "brew search --cask"
abbr brd "brew dump"
abbr brup "brew update && brew upgrade && brew cleanup"

# node
abbr np "npm"
abbr npi "npm install"
abbr npd "npm uninstall"
abbr npu "npm update"
abbr npl "npm list"
abbr nplg 'npm list -g --depth=0'
abbr npr "npm run"
abbr nprd "npm run dev"
abbr nprs "npm run start"
abbr nprb "npm run build"
abbr nprt "npm run test"

abbr pn "pnpm"
abbr pni "pnpm install"
abbr pnd "pnpm uninstall"
abbr pnu "pnpm update"
abbr pnl "pnpm list"
abbr pnlg 'pnpm list -g'
abbr pnr "pnpm run"
abbr pnrd "pnpm run dev"
abbr pnrs "pnpm run start"
abbr pnrb "pnpm run build"
abbr pnrt "pnpm run test"
abbr pnrl "pnpm run lint"
abbr pnrt "pnpm run typecheck"
abbr pnx "pnpx"

abbr bu "bun"
abbr bui "bun install"
abbr bud "bun remove"
abbr buu "bun update"
abbr bulg 'bun pm ls'
abbr bulg 'bun pm ls -g'
abbr burd "bun run dev"
abbr burs "bun run start"
abbr burb "bun run build"
abbr burt "bun test"

# fisher
abbr fi "fisher"
abbr fii "fisher install"
abbr fiu "fisher update"
abbr fid "fisher remove"
abbr fil "fisher list"

# dot
abbr de "dot edit"
abbr dg "dot go"
abbr dl "dot link"

# docker
abbr dk "docker"
abbr dc "docker compose"

# python
abbr py "python"
abbr pyi "pip install"

# utils
abbr --add sp speedtest
abbr --add cl clear
