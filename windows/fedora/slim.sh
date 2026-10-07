#!/usr/bin/bash
# Allègement de la Fedora intégrée à Windows : sous WSL, c'est Windows qui gère le réseau,
# l'heure et le matériel. Ces services n'y servent à rien mais occupent de la mémoire.
set -uo pipefail

units=(
    dnf-makecache.timer      # dnf rafraîchit lui-même ses listes au besoin
    NetworkManager.service   # le réseau est fourni par Windows
    ModemManager.service
    bluetooth.service
    avahi-daemon.socket avahi-daemon.service
    chronyd.service          # l'heure vient de Windows
)
for u in "${units[@]}"; do
    systemctl is-enabled --quiet "$u" 2>/dev/null || continue
    if systemctl disable --now "$u" >/dev/null 2>&1; then
        echo "    OK désactivé : $u"
    fi
done
