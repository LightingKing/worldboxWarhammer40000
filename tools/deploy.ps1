# Builds the sprites and the mod, then replaces Mods\40KBox with a clean copy.
# The previous install is moved to 40KBox-backups (outside Mods, or NML would
# load it as a second mod). Run with pwsh; WorldBox must be closed.
[CmdletBinding()]
param(
    [string]$WorldBoxInstall = 'H:\SteamLibrary\steamapps\common\worldbox'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repo 'src\FortyKBox\FortyKBox.csproj'
$output = Join-Path $repo 'src\FortyKBox\bin\Release\net48'
$target = Join-Path $WorldBoxInstall 'Mods\40KBox'
$backups = Join-Path $WorldBoxInstall '40KBox-backups'

if (Get-Process worldbox -ErrorAction SilentlyContinue) {
    throw 'WorldBox is running; close it before deploying.'
}

# The WinGet godot shim does not set $LASTEXITCODE, so wait on the process.
$godotProject = Join-Path $repo 'godot'
$godot = Start-Process godot -ArgumentList "--headless --path `"$godotProject`" --script res://build_sprites.gd" `
    -NoNewWindow -Wait -PassThru
if ($godot.ExitCode -ne 0) { throw 'Sprite build failed; nothing was deployed.' }

& dotnet build $project -c Release --nologo "-p:WorldBoxInstall=$WorldBoxInstall"
if ($LASTEXITCODE -ne 0) { throw 'Mod build failed; nothing was deployed.' }

if (Test-Path $target) {
    New-Item -ItemType Directory -Force $backups | Out-Null
    $backup = Join-Path $backups ('40KBox-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item $target $backup
    Write-Host "Previous install moved to $backup"
}

New-Item -ItemType Directory -Force $target | Out-Null
foreach ($item in '40KBox.dll', '40KBox.pdb', 'mod.json', 'icon.png', 'Locales', 'GameResources') {
    Copy-Item (Join-Path $output $item) $target -Recurse
}

$files = (Get-ChildItem $target -Recurse -File).Count
Write-Host "Deployed $files files to $target"
