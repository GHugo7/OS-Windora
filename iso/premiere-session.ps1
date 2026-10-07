# Windora : lancé une seule fois par Windows, à la première ouverture de session après son
# installation depuis un ISO ou une clé Windora (voir autounattend.xml).
#
# À ce moment, le bureau n'est pas encore affiché : on programme donc la suite de
# l'installation (installer.cmd) dans le dossier Démarrage de l'utilisateur. Elle s'ouvre
# dès que le bureau apparaît, et le lanceur s'efface aussitôt : il ne sert qu'une fois.
# Si l'installation s'interrompt, il suffit de relancer C:\Windora\installer.cmd.

param(
    # Dossier Démarrage de l'utilisateur (modifiable pour les tests).
    [string]$Startup = [Environment]::GetFolderPath('Startup')
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$installer = Join-Path $here 'installer.cmd'
if (-not (Test-Path -LiteralPath $installer)) { exit 1 }

New-Item -ItemType Directory -Path $Startup -Force | Out-Null
$launcher = Join-Path $Startup 'windora-installation.cmd'
# (goto) 2>nul & del "%~f0" : le fichier .cmd s'efface lui-même sans message d'erreur.
$lines = @(
    '@echo off'
    'rem Windora : suite de l''installation, lancee une seule fois.'
    "start `"Windora`" `"$installer`""
    '(goto) 2>nul & del "%~f0"'
)
# Fichier .cmd en ANSI : le chemin de Windora (C:\Windora) ne contient que de l'ASCII.
[IO.File]::WriteAllText($launcher, (($lines -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
