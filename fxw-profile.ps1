# Windora : Fedora directement dans PowerShell.
#
#   sudo dnf install gimp      -> Fedora
#   installer firefox jeu.exe  -> Fedora ET Windows dans la même commande
#   ls, cat, cp, mv, rm, ps, kill, curl, sort, diff, man... tapés au clavier -> Fedora
#   toute commande inconnue de Windows (htop, nano, git, gcc...) -> Fedora
#
# Les scripts PowerShell gardent les commandes Windows : seul ce que tu TAPES va vers Fedora.
# Commandes Windows au clavier : Get-ChildItem, Get-Content, Remove-Item, Get-Process...
# Pour tout désactiver : retirer la ligne « . ...\fxw-profile.ps1 » de $PROFILE.

$global:FxwDistro = 'Fedora'

# Une commande existe-t-elle dans Fedora ?
function Test-FxwLinuxCommand([string]$Name) {
    if ($Name -notmatch '^[A-Za-z0-9._+-]+$') { return $false }
    # Pas de guillemets doubles dans l'argument : PowerShell 5.1 les transmet mal aux .exe.
    # $Name est sûr (lettres, chiffres, . _ + -), il peut rester sans guillemets côté sh.
    & wsl.exe -d $global:FxwDistro -e sh -c 'command -v $1 >/dev/null 2>&1' sh $Name 2>$null
    return ($LASTEXITCODE -eq 0)
}

# Remplace les chemins existants par leur chemin Windows complet (Fedora les convertit).
function ConvertTo-FxwArgs([object[]]$Arguments) {
    foreach ($a in $Arguments) {
        $s = [string]$a
        if ($s -and -not $s.StartsWith('-') -and (Test-Path -LiteralPath $s)) {
            (Resolve-Path -LiteralPath $s).ProviderPath
        } else {
            $s
        }
    }
}

# Lance une commande Fedora dans le dossier courant de PowerShell (wsl.exe ne suit pas « cd »).
function Invoke-Fedora {
    $location = Get-Location
    $dir = if ($location.Provider.Name -eq 'FileSystem') { $location.ProviderPath } else { '~' }
    $converted = @(ConvertTo-FxwArgs $args)
    if ($MyInvocation.ExpectingInput) {
        $input | & wsl.exe -d $global:FxwDistro --cd $dir -e /usr/local/bin/fxw-exec @converted
    } else {
        & wsl.exe -d $global:FxwDistro --cd $dir -e /usr/local/bin/fxw-exec @converted
    }
}

function dnf { Invoke-Fedora dnf @args }
function installer { Invoke-Fedora /usr/local/bin/installer @args }

# sudo : vers Fedora pour une commande Linux, sinon vers le sudo de Windows (s'il est activé).
function sudo {
    if ($args.Count -gt 0 -and (Test-FxwLinuxCommand ([string]$args[0]))) {
        Invoke-Fedora sudo @args
        return
    }
    $windowsSudo = Get-Command sudo.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($windowsSudo) {
        & $windowsSudo.Source @args
    } else {
        Write-Error "sudo : « $($args[0]) » n'existe ni dans Fedora ni dans Windows."
    }
}

# Noms communs à Linux et PowerShell : Fedora au clavier, Windows dans les scripts.
$global:FxwLinuxNames = [ordered]@{
    ls = 'Get-ChildItem'; cat = 'Get-Content'; cp = 'Copy-Item'; mv = 'Move-Item'
    rm = 'Remove-Item'; rmdir = 'Remove-Item'; ps = 'Get-Process'; kill = 'Stop-Process'
    sort = 'Sort-Object'; diff = 'Compare-Object'; tee = 'Tee-Object'; man = 'help'
    curl = 'Invoke-WebRequest'; wget = 'Invoke-WebRequest'
}
foreach ($fxwName in @($global:FxwLinuxNames.Keys)) {
    if (Test-Path -LiteralPath "Alias:\$fxwName") { Remove-Item -LiteralPath "Alias:\$fxwName" -Force }
    $linux = $fxwName
    $windows = $global:FxwLinuxNames[$fxwName]
    $body = {
        if ($MyInvocation.CommandOrigin -eq 'Runspace') {
            if ($MyInvocation.ExpectingInput) { $input | Invoke-Fedora $linux @args } else { Invoke-Fedora $linux @args }
        } elseif ($MyInvocation.ExpectingInput) {
            $input | & $windows @args
        } else {
            & $windows @args
        }
    }.GetNewClosure()
    Set-Item -LiteralPath "Function:\global:$fxwName" -Value $body
}
Remove-Variable -Name fxwName, linux, windows, body -ErrorAction SilentlyContinue

# Toute commande tapée au clavier et inconnue de Windows est essayée dans Fedora.
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param([string]$CommandName, [System.Management.Automation.CommandLookupEventArgs]$LookupArgs)
    # Seulement pour ce que l'utilisateur tape, jamais pour les scripts ou les modules.
    if ($LookupArgs.CommandOrigin -ne 'Runspace') { return }
    if ($CommandName -match '[\\/:]' -or $CommandName -like 'get-*') { return }
    if (-not (Test-FxwLinuxCommand $CommandName)) { return }
    # GetNewClosure fige $name pour le bloc exécuté à la place de la commande.
    $name = $CommandName
    $LookupArgs.CommandScriptBlock = {
        if ($MyInvocation.ExpectingInput) { $input | Invoke-Fedora $name @args } else { Invoke-Fedora $name @args }
    }.GetNewClosure()
    $LookupArgs.StopSearch = $true
}
