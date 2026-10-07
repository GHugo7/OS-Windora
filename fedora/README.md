# Variante 1 : Fedora d'abord

Une Fedora normale (Workstation GNOME ou KDE), transformée par un script en PC de jeu qui
**lance les `.exe` comme sous Windows** : double-clic, `./setup.exe` dans un terminal,
raccourcis dans le menu après une installation, Steam, Epic, GOG, Battle.net…

> **Limite à connaître :** les jeux protégés par un anti-triche « noyau » (Valorant,
> League of Legends, Fortnite…) ne marchent **pas** sous Linux. Voir
> [Ce qui marche, ce qui ne marche pas](#ce-qui-marche-ce-qui-ne-marche-pas). Si ces jeux
> comptent pour toi, regarde aussi la [variante Windows](../windows/README.md).

## Installation

Sur une **Fedora 43, 44 ou 45** installée (pas Silverblue/Kinoite) :

```sh
git clone https://github.com/GHugo7/OS-Windora.git
cd OS-Windora/fedora
./install.sh            # pose quelques questions, demande le mot de passe (sudo)
```

- `./install.sh --dry-run` montre tout ce qui serait fait, sans rien toucher.
- `./install.sh --yes` installe sans poser de questions.
- `./install.sh --help` liste les options (`--no-flatpak`, `--no-optimize`, `--nvidia=580xx`, `--uninstall`…).

Le script peut être relancé sans risque : ce qui est déjà fait est sauté.
Compte 15 à 40 minutes selon la connexion. **Redémarre** à la fin.

### Ce que le script installe

| Étape | Détail |
|---|---|
| Dépôts | RPM Fusion libre + non libre, codec H.264 de Cisco |
| Mise à jour | `dnf upgrade` (nécessaire avant un pilote NVIDIA) |
| Codecs | ffmpeg complet, GStreamer, décodage vidéo matériel AMD/Intel |
| Pilote NVIDIA | `akmod-nvidia` (RTX, GTX 16xx) ou `akmod-nvidia-580xx` (GTX 750 à 1080), choisi automatiquement ; gestion de Secure Boot |
| Jeux | Steam, Wine 11, DXVK, winetricks, Lutris, GameMode, MangoHud, gamescope, ntsync |
| Proton hors Steam | [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) : le Proton de Valve pour n'importe quel `.exe` |
| Flathub | Heroic (Epic, GOG, Amazon), Bottles, ProtonPlus (GE-Proton), Flatseal |
| Compilateur | MinGW : fabrique des `.exe` Windows depuis Fedora |
| Intégration | la commande `fxw`, le double-clic, `./programme.exe`, les raccourcis du menu |
| Allègement | coupe les services inutiles pour un PC de jeu (voir plus bas) |

Les cartes **AMD et Intel** n'ont besoin de rien : leurs pilotes sont déjà dans Fedora.

## Utilisation au quotidien

**Double-clic** sur un `.exe` ou un `.msi` : il est lancé avec Proton. Le tout premier
lancement télécharge Proton (quelques centaines de Mo) : une notification l'indique.

**Installer un jeu ou un logiciel** : double-clic sur `setup.exe`. À la fin, les raccourcis
créés par l'installeur apparaissent dans le menu des applications, avec leur icône.

**Dans un terminal** :

```sh
fxw setup.exe                    # lance un programme
chmod +x jeu.exe && ./jeu.exe    # comme un programme Linux
fxw run --isolated jeu.exe       # dans un "C:\" séparé, rien que pour lui
fxw run --hud jeu.exe            # avec compteur d'images par seconde
fxw tricks vcrun2022 dotnet48    # composants Windows (Visual C++, .NET...)
fxw menu jeu.exe "Mon jeu"       # ajoute un raccourci au menu
fxw config                       # réglages de Windows (winecfg)
fxw list                         # liste les "C:\" (préfixes)
fxw doctor                       # vérifie que tout est bien installé
```

Chaque **préfixe** est un faux `C:\` rangé dans `~/Games/FXW/prefixes/`. Par défaut, tout
va dans le préfixe `principal`, comme sur un seul PC Windows. Un programme qui se trouve
dans un préfixe est toujours relancé dans ce préfixe.

**Compiler un programme Windows** sans quitter Fedora :

```sh
x86_64-w64-mingw32-gcc bonjour.c -o bonjour.exe
./bonjour.exe
```

### Réglages

Dans `~/.config/fxw/fxw.conf` :

```sh
FXW_ENGINE=auto          # auto | proton | wine
FXW_PROTON=GE-Proton     # vide = UMU-Proton ; GE-Proton = dernière GE-Proton
FXW_HUD=1                # MangoHud toujours affiché
FXW_MENU_CATEGORY=Game   # catégorie des raccourcis créés
```

### Steam

Dans Steam : **Paramètres > Compatibilité > Activer Steam Play pour tous les autres
titres**. Les jeux Windows s'installent ensuite comme sous Windows. Pour un `.exe` acheté
ailleurs : **Jeux > Ajouter un jeu non-Steam**, puis **Propriétés > Compatibilité >
Forcer Proton**.

## Ce qui marche, ce qui ne marche pas

Environ **85 à 90 % des jeux Windows** se lancent sous Linux (analyse des données ProtonDB,
octobre 2025), et environ 30 000 jeux sont classés « Vérifié » ou « Jouable » sur
Steam Deck. Sur AMD, les performances sont souvent égales à Windows. Sur NVIDIA, les jeux
DirectX 12 sont encore un peu plus lents.

| Ça marche | Ça ne marche pas (bloqué par l'éditeur) |
|---|---|
| Counter-Strike 2, Dota 2, Deadlock (natifs) | **Valorant, League of Legends, 2XKO** (Vanguard) |
| Elden Ring, Cyberpunk, Baldur's Gate 3… | **Fortnite** (Epic refuse d'activer Linux) |
| Overwatch 2, Halo Infinite, Sea of Thieves | **Apex Legends** (bloqué depuis octobre 2024) |
| Rocket League, The Finals, Hunt Showdown | **GTA Online** (le mode histoire de GTA V marche) |
| Dead by Daylight (version Steam), War Thunder | **Battlefield 6, EA FC** (anti-triche Javelin) |
| Minecraft Java (natif) | **Call of Duty / Warzone**, PUBG, Rainbow Six Siege, Destiny 2, Rust |
| Steam, Heroic (Epic, GOG), Lutris (Battle.net, EA, Ubisoft) | Xbox app, Game Pass PC, Microsoft Store |
| Logiciels simples, vieux Office | Microsoft 365, Photoshop récent, pilotes, outils RGB, antivirus |

Avant d'acheter un jeu, vérifie-le sur [protondb.com](https://www.protondb.com) et, pour les
jeux en ligne, sur [areweanticheatyet.com](https://areweanticheatyet.com). Un jeu en ligne
peut cesser de marcher après une mise à jour de son anti-triche.

### Pourquoi Valorant ne marchera jamais ici

Vanguard est un **pilote du noyau Windows** : il démarre avec Windows et vérifie que la
machine est un vrai Windows non modifié (Secure Boot, TPM). Wine et Proton font tourner des
programmes, jamais des pilotes noyau. Et Riot bloque volontairement Linux et les machines
virtuelles. Contourner ces vérifications serait de la triche, sanctionnée par un
bannissement du compte et du matériel.

**Solution honnête : le double démarrage.** Installe Windows à côté de Fedora (idéalement
sur un deuxième SSD). Le script ajoute alors l'icône **Redémarrer sous Windows** :

```sh
fxw windows     # redémarre UNE fois sous Windows ; le démarrage suivant revient sur Fedora
```

## Allègement

Fedora démarre déjà peu de services, mais le script coupe ceux qui ne servent à rien sur un PC
de jeu, et note chacun pour pouvoir le réactiver (`./install.sh --uninstall`) :

- toujours : le rafraîchissement automatique de `dnf` (il le fait lui-même au besoin) et les
  rapports de plantage automatiques ;
- s'ils ne servent pas sur ta machine : le service des modems 4G/5G, iSCSI, NFS ;
- **seulement si tu réponds oui** : l'impression (si tu n'as aucune imprimante), le Bluetooth
  (si tu n'as aucune manette, casque ou souris Bluetooth), le téléchargement des mises à jour en
  arrière-plan par GNOME Logiciels.

Avec `--yes`, les trois derniers ne sont jamais coupés. Jamais touchés : le pare-feu, l'heure,
la protection contre le manque de mémoire, les mises à jour de micrologiciel, le son.

## Sécurité

Wine et Proton ne sont **pas** des bacs à sable : un `.exe` lancé peut lire et modifier
tous tes fichiers personnels (le lecteur `Z:` voit tout le système). Ne lance que des
programmes de confiance, comme sous Windows. Pour un logiciel douteux, utilise **Bottles**
(installé par le script), dont les « bouteilles » sont isolées.

## Désinstaller

```sh
./install.sh --uninstall    # retire fxw et l'intégration, réactive les services coupés ;
                            # garde Steam, Wine et tes jeux
```

## Dépannage

| Problème | Solution |
|---|---|
| Un jeu ne démarre pas | `fxw run --wine jeu.exe` (autre moteur), `fxw tricks vcrun2022`, journal dans `~/.local/state/fxw/logs/` |
| Écran noir après installation NVIDIA | Attends 5 minutes (compilation du pilote), puis redémarre |
| Écran bleu « MOK Manager » au démarrage | Normal avec Secure Boot : *Enroll MOK > Continue > Yes*, puis le mot de passe choisi |
| GTX 9xx/10xx : pas de pilote | `./install.sh --nvidia=580xx` |
| Le double-clic ouvre un autre programme | Clic droit > Ouvrir avec > « Programme Windows » > par défaut |
| Tout vérifier | `fxw doctor` |
