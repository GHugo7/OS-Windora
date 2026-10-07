<#
.SYNOPSIS
    Windora : Windows pour les jeux et les .exe, la vraie Fedora
    intégrée (WSL) pour les commandes et les logiciels Linux.

.DESCRIPTION
    - installe WSL et la Fedora officielle, crée ton compte Linux ;
    - le Terminal Windows s'ouvre directement sur Fedora (sudo dnf install ... sans rien lancer) ;
    - PowerShell comprend aussi « sudo dnf ... », « dnf ... » et les commandes Linux ;
    - « installer » installe des logiciels Fedora ET Windows dans la même commande ;
    - double-clic sur un .rpm = installé dans Fedora ;
    - allège Windows (applis inutiles, télémétrie, pubs) sans toucher à la sécurité ni à Vanguard ;
    - habillage façon GNOME (thème sombre, fond d'écran, polices Adwaita) ;
    - vérifie que le PC est prêt pour Vanguard (Secure Boot, TPM 2.0, isolation du noyau).

    Le plus simple : double-clic sur installer.cmd.

.EXAMPLE
    .\setup.ps1                 # installation interactive
.EXAMPLE
    .\setup.ps1 -Check          # vérifie seulement le PC (Vanguard, WSL)
.EXAMPLE
    .\setup.ps1 -Restore        # annule l'habillage et l'allègement
#>
[CmdletBinding()]
param(
    # Répond oui à toutes les questions.
    [switch]$Yes,
    # Nom du compte Linux (par défaut : dérivé du nom Windows).
    [string]$UserName,
    # Pas d'applications graphiques GNOME dans Fedora.
    [switch]$NoGuiApps,
    # Pas de compilateur Windows (MinGW) dans Fedora.
    [switch]$NoDev,
    # Pas d'habillage façon GNOME.
    [switch]$NoLook,
    # Pas d'allègement de Windows.
    [switch]$NoSlim,
    # N'installe pas Steam.
    [switch]$NoSteam,
    # Vérifie seulement si le PC est prêt (Vanguard, WSL), sans rien changer.
    [switch]$Check,
    # Annule l'habillage, l'allègement et l'intégration (Fedora et tes fichiers sont gardés).
    [switch]$Restore,
    # Usage interne : phase administrateur, fichier de résultat, reprise après redémarrage.
    [switch]$AdminPhase,
    [string]$ResultFile,
    [switch]$Resume,
    [string]$BackupFile,
    [string]$ParentSid
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:WSL_UTF8 = '1'   # wsl.exe écrit en UTF-16 sinon
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$script:Version = '1.0'
$script:Distro = 'Fedora'
$script:Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:AppDir = Join-Path $env:LOCALAPPDATA 'Windora'
$script:UserBackup = Join-Path $script:AppDir 'sauvegarde-utilisateur.json'
$script:AdminBackup = Join-Path $script:AppDir 'sauvegarde-systeme.json'
$script:Notes = New-Object System.Collections.Generic.List[string]

# Polices GNOME (licence OFL), versions figées et vérifiées par empreinte SHA-256.
$script:Fonts = @(
    @{ File = 'AdwaitaSans-Regular.ttf'; Name = 'Adwaita Sans (TrueType)'
       Url = 'https://raw.githubusercontent.com/GNOME/adwaita-fonts/51.0/sans/AdwaitaSans-Regular.ttf'
       Sha256 = '8381c33b9a44f066f2b99dba3d416a2342891e28c956a35dfd8d16ee2987e6d4' }
    @{ File = 'AdwaitaSans-Italic.ttf'; Name = 'Adwaita Sans Italic (TrueType)'
       Url = 'https://raw.githubusercontent.com/GNOME/adwaita-fonts/51.0/sans/AdwaitaSans-Italic.ttf'
       Sha256 = 'a3dc55af75f746756596dca37f3ff7c0f0b015f2fd2e87f2cf0ef4a69d4f3015' }
    @{ File = 'AdwaitaMono-Regular.ttf'; Name = 'Adwaita Mono (TrueType)'
       Url = 'https://raw.githubusercontent.com/GNOME/adwaita-fonts/51.0/mono/AdwaitaMono-Regular.ttf'
       Sha256 = 'ffc549b7fc28057d624086111f1ba0b1f752d2d7ff7c5363dfa064e4dca17d47' }
    @{ File = 'AdwaitaMono-Bold.ttf'; Name = 'Adwaita Mono Bold (TrueType)'
       Url = 'https://raw.githubusercontent.com/GNOME/adwaita-fonts/51.0/mono/AdwaitaMono-Bold.ttf'
       Sha256 = '9963c9a54805dd29cd803aa5f816c9f7c74c7bdae015467a485ae729868d2325' }
    @{ File = 'AdwaitaMono-Italic.ttf'; Name = 'Adwaita Mono Italic (TrueType)'
       Url = 'https://raw.githubusercontent.com/GNOME/adwaita-fonts/51.0/mono/AdwaitaMono-Italic.ttf'
       Sha256 = '20795e28c01f7df230002925d93e16cfe1bc1ab9e84426ac106344fb419cb57b' }
    @{ File = 'AdwaitaMono-BoldItalic.ttf'; Name = 'Adwaita Mono Bold Italic (TrueType)'
       Url = 'https://raw.githubusercontent.com/GNOME/adwaita-fonts/51.0/mono/AdwaitaMono-BoldItalic.ttf'
       Sha256 = '7108404fc597fa8586b822c6d03b676caad353be1bc4a89adfab77084663a04e' }
)

# ------------------------------------------------------------------ affichage

function Write-Step([string]$Text) { Write-Host ''; Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Info([string]$Text) { Write-Host "    $Text" }
function Write-Warn([string]$Text) { Write-Host "    [!] $Text" -ForegroundColor Yellow }
function Add-Note([string]$Text) { $script:Notes.Add($Text) }

function Confirm-Choice([string]$Question, [bool]$Default = $true) {
    if ($Yes) { return $true }
    $hint = if ($Default) { '[O/n]' } else { '[o/N]' }
    $answer = Read-Host "    $Question $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return ($answer -match '^\s*[oOyY]')
}

# ------------------------------------------------------------------ outils

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Lance un programme externe sans que ses messages d'erreur arrêtent le script.
function Invoke-Native([string]$FilePath, [string[]]$Arguments = @(), [switch]$Capture) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($Capture) {
            $output = (& $FilePath @Arguments 2>$null | Out-String)
        } else {
            & $FilePath @Arguments | Out-Host
            $output = ''
        }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Write-Utf8File([string]$Path, [string]$Text, [switch]$Bom) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($Bom.IsPresent)))
}

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json)
}

# ---- sauvegarde de tout ce qui est modifié, pour pouvoir revenir en arrière (-Restore)

$script:Backup = New-Object System.Collections.Generic.List[object]

function Save-RegistryValue([string]$Path, [string]$Name) {
    foreach ($entry in $script:Backup) {
        if ($entry.Type -eq 'Registry' -and $entry.Path -eq $Path -and $entry.Name -eq $Name) { return }
    }
    $existed = $false
    $value = $null
    $kind = $null
    $netName = if ($Name -eq '(default)') { '' } else { $Name }
    if (Test-Path -LiteralPath $Path) {
        $key = Get-Item -LiteralPath $Path
        if ($key.GetValueNames() -contains $netName) {
            $existed = $true
            $value = $key.GetValue($netName, $null, 'DoNotExpandEnvironmentNames')
            $kind = $key.GetValueKind($netName).ToString()
        }
    }
    $script:Backup.Add([pscustomobject]@{ Type = 'Registry'; Path = $Path; Name = $Name
        Existed = $existed; Value = $value; Kind = $kind })
}

function Set-RegistryValue([string]$Path, [string]$Name, $Value, [string]$Kind = 'DWord') {
    Save-RegistryValue $Path $Name
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Kind -Force | Out-Null
        return $true
    } catch {
        # Certaines clés sont protégées par Windows (UCPD) : on n'insiste pas.
        Write-Warn "Réglage refusé par Windows : $Path\$Name"
        return $false
    }
}

# Ce réglage a-t-il déjà été sauvegardé lors d'un passage précédent ?
function Test-AlreadyBackedUp([string]$Type, [string]$Path) {
    foreach ($e in @(Read-JsonFile $script:UserBackup)) {
        if ($e -and $e.Type -eq $Type -and $e.Path -eq $Path) { return $true }
    }
    return $false
}

function Save-Backup([string]$File) {
    $previous = @()
    $old = Read-JsonFile $File
    if ($old) { $previous = @($old) }
    # On garde la valeur d'origine si elle a déjà été sauvegardée lors d'un passage précédent.
    $merged = New-Object System.Collections.Generic.List[object]
    foreach ($p in $previous) { $merged.Add($p) }
    foreach ($b in $script:Backup) {
        $dup = $false
        foreach ($p in $previous) {
            if ($p.Type -eq $b.Type -and $p.Path -eq $b.Path -and $p.Name -eq $b.Name) { $dup = $true }
        }
        if (-not $dup) { $merged.Add($b) }
    }
    Write-Utf8File $File (ConvertTo-Json -InputObject ([object[]]$merged.ToArray()) -Depth 5)
    $script:Backup.Clear()
}

function Restore-Backup([string]$File) {
    $entries = Read-JsonFile $File
    if (-not $entries) { return }
    $failed = New-Object System.Collections.Generic.List[object]
    foreach ($e in @($entries)) {
        try {
            switch ($e.Type) {
                'Registry' {
                    if ($e.Existed) {
                        if (-not (Test-Path -LiteralPath $e.Path)) { New-Item -Path $e.Path -Force | Out-Null }
                        $value = $e.Value
                        if ($e.Kind -eq 'Binary') { $value = [byte[]]@($e.Value) }
                        New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value $value -PropertyType $e.Kind -Force | Out-Null
                    } elseif (Test-Path -LiteralPath $e.Path) {
                        Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue
                    }
                }
                'Task' {
                    Enable-ScheduledTask -TaskPath $e.Path -TaskName $e.Name | Out-Null
                }
                'ExecutionPolicy' {
                    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $e.Value -Force
                }
                'File' {
                    # Fichier modifié : on remet la copie d'origine, ou on le supprime s'il n'existait pas.
                    if ($e.Value -and (Test-Path -LiteralPath $e.Value)) {
                        Move-Item -LiteralPath $e.Value -Destination $e.Path -Force
                    } elseif (-not $e.Value) {
                        Remove-Item -LiteralPath $e.Path -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch {
            Write-Warn "Impossible de restaurer $($e.Path)\$($e.Name) : $($_.Exception.Message)"
            $failed.Add($e)
        }
    }
    if ($failed.Count) {
        # Gardées pour un prochain -Restore (par exemple une fois le blocage levé).
        Write-Utf8File $File (ConvertTo-Json -InputObject ([object[]]$failed.ToArray()) -Depth 5)
    } else {
        Remove-Item -LiteralPath $File -Force
    }
}

# ------------------------------------------------------------------ vérifications

function Get-Readiness {
    $r = [ordered]@{ Build = [Environment]::OSVersion.Version.Build }
    # Secure Boot : cette valeur du registre est lisible même sans droits administrateur.
    $sb = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -ErrorAction SilentlyContinue
    $r.SecureBoot = [bool]($sb -and $sb.PSObject.Properties.Name -contains 'UEFISecureBootEnabled' -and $sb.UEFISecureBootEnabled -eq 1)
    try {
        $tpm = Get-CimInstance -Namespace 'root/cimv2/security/microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop
        $r.Tpm2 = [bool]($tpm -and ([string]$tpm.SpecVersion).StartsWith('2.0'))
    } catch {
        # Sans droits administrateur : tpmtool donne la version.
        $info = Invoke-Native 'tpmtool.exe' @('getdeviceinformation') -Capture
        $r.Tpm2 = ($info.Output -match 'TPM.*2\.0')
    }
    try {
        $dg = Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        $r.Vbs = ($dg.VirtualizationBasedSecurityStatus -eq 2)
        $r.Hvci = (@($dg.SecurityServicesRunning) -contains 2)
    } catch { $r.Vbs = $false; $r.Hvci = $false }
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    # Quand l'hyperviseur Windows tourne déjà, le processeur ne signale plus la virtualisation.
    $r.Virtualization = [bool]($cs.HypervisorPresent -or $cpu.VirtualizationFirmwareEnabled)
    return $r
}

function Show-Readiness($r) {
    Write-Step 'Le PC est-il prêt pour Vanguard (Valorant, LoL) et pour Fedora ?'
    $rows = @(
        @{ Ok = ($r.Build -ge 22000); Label = 'Windows 11'
           Fix = 'Windows 10 n''est plus maintenu ; Vanguard « à la demande » exige Windows 11 25H2.' }
        @{ Ok = $r.SecureBoot; Label = 'Secure Boot activé'
           Fix = 'BIOS/UEFI > Boot > Secure Boot : Enabled (le disque doit être en GPT/UEFI).' }
        @{ Ok = $r.Tpm2; Label = 'Puce TPM 2.0 active'
           Fix = 'BIOS/UEFI : activer fTPM (AMD) ou PTT (Intel).' }
        @{ Ok = $r.Virtualization; Label = 'Virtualisation du processeur (WSL)'
           Fix = 'BIOS/UEFI : activer SVM (AMD) ou VT-x (Intel).' }
        @{ Ok = $r.Hvci; Label = 'Isolation du noyau / intégrité de la mémoire (HVCI)'
           Fix = 'Sécurité Windows > Sécurité de l''appareil > Isolation du noyau > Intégrité de la mémoire.' }
    )
    foreach ($row in $rows) {
        if ($row.Ok) {
            Write-Host "    [OK] $($row.Label)" -ForegroundColor Green
        } else {
            Write-Host "    [!!] $($row.Label)" -ForegroundColor Yellow
            Write-Host "         -> $($row.Fix)" -ForegroundColor DarkGray
        }
    }
    if (-not $r.Hvci) {
        Add-Note 'Riot peut exiger l''intégrité de la mémoire (erreur « VAN: RESTRICTION: 5 ») : active-la dans Sécurité Windows > Isolation du noyau. Ne désactive jamais Hyper-V ni cette option « pour les jeux ».'
    }
    if (-not ($r.SecureBoot -and $r.Tpm2)) {
        Add-Note 'Sans Secure Boot et TPM 2.0, Valorant et LoL refusent de démarrer (erreur VAN9001 / VAN9003). Ces réglages se font dans le BIOS.'
    }
    Write-Info 'Riot n''a rien publié sur WSL ; WSL utilise le même hyperviseur que l''isolation du noyau'
    Write-Info 'exigée par Vanguard, donc ils sont compatibles en pratique. Vérifie avec l''outil'
    Write-Info '« Vanguard Pre-Check » de Riot si un jeu affiche une erreur VAN.'
}

# ------------------------------------------------------------------ phase administrateur

function Test-WslReady {
    $status = Invoke-Native 'wsl.exe' @('--status') -Capture
    if ($status.ExitCode -ne 0) { return $false }
    try {
        $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        return ($vmp.State -eq 'Enabled')
    } catch {
        return $true
    }
}

function Install-WingetPackage([string]$Id, [string]$Label) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Warn "winget est absent : installe « $Label » à la main (ou installe « Programme d'installation d'application » depuis le Microsoft Store)."
        return
    }
    $list = Invoke-Native 'winget.exe' @('list', '-e', '--id', $Id, '--accept-source-agreements') -Capture
    if ($list.ExitCode -eq 0 -and $list.Output -match [regex]::Escape($Id)) {
        Write-Ok "$Label déjà installé"
        return
    }
    Write-Info "Installation de $Label..."
    $r = Invoke-Native 'winget.exe' @('install', '-e', '--id', $Id, '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements', '--silent')
    if ($r.ExitCode -eq 0) { Write-Ok "$Label installé" } else { Write-Warn "$Label : échec (code $($r.ExitCode))" }
}

function Invoke-SystemSlimming {
    $planFile = Join-Path $script:Here 'allegement.psd1'
    if (-not (Test-Path -LiteralPath $planFile)) { return }
    $plan = Import-PowerShellDataFile -LiteralPath $planFile
    Write-Step 'Allègement de Windows (réversible avec -Restore)'
    # La sauvegarde est écrite même si une étape échoue en route.
    try {
        Invoke-SystemSlimmingSteps $plan
    } finally {
        Save-Backup $script:AdminBackup
    }
}

function Invoke-SystemSlimmingSteps($plan) {
    foreach ($svc in $plan.Services) {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if (-not $s) { continue }
        if ([string]$s.StartType -eq $svc.StartType) { continue }
        # Sauvegarde exacte du mode de démarrage (y compris « automatique différé »).
        $svcKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
        Save-RegistryValue $svcKey 'Start'
        Save-RegistryValue $svcKey 'DelayedAutostart'
        try {
            Set-Service -Name $svc.Name -StartupType $svc.StartType
            if ($svc.StartType -eq 'Disabled' -and $s.Status -eq 'Running') { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue }
            Write-Ok "$($svc.Label) : $($svc.StartType)"
        } catch {
            Write-Warn "$($svc.Label) : non modifiable"
        }
    }

    foreach ($reg in $plan.MachineRegistry) {
        if (Set-RegistryValue $reg.Path $reg.Name $reg.Value $reg.Kind) { Write-Ok $reg.Label }
    }

    # Stratégies du compte (HKCU\Software\Policies) : seul un administrateur peut les écrire.
    # On ne les applique que si l'administrateur est bien le compte de la session.
    $sameUser = (-not $ParentSid) -or ($ParentSid -eq [Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
    if ($plan.ContainsKey('AdminUserRegistry') -and $sameUser) {
        foreach ($reg in $plan.AdminUserRegistry) {
            if (Set-RegistryValue $reg.Path $reg.Name $reg.Value $reg.Kind) { Write-Ok $reg.Label }
        }
    }

    foreach ($t in $plan.Tasks) {
        $task = Get-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction SilentlyContinue
        if (-not $task -or $task.State -eq 'Disabled') { continue }
        $script:Backup.Add([pscustomobject]@{ Type = 'Task'; Path = $t.Path; Name = $t.Name })
        try {
            Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name | Out-Null
            Write-Ok "tâche de collecte désactivée : $($t.Name)"
        } catch {
            Write-Warn "tâche non modifiable : $($t.Name)"
        }
    }

    # Applications préinstallées : retirées pour tous les comptes et des futurs comptes.
    $provisioned = @()
    try { $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) }
    catch { Write-Warn 'Liste des applications préinstallées indisponible (DISM occupé ?) : seules les copies installées seront retirées.' }
    foreach ($app in $plan.Apps) {
        $found = @(Get-AppxPackage -AllUsers -Name $app.Name -ErrorAction SilentlyContinue)
        $prov = @($provisioned | Where-Object { $_.DisplayName -eq $app.Name })
        if (-not $found -and -not $prov) { continue }
        foreach ($p in $found) {
            try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop }
            catch { Write-Verbose "Remove-AppxPackage $($p.Name) : $($_.Exception.Message)" }
        }
        foreach ($p in $prov) {
            try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null }
            catch { Write-Verbose "Remove-AppxProvisionedPackage $($p.DisplayName) : $($_.Exception.Message)" }
        }
        Write-Ok "retiré : $($app.Label)"
    }
}

function Invoke-AdminPhase {
    $result = [ordered]@{ RebootRequired = $false; Readiness = $null }
    $result.Readiness = Get-Readiness

    Write-Step 'WSL (le sous-système qui fait tourner Fedora)'
    if (Test-WslReady) {
        Write-Ok 'WSL est installé'
        Invoke-Native 'wsl.exe' @('--update') | Out-Null
    } elseif (-not $result.Readiness.Virtualization) {
        Write-Warn 'La virtualisation est désactivée dans le BIOS : WSL ne peut pas fonctionner.'
    } else {
        $install = Invoke-Native 'wsl.exe' @('--install', '--no-distribution')
        if (-not (Test-WslReady)) {
            if ($Resume -or ($install.ExitCode -ne 0 -and $install.ExitCode -ne 3010)) {
                # Déjà redémarré, ou échec franc : redémarrer encore ne servirait à rien.
                throw "L'installation de WSL a échoué (code $($install.ExitCode)). Vérifie la connexion Internet, puis relance installer.cmd."
            }
            $result.RebootRequired = $true
            Write-Ok 'WSL installé : un redémarrage est nécessaire'
        }
    }

    Write-Step 'Applications Windows'
    if (-not (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue)) {
        Install-WingetPackage 'Microsoft.WindowsTerminal' 'Terminal Windows'
    } else {
        Write-Ok 'Terminal Windows déjà installé'
    }
    Install-WingetPackage 'Microsoft.PowerToys' 'PowerToys (recherche rapide Win+Alt+Espace, comme GNOME)'
    if (-not $NoSteam) { Install-WingetPackage 'Valve.Steam' 'Steam' }

    if (-not $NoSlim) { Invoke-SystemSlimming }
    return $result
}

# ------------------------------------------------------------------ Fedora (phase utilisateur)

function Get-WslDistributions {
    $r = Invoke-Native 'wsl.exe' @('--list', '--quiet') -Capture
    if ($r.ExitCode -ne 0) { return @() }
    return @($r.Output -split "`r?`n" | ForEach-Object { $_.Trim([char]0, ' ', "`t") } | Where-Object { $_ })
}

function Install-Fedora {
    Write-Step 'Fedora (image officielle du projet Fedora)'
    $distros = Get-WslDistributions
    $existing = $distros | Where-Object { $_ -eq $script:Distro } | Select-Object -First 1
    if (-not $existing) { $existing = $distros | Where-Object { $_ -like 'Fedora*' } | Select-Object -First 1 }
    if ($existing) {
        $script:Distro = $existing
        Write-Ok "Fedora déjà installée (« $existing »)"
        return
    }
    $r = Invoke-Native 'wsl.exe' @('--install', 'Fedora', '--name', $script:Distro, '--no-launch')
    if ((Get-WslDistributions) -notcontains $script:Distro) {
        throw "L'installation de Fedora a échoué (code $($r.ExitCode)). Relance le script ; si ça persiste : wsl --install Fedora --name Fedora"
    }
    Write-Ok 'Fedora installée'
}

function Get-DefaultLinuxUser {
    $name = $env:USERNAME.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $name = -join ($name.ToCharArray() | Where-Object {
            [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    $name = $name -replace '[^a-z0-9_-]', ''
    if ($name -notmatch '^[a-z_]') { $name = "u$name" }
    if ($name.Length -gt 32) { $name = $name.Substring(0, 32) }
    if ($name -eq 'u' -or $name -eq 'root') { $name = 'fedora' }
    return $name
}

function Get-LinuxPath([string]$WindowsPath) {
    $r = Invoke-Native 'wsl.exe' @('-d', $script:Distro, '-u', 'root', '-e', 'wslpath', '-u', $WindowsPath) -Capture
    if ($r.ExitCode -ne 0) { throw "Chemin inaccessible depuis Fedora : $WindowsPath" }
    return $r.Output.Trim()
}

# Copie les scripts destinés à Fedora en forçant les fins de ligne Linux (LF) : un clone Git
# sous Windows ou un éditeur peut les avoir converties en CRLF, que bash refuse.
function Copy-FedoraScripts {
    $dest = Join-Path $env:TEMP 'windora-fedora'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $script:Here 'fedora') -File) {
        $text = [IO.File]::ReadAllText($f.FullName).Replace("`r`n", "`n")
        Write-Utf8File (Join-Path $dest $f.Name) $text
    }
    return $dest
}

function Initialize-Fedora {
    Write-Step 'Configuration de Fedora'
    $user = $UserName
    if (-not $user) { $user = Get-DefaultLinuxUser }
    while ($user -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
        Write-Warn "Nom invalide : « $user » (minuscules, chiffres, - et _)"
        $user = Read-Host '    Nom du compte Linux'
    }
    if (-not $Yes -and -not $UserName) {
        $answer = Read-Host "    Nom du compte Linux [$user]"
        if ($answer -match '^[a-z_][a-z0-9_-]{0,31}$') { $user = $answer }
    }

    $scripts = Get-LinuxPath (Copy-FedoraScripts)
    $gui = if ($NoGuiApps) { '0' } else { '1' }
    $dev = if ($NoDev) { '0' } else { '1' }
    Write-Info 'Mise à jour et installation des logiciels (quelques minutes)...'
    $r = Invoke-Native 'wsl.exe' @('-d', $script:Distro, '-u', 'root', '-e', 'bash', "$scripts/provision.sh", $user, $gui, $dev)
    if ($r.ExitCode -ne 0) { throw "La configuration de Fedora a échoué (code $($r.ExitCode))." }

    # Compte réellement utilisé (celui qui existait déjà, le cas échéant).
    $passwd = Invoke-Native 'wsl.exe' @('-d', $script:Distro, '-u', 'root', '-e', 'getent', 'passwd', '1000') -Capture
    if ($passwd.Output -match '^([a-z_][a-z0-9_-]*):') { $user = $Matches[1] }
    Invoke-Native 'wsl.exe' @('--manage', $script:Distro, '--set-default-user', $user) -Capture | Out-Null
    Invoke-Native 'wsl.exe' @('--terminate', $script:Distro) -Capture | Out-Null
    Write-Ok "Fedora prête, compte « $user »"
    return $user
}

# ---- Terminal Windows : Fedora par défaut, couleurs et police GNOME

function Get-WslProfileGuid {
    $root = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    if (-not (Test-Path $root)) { return $null }
    foreach ($key in Get-ChildItem $root) {
        $props = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        if ($props.PSObject.Properties.Name -notcontains 'DistributionName') { continue }
        if ($props.DistributionName -ne $script:Distro) { continue }
        if ($props.PSObject.Properties.Name -contains 'TerminalProfilePath' -and
            -not [string]::IsNullOrEmpty($props.TerminalProfilePath) -and (Test-Path -LiteralPath $props.TerminalProfilePath)) {
            $fragment = Read-JsonFile $props.TerminalProfilePath
            foreach ($p in @($fragment.profiles)) {
                if ($p.PSObject.Properties.Name -contains 'guid' -and $p.PSObject.Properties.Name -contains 'commandline') { return $p.guid }
            }
        }
    }
    return $null
}

function Set-TerminalDefault([string]$Guid) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $done = $false
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $file = $candidates[$i]
        # Versions Store/Preview : le dossier du paquet ; version « portable » : son propre dossier.
        $installDir = if ($i -lt 2) { Split-Path -Parent (Split-Path -Parent $file) } else { Split-Path -Parent $file }
        if (-not (Test-Path -LiteralPath $installDir)) { continue }
        $pattern = '("defaultProfile"\s*:\s*")([^"]*)(")'
        if (Test-Path -LiteralPath $file) {
            $text = [IO.File]::ReadAllText($file)
            $m = [regex]::Match($text, $pattern)
            # Valeur d'origine ($null = la clé n'existait pas) : -Restore la remettra ou l'enlèvera.
            $original = if ($m.Success) { $m.Groups[2].Value } else { $null }
            if ($m.Success) {
                $text = [regex]::Replace($text, $pattern, ('${1}' + $Guid + '${3}'), 'None')
            } else {
                $text = [regex]::Replace($text, '^\s*\{', ("{`n    `"defaultProfile`": `"$Guid`","), 'None')
            }
            if (-not (Test-Path -LiteralPath "$file.avant-windora")) {
                Copy-Item -LiteralPath $file -Destination "$file.avant-windora"
            }
        } else {
            $original = $null
            $text = "{`n    `"defaultProfile`": `"$Guid`"`n}`n"
        }
        $script:Backup.Add([pscustomobject]@{ Type = 'TerminalDefault'; Path = $file; Name = 'defaultProfile'; Value = $original })
        Write-Utf8File $file $text
        $done = $true
    }
    return $done
}

function Set-TerminalIntegration {
    Write-Step 'Terminal Windows : s''ouvre directement sur Fedora'
    $guid = Get-WslProfileGuid
    if (-not $guid) {
        Write-Warn 'Profil Fedora du Terminal introuvable : ouvre le Terminal une fois, puis relance le script.'
        return
    }
    $fragment = [ordered]@{
        profiles = @([ordered]@{
                updates = $guid
                name = 'Fedora'
                colorScheme = 'Adwaita Dark (Windora)'
                padding = '10'
                cursorShape = 'bar'
                startingDirectory = '~'
            })
        schemes = @([ordered]@{
                name = 'Adwaita Dark (Windora)'
                background = '#1E1E1E'; foreground = '#FFFFFF'
                cursorColor = '#FFFFFF'; selectionBackground = '#3584E4'
                black = '#241F31'; red = '#C01C28'; green = '#2EC27E'; yellow = '#F5C211'
                blue = '#1E78E4'; purple = '#9841BB'; cyan = '#0AB9DC'; white = '#C0BFBC'
                brightBlack = '#5E5C64'; brightRed = '#ED333B'; brightGreen = '#57E389'; brightYellow = '#F8E45C'
                brightBlue = '#51A1FF'; brightPurple = '#C061CB'; brightCyan = '#4FD2FD'; brightWhite = '#F6F5F4'
            })
    }
    # Police GNOME seulement si elle a bien été installée (sinon le Terminal affiche une erreur).
    if (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts\AdwaitaMono-Regular.ttf')) {
        $fragment.profiles[0]['font'] = [ordered]@{ face = 'Adwaita Mono'; size = 11 }
    }
    $fragmentFile = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Windora\fedora.json'
    Write-Utf8File $fragmentFile (ConvertTo-Json -InputObject $fragment -Depth 5)
    if (Set-TerminalDefault $guid) {
        Write-Ok 'Fedora est le profil par défaut du Terminal'
    } else {
        Write-Warn 'Terminal Windows introuvable : ouvre-le une fois puis relance le script.'
    }
}

# ---- PowerShell : sudo dnf, dnf, installer, commandes Linux

function Set-PowerShellIntegration {
    Write-Step 'PowerShell : « sudo dnf », « installer » et les commandes Linux'
    $source = [IO.File]::ReadAllText((Join-Path $script:Here 'fxw-profile.ps1'))
    $source = $source.Replace("`$global:FxwDistro = 'Fedora'", "`$global:FxwDistro = '$($script:Distro)'")
    $target = Join-Path $script:AppDir 'fxw-profile.ps1'
    Write-Utf8File $target $source -Bom

    $line = ". `"$target`"  # Windora"
    $docs = [Environment]::GetFolderPath('MyDocuments')
    foreach ($profilePath in @((Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
            (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'))) {
        $content = ''
        if (Test-Path -LiteralPath $profilePath) { $content = [IO.File]::ReadAllText($profilePath) }
        if ($content -notmatch 'Windora') {
            Write-Utf8File $profilePath ($content.TrimEnd() + "`r`n" + $line + "`r`n") -Bom
        }
    }

    # Sans cela, Windows PowerShell refuse de charger les profils (politique « Restricted »).
    # AllSigned est un choix de sécurité (de l'utilisateur ou de l'entreprise) : on n'y touche pas.
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    $effective = Get-ExecutionPolicy
    if ($effective -eq 'AllSigned') {
        Write-Warn 'Politique d''exécution AllSigned : le profil Windora (non signé) ne sera pas chargé dans PowerShell.'
        Add-Note 'PowerShell est en mode AllSigned : les commandes Fedora y sont désactivées (le Terminal Fedora fonctionne).'
    } elseif ($effective -eq 'Restricted' -and ($policy -eq 'Undefined' -or $policy -eq 'Restricted')) {
        try {
            $script:Backup.Add([pscustomobject]@{ Type = 'ExecutionPolicy'; Path = 'CurrentUser'; Name = 'ExecutionPolicy'; Value = [string]$policy })
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
            Write-Ok 'scripts locaux autorisés pour ton compte (RemoteSigned)'
        } catch {
            Write-Warn 'Politique d''exécution verrouillée : les commandes Fedora ne seront pas chargées dans PowerShell.'
        }
    }
    Write-Ok 'actif dans les nouvelles fenêtres PowerShell'
}

# ---- Double-clic sur un .rpm : installé dans Fedora

function Register-RpmHandler {
    Write-Step 'Double-clic sur un .rpm : installation dans Fedora'
    $wsl = Join-Path $env:WINDIR 'System32\wsl.exe'
    $command = "`"$wsl`" -d $($script:Distro) --cd ~ -e /usr/local/bin/installer --pause `"%1`""
    $classes = 'HKCU:\Software\Classes'
    Set-RegistryValue "$classes\.rpm" '(default)' 'Windora.rpm' 'String' | Out-Null
    Set-RegistryValue "$classes\Windora.rpm" '(default)' 'Paquet Fedora (RPM)' 'String' | Out-Null
    Set-RegistryValue "$classes\Windora.rpm\DefaultIcon" '(default)' "$wsl,0" 'String' | Out-Null
    Set-RegistryValue "$classes\Windora.rpm\shell\open" '(default)' 'Installer dans Fedora' 'String' | Out-Null
    Set-RegistryValue "$classes\Windora.rpm\shell\open\command" '(default)' $command 'String' | Out-Null
    Update-ShellAssociations
    Write-Ok '.rpm associés à Fedora'
}

function Update-ShellAssociations {
    if (-not ('FxwNative.FxwShell' -as [type])) {
        Add-Type -Namespace 'FxwNative' -Name 'FxwShell' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern void SHChangeNotify(int eventId, int flags, System.IntPtr item1, System.IntPtr item2);
'@
    }
    [FxwNative.FxwShell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}

# ---- Ressources de Fedora : limitée et éteinte quand on ne s'en sert pas

function Set-WslResources {
    Write-Step 'Fedora sobre : mémoire plafonnée, arrêt automatique quand inutilisée'
    $file = Join-Path $env:USERPROFILE '.wslconfig'
    # Fedora ne prend jamais plus d'un quart de la RAM (par défaut WSL autorise la moitié),
    # rend la mémoire inutilisée à Windows, et s'éteint ~1 min après la dernière fenêtre fermée.
    $ramGb = 16
    try { $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) }
    catch { Write-Verbose 'Quantité de RAM inconnue : 16 Go supposés.' }
    $memGb = [math]::Max(4, [math]::Floor($ramGb / 4))
    $wanted = [ordered]@{
        'wsl2' = [ordered]@{ memory = "$($memGb)GB"; guiApplications = 'true' }
        'experimental' = [ordered]@{ autoMemoryReclaim = 'dropCache'; sparseVhd = 'true' }
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $copy = "$file.avant-windora"
    if (-not (Test-AlreadyBackedUp 'File' $file)) {
        # Premier passage : on garde l'original ($null = le fichier n'existait pas).
        $original = $null
        if (Test-Path -LiteralPath $file) {
            Copy-Item -LiteralPath $file -Destination $copy -Force
            $original = $copy
        }
        $script:Backup.Add([pscustomobject]@{ Type = 'File'; Path = $file; Name = '.wslconfig'; Value = $original })
    }
    if (Test-Path -LiteralPath $file) {
        foreach ($l in [IO.File]::ReadAllLines($file)) { $lines.Add($l) }
    }
    foreach ($section in $wanted.Keys) {
        $header = "[$section]"
        $index = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq $header) { $index = $i; break } }
        if ($index -lt 0) { $lines.Add(''); $lines.Add($header); $index = $lines.Count - 1 }
        foreach ($key in $wanted[$section].Keys) {
            # Une valeur déjà choisie par l'utilisateur est respectée.
            $present = $false
            for ($j = $index + 1; $j -lt $lines.Count -and -not $lines[$j].Trim().StartsWith('['); $j++) {
                if ($lines[$j] -match "^\s*$([regex]::Escape($key))\s*=") { $present = $true }
            }
            if (-not $present) { $lines.Insert($index + 1, "$key=$($wanted[$section][$key])") }
        }
    }
    Write-Utf8File $file (($lines -join "`r`n").Trim() + "`r`n")
    Write-Ok "réglages dans $file (pris en compte au prochain démarrage de Fedora)"
}

# ---- Habillage façon GNOME

function Install-UserFonts {
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    foreach ($font in $script:Fonts) {
        $dest = Join-Path $fontDir $font.File
        if (-not (Test-Path -LiteralPath $dest)) {
            $tmp = Join-Path $env:TEMP $font.File
            Invoke-WebRequest -Uri $font.Url -OutFile $tmp -UseBasicParsing
            $hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne $font.Sha256) {
                Remove-Item -LiteralPath $tmp -Force
                throw "Empreinte inattendue pour $($font.File) : téléchargement refusé."
            }
            Move-Item -LiteralPath $tmp -Destination $dest -Force
        }
        Set-RegistryValue $regPath $font.Name $dest 'String' | Out-Null
    }
    Write-Ok 'polices Adwaita Sans et Adwaita Mono (GNOME)'
}

# Applique un fond d'écran (SPI_SETDESKWALLPAPER), sans toucher au style d'affichage.
function Invoke-SetWallpaper([string]$Path) {
    if (-not ('FxwNative.FxwWallpaper' -as [type])) {
        Add-Type -Namespace 'FxwNative' -Name 'FxwWallpaper' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int SystemParametersInfo(int action, int param, string value, int flags);
'@
    }
    # SPI_SETDESKWALLPAPER, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
    [FxwNative.FxwWallpaper]::SystemParametersInfo(0x0014, 0, $Path, 0x03) | Out-Null
}

function Set-Wallpaper([string]$Path) {
    Set-RegistryValue 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' '10' 'String' | Out-Null
    Set-RegistryValue 'HKCU:\Control Panel\Desktop' 'TileWallpaper' '0' 'String' | Out-Null
    Save-RegistryValue 'HKCU:\Control Panel\Desktop' 'WallPaper'
    Invoke-SetWallpaper $Path
}

function Set-GnomeLook {
    Write-Step 'Habillage façon GNOME (réversible avec -Restore)'
    $personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-RegistryValue $personalize 'AppsUseLightTheme' 0 | Out-Null
    Set-RegistryValue $personalize 'SystemUsesLightTheme' 0 | Out-Null
    Write-Ok 'thème sombre'

    $wallpaper = Join-Path $script:AppDir 'fond-ecran.jpg'
    Copy-Item -LiteralPath (Join-Path $script:Here 'assets\wallpaper.jpg') -Destination $wallpaper -Force
    Set-Wallpaper $wallpaper
    Write-Ok 'fond d''écran'

    try { Install-UserFonts } catch { Write-Warn "Polices non installées : $($_.Exception.Message)" }
}

function Invoke-UserSlimming {
    $planFile = Join-Path $script:Here 'allegement.psd1'
    if (-not (Test-Path -LiteralPath $planFile)) { return }
    $plan = Import-PowerShellDataFile -LiteralPath $planFile
    if (-not $plan.ContainsKey('UserRegistry')) { return }
    Write-Step 'Allègement de ton compte Windows (pubs, suggestions, enregistrement en arrière-plan)'
    foreach ($reg in $plan.UserRegistry) {
        if (Set-RegistryValue $reg.Path $reg.Name $reg.Value $reg.Kind) { Write-Ok $reg.Label }
    }
}

# ------------------------------------------------------------------ reprise après redémarrage

function Register-Resume {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Resume')
    foreach ($name in @('Yes', 'NoGuiApps', 'NoDev', 'NoLook', 'NoSlim', 'NoSteam')) {
        if ((Get-Variable -Name $name -ValueOnly).IsPresent) { $argList += "-$name" }
    }
    if ($UserName) { $argList += @('-UserName', $UserName) }
    $command = "powershell.exe $($argList -join ' ')"
    if ($command.Length -gt 255) {
        Add-Note "Après le redémarrage, relance installer.cmd pour terminer (chemin trop long pour une reprise automatique)."
        return
    }
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'Windora' -Value $command
}

# ------------------------------------------------------------------ annulation

function Invoke-Restore {
    Write-Step 'Annulation de l''habillage, de l''allègement et de l''intégration'
    $userEntries = Read-JsonFile $script:UserBackup
    foreach ($e in @($userEntries)) {
        if ($e -and $e.Type -eq 'TerminalDefault' -and (Test-Path -LiteralPath $e.Path)) {
            $text = [IO.File]::ReadAllText($e.Path)
            if ($null -eq $e.Value) {
                # La clé avait été ajoutée par Windora : on l'enlève.
                $text = [regex]::Replace($text, '\s*"defaultProfile"\s*:\s*"[^"]*"\s*,?', '')
            } else {
                $text = [regex]::Replace($text, '("defaultProfile"\s*:\s*")([^"]*)(")', ('${1}' + $e.Value + '${3}'))
            }
            Write-Utf8File $e.Path $text
        }
    }
    Restore-Backup $script:UserBackup
    $fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Windora'
    if (Test-Path -LiteralPath $fragmentDir) { Remove-Item -LiteralPath $fragmentDir -Recurse -Force }
    Remove-Item -LiteralPath 'HKCU:\Software\Classes\Windora.rpm' -Recurse -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'Windora' -ErrorAction SilentlyContinue
    $docs = [Environment]::GetFolderPath('MyDocuments')
    foreach ($profilePath in @((Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
            (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'))) {
        if (Test-Path -LiteralPath $profilePath) {
            $kept = [IO.File]::ReadAllLines($profilePath) | Where-Object { $_ -notmatch 'Windora' }
            Write-Utf8File $profilePath (($kept -join "`r`n") + "`r`n") -Bom
        }
    }
    # Réapplique le fond d'écran d'origine (vide = pas de fond), avec son style restauré.
    Invoke-SetWallpaper ([string](Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallPaper)
    Update-ShellAssociations
    Write-Ok 'réglages de ton compte restaurés'
    if (Test-Path -LiteralPath $script:AdminBackup) {
        if (Test-Admin) {
            Restore-Backup $script:AdminBackup
            Write-Ok 'services et réglages système restaurés'
        } else {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @('-NoProfile',
                '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Restore',
                '-BackupFile', "`"$script:AdminBackup`"")
            return
        }
    }
    Write-Info 'Les applications retirées se réinstallent depuis le Microsoft Store si besoin.'
    Write-Info 'Fedora et tes fichiers Linux sont conservés. Pour supprimer Fedora (définitif) :'
    Write-Info "  wsl --unregister $($script:Distro)"
}

# ------------------------------------------------------------------ programme principal

function Show-Summary([string]$User) {
    Write-Step 'Terminé !'
    Write-Host @"
    Ouvre le Terminal Windows : tu es directement dans Fedora ($User@$env:COMPUTERNAME).

      sudo dnf install gimp        logiciel Linux (il apparaît dans le menu Démarrer)
      sudo dnf upgrade             met Fedora à jour
      installer firefox jeu.exe    Fedora ET Windows dans la même commande
      ./setup.exe                  lance un programme Windows depuis Fedora
      open .                       ouvre le dossier courant dans l'Explorateur
      x86_64-w64-mingw32-gcc prog.c -o prog.exe && ./prog.exe

    Dans PowerShell aussi : sudo dnf ..., dnf ..., installer ..., htop, nano...
    Tes fichiers Linux : Explorateur > Linux > $($script:Distro)  (\\wsl.localhost\$($script:Distro))
    Double-clic sur un .rpm : installé dans Fedora. Double-clic sur un .exe : Windows, comme d'habitude.

    Jeux : Steam, Riot (Valorant, LoL), Epic... s'installent normalement sous Windows.
"@
    foreach ($n in $script:Notes) { Write-Host ''; Write-Warn $n }
    Write-Host ''
}

# Retire la marque « téléchargé d'Internet » des seuls fichiers de Windora.
function Unblock-WindoraFiles {
    $files = New-Object System.Collections.Generic.List[string]
    foreach ($name in @('installer.cmd', 'setup.ps1', 'allegement.psd1', 'fxw-profile.ps1')) {
        $files.Add((Join-Path $script:Here $name))
    }
    foreach ($dir in @('fedora', 'assets')) {
        $path = Join-Path $script:Here $dir
        if (Test-Path -LiteralPath $path) {
            Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { $files.Add($_.FullName) }
        }
    }
    foreach ($f in $files) {
        if (Test-Path -LiteralPath $f) { Unblock-File -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

function Start-Main {
    # Sauvegarde système transmise par le processus parent (le compte administrateur peut
    # être différent de celui de la session, avec un autre dossier AppData).
    if ($BackupFile) { $script:AdminBackup = $BackupFile }
    if ($AdminPhase) {
        try {
            $result = Invoke-AdminPhase
        } catch {
            $result = [ordered]@{ Error = $_.Exception.Message }
        }
        if ($ResultFile) { Write-Utf8File $ResultFile (ConvertTo-Json -InputObject $result -Depth 4) }
        return
    }

    Write-Host "Windora $($script:Version)" -ForegroundColor Cyan
    $build = [Environment]::OSVersion.Version.Build
    if ($build -lt 19045) { throw 'Windows 10 22H2 ou Windows 11 est nécessaire.' }
    New-Item -ItemType Directory -Path $script:AppDir -Force | Out-Null
    Unblock-WindoraFiles

    if ($Restore) { Invoke-Restore; return }

    if ($Check) {
        if (-not (Test-Admin)) { Write-Warn 'Sans droits administrateur, Secure Boot, TPM et HVCI ne peuvent pas être lus : lance le Terminal en administrateur.' }
        Show-Readiness (Get-Readiness)
        foreach ($n in $script:Notes) { Write-Host ''; Write-Warn $n }
        return
    }

    if (-not $Yes -and -not $Resume) {
        Write-Info 'Ce script installe Fedora dans Windows (WSL) et l''intègre au Terminal, à PowerShell et'
        Write-Info 'à l''Explorateur. Il installe aussi Windows Terminal, PowerToys et Steam (sauf -NoSteam).'
        if (-not $NoSlim) {
            Write-Info 'Allègement (-NoSlim pour l''éviter) : désinstalle Actualités, Météo, Solitaire, To Do,'
            Write-Info 'Clipchamp, Power Automate, Copilot, Cortana... (réinstallables depuis le Microsoft Store),'
            Write-Info 'coupe la télémétrie, les pubs et les suggestions. Liste complète : allegement.psd1.'
        }
        if (-not $NoLook) { Write-Info 'Apparence (-NoLook pour l''éviter) : thème sombre, fond d''écran, polices GNOME.' }
        Write-Info 'Les réglages sont réversibles avec -Restore.'
        if (-not (Confirm-Choice 'Continuer ?')) { return }
    }

    # 1) Partie administrateur : WSL, applications, allègement du système.
    if (Test-Admin) {
        # Lancé en administrateur : il faut que ce soit le compte de la session, sinon Fedora
        # serait installée pour un autre utilisateur.
        $owner = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1 |
            Invoke-CimMethod -MethodName GetOwner -ErrorAction SilentlyContinue
        if ($owner -and $owner.User -and $owner.User -ne $env:USERNAME) {
            throw "Lance ce script sans « Exécuter en tant qu'administrateur » (double-clic sur installer.cmd) : il demandera lui-même les droits."
        }
        $admin = Invoke-AdminPhase
    } else {
        Write-Info 'Windows va demander l''autorisation administrateur (installation de WSL et des applications).'
        $resultFile = Join-Path $env:TEMP "fxw-admin-$PID.json"
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-AdminPhase',
            '-ResultFile', "`"$resultFile`"", '-BackupFile', "`"$script:AdminBackup`"", '-ParentSid', $sid)
        foreach ($name in @('NoSlim', 'NoSteam')) {
            if ((Get-Variable -Name $name -ValueOnly).IsPresent) { $childArgs += "-$name" }
        }
        try {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList $childArgs
        } catch {
            throw 'Autorisation administrateur refusée : impossible d''installer WSL.'
        }
        $admin = Read-JsonFile $resultFile
        if (-not $admin) { throw 'La partie administrateur a échoué (voir la fenêtre qui s''est ouverte).' }
        Remove-Item -LiteralPath $resultFile -Force
    }
    if ($admin.PSObject.Properties.Name -contains 'Error') { throw "Partie administrateur : $($admin.Error)" }

    Show-Readiness $admin.Readiness
    if (-not $admin.Readiness.Virtualization) {
        throw 'Active la virtualisation dans le BIOS (SVM ou VT-x), puis relance installer.cmd.'
    }
    if ($admin.RebootRequired) {
        Register-Resume
        Write-Step 'Redémarrage nécessaire'
        Write-Info 'WSL vient d''être installé. Après le redémarrage, l''installation reprendra toute seule.'
        if (Confirm-Choice 'Redémarrer maintenant ?') { Restart-Computer -Force }
        return
    }

    # 2) Partie utilisateur : Fedora, apparence, Terminal, PowerShell.
    try {
        Install-Fedora
        $user = Initialize-Fedora
        if (-not $NoLook) { Set-GnomeLook }       # avant le Terminal : il a besoin de la police
        Set-TerminalIntegration
        Set-PowerShellIntegration
        Register-RpmHandler
        Set-WslResources
        if (-not $NoSlim) { Invoke-UserSlimming }
    } finally {
        # Écrite même en cas d'erreur, pour que -Restore puisse tout défaire.
        Save-Backup $script:UserBackup
        # WSL refuse qu'une session administrateur et une session normale tournent en même temps.
        if (Test-Admin) { Invoke-Native 'wsl.exe' @('--shutdown') | Out-Null }
    }
    Show-Summary $user
}

# Le script peut être chargé (« . .\setup.ps1 ») sans rien lancer, pour les tests.
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = 0
    try {
        Start-Main
    } catch {
        Write-Host ''
        Write-Host "Erreur : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Rien n'est perdu : corrige le problème puis relance installer.cmd (dans $($script:Here))." -ForegroundColor Red
        $exitCode = 1
    } finally {
        # Après le redémarrage, la fenêtre s'ouvre toute seule : on la laisse ouverte pour lire.
        if ($Resume -and -not $AdminPhase) { Read-Host 'Appuie sur Entrée pour fermer' | Out-Null }
    }
    exit $exitCode
}
