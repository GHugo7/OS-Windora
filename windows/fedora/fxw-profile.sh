# Windora : confort du terminal Fedora intégré à Windows.
# (Mettre FXW_NO_FASTFETCH=1 dans ~/.bashrc pour ne plus afficher le logo.)

if [[ $- == *i* ]]; then
    # Ouvre un dossier ou un fichier avec Windows : « open . », « open image.png »
    open() { explorer.exe "$(wslpath -w "${1:-.}")"; }

    # Le gestionnaire de paquets de Windows, depuis Fedora.
    winget() { cmd.exe /c winget "$@"; }

    if [[ -z "${FXW_NO_FASTFETCH:-}" && -z "${FXW_FASTFETCH_SHOWN:-}" ]] && command -v fastfetch >/dev/null; then
        export FXW_FASTFETCH_SHOWN=1
        fastfetch
    fi
fi
