# Windora : confort du terminal Fedora intégré à Windows.
# (Mettre FXW_NO_FASTFETCH=1 dans ~/.bashrc pour ne plus afficher le logo.)

if [[ $- == *i* ]]; then
    # Ouvre un dossier ou un fichier avec Windows : « open . », « open image.png »
    open() { explorer.exe "$(wslpath -w "${1:-.}")"; }

    # Le gestionnaire de paquets de Windows, depuis Fedora. cmd.exe ne sait pas démarrer dans
    # un dossier Linux (\\wsl.localhost\...) : il est lancé depuis C:, et les fichiers donnés
    # en argument (winget import liste.json) sont convertis en chemins Windows.
    winget() {
        local a args=()
        for a in "$@"; do
            if [[ "$a" != -* && -e "$a" ]]; then a="$(wslpath -w "$a")"; fi
            args+=("$a")
        done
        if [[ "$PWD" == /mnt/[a-z]/* ]]; then
            cmd.exe /d /c winget "${args[@]}"
        else
            (cd /mnt/c && cmd.exe /d /c winget "${args[@]}")
        fi
    }

    if [[ -z "${FXW_NO_FASTFETCH:-}" && -z "${FXW_FASTFETCH_SHOWN:-}" ]] && command -v fastfetch >/dev/null; then
        export FXW_FASTFETCH_SHOWN=1
        fastfetch
    fi
fi
