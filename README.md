# Windora

**Fedora + Windows, sans choisir.** Toutes les commandes et les logiciels de Fedora, et
tous les `.exe` et jeux de Windows, sur le même PC.

Deux façons d'y arriver :

| | [**Windows d'abord**](windows/README.md) (recommandé) | [**Fedora d'abord**](fedora/README.md) |
|---|---|---|
| Noyau | Windows | Linux (Fedora) |
| Commandes Fedora (`sudo dnf install`…) | ✅ 100 % : Terminal ouvert sur Fedora, et dans PowerShell | ✅ 100 % |
| Applications Linux | ✅ dans le menu Démarrer | ✅ |
| Installer Fedora ET Windows en une commande | ✅ `installer firefox jeu.exe` | ✅ `.exe` par double-clic ou `./jeu.exe` |
| Jeux Windows | ✅ 100 % | ✅ environ 85-90 % (Proton) |
| **Valorant, League of Legends** (Vanguard) | ✅ | ❌ impossible sous Linux |
| Fortnite, Call of Duty, Battlefield 6, GTA Online | ✅ | ❌ bloqués par les éditeurs |
| Compiler des `.exe` | ✅ MinGW dans Fedora, lancement natif | ✅ MinGW |
| Allégé (pas de services inutiles) | ✅ Windows allégé, Fedora éteinte quand inutilisée | ✅ |
| Installation | double-clic sur `windows/installer.cmd` | `./fedora/install.sh` |

**Tu joues à Valorant ou League of Legends → [Windows d'abord](windows/README.md).**
Sinon, [Fedora d'abord](fedora/README.md) donne un vrai Linux qui lance la plupart des jeux Windows.

## Pourquoi pas un « Fedora avec le noyau Windows » ?

C'est exactement la variante « Windows d'abord », sous la seule forme qui existe :

- le noyau Windows est fermé : sa licence interdit de le modifier ou de l'intégrer à un autre
  système, donc personne ne peut fabriquer une distribution Fedora avec ce noyau ;
- WSL (Windows Subsystem for Linux) fait le chemin inverse, officiellement : il fait tourner la
  **vraie Fedora** (image publiée par le projet Fedora) dans Windows. Le noyau reste celui de
  Windows, donc **Vanguard fonctionne** ;
- faire croire à Vanguard qu'un autre système est Windows (noyau « compatible », machine
  virtuelle cachée…) serait un contournement d'anti-triche : bannissement du compte et du
  matériel. Ce projet ne le fait pas.

## Contenu du dépôt

| Dossier | Contenu |
|---|---|
| [`windows/`](windows/README.md) | `installer.cmd` / `setup.ps1` : Windows + Fedora intégré (WSL), PowerShell « 100 % Fedora », commande `installer`, allègement, habillage GNOME |
| [`fedora/`](fedora/README.md) | `install.sh` : Fedora + Steam, Proton, Wine, la commande `fxw` (`.exe` par double-clic), pilotes, allègement ; [`image/`](fedora/image/README.md) pour fabriquer son propre ISO |
| [`novaos/`](novaos/README.md) | NovaOS, un petit système d'exploitation écrit de zéro (noyau x86 en C), pour comprendre comment marche un OS |

## Mentions

Projet personnel, non affilié à Microsoft, Red Hat, au projet Fedora ni à Riot Games.
Fedora est une marque de Red Hat, Inc. Windows est une marque de Microsoft Corporation.
Les polices Adwaita (GNOME) sont téléchargées depuis leur dépôt officiel (licence OFL).
