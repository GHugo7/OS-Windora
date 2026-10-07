# Windora : Fedora directement dans PowerShell.
#
#   sudo dnf install gimp      -> Fedora
#   installer firefox jeu.exe  -> Fedora ET Windows dans la même commande
#   ls, cat, cp, mv, rm, ps, kill, sort, diff, man... tapés au clavier -> Fedora
#   toute commande inconnue de Windows (htop, nano, git, gcc...) -> Fedora
#
# Seul ce que tu TAPES va vers Fedora : les scripts gardent les commandes Windows, et hors
# d'un dossier de disque local (registre, partage réseau...) les commandes restent Windows.
# Commandes Windows au clavier : Get-ChildItem, Get-Content, Remove-Item, Get-Process...
# Pour tout désactiver : retirer la ligne « . ...\fxw-profile.ps1 » de $PROFILE.

# Rien dans un PowerShell administrateur : WSL refuse de mélanger sessions administrateur et
# normales, et un « rm » tapé là doit rester celui de Windows.
$fxwAdmin = $false
try {
    $fxwIdentity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $fxwAdmin = $fxwIdentity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    Write-Verbose 'Droits du compte inconnus (PowerShell hors de Windows).'
}
if ($fxwAdmin) { return }
# Rien non plus quand un programme lance PowerShell pour exécuter une commande ou un script
# (powershell -Command ..., -File ..., script.ps1), sauf avec -NoExit.
if ($Host.Name -ne 'ConsoleHost') { return }
$fxwCmdLine = @([Environment]::GetCommandLineArgs() | Select-Object -Skip 1)
$fxwNoExit = @($fxwCmdLine | Where-Object { $_ -match '^[-/]noe' }).Count -gt 0
$fxwBatch = @($fxwCmdLine | Where-Object {
        $_ -match '^[-/](c|co|com|comm|comma|comman|command|f|fi|fil|file|e|ec|en|enc|enco|encod|encode|encoded|encodedc\w*|noni\w*)$' -or
        $_ -match '\.ps1$'
    }).Count -gt 0
if ($fxwBatch -and -not $fxwNoExit) { return }
Remove-Variable -Name fxwAdmin, fxwIdentity, fxwCmdLine, fxwNoExit, fxwBatch -ErrorAction SilentlyContinue

$global:FxwDistro = 'Fedora'
$global:FxwCommands = $null
$global:FxwCommandsTime = [datetime]::MinValue

# Liste des commandes de Fedora, gardée en mémoire (une faute de frappe ne coûte presque rien).
function Update-FxwCommands {
    $list = & wsl.exe -d $global:FxwDistro -e bash -c 'compgen -c' 2>$null
    if ($LASTEXITCODE -eq 0) {
        $set = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($l in $list) { [void]$set.Add(([string]$l).Trim()) }
        $global:FxwCommands = $set
    }
    $global:FxwCommandsTime = Get-Date
}

function Test-FxwLinuxCommand([string]$Name) {
    if ($Name -notmatch '^[A-Za-z0-9._+-]+$' -or $Name.StartsWith('-')) { return $false }
    if (-not $global:FxwCommands) { Update-FxwCommands }
    if ($global:FxwCommands -and $global:FxwCommands.Contains($Name)) { return $true }
    # Peut-être installée depuis (sudo dnf install) : on rafraîchit, au plus toutes les 30 s.
    if (((Get-Date) - $global:FxwCommandsTime).TotalSeconds -gt 30) {
        Update-FxwCommands
        return [bool]($global:FxwCommands -and $global:FxwCommands.Contains($Name))
    }
    return $false
}

# Dossier courant si Fedora peut y accéder (disque local ou fichiers de Fedora), sinon $null.
function Get-FxwDirectory {
    $location = Get-Location
    if ($location.Provider.Name -ne 'FileSystem') { return $null }
    $path = $location.ProviderPath
    if ($path -match '^\\\\wsl(\.localhost|\$)\\') { return $path }
    if ($path -match '^[A-Za-z]:\\') {
        try {
            $type = ([IO.DriveInfo]$path.Substring(0, 3)).DriveType
            if ($type -eq 'Fixed' -or $type -eq 'Removable') { return $path }
        } catch {
            Write-Verbose "Lecteur inconnu : $path"
        }
    }
    return $null
}

# Pour chaque argument tapé : $true s'il a été écrit sans guillemets (seuls ceux-là voient
# leurs jokers * ? [ ] développés, comme dans bash). $null si on ne peut pas le savoir.
function Get-FxwBareWords([System.Management.Automation.InvocationInfo]$Invocation) {
    if (-not $Invocation -or -not $Invocation.Line) { return $null }
    try {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($Invocation.Line, [ref]$tokens, [ref]$errors)
        $start = $Invocation.OffsetInLine - 1
        $command = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and $node.Extent.StartOffset -eq $start
            }, $true) | Select-Object -First 1
        if (-not $command) { return $null }
        return @($command.CommandElements | Select-Object -Skip 1 | ForEach-Object {
                $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $_.StringConstantType -eq 'BareWord'
            })
    } catch {
        return $null
    }
}

function ConvertTo-FxwArgs([object[]]$Arguments, [object[]]$BareWords) {
    $i = 0
    foreach ($a in $Arguments) {
        $s = [string]$a
        $bare = ($null -ne $BareWords) -and ($i -lt $BareWords.Count) -and [bool]$BareWords[$i]
        $i++
        # ~ = dossier personnel de Fedora (développé par fxw-exec), on n'y touche pas.
        if ($s -match '^~([\\/]|$)') { $s; continue }
        # Chemin relatif écrit à la Windows : séparateurs Linux. Les chemins absolus
        # (C:\..., \\serveur\...) sont convertis par fxw-exec.
        if (-not $s.StartsWith('-') -and $s.Contains('\') -and -not [IO.Path]::IsPathRooted($s)) {
            $s = $s.Replace('\', '/')
        }
        if ($bare -and -not $s.StartsWith('-') -and $s -match '[*?\[]') {
            $found = @(Resolve-Path -Path $s -Relative -ErrorAction SilentlyContinue | ForEach-Object {
                    ($_ -replace '^\.[\\/]', '').Replace('\', '/')
                })
            if ($found.Count) { $found; continue }
        }
        $s
    }
}

# Lance une commande Fedora dans le dossier courant de PowerShell (wsl.exe ne suit pas « cd »).
function Invoke-Fedora {
    param(
        [System.Management.Automation.InvocationInfo]$Invocation,
        [string]$Name,
        [object[]]$Arguments
    )
    $dir = Get-FxwDirectory
    if (-not $dir) {
        Write-Error "Fedora n'a pas accès à cet emplacement ($((Get-Location).Path)) : va dans un dossier d'un disque local."
        return
    }
    $all = @($Name) + @(ConvertTo-FxwArgs $Arguments (Get-FxwBareWords $Invocation))
    # Arguments transmis hors de la ligne de commande : Windows PowerShell 5.1 perd sinon les
    # arguments vides et les guillemets. fxw-exec les relit dans FXW_ARGS.
    $payload = -join ($all | ForEach-Object { [string]$_ + [char]0 })
    $oldWslEnv = $env:WSLENV
    $env:FXW_ARGS = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
    $env:WSLENV = if ($oldWslEnv) { $oldWslEnv + ':FXW_ARGS' } else { 'FXW_ARGS' }
    # Échanges en UTF-8 (accents corrects dans les tuyaux, même sous Windows PowerShell 5.1).
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $oldConsole = [Console]::OutputEncoding
    $OutputEncoding = $utf8
    try {
        [Console]::OutputEncoding = $utf8
        if ($MyInvocation.ExpectingInput) {
            $input | & wsl.exe -d $global:FxwDistro --cd $dir -e /usr/local/bin/fxw-exec
        } else {
            & wsl.exe -d $global:FxwDistro --cd $dir -e /usr/local/bin/fxw-exec
        }
    } finally {
        [Console]::OutputEncoding = $oldConsole
        $env:WSLENV = $oldWslEnv
        Remove-Item -LiteralPath Env:\FXW_ARGS -ErrorAction SilentlyContinue
    }
}

function dnf {
    Invoke-Fedora -Invocation $MyInvocation -Name dnf -Arguments $args
    $global:FxwCommandsTime = [datetime]::MinValue   # de nouvelles commandes ont pu arriver
}

function installer {
    Invoke-Fedora -Invocation $MyInvocation -Name /usr/local/bin/installer -Arguments $args
    $global:FxwCommandsTime = [datetime]::MinValue
}

# sudo : sudo de Windows pour un programme Windows, sinon celui de Fedora.
function sudo {
    $first = if ($args.Count) { [string]$args[0] } else { '' }
    $windowsApp = $null
    if ($first -and -not $first.StartsWith('-')) {
        $windowsApp = Get-Command -Name $first -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $windowsApp -and $first -and ($first.StartsWith('-') -or (Test-FxwLinuxCommand $first))) {
        Invoke-Fedora -Invocation $MyInvocation -Name sudo -Arguments $args
        $global:FxwCommandsTime = [datetime]::MinValue
        return
    }
    $windowsSudo = Get-Command -Name sudo.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($windowsSudo) {
        & $windowsSudo.Source @args
    } else {
        Write-Error "sudo : « $first » n'existe ni dans Fedora ni dans Windows (ou le sudo de Windows est désactivé)."
    }
}

# Noms communs à Linux et PowerShell : Fedora au clavier, Windows dans les scripts.
# Seuls les noms qui sont des alias PowerShell sont concernés (dans PowerShell 7, curl et
# wget sont les vrais programmes et ne sont pas touchés).
foreach ($fxwName in @('ls', 'cat', 'cp', 'mv', 'rm', 'rmdir', 'ps', 'kill', 'sort', 'diff', 'tee', 'man', 'curl', 'wget')) {
    $fxwAlias = Get-Alias -Name $fxwName -ErrorAction SilentlyContinue
    if (-not $fxwAlias) { continue }
    $windows = $fxwAlias.Definition
    $linux = $fxwName
    Remove-Item -LiteralPath "Alias:\$fxwName" -Force
    $body = {
        if ($MyInvocation.CommandOrigin -eq 'Runspace' -and (Get-FxwDirectory)) {
            if ($MyInvocation.ExpectingInput) {
                $input | Invoke-Fedora -Invocation $MyInvocation -Name $linux -Arguments $args
            } else {
                Invoke-Fedora -Invocation $MyInvocation -Name $linux -Arguments $args
            }
        } elseif ($MyInvocation.ExpectingInput) {
            $input | & $windows @args
        } else {
            & $windows @args
        }
    }.GetNewClosure()
    Set-Item -LiteralPath "Function:\global:$fxwName" -Value $body
}
Remove-Variable -Name fxwName, fxwAlias, windows, linux, body -ErrorAction SilentlyContinue

# Toute commande tapée au clavier et inconnue de Windows est essayée dans Fedora.
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param([string]$CommandName, [System.Management.Automation.CommandLookupEventArgs]$LookupArgs)
    # Seulement pour ce que l'utilisateur tape, jamais pour les scripts ou les modules.
    if ($LookupArgs.CommandOrigin -ne 'Runspace') { return }
    if ($CommandName -match '[\\/:]' -or $CommandName -like 'get-*') { return }
    if (-not (Get-FxwDirectory)) { return }
    if (-not (Test-FxwLinuxCommand $CommandName)) { return }
    # GetNewClosure fige $name pour le bloc exécuté à la place de la commande.
    $name = $CommandName
    $LookupArgs.CommandScriptBlock = {
        if ($MyInvocation.ExpectingInput) {
            $input | Invoke-Fedora -Invocation $MyInvocation -Name $name -Arguments $args
        } else {
            Invoke-Fedora -Invocation $MyInvocation -Name $name -Arguments $args
        }
    }.GetNewClosure()
    $LookupArgs.StopSearch = $true
}
