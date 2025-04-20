if not status --is-interactive
    exit
end

# brew
abbr b "brew"
abbr bi "brew install"
abbr bic "brew install --cask"
abbr bd "brew uninstall"
abbr bl "brew list"
abbr bu "brew upgrade"
abbr bud "brew update"
abbr bs "brew search"
abbr bsc "brew search --cask"
abbr bp "brew dump"
abbr bup "brew update && brew upgrade && brew cleanup"

# node
abbr n "bun"
abbr na "bun add"
abbr nini "bun init"
abbr ni "bun install"
abbr nig "bun install --global"
abbr nd "bun remove"
abbr nu "bun update"
abbr nb "bun bundle"
abbr nl 'bun pm ls'
abbr nlg 'bun pm ls -g'
abbr nr 'bun run'
abbr nrd "bun run dev"
abbr nrs "bun run start"
abbr nrb "bun run build"
abbr nrl "bun run lint"
abbr nrt "bun run typecheck"
abbr nx "bun x"

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
abbr pnig "pnpm install --global"
abbr pnd "pnpm uninstall"
abbr pnu "pnpm update"
abbr pnl "pnpm list"
abbr pnlg 'pnpm list --global'
abbr pnt "pnpm run test"
abbr pnr "pnpm run"
abbr pnrd "pnpm run dev"
abbr pnrs "pnpm run start"
abbr pnrb "pnpm run build"
abbr pnrt "pnpm run test"
abbr pnrl "pnpm run lint"
abbr pnrt "pnpm run typecheck"
abbr pnx "pnpx"

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

abbr p "uv"
abbr pr "uv run"
abbr pini "uv init"
abbr pa "uv add"
abbr pd "uv remove"
abbr ps "uv sync"
abbr pl "uv lock"
abbr pe "uv export"
abbr pt "uv tree"
abbr ptl "uv tool"
abbr ppy "uv python"
abbr pp "uv pip"
abbr pv "uv venv"
abbr pb "uv build"
abbr ppu "uv publish"
abbr pc "uv cache"
abbr psf "uv self"
abbr pver "uv version"
abbr ph "uv help"

# utils
abbr sp speedtest
abbr cl clear
abbr ltl lt --level
