# swaps the theme in wezterm, nvim, oh-my-posh and claude code at once. a theme
# is a json file, wzt copies the one you pick to current.json, which
# .wezterm.lua, nvim's config/theme.lua and the shells read. running nvims get
# told over their pipes
param(
  [Parameter(Position = 0)] [string] $Cmd,
  [Parameter(Position = 1)] [string] $Name
)
$ErrorActionPreference = 'Stop'

$root = $env:WZT_DIR ?? "$HOME\.config\wezterm\themes"
$current = Join-Path $root 'current.json'
$claude = "$HOME\.claude\settings.json"

function Get-Theme($n) {
  $f = Join-Path $root "$n.json"
  if (-not (Test-Path $f)) { throw "no theme called $n" }
  Get-Content $f -Raw | ConvertFrom-Json
}

function Get-Themes {
  Get-ChildItem $root -Filter *.json -ErrorAction Ignore | ? BaseName -ne 'current' | % BaseName
}

function Get-Nvims { [IO.Directory]::GetFiles('\\.\pipe\') -like '*nvim*' }

function Nvim-Expr($server, $expr) { nvim --headless --server $server --remote-expr $expr 2>$null }

function Get-Current { if (Test-Path $current) { (Get-Content $current -Raw | ConvertFrom-Json).name } }

# keeps the rest of settings.json as it is, ConvertTo-Json would reformat all of it
function Set-ClaudeTheme($value) {
  if (-not $value -or -not (Test-Path $claude)) { return }
  $text = Get-Content $claude -Raw
  if ($text -notmatch '"theme"\s*:\s*"[^"]*"') { Write-Warning 'no "theme" in claude settings, left it'; return }
  $text -replace '"theme"\s*:\s*"[^"]*"', "`"theme`": `"$value`"" | Set-Content $claude -NoNewline
}

function Apply {
  $t = Get-Theme $Name
  $t | Add-Member name $Name -Force
  # wezterm watches this file and reloads on its own
  $t | ConvertTo-Json | Set-Content $current

  $n = 0
  foreach ($s in Get-Nvims) {
    Nvim-Expr $s "execute('colorscheme $($t.nvim)')" | Out-Null
    $n++
  }
  Set-ClaudeTheme $t.claude
  "switched to $Name, $n nvim"
}

# the current theme with whatever nvim and claude code are actually using now
function Save {
  if ($Name -notmatch '^[\w.-]+$' -or $Name -eq 'current') { throw "bad name '$Name', stick to letters, numbers, . - _" }
  $t = if (Test-Path $current) { Get-Content $current -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  $t.PSObject.Properties.Remove('name')

  foreach ($s in Get-Nvims) {
    if ($c = Nvim-Expr $s 'get(g:, "colors_name", "")') { $t | Add-Member nvim $c -Force; break }
  }
  if ((Test-Path $claude) -and (Get-Content $claude -Raw) -match '"theme"\s*:\s*"([^"]*)"') {
    $t | Add-Member claude $Matches[1] -Force
  }

  $f = Join-Path $root "$Name.json"
  $existed = Test-Path $f
  New-Item -ItemType Directory $root -Force | Out-Null
  $t | ConvertTo-Json | Set-Content $f
  "$(($existed) ? 'updated' : 'saved') $Name"
}

function Rows {
  $on = Get-Current
  foreach ($n in Get-Themes) {
    $t = Get-Theme $n
    $bg = if ($t.background) { Split-Path $t.background -Leaf } else { 'no image' }
    '{0} {1,-14} wezterm {2,-10} nvim {3,-10} {4}' -f (($n -eq $on) ? '*' : ' '), $n, $t.wezterm, $t.nvim, $bg
  }
}

# arrow key menu like claude code's, returns the index or $null on esc
function Menu($title, $items, $start = 0) {
  $i = $start
  Write-Host "`n $title`n"
  [Console]::CursorVisible = $false
  try {
    while ($true) {
      for ($n = 0; $n -lt $items.Count; $n++) {
        $line = '{0}. {1}' -f ($n + 1), $items[$n]
        if ($n -eq $i) { Write-Host "`e[2K `e[36m❯ $line`e[0m" } else { Write-Host "`e[2K   $line" }
      }
      Write-Host "`e[2K`e[90m   ↑/↓ move  enter pick  esc cancel`e[0m" -NoNewline
      $k = [Console]::ReadKey($true)
      $pick = $null
      if ($k.Key -eq 'UpArrow' -or $k.KeyChar -eq 'k') { $i = ($i - 1 + $items.Count) % $items.Count }
      elseif ($k.Key -eq 'DownArrow' -or $k.KeyChar -eq 'j') { $i = ($i + 1) % $items.Count }
      elseif ($k.Key -eq 'Enter') { $pick = $i }
      elseif ($k.KeyChar -match '\d' -and [int]"$($k.KeyChar)" -ge 1 -and [int]"$($k.KeyChar)" -le $items.Count) { $pick = [int]"$($k.KeyChar)" - 1 }
      elseif ($k.Key -eq 'Escape' -or $k.KeyChar -eq 'q') { $pick = -1 }
      # back up to the first item and redraw over it
      Write-Host "`r`e[$($items.Count)A" -NoNewline
      if ($null -ne $pick) {
        Write-Host "`e[0J" -NoNewline
        if ($pick -lt 0) { Write-Host '   cancelled'; return $null }
        Write-Host " `e[36m❯ $($items[$pick])`e[0m"
        return $pick
      }
    }
  } finally { [Console]::CursorVisible = $true }
}

function Pick($title) {
  $names = @(Get-Themes)
  if (-not $names) { throw 'no themes yet' }
  $n = Menu $title @(Rows) ([math]::Max(0, [array]::IndexOf($names, (Get-Current))))
  if ($null -eq $n) { exit }
  $names[$n]
}

function Confirm($title) { (Menu $title 'No', 'Yes') -eq 1 }

switch ($Cmd) {
  'save' { if (-not $Name) { throw 'wzt save <name>' }; Save }
  'ls' { Rows }
  'rm' {
    if (-not $Name) { $Name = Pick 'remove which?' }
    if ($Name -eq (Get-Current)) { throw "$Name is the one in use, switch first" }
    Get-Theme $Name | Out-Null
    if (-not (Confirm "remove ${Name}?")) { exit }
    Remove-Item (Join-Path $root "$Name.json")
    "removed $Name"
  }
  { $_ -in 'help', '-h', '--help' } {
    'wzt                 pick a theme'
    'wzt <name>          switch to it'
    'wzt save <name>     save what nvim and claude code are using now as a theme'
    'wzt ls              list themes, * is the one in use'
    'wzt rm [name]       remove one'
  }
  '' { $Name = Pick 'themes'; Apply }
  default { $Name = $Cmd; Apply }
}
