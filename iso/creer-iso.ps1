<#
.SYNOPSIS
    Windora en installation complète : un ISO (ou une clé USB) qui installe Windows ET
    Windora d'un seul coup, sur un PC vide.

.DESCRIPTION
    Part de TON image officielle de Windows 11 (téléchargée chez Microsoft) et y ajoute :
      - autounattend.xml : à la première ouverture de session, la suite de l'installation
        de Windora (Fedora, intégration, allègement, apparence) démarre toute seule ;
      - le dossier Windora, copié dans C:\Windora pendant l'installation de Windows.

    L'installation de Windows reste normale : tu choisis la langue, le disque et le compte.
    Rien n'est contourné (TPM, Secure Boot, activation) : Vanguard en a besoin, et la
    licence de Windows reste la tienne. L'image créée est pour ton usage : la licence de
    Windows interdit de la partager.

    Deux façons de faire :
      - ISO  : il faut l'outil oscdimg de Microsoft (« Outils de déploiement » du kit ADK) ;
               le script propose de l'installer ;
      - clé  : -Cle E: prépare une clé USB créée avec l'outil de création de support de
               Microsoft. Rien d'autre à installer.

.EXAMPLE
    .\creer-iso.ps1                                    # demande l'ISO de Windows à utiliser
.EXAMPLE
    .\creer-iso.ps1 -Iso D:\Win11_25H2_French_x64.iso -Sortie D:\Windora.iso
.EXAMPLE
    .\creer-iso.ps1 -Cle E:                            # clé USB d'installation de Windows
#>
[CmdletBinding()]
param(
    # Image ISO officielle de Windows 11 (ou 10).
    [string]$Iso,
    # ISO à créer (par défaut : à côté de l'ISO de départ).
    [string]$Sortie,
    # Lettre (E:) ou dossier d'une clé USB d'installation de Windows à préparer.
    [string]$Cle,
    # Usage interne : relancé en administrateur.
    [switch]$Eleve
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:IsoDir = Join-Path $script:Root 'iso'
# Fichiers de Windora copiés sur le support (les extras ne servent pas à l'installation).
$script:PayloadFiles = @('installer.cmd', 'setup.ps1', 'allegement.psd1', 'fxw-profile.ps1', 'README.md')
$script:PayloadDirs = @('fedora', 'assets')
$script:DownloadPage = 'https://www.microsoft.com/software-download/windows11'

function Write-Step([string]$Text) { Write-Host ''; Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Info([string]$Text) { Write-Host "    $Text" }
function Write-Warn([string]$Text) { Write-Host "    [!] $Text" -ForegroundColor Yellow }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Un support d'installation de Windows : setup.exe, l'image de démarrage et celle du système.
function Test-WindowsMedia([string]$Path) {
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'setup.exe'))) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'sources\boot.wim'))) { return $false }
    foreach ($image in @('install.wim', 'install.esd', 'install.swm')) {
        if (Test-Path -LiteralPath (Join-Path $Path "sources\$image")) { return $true }
    }
    return $false
}

# Ajoute Windora à un support d'installation de Windows (dossier d'ISO ou clé USB).
function Add-WindoraPayload([string]$MediaRoot) {
    $answer = Join-Path $MediaRoot 'autounattend.xml'
    if (Test-Path -LiteralPath $answer) {
        $existing = [IO.File]::ReadAllText($answer)
        if ($existing -notmatch 'Windora') {
            # Par exemple celui de Rufus : gardé à côté, mais remplacé.
            Copy-Item -LiteralPath $answer -Destination "$answer.avant-windora" -Force
            Write-Warn 'Ce support avait déjà un autounattend.xml : copie gardée (autounattend.xml.avant-windora).'
        }
    }
    Copy-Item -LiteralPath (Join-Path $script:IsoDir 'autounattend.xml') -Destination $answer -Force

    # sources\$OEM$\$1\X est copié par Windows dans C:\X pendant l'installation.
    $target = Join-Path $MediaRoot 'sources\$OEM$\$1\Windora'
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($f in $script:PayloadFiles) {
        Copy-Item -LiteralPath (Join-Path $script:Root $f) -Destination $target -Force
    }
    foreach ($d in $script:PayloadDirs) {
        Copy-Item -LiteralPath (Join-Path $script:Root $d) -Destination $target -Recurse -Force
    }
    Copy-Item -LiteralPath (Join-Path $script:IsoDir 'premiere-session.ps1') -Destination $target -Force
    # Sans la marque « téléchargé d'Internet » (gardée sur une clé NTFS) : pas d'avertissement
    # de sécurité au lancement de l'installation, à la première ouverture de session.
    try {
        Get-ChildItem -LiteralPath $target -Recurse -File | Unblock-File
    } catch {
        Write-Verbose "Fichiers non débloqués : $($_.Exception.Message)"
    }
    Write-Ok 'Windora ajouté (autounattend.xml et sources\$OEM$\$1\Windora)'
}

# ------------------------------------------------------------------ clé USB

function Resolve-KeyRoot([string]$Value) {
    if ($Value -match '^([A-Za-z]):?\\?$') { return "$($Matches[1].ToUpperInvariant()):\" }
    return $Value
}

function Update-UsbKey([string]$Value) {
    $root = Resolve-KeyRoot $Value
    Write-Step "Clé USB d'installation : $root"
    if (-not (Test-Path -LiteralPath $root)) { throw "Lecteur introuvable : $root" }
    if (-not (Test-WindowsMedia $root)) {
        throw "$root n'est pas une clé d'installation de Windows. Crée-la d'abord avec l'outil de création de support de Microsoft ($script:DownloadPage)."
    }
    Add-WindoraPayload $root
    Write-Step 'Clé prête'
    Write-Info "Démarre le PC sur la clé et installe Windows comme d'habitude : à la première"
    Write-Info 'ouverture de session, l''installation de Windora se lance toute seule.'
    Write-Info 'Une fois Windows installé, retire la clé (elle ne sert plus).'
}

# ------------------------------------------------------------------ ISO

function Select-SourceIso {
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    $found = @(Get-ChildItem -LiteralPath $downloads -Filter '*.iso' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Win' -and $_.Name -notmatch '^Windora' })
    if ($found.Count -eq 1) {
        $answer = Read-Host "    Utiliser $($found[0].FullName) ? [O/n]"
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^\s*[oOyY]') { return $found[0].FullName }
    }
    Write-Info 'Choisis l''image ISO officielle de Windows 11 dans la fenêtre qui s''ouvre...'
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Image ISO officielle de Windows 11'
    $dialog.Filter = 'Image disque (*.iso)|*.iso'
    if (Test-Path -LiteralPath $downloads) { $dialog.InitialDirectory = $downloads }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.FileName }
    Write-Info "Pas d'ISO de Windows ? Télécharge-la gratuitement chez Microsoft :"
    Write-Info "  $script:DownloadPage  (« Télécharger l'image disque (ISO) de Windows 11 »)"
    Start-Process $script:DownloadPage
    return $null
}

function Find-Oscdimg {
    $cmd = Get-Command oscdimg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) { 'ARM64' { 'arm64' } 'x86' { 'x86' } default { 'amd64' } }
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (-not $base) { continue }
        $path = Join-Path $base "Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$arch\Oscdimg\oscdimg.exe"
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return $null
}

function Install-Oscdimg {
    Write-Info 'Il faut oscdimg, l''outil de Microsoft qui fabrique les ISO de Windows.'
    Write-Info 'Il fait partie du kit ADK (seuls les « Outils de déploiement » sont installés, ~100 Mo).'
    $answer = Read-Host '    L''installer maintenant ? [O/n]'
    if (-not ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^\s*[oOyY]')) { return }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Warn 'winget est absent.'
        return
    }
    & winget.exe install -e --id Microsoft.WindowsADK --source winget --accept-package-agreements `
        --accept-source-agreements --override '/quiet /norestart /ceip off /features OptionId.DeploymentTools'
}

function New-WindoraIso([string]$Source, [string]$Output) {
    $oscdimg = Find-Oscdimg
    if (-not $oscdimg) {
        Install-Oscdimg
        $oscdimg = Find-Oscdimg
    }
    if (-not $oscdimg) {
        throw ("oscdimg introuvable. Installe le kit ADK de Microsoft en ne cochant que « Outils de déploiement » " +
            '(https://learn.microsoft.com/windows-hardware/get-started/adk-install), ou prépare plutôt une clé USB : ' +
            'creer-iso.cmd -Cle E:')
    }

    # Assez de place pour la copie de travail et le nouvel ISO.
    $outDir = Split-Path -Parent $Output
    $size = (Get-Item -LiteralPath $Source).Length
    $free = ([IO.DriveInfo]([IO.Path]::GetPathRoot($outDir))).AvailableFreeSpace
    if ($free -lt (2 * $size + 1GB)) {
        throw ("Pas assez de place sur $([IO.Path]::GetPathRoot($outDir)) : il faut $([math]::Ceiling((2 * $size + 1GB) / 1GB)) Go libres " +
            '(choisis un autre dossier avec -Sortie).')
    }

    $work = Join-Path $outDir "windora-iso-travail-$PID"
    $mounted = $false
    try {
        Write-Step 'Lecture de l''ISO de Windows'
        # Déjà ouvert (double-clic dans l'Explorateur) : on le réutilise et on le laisse ouvert.
        if (-not (Get-DiskImage -ImagePath $Source).Attached) {
            Mount-DiskImage -ImagePath $Source | Out-Null
            $mounted = $true
        }
        $letter = $null
        for ($i = 0; $i -lt 20 -and -not $letter; $i++) {
            $volume = Get-DiskImage -ImagePath $Source | Get-Volume | Where-Object { $_.DriveLetter } | Select-Object -First 1
            if ($volume) { $letter = $volume.DriveLetter } else { Start-Sleep -Milliseconds 500 }
        }
        if (-not $letter) { throw 'L''ISO a été ouvert, mais Windows ne lui a pas donné de lettre de lecteur.' }
        $sourceRoot = "$($letter):\"
        if (-not (Test-WindowsMedia $sourceRoot)) { throw "$Source n'est pas une image d'installation de Windows." }

        Write-Step 'Copie de l''ISO (quelques minutes)'
        & robocopy.exe $sourceRoot $work /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "La copie de l'ISO a échoué (robocopy, code $LASTEXITCODE)." }
        if ($mounted) {
            Dismount-DiskImage -ImagePath $Source | Out-Null
            $mounted = $false
        }
        Write-Ok "copié dans $work"

        Write-Step 'Ajout de Windora'
        Add-WindoraPayload $work

        Write-Step "Fabrication de $Output"
        # Démarrage BIOS (etfsboot.com) et UEFI (efisys.bin), comme l'ISO officiel. Les ISO ARM
        # n'ont que l'UEFI. Ligne de commande écrite telle quelle : oscdimg veut les guillemets
        # collés à b"chemin", ce que Windows PowerShell 5.1 ne sait pas transmettre autrement.
        $efi = Join-Path $work 'efi\microsoft\boot\efisys.bin'
        $bios = Join-Path $work 'boot\etfsboot.com'
        if (-not (Test-Path -LiteralPath $efi)) { throw 'efisys.bin introuvable dans l''ISO : image de Windows non prise en charge.' }
        $bootData = if (Test-Path -LiteralPath $bios) {
            "2#p0,e,b`"$bios`"#pEF,e,b`"$efi`""
        } else {
            "1#pEF,e,b`"$efi`""
        }
        if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
        $argLine = "-m -o -u2 -udfver102 -lWINDORA -bootdata:$bootData `"$work`" `"$Output`""
        $p = Start-Process -FilePath $oscdimg -ArgumentList $argLine -NoNewWindow -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "oscdimg a échoué (code $($p.ExitCode))." }
        Write-Ok $Output
    } finally {
        if ($mounted) { Dismount-DiskImage -ImagePath $Source -ErrorAction SilentlyContinue | Out-Null }
        if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Write-Step 'ISO Windora prêt'
    Write-Info 'Pour l''installer sur un PC : écris-le sur une clé USB avec Rufus (rufus.ie). À la'
    Write-Info 'question « Personnalisation de l''installation de Windows », décoche tout : sinon'
    Write-Info 'Rufus remplace le fichier de Windora et peut retirer les vérifications TPM et Secure'
    Write-Info 'Boot, dont Vanguard a besoin. Il marche aussi tel quel dans une machine virtuelle.'
    Write-Info 'Cet ISO contient Windows : il est pour ton usage, ne le partage pas.'
}

# ------------------------------------------------------------------ programme principal

function Start-Main {
    Write-Host 'Windora : installation complète (Windows + Windora)' -ForegroundColor Cyan
    if ($Cle) {
        Update-UsbKey $Cle
        return
    }

    if (-not $Iso) { $Iso = Select-SourceIso }
    if (-not $Iso) { return }
    $Iso = (Resolve-Path -LiteralPath $Iso).ProviderPath
    if (-not $Sortie) {
        $Sortie = Join-Path (Split-Path -Parent $Iso) ("Windora-" + [IO.Path]::GetFileName($Iso))
    }
    $Sortie = [IO.Path]::GetFullPath($Sortie)
    if ($Sortie -notmatch '\.iso$') { throw '-Sortie doit être un fichier .iso.' }
    if ($Sortie -eq $Iso) { throw 'L''ISO créé ne peut pas remplacer celui de départ : choisis un autre nom avec -Sortie.' }
    if (-not $Eleve -and (Test-Path -LiteralPath $Sortie)) {
        $answer = Read-Host "    $Sortie existe déjà. Le remplacer ? [o/N]"
        if ($answer -notmatch '^\s*[oOyY]') { return }
    }

    # Ouvrir un ISO (Mount-DiskImage) demande les droits administrateur.
    if (-not (Test-Admin)) {
        Write-Info 'Windows va demander l''autorisation administrateur (ouverture de l''ISO).'
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
            '-Iso', "`"$Iso`"", '-Sortie', "`"$Sortie`"", '-Eleve')
        try {
            $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList $argList
        } catch {
            throw 'Autorisation administrateur refusée.'
        }
        if ($p.ExitCode -ne 0) { throw 'La fabrication de l''ISO a échoué (voir la fenêtre administrateur).' }
        Write-Ok "ISO créé : $Sortie"
        return
    }
    New-WindoraIso $Iso $Sortie
}

if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = 0
    try {
        Start-Main
    } catch {
        Write-Host ''
        Write-Host "Erreur : $($_.Exception.Message)" -ForegroundColor Red
        $exitCode = 1
    } finally {
        # Fenêtre administrateur ouverte à part : on la laisse ouverte pour lire.
        if ($Eleve) { Read-Host 'Appuie sur Entrée pour fermer' | Out-Null }
    }
    exit $exitCode
}
