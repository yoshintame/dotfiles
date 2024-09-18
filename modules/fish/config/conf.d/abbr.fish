if not status --is-interactive
    exit
end

# brew
abbr br "brew"
abbr bri "brew install"
abbr brr "brew uninstall"
abbr brl "brew list"
abbr nplg 'npm list -g --depth=0'
abbr bru "brew upgrade"
abbr brud "brew update"
abbr brs "brew search"
abbr brd "brew dump"
abbr brup "brew update && brew upgrade && brew cleanup"

# node
abbr np "npm"
abbr npi "npm install"
abbr npr "npm uninstall"
abbr npu "npm update"
abbr npd "npm run dev"
abbr nps "npm run start"
abbr npb "npm run build"
abbr npt "npm test"
abbr npr "npm run"

abbr pn "pnpm"
abbr pni "pnpm install"
abbr pnr "pnpm remove"
abbr pnu "pnpm update"
abbr pnl "pnpm list"
abbr pnlg 'pnpm list -g'
abbr pnd "pnpm dev"
abbr pns "pnpm start"
abbr pnb "pnpm build"
abbr pnt "pnpm test"
abbr pnx "pnpx"

abbr bu "bun"
abbr bui "bun install"
abbr bur "bun remove"
abbr buu "bun update"
abbr bulg 'bun pm ls'
abbr bulg 'bun pm ls -g'
abbr bud "bun run dev"
abbr bus "bun run start"
abbr bub "bun run build"
abbr but "bun test"

# fisher
abbr fi "fisher"
abbr fii "fisher install"
abbr fiu "fisher update"
abbr fir "fisher remove"
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
