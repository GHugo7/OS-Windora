#!/usr/bin/bash
# Configure la Fedora intégrée à Windows (WSL). Lancé en root par setup.ps1 :
#   provision.sh <utilisateur> <applis graphiques 0|1> <compilateur 0|1>
set -euo pipefail

user="$1"
gui="${2:-1}"
dev="${3:-1}"
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs seulement dans un vrai terminal (setup.ps1 affiche la sortie telle quelle).
if [[ -t 1 ]]; then B=$'\033[1;34m' G=$'\033[1;32m' Y=$'\033[1;33m' N=$'\033[0m'; else B='' G='' Y='' N=''; fi
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok() { printf '    %sOK%s %s\n' "$G" "$N" "$*"; }

[[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "Nom d'utilisateur invalide : $user" >&2; exit 2; }

step "Compte utilisateur « $user »"
# Même chose que le premier lancement officiel de Fedora sur WSL : UID 1000, groupe wheel,
# sudo sans mot de passe (dans WSL, Windows donne de toute façon accès root via « wsl -u root »).
existing="$(getent passwd 1000 | cut -d: -f1 || true)"
if [[ -n "$existing" ]]; then
    user="$existing"
    ok "compte existant : $user"
else
    useradd -m -G wheel --uid 1000 "$user"
    ok "compte créé"
fi
echo "$user ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/wsluser
chmod 440 /etc/sudoers.d/wsluser
# setup.ps1 lit cette ligne pour connaître le compte réellement utilisé.
echo "FXW_USER=$user"

step "Mise à jour de Fedora"
dnf -y upgrade --refresh

step "Logiciels"
pkgs=(bash-completion git curl wget nano vim-enhanced htop fastfetch man-pages
    unzip zip tar python3 gcc make)
if [[ "$dev" == 1 ]]; then
    # Compilateur Windows : x86_64-w64-mingw32-gcc prog.c -o prog.exe && ./prog.exe
    pkgs+=(mingw64-gcc mingw64-gcc-c++ mingw32-gcc mingw32-gcc-c++)
fi
if [[ "$gui" == 1 ]]; then
    # Applications GNOME : elles apparaissent dans le menu Démarrer (dossier « Fedora »).
    pkgs+=(nautilus gnome-text-editor gnome-calculator gnome-system-monitor loupe papers
        adwaita-icon-theme adwaita-sans-fonts adwaita-mono-fonts mesa-dri-drivers mesa-vulkan-drivers)
fi
dnf -y install --skip-unavailable "${pkgs[@]}"
ok "logiciels installés"

step "Commande « installer » et confort du terminal"
install -m 755 "$here/installer" /usr/local/bin/installer
install -m 755 "$here/fxw-exec" /usr/local/bin/fxw-exec
install -m 644 "$here/fxw-profile.sh" /etc/profile.d/fxw.sh
ok "installer, open, winget, logo au démarrage"

if [[ -f "$here/slim.sh" ]]; then
    step "Allègement de Fedora"
    bash "$here/slim.sh"
fi

# Les .exe doivent rester lançables depuis Fedora (interopérabilité WSL).
if /mnt/c/Windows/System32/cmd.exe /c ver >/dev/null 2>&1; then
    ok "les programmes Windows se lancent depuis Fedora"
else
    printf '    %s!!%s %s\n' "$Y" "$N" "Les .exe ne se lancent pas depuis Fedora (interopérabilité WSL désactivée ?)"
fi
