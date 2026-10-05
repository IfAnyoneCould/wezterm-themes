# wezterm-themes

Swaps the theme in wezterm, nvim, oh-my-posh, yazi, btop and claude code at once.

## Setup

In the pwsh profile:

```powershell
Set-Alias wzt ~\Projects\wezterm-themes\wzt.ps1
```

In `.zshrc`:

```zsh
alias wzt='pwsh -NoLogo -NoProfile -File ~/Projects/wezterm-themes/wzt.ps1'
```

`.wezterm.lua` reads `~/.config/wezterm/themes/current.json` and watches it, and nvim's `lua/config/theme.lua` reads the colorscheme out of it.

For the prompt, `.zshrc` sets `POSH_THEME` from it before every prompt (zsh's `mapfile`, no fork) and the pwsh profile passes it to `oh-my-posh init`.

## Usage

```
wzt               # pick a theme
wzt <name>        # switch to it
wzt save <name>   # save what nvim, yazi, btop and claude code are using now as a theme
wzt ls            # * is the one in use
wzt rm [name]
```

Menus take arrows, j/k or the number, enter to pick, esc to cancel.

## Themes

Themes go in `~\.config\wezterm\themes\<name>.json`, or `$env:WZT_DIR`.

```json
{
  "wezterm": "nord",
  "background": "C:/Users/JonahW/Pictures/wallpapers/icecave-term.jpg",
  "brightness": 1.0,
  "saturation": 1.0,
  "nvim": "nord",
  "claude": "custom:nord",
  "omp": "C:/Users/JonahW/.ohmyposhconfigs/icecave.omp.json",
  "yazi": "C:/Users/JonahW/.config/wezterm/themes/icecave.yazi.toml",
  "btop": "nord"
}
```

- `wezterm` is a lua file in `~/.config/wezterm` (`ashen` -> `ashen.lua`) or a built in scheme name
- `nvim` is a colorscheme, its plugin has to be in the nvim config
- `claude` goes into the `theme` in `~/.claude/settings.json`, custom ones live in `~/.claude/themes`
- `omp` is an oh-my-posh config
- `yazi` is a whole `theme.toml`, copied over yazi's. yazi has no include, and an `[icon]` list in `theme.toml` beats the flavor's, so each theme keeps its own file. flavors go in with `ya pkg add`
- `btop` is a theme in btop's `themes` folder, without the `.theme`. scoop's btop keeps its config next to the exe, `$env:WZT_BTOP` points somewhere else
- leave out `background` for no image

## How it works

- picking a theme copies it to `current.json` and touches `.wezterm.lua`, wezterm doesn't always notice `current.json` changing on its own
- every nvim listening on a pipe gets `:colorscheme` sent to it, new ones read `current.json` on startup
- omp reads `POSH_THEME` on every prompt, so open zsh shells switch on their next prompt. pwsh only picks it up in new shells
- `save` starts from `current.json` and takes the colorscheme from a running nvim, yazi's `theme.toml` and the theme from claude's settings

## Notes

- wsl nvims aren't switched
- an open yazi keeps its old theme until it's restarted
- btop writes its whole config back when it quits, so an open btop puts its old theme back. wzt warns about it
- wsl's btop isn't switched
